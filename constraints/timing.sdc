# Timing Constraints for USB Mouse Emulator

# Primary input clock - 27 MHz from oscillator
create_clock -name clk_in -period 37.037 [get_ports {clk}]

# PLL generated clock - 48 MHz
create_clock -name clk_48m -period 20.833 [get_nets {clk_rst_inst/pll_clk}]

# Mark clk_d (unused PLL output) as false path to suppress routing warnings
# This is the CLKOUTD output from the PLL that is not used in the design
set_false_path -from [get_clocks clk_d] -to [get_clocks *]
set_false_path -from [get_clocks *] -to [get_clocks clk_d]

# Asynchronous inputs
set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {pattern_select[*]}]
set_false_path -from [get_ports {pattern_enable}]

# USB signals are asynchronous to internal clock
set_false_path -from [get_ports {usb_dp}]
set_false_path -from [get_ports {usb_dn}]
