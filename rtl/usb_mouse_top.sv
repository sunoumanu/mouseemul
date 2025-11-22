module usb_mouse_top (
    input  logic       clk,      // 27 MHz
    input  logic       rst_n,    // S1
    
    inout  logic       usb_dp,
    inout  logic       usb_dn,
    
    input  logic [1:0] pattern_select, // S1, S2
    input  logic       pattern_enable, // S3
    
    output logic [5:0] led
);

    // Clock & Reset
    logic clk_48m;
    logic sys_rst_n;
    
    clock_reset clk_rst_inst (
        .clk_in(clk),
        .rst_n_in(rst_n),
        .clk_48m(clk_48m),
        .rst_n_out(sys_rst_n)
    );

    // USB PHY Signals
    logic usb_dp_out, usb_dn_out, usb_oe;
    logic usb_dp_in, usb_dn_in;
    
    // Bidirectional Buffer
    assign usb_dp = usb_oe ? usb_dp_out : 1'bz;
    assign usb_dn = usb_oe ? usb_dn_out : 1'bz;
    assign usb_dp_in = usb_dp;
    assign usb_dn_in = usb_dn;

    // Signals
    logic [7:0] mouse_x, mouse_y;
    logic [2:0] buttons;
    logic       report_req;
    
    logic [7:0] hid_tx_data;
    logic       hid_tx_valid;
    logic       hid_tx_ready;
    logic       usb_configured;
    
    // Pattern Generator
    pattern_generator pat_gen (
        .clk(clk_48m),
        .rst_n(sys_rst_n),
        .enable(pattern_enable),
        .pattern_sel(pattern_select),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .report_req(report_req)
    );

    // HID Report Manager
    hid_report_manager hid_mgr (
        .clk(clk_48m),
        .rst_n(sys_rst_n),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .report_req(report_req),
        .tx_data(hid_tx_data),
        .tx_valid(hid_tx_valid),
        .tx_ready(hid_tx_ready),
        .usb_configured(usb_configured)
    );

    // USB Device Core
    usb_device_core usb_core (
        .clk(clk_48m),
        .rst_n(sys_rst_n),
        .usb_dp_i(usb_dp_in),
        .usb_dn_i(usb_dn_in),
        .usb_dp_o(usb_dp_out),
        .usb_dn_o(usb_dn_out),
        .usb_oe(usb_oe),
        .hid_tx_data(hid_tx_data),
        .hid_tx_valid(hid_tx_valid),
        .hid_tx_ready(hid_tx_ready),
        .usb_configured(usb_configured),
        .led_configured(led[2]),
        .led_activity(led[5])
    );

    // LEDs
    // LED[0]: Heartbeat
    logic [24:0] hb_cnt;
    always_ff @(posedge clk_48m) hb_cnt <= hb_cnt + 25'd1;
    assign led[0] = hb_cnt[24];
    
    assign led[1] = sys_rst_n; // PLL Lock / Reset status
    assign led[3] = pattern_enable;
    assign led[4] = report_req; // Blink on report

endmodule
