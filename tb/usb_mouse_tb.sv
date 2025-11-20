`timescale 1ns/1ps

module usb_mouse_tb;

    logic clk;
    logic rst_n;
    wire  usb_dp;
    wire  usb_dn;
    logic [1:0] pattern_select;
    logic pattern_enable;
    wire [5:0] led;

    // Instantiate Top Module
    usb_mouse_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .usb_dp(usb_dp),
        .usb_dn(usb_dn),
        .pattern_select(pattern_select),
        .pattern_enable(pattern_enable),
        .led(led)
    );

    // Clock Generation (27 MHz)
    initial begin
        clk = 0;
        forever #18.518 clk = ~clk;
    end

    // Pull-ups on USB lines
    assign (weak1, weak0) usb_dp = 1'b0; // Host pulldown
    assign (weak1, weak0) usb_dn = 1'b0;

    initial begin
        $dumpfile("usb_mouse_tb.vcd");
        $dumpvars(0, usb_mouse_tb);

        // Initialize
        rst_n = 0;
        pattern_select = 0;
        pattern_enable = 0;
        
        #1000;
        rst_n = 1;
        
        #10000;
        
        // Enable Pattern
        pattern_enable = 1;
        
        // Simulate some time
        #1000000;
        
        $finish;
    end

endmodule
