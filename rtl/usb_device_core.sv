module usb_device_core (
    input  logic        clk,
    input  logic        rst_n,

    // PHY Interface
    input  logic        usb_dp_i,
    input  logic        usb_dn_i,
    output logic        usb_dp_o,
    output logic        usb_dn_o,
    output logic        usb_oe,

    // HID Interface
    input  logic [7:0]  hid_tx_data,
    input  logic        hid_tx_valid,
    output logic        hid_tx_ready,
    output logic        usb_configured,
    
    // Debug/Status
    output logic        led_configured,
    output logic        led_activity
);

    logic       tx_data_valid;
    logic       tx_pkt_start;
    logic       tx_pkt_end;
    logic       tx_ready;
    
    // Missing declarations
    logic       sending;
    logic [3:0] tx_pid;
    logic [7:0] tx_data;
    
    // RX signals from packet handler
    logic [3:0] rx_pid;
    logic       rx_pid_valid;
    logic [7:0] rx_data;
    logic       rx_data_valid;
    logic       rx_pkt_start;
    logic       rx_pkt_end;
    logic       rx_crc_err;

    usb_packet packet_handler (
        .clk_48m(clk),
        .rst_n(rst_n),
        .usb_dp_i(usb_dp_i),
        .usb_dn_i(usb_dn_i),
        .usb_dp_o(usb_dp_o),
        .usb_dn_o(usb_dn_o),
        .usb_oe(usb_oe),
        .rx_pid(rx_pid),
        .rx_pid_valid(rx_pid_valid),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_pkt_start(rx_pkt_start),
        .rx_pkt_end(rx_pkt_end),
        .rx_crc_err(rx_crc_err),
        .tx_pid(tx_pid),
        .tx_data(tx_data),
        .tx_data_valid(tx_data_valid),
        .tx_pkt_start(tx_pkt_start),
        .tx_pkt_end(tx_pkt_end),
        .tx_ready(tx_ready)
    );

    // -------------------------------------------------------------------------
    // Protocol Constants
    // -------------------------------------------------------------------------
    localparam PID_OUT   = 4'b0001;
    localparam PID_IN    = 4'b1001;
    localparam PID_SOF   = 4'b0101;
    localparam PID_SETUP = 4'b1101;
    localparam PID_DATA0 = 4'b0011;
    localparam PID_DATA1 = 4'b1011;
    localparam PID_ACK   = 4'b0010;
    localparam PID_NAK   = 4'b1010;
    localparam PID_STALL = 4'b1110;

    // -------------------------------------------------------------------------
    // State Machine
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_RX_TOKEN,
        ST_RX_DATA,
        ST_TX_HANDSHAKE,
        ST_TX_DATA,
        ST_RX_HANDSHAKE,
        ST_WAIT_EOP
    } state_t;

    state_t state;
    
    logic [6:0] dev_addr;
    logic [6:0] target_addr;
    logic [3:0] target_endp;
    logic [3:0] token_pid;
    
    logic [7:0] setup_data [0:7];
    logic [2:0] setup_idx;
    logic       setup_received;
    
    logic       data0_1; // Data toggle for EP0
    logic       ep1_data_toggle;
    
    // Control Transfer State
    logic [15:0] wValue, wIndex, wLength;
    logic [7:0]  bmRequestType, bRequest;
    
    // Descriptor Reader
    logic [15:0] desc_byte_index;
    logic [7:0]  desc_data_out;
    logic        desc_valid;
    
    usb_descriptors descriptors (
        .requested_length(wLength),
        .data_out(desc_data_out),
        .byte_index(desc_byte_index),
        .descriptor_type(wValue[15:8]),
        .descriptor_index(wValue[7:0]),
        .valid(desc_valid)
    );

    // Address logic
    logic [6:0] new_addr;
    logic       set_addr_pending;

    // Token Data Capture
    logic [15:0] token_data;
    logic [1:0]  token_byte_cnt;

    assign usb_configured = (dev_addr != 0); 
    assign led_configured = usb_configured;
    assign led_activity = (state != ST_IDLE);

    // Main FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            dev_addr <= 0;
            new_addr <= 0;
            set_addr_pending <= 0;
            setup_received <= 0;
            data0_1 <= 0;
            ep1_data_toggle <= 0;
            sending <= 0;
            tx_pkt_start <= 0;
            tx_pkt_end <= 0;
            tx_data_valid <= 0;
            desc_byte_index <= 0;
            hid_tx_ready <= 0;
            token_byte_cnt <= 0;
            setup_idx <= 0;
        end else begin
            // Default signals
            tx_pkt_start <= 0;
            tx_pkt_end <= 0;
            tx_data_valid <= 0;
            hid_tx_ready <= 0;

            case (state)
                ST_IDLE: begin
                    if (rx_pkt_start) begin
                        state <= ST_RX_TOKEN;
                        token_byte_cnt <= 0;
                    end
                end

                ST_RX_TOKEN: begin
                    if (rx_pid_valid) begin
                        token_pid <= rx_pid;
                    end
                    
                    if (rx_data_valid) begin
                        token_data <= {rx_data, token_data[15:8]}; // LSB first
                        token_byte_cnt <= token_byte_cnt + 1;
                    end
                    
                    if (rx_pkt_end) begin
                        // Parse Token
                        // Token format: ADDR(7) ENDP(4) CRC(5)
                        // token_data[6:0] = ADDR
                        // token_data[10:7] = ENDP
                        target_addr <= token_data[6:0];
                        target_endp <= token_data[10:7];
                        
                        if (token_pid == PID_SOF) begin
                            state <= ST_IDLE; // Ignore SOF
                        end else if (target_addr == dev_addr) begin
                            if (token_pid == PID_SETUP) begin
                                state <= ST_RX_DATA; // Expect DATA0 next
                                setup_idx <= 0;
                            end else if (token_pid == PID_OUT) begin
                                state <= ST_RX_DATA;
                            end else if (token_pid == PID_IN) begin
                                state <= ST_TX_DATA;
                                // Prepare data to send
                                if (target_endp == 0) begin
                                    // Control IN
                                    if (setup_received) begin
                                        // We are in Data Stage of Control Transfer
                                        if (bmRequestType[7]) begin // Device to Host
                                            if (bRequest == 6) begin // GET_DESCRIPTOR
                                                 // Data is ready in descriptors module
                                            end
                                        end
                                    end
                                end
                            end else begin
                                state <= ST_IDLE;
                            end
                        end else begin
                            state <= ST_IDLE; // Not for us
                        end
                    end
                end

                ST_RX_DATA: begin
                    if (rx_data_valid) begin
                        if (token_pid == PID_SETUP) begin
                            setup_data[setup_idx] <= rx_data;
                            setup_idx <= setup_idx + 1;
                        end
                    end
                    
                    if (rx_pkt_end) begin
                        if (!rx_crc_err) begin
                            // Send ACK
                            tx_pid <= PID_ACK;
                            tx_pkt_start <= 1;
                            state <= ST_TX_HANDSHAKE;
                            
                            if (token_pid == PID_SETUP) begin
                                setup_received <= 1;
                                bmRequestType <= setup_data[0];
                                bRequest <= setup_data[1];
                                wValue <= {setup_data[3], setup_data[2]};
                                wIndex <= {setup_data[5], setup_data[4]};
                                wLength <= {setup_data[7], setup_data[6]};
                                desc_byte_index <= 0;
                                data0_1 <= 1; // Next IN will be DATA1
                            end
                        end else begin
                            state <= ST_IDLE; // Ignore if CRC error
                        end
                    end
                end

                ST_TX_HANDSHAKE: begin
                    if (tx_ready) begin
                        tx_pkt_end <= 1;
                        state <= ST_WAIT_EOP;
                    end
                end

                ST_TX_DATA: begin
                    // Handle IN transfer
                    if (target_endp == 0) begin
                        // EP0 Control
                        if (setup_received) begin
                            if (bRequest == 6) begin // GET_DESCRIPTOR
                                if (!sending) begin
                                    tx_pid <= data0_1 ? PID_DATA1 : PID_DATA0;
                                    tx_pkt_start <= 1;
                                    sending <= 1;
                                end
                                
                                if (tx_ready) begin
                                    if (desc_valid && desc_byte_index < wLength) begin
                                        tx_data <= desc_data_out;
                                        tx_data_valid <= 1;
                                        desc_byte_index <= desc_byte_index + 1;
                                    end else begin
                                        tx_pkt_end <= 1;
                                        state <= ST_RX_HANDSHAKE;
                                        data0_1 <= !data0_1;
                                        sending <= 0;
                                    end
                                end
                            end else if (bRequest == 5) begin // SET_ADDRESS
                                // Status stage (ZLP)
                                if (!sending) begin
                                    tx_pid <= PID_DATA1;
                                    tx_pkt_start <= 1;
                                    sending <= 1;
                                end
                                if (tx_ready) begin
                                    tx_pkt_end <= 1;
                                    state <= ST_RX_HANDSHAKE;
                                    set_addr_pending <= 1;
                                    new_addr <= wValue[6:0];
                                    sending <= 0;
                                end
                            end else begin
                                // Unknown/Unsupported -> STALL
                                tx_pid <= PID_STALL;
                                tx_pkt_start <= 1;
                                state <= ST_TX_HANDSHAKE;
                            end
                        end
                    end else if (target_endp == 1) begin
                        // EP1 HID
                        if (!sending) begin
                            if (hid_tx_valid) begin
                                tx_pid <= ep1_data_toggle ? PID_DATA1 : PID_DATA0;
                                tx_pkt_start <= 1;
                                sending <= 1;
                            end else begin
                                tx_pid <= PID_NAK;
                                tx_pkt_start <= 1;
                                state <= ST_TX_HANDSHAKE;
                            end
                        end else begin
                            if (tx_ready) begin
                                if (hid_tx_valid) begin
                                    tx_data <= hid_tx_data;
                                    tx_data_valid <= 1;
                                    hid_tx_ready <= 1; // Ack to HID manager
                                end else begin
                                    tx_pkt_end <= 1;
                                    state <= ST_RX_HANDSHAKE;
                                    sending <= 0;
                                end
                            end
                        end
                    end
                end
                
                ST_RX_HANDSHAKE: begin
                    // Wait for ACK from host
                    if (rx_pkt_end) begin
                        if (rx_pid == PID_ACK) begin
                            if (set_addr_pending) begin
                                dev_addr <= new_addr;
                                set_addr_pending <= 0;
                            end
                            if (target_endp == 1) begin
                                ep1_data_toggle <= !ep1_data_toggle;
                            end
                        end
                        state <= ST_IDLE;
                    end
                end

                ST_WAIT_EOP: begin
                    // Wait for TX to finish
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
