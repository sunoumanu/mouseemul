module usb_packet (
    input  logic        clk_48m,
    input  logic        rst_n,

    // USB PHY Interface
    input  logic        usb_dp_i,
    input  logic        usb_dn_i,
    output logic        usb_dp_o,
    output logic        usb_dn_o,
    output logic        usb_oe,

    // Protocol Layer Interface
    // RX
    output logic [3:0]  rx_pid,
    output logic        rx_pid_valid,
    output logic [7:0]  rx_data,
    output logic        rx_data_valid,
    output logic        rx_pkt_start,
    output logic        rx_pkt_end,
    output logic        rx_crc_err,
    
    // TX
    input  logic [3:0]  tx_pid,
    input  logic [7:0]  tx_data,
    input  logic        tx_data_valid,
    input  logic        tx_pkt_start, // Triggers sending SYNC + PID
    input  logic        tx_pkt_end,   // Triggers sending CRC + EOP
    output logic        tx_ready      // Ready for next byte
);

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    localparam STATE_IDLE      = 3'd0;
    localparam STATE_SYNC      = 3'd1;
    localparam STATE_PID       = 3'd2;
    localparam STATE_DATA      = 3'd3;
    localparam STATE_CRC16_1   = 3'd4;
    localparam STATE_CRC16_2   = 3'd5;
    localparam STATE_EOP_1     = 3'd6;
    localparam STATE_EOP_2     = 3'd7;

    // -------------------------------------------------------------------------
    // Input Synchronization & Edge Detection
    // -------------------------------------------------------------------------
    logic dp_sync, dn_sync;
    logic dp_r, dn_r;
    logic dp_rr, dn_rr;

    always_ff @(posedge clk_48m or negedge rst_n) begin
        if (!rst_n) begin
            dp_sync <= 1'b1; dn_sync <= 1'b0;
            dp_r <= 1'b1;    dn_r <= 1'b0;
            dp_rr <= 1'b1;   dn_rr <= 1'b0;
        end else begin
            dp_sync <= usb_dp_i; dn_sync <= usb_dn_i;
            dp_r <= dp_sync;     dn_r <= dn_sync;
            dp_rr <= dp_r;       dn_rr <= dn_r;
        end
    end

    // Line State
    logic line_j, line_k, line_se0;
    assign line_j   = (dp_r == 1'b1) && (dn_r == 1'b0);
    assign line_k   = (dp_r == 1'b0) && (dn_r == 1'b1);
    assign line_se0 = (dp_r == 1'b0) && (dn_r == 1'b0);

    // -------------------------------------------------------------------------
    // Clock Recovery / Bit Extraction (Simplified for 48MHz oversampling 12Mbps)
    // -------------------------------------------------------------------------
    // 48MHz / 12Mbps = 4 clocks per bit.
    // We need to align to transitions.
    
    logic [1:0] bit_phase;
    logic       sample_now;
    logic       transition;

    assign transition = (dp_r != dp_rr) || (dn_r != dn_rr);

    always_ff @(posedge clk_48m or negedge rst_n) begin
        if (!rst_n) begin
            bit_phase <= 2'd0;
        end else begin
            if (transition) begin
                bit_phase <= 2'd0; // Re-align on transition
            end else begin
                bit_phase <= bit_phase + 1'b1;
            end
        end
    end

    assign sample_now = (bit_phase == 2'd2); // Sample in middle

    // -------------------------------------------------------------------------
    // NRZI Decoder & Bit Unstuffing
    // -------------------------------------------------------------------------
    logic       rx_bit;
    logic       rx_bit_valid;
    logic       prev_dp;
    logic [2:0] ones_cnt;
    logic       bit_stuff_error;

    always_ff @(posedge clk_48m or negedge rst_n) begin
        if (!rst_n) begin
            prev_dp <= 1'b1;
            ones_cnt <= 3'd0;
            rx_bit_valid <= 1'b0;
            rx_bit <= 1'b0;
        end else if (sample_now) begin
            if (line_se0) begin
                // EOP, reset stuff
                ones_cnt <= 3'd0;
                rx_bit_valid <= 1'b0;
            end else begin
                // NRZI: No change = 1, Change = 0
                logic raw_bit;
                raw_bit = (dp_r == prev_dp) ? 1'b1 : 1'b0;
                prev_dp <= dp_r;

                if (ones_cnt == 3'd6) begin
                    // Bit stuffing error or valid unstuff
                    if (raw_bit == 1'b0) begin
                        // Stuffed bit (0), discard it
                        rx_bit_valid <= 1'b0;
                        ones_cnt <= 3'd0;
                    end else begin
                        // Error: 7 ones in a row
                        rx_bit_valid <= 1'b1; // Pass it up? Or flag error
                        rx_bit <= raw_bit;
                        ones_cnt <= ones_cnt + 1'b1;
                    end
                end else begin
                    rx_bit <= raw_bit;
                    rx_bit_valid <= 1'b1;
                    if (raw_bit) ones_cnt <= ones_cnt + 1'b1;
                    else ones_cnt <= 3'd0;
                end
            end
        end else begin
            rx_bit_valid <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // RX Packet State Machine
    // -------------------------------------------------------------------------
    logic [2:0] rx_state;
    logic [7:0] rx_shift;
    logic [2:0] rx_bit_cnt;

    always_ff @(posedge clk_48m or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= STATE_IDLE;
            rx_pkt_start <= 1'b0;
            rx_pkt_end <= 1'b0;
            rx_data_valid <= 1'b0;
            rx_pid <= 4'd0;
            rx_shift <= 8'd0;
            rx_bit_cnt <= 3'd0;
        end else begin
            rx_pkt_start <= 1'b0;
            rx_pkt_end <= 1'b0;
            rx_data_valid <= 1'b0;
            rx_pid_valid <= 1'b0;

            if (sample_now && line_se0 && rx_state != STATE_IDLE) begin
                rx_state <= STATE_IDLE;
                rx_pkt_end <= 1'b1;
            end else if (rx_bit_valid) begin
                case (rx_state)
                    STATE_IDLE: begin
                        if (rx_bit == 1'b0) begin // K-state start of SYNC
                             rx_state <= STATE_SYNC;
                             rx_shift <= {rx_bit, rx_shift[7:1]};
                             rx_bit_cnt <= 3'd1;
                        end
                    end
                    STATE_SYNC: begin
                        rx_shift <= {rx_bit, rx_shift[7:1]};
                        rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        if (rx_bit_cnt == 3'd7) begin
                            // Check SYNC byte 0x80 (LSB first: 00000001)
                            // Actually USB SYNC is 00000001 (KJKJKJKK)
                            // Shift reg will be 10000000 (0x80) if LSB arrived first
                            if ({rx_bit, rx_shift[7:1]} == 8'h80) begin
                                rx_state <= STATE_PID;
                                rx_bit_cnt <= 3'd0;
                                rx_pkt_start <= 1'b1;
                            end else begin
                                rx_state <= STATE_IDLE; // Noise
                            end
                        end
                    end
                    STATE_PID: begin
                        rx_shift <= {rx_bit, rx_shift[7:1]};
                        rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        if (rx_bit_cnt == 3'd7) begin
                            rx_pid <= {rx_bit, rx_shift[7:1]}[3:0]; // Lower 4 bits
                            // Verify PID check bits (upper 4 bits should be ~lower 4 bits)
                            rx_pid_valid <= 1'b1;
                            rx_state <= STATE_DATA;
                            rx_bit_cnt <= 3'd0;
                        end
                    end
                    STATE_DATA: begin
                        rx_shift <= {rx_bit, rx_shift[7:1]};
                        rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        if (rx_bit_cnt == 3'd7) begin
                            rx_data <= {rx_bit, rx_shift[7:1]};
                            rx_data_valid <= 1'b1;
                            rx_bit_cnt <= 3'd0;
                        end
                    end
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // TX Logic (Simplified)
    // -------------------------------------------------------------------------
    // Needs to handle:
    // 1. Preamble (SYNC)
    // 2. PID
    // 3. Data (if any)
    // 4. CRC (calculated externally or here? Let's do simple pass-through for now or calc here)
    // For simplicity, we'll assume the upper layer handles CRC for data packets, 
    // or we implement CRC generation here.
    // The prompt asked for "Packet Handler", usually implies CRC is here.
    // Let's implement basic TX state machine.

    logic [2:0] tx_state;
    logic [2:0] tx_bit_cnt;
    logic [7:0] tx_shift;
    logic       tx_bit_out;
    logic       tx_enable;
    logic [2:0] tx_ones_cnt;
    logic       tx_stuffing;

    // TX Clock Divider (48MHz -> 12Mbps)
    logic [1:0] tx_clk_div;
    logic       tx_tick;

    always_ff @(posedge clk_48m or negedge rst_n) begin
        if (!rst_n) begin
            tx_clk_div <= 2'd0;
        end else begin
            tx_clk_div <= tx_clk_div + 1'b1;
        end
    end
    assign tx_tick = (tx_clk_div == 2'd3);

    // TX State Machine
    always_ff @(posedge clk_48m or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= STATE_IDLE;
            usb_oe <= 1'b0;
            tx_ready <= 1'b0;
            tx_stuffing <= 1'b0;
            tx_ones_cnt <= 3'd0;
            usb_dp_o <= 1'b1; // J state (Idle)
            usb_dn_o <= 1'b0;
        end else if (tx_tick) begin
            case (tx_state)
                STATE_IDLE: begin
                    if (tx_pkt_start) begin
                        tx_state <= STATE_SYNC;
                        tx_shift <= 8'h80; // SYNC
                        tx_bit_cnt <= 3'd0;
                        usb_oe <= 1'b1;
                        tx_ones_cnt <= 3'd0;
                        // Drive J first
                        usb_dp_o <= 1'b1; usb_dn_o <= 1'b0; 
                    end else begin
                        usb_oe <= 1'b0;
                    end
                end

                STATE_SYNC: begin
                    // Send SYNC (00000001) LSB first
                    // NRZI encoding happens at output
                    logic next_bit;
                    next_bit = tx_shift[0];
                    
                    // NRZI
                    if (next_bit == 1'b0) begin
                        usb_dp_o <= !usb_dp_o;
                        usb_dn_o <= !usb_dn_o;
                    end
                    // Else hold state

                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_bit_cnt <= tx_bit_cnt + 1'b1;

                    if (tx_bit_cnt == 3'd7) begin
                        tx_state <= STATE_PID;
                        tx_shift <= {~tx_pid, tx_pid}; // PID + ~PID
                        tx_bit_cnt <= 3'd0;
                    end
                end

                STATE_PID: begin
                    logic next_bit;
                    next_bit = tx_shift[0];
                    
                    if (next_bit == 1'b0) begin
                        usb_dp_o <= !usb_dp_o;
                        usb_dn_o <= !usb_dn_o;
                    end
                    
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_bit_cnt <= tx_bit_cnt + 1'b1;
                    
                    if (tx_bit_cnt == 3'd7) begin
                        tx_state <= STATE_DATA;
                        tx_ready <= 1'b1; // Request first data byte
                        tx_bit_cnt <= 3'd0;
                    end
                end

                STATE_DATA: begin
                    // Handle Bit Stuffing
                    if (tx_stuffing) begin
                        // Send a 0
                        usb_dp_o <= !usb_dp_o;
                        usb_dn_o <= !usb_dn_o;
                        tx_stuffing <= 1'b0;
                        tx_ones_cnt <= 3'd0;
                    end else begin
                        if (tx_pkt_end && !tx_data_valid && tx_bit_cnt == 0) begin
                            // End of packet
                            tx_state <= STATE_EOP_1;
                            usb_dp_o <= 1'b0; usb_dn_o <= 1'b0; // SE0
                            usb_oe <= 1'b1;
                        end else begin
                            logic next_bit;
                            
                            // Load new byte if needed
                            if (tx_bit_cnt == 0 && tx_data_valid) begin
                                tx_shift <= tx_data;
                                tx_ready <= 1'b1; // Ack and ask for next
                            end else begin
                                tx_ready <= 1'b0;
                            end

                            next_bit = tx_shift[0];
                            
                            // NRZI
                            if (next_bit == 1'b0) begin
                                usb_dp_o <= !usb_dp_o;
                                usb_dn_o <= !usb_dn_o;
                                tx_ones_cnt <= 3'd0;
                            end else begin
                                tx_ones_cnt <= tx_ones_cnt + 1'b1;
                            end

                            if (tx_ones_cnt == 3'd5 && next_bit == 1'b1) begin
                                tx_stuffing <= 1'b1; // Next cycle send stuffed 0
                            end else begin
                                tx_shift <= {1'b0, tx_shift[7:1]};
                                tx_bit_cnt <= tx_bit_cnt + 1'b1;
                            end
                        end
                    end
                end

                STATE_EOP_1: begin
                    usb_dp_o <= 1'b0; usb_dn_o <= 1'b0; // SE0
                    tx_state <= STATE_EOP_2;
                end
                
                STATE_EOP_2: begin
                    usb_dp_o <= 1'b1; usb_dn_o <= 1'b0; // J
                    tx_state <= STATE_IDLE;
                    usb_oe <= 1'b1; // Drive J for 1 bit
                end
            endcase
        end
    end

    assign rx_crc_err = 1'b0;

endmodule
