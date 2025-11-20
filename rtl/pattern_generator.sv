module pattern_generator (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control
    input  logic        enable,
    input  logic [1:0]  pattern_sel, // 0: Circle, 1: Square, 2: Figure-8, 3: Random
    
    // Output
    output logic [7:0]  mouse_x,
    output logic [7:0]  mouse_y,
    output logic [2:0]  buttons,
    output logic        report_req
);

    // Timing
    // 48 MHz clock. Report rate 100 Hz -> 480,000 cycles
    localparam TICKS_PER_REPORT = 480_000;
    logic [19:0] tick_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= 0;
            report_req <= 0;
        end else begin
            if (enable) begin
                if (tick_cnt >= TICKS_PER_REPORT - 1) begin
                    tick_cnt <= 0;
                    report_req <= 1;
                end else begin
                    tick_cnt <= tick_cnt + 1;
                    report_req <= 0;
                end
            end else begin
                report_req <= 0;
            end
        end
    end

    // Pattern Logic
    logic [7:0] angle; // 0-255 for 0-2pi
    
    // Simple LUT for Sin/Cos (Partial) or algorithmic generation
    // For simplicity, let's use a small lookup table or just some basic math
    // Actually, for a circle, we need sin/cos.
    // Let's implement a simple CORDIC or just a small LUT.
    // Or even simpler: Square wave is easy. Circle needs sin/cos.
    
    // Let's use a 64-entry LUT for 1/4 sine wave
    logic [7:0] sin_lut [0:63];
    initial begin
        // Generate some values... approximated
        // 127 * sin(i * pi/2 / 64)
        sin_lut[0] = 0;   sin_lut[1] = 3;   sin_lut[2] = 6;   sin_lut[3] = 9;
        sin_lut[4] = 12;  sin_lut[5] = 16;  sin_lut[6] = 19;  sin_lut[7] = 22;
        sin_lut[8] = 25;  sin_lut[9] = 28;  sin_lut[10]= 31;  sin_lut[11]= 34;
        sin_lut[12]= 37;  sin_lut[13]= 40;  sin_lut[14]= 43;  sin_lut[15]= 46;
        sin_lut[16]= 49;  sin_lut[17]= 51;  sin_lut[18]= 54;  sin_lut[19]= 57;
        sin_lut[20]= 60;  sin_lut[21]= 62;  sin_lut[22]= 65;  sin_lut[23]= 67;
        sin_lut[24]= 70;  sin_lut[25]= 72;  sin_lut[26]= 75;  sin_lut[27]= 77;
        sin_lut[28]= 79;  sin_lut[29]= 81;  sin_lut[30]= 83;  sin_lut[31]= 85;
        sin_lut[32]= 87;  sin_lut[33]= 89;  sin_lut[34]= 91;  sin_lut[35]= 93;
        sin_lut[36]= 94;  sin_lut[37]= 96;  sin_lut[38]= 97;  sin_lut[39]= 99;
        sin_lut[40]= 100; sin_lut[41]= 101; sin_lut[42]= 103; sin_lut[43]= 104;
        sin_lut[44]= 105; sin_lut[45]= 106; sin_lut[46]= 107; sin_lut[47]= 108;
        sin_lut[48]= 109; sin_lut[49]= 110; sin_lut[50]= 111; sin_lut[51]= 111;
        sin_lut[52]= 112; sin_lut[53]= 113; sin_lut[54]= 113; sin_lut[55]= 114;
        sin_lut[56]= 114; sin_lut[57]= 114; sin_lut[58]= 115; sin_lut[59]= 115;
        sin_lut[60]= 115; sin_lut[61]= 115; sin_lut[62]= 115; sin_lut[63]= 115;
    end

    function logic signed [7:0] get_sin(input logic [7:0] theta);
        logic [1:0] quad;
        logic [5:0] idx;
        quad = theta[7:6];
        idx = theta[5:0];
        case (quad)
            0: return sin_lut[idx];
            1: return sin_lut[63-idx];
            2: return -sin_lut[idx];
            3: return -sin_lut[63-idx];
        endcase
    endfunction

    function logic signed [7:0] get_cos(input logic [7:0] theta);
        return get_sin(theta + 64);
    endfunction

    // Random Generator (LFSR)
    logic [15:0] lfsr;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) lfsr <= 16'hACE1;
        else if (report_req) lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // Pattern State
    logic [7:0] step_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_cnt <= 0;
            mouse_x <= 0;
            mouse_y <= 0;
            buttons <= 0;
        end else if (report_req) begin
            step_cnt <= step_cnt + 1;
            
            case (pattern_sel)
                2'd0: begin // Circle
                    // We need DELTA values, not absolute position.
                    // x = R * cos(t), y = R * sin(t)
                    // dx = -R * sin(t) * dt, dy = R * cos(t) * dt
                    // Let's just output small values based on sin/cos
                    mouse_x <= get_sin(step_cnt) >>> 3; // Scale down
                    mouse_y <= get_cos(step_cnt) >>> 3;
                end
                
                2'd1: begin // Square
                    // Move right, then down, then left, then up
                    if (step_cnt[7:6] == 0) begin mouse_x <= 5; mouse_y <= 0; end
                    else if (step_cnt[7:6] == 1) begin mouse_x <= 0; mouse_y <= 5; end
                    else if (step_cnt[7:6] == 2) begin mouse_x <= -5; mouse_y <= 0; end
                    else begin mouse_x <= 0; mouse_y <= -5; end
                end
                
                2'd2: begin // Figure-8
                    // x = sin(t), y = sin(2t)
                    mouse_x <= get_cos(step_cnt) >>> 3; // dx/dt of sin(t) is cos(t)
                    mouse_y <= get_cos(step_cnt << 1) >>> 3; // dx/dt of sin(2t) is 2cos(2t)
                end
                
                2'd3: begin // Random
                    mouse_x <= lfsr[3:0] - 4'd8;
                    mouse_y <= lfsr[7:4] - 4'd8;
                end
            endcase
        end
    end

endmodule
