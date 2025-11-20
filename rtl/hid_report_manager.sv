module hid_report_manager (
    input  logic        clk,
    input  logic        rst_n,
    
    // Inputs from Pattern Generator
    input  logic [7:0]  mouse_x,
    input  logic [7:0]  mouse_y,
    input  logic [2:0]  buttons,
    input  logic        report_req, // Pulse when new data is ready
    
    // Interface to USB Core
    output logic [7:0]  tx_data,
    output logic        tx_valid,
    input  logic        tx_ready,   // USB Core is ready for next byte
    input  logic        usb_configured
);

    // Mouse Report Format (Boot Protocol):
    // Byte 0: Buttons (Bit 0: Left, 1: Right, 2: Middle)
    // Byte 1: X Displacement (Signed 8-bit)
    // Byte 2: Y Displacement (Signed 8-bit)
    // Byte 3: Wheel (Optional, we included it in descriptor)

    typedef enum logic [2:0] {
        IDLE,
        SEND_BTN,
        SEND_X,
        SEND_Y,
        SEND_WHEEL,
        DONE
    } state_t;

    state_t state;
    
    logic [7:0] saved_x, saved_y, saved_wheel;
    logic [2:0] saved_btns;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_valid <= 1'b0;
            tx_data <= 8'd0;
            saved_x <= 8'd0;
            saved_y <= 8'd0;
            saved_btns <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (report_req && usb_configured) begin
                        saved_x <= mouse_x;
                        saved_y <= mouse_y;
                        saved_btns <= buttons;
                        state <= SEND_BTN;
                        
                        tx_data <= {5'd0, buttons};
                        tx_valid <= 1'b1;
                    end else begin
                        tx_valid <= 1'b0;
                    end
                end

                SEND_BTN: begin
                    if (tx_ready) begin
                        tx_data <= saved_x;
                        tx_valid <= 1'b1;
                        state <= SEND_X;
                    end
                end

                SEND_X: begin
                    if (tx_ready) begin
                        tx_data <= saved_y;
                        tx_valid <= 1'b1;
                        state <= SEND_Y;
                    end
                end

                SEND_Y: begin
                    if (tx_ready) begin
                        tx_data <= 8'd0; // Wheel = 0
                        tx_valid <= 1'b1;
                        state <= SEND_WHEEL;
                    end
                end
                
                SEND_WHEEL: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
