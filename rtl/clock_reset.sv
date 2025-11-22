module clock_reset (
    input  logic clk_in,      // 27 MHz input from Tang Nano 20K
    input  logic rst_n_in,    // Active low reset button
    output logic clk_48m,     // 48 MHz output for USB
    output logic rst_n_out    // Synchronized active low reset
);

    logic       lock;
    logic       pll_clk;
    
    // Connect unused PLL outputs to wires to avoid routing warnings
    // The synthesis tool will optimize these away but won't complain
    (* keep = "true" *) logic clkoutd_unused;
    (* keep = "true" *) logic clkoutd3_unused;

    // Gowin rPLL Primitive to generate 48 MHz from 27 MHz
    // Fout = Fin * FBDIV / (IDIV * ODIV)
    // 48 = 27 * 16 / (9 * 1)
    // IDIV_SEL = 8 (divide by 9)
    // FBDIV_SEL = 15 (multiply by 16)
    // ODIV_SEL = 8 (divide by 1) -> This seems to be a specific encoding, let's check docs or use standard primitive
    // Actually, for Gowin rPLL, it's best to use the IP generated code pattern, but here we use the primitive directly.
    
    // GW2AR-18 rPLL parameters for 27MHz -> 48MHz
    rPLL #(
        .FCLKIN("27"),
        .DEVICE("GW2AR-18C"),
        .IDIV_SEL(8),      // /9
        .FBDIV_SEL(15),    // *16
        .ODIV_SEL(16)      // /16 (VCO = 27*16*16/9 = 768MHz, Out = 48MHz)
    ) pll_inst (
        .CLKOUT(pll_clk),
        .LOCK(lock),
        .CLKOUTP(),
        .CLKOUTD(clkoutd_unused),   // Connected to prevent routing warning
        .CLKOUTD3(clkoutd3_unused), // Connected to prevent routing warning
        .RESET(1'b0),      // No PLL reset
        .RESET_P(1'b0),
        .CLKIN(clk_in),
        .CLKFB(1'b0),
        .FBDSEL(6'b0),
        .IDSEL(6'b0),
        .ODSEL(6'b0),
        .PSDA(4'b0),
        .DUTYDA(4'b0),
        .FDLY(4'b0)
    );

    assign clk_48m = pll_clk;

    // Reset Synchronization
    // Wait for PLL lock, then release reset after a few cycles
    logic [3:0] reset_cnt;
    logic       safe_rst_n;

    always_ff @(posedge clk_48m or negedge lock) begin
        if (!lock) begin
            reset_cnt <= 4'd0;
            safe_rst_n <= 1'b0;
        end else begin
            if (reset_cnt == 4'd15) begin
                safe_rst_n <= 1'b1;
            end else begin
                reset_cnt <= reset_cnt + 1'b1;
                safe_rst_n <= 1'b0;
            end
        end
    end

    // Combine external reset and PLL lock reset
    // Synchronize external reset to 48MHz domain
    logic rst_n_meta, rst_n_sync;
    
    always_ff @(posedge clk_48m or negedge safe_rst_n) begin
        if (!safe_rst_n) begin
            rst_n_meta <= 1'b0;
            rst_n_sync <= 1'b0;
        end else begin
            rst_n_meta <= rst_n_in;
            rst_n_sync <= rst_n_meta;
        end
    end

    assign rst_n_out = rst_n_sync;

endmodule
