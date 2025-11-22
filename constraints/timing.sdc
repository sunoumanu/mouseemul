# Timing Constraints for USB Mouse Emulator

# Primary input clock - 27 MHz from oscillator
create_clock -name clk_in -period 37.037 [get_ports {clk}]

# PLL generated clock - 48 MHz
# Note: The PLL output is already defined as clk_48m at the top level
create_clock -name clk_48m -period 20.833 [get_nets {clk_48m}]

# Asynchronous inputs - no timing relationship to internal clocks
set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {pattern_select[*]}]
set_false_path -from [get_ports {pattern_enable}]

# USB signals are asynchronous to internal clock
set_false_path -from [get_ports {usb_dp}]
set_false_path -from [get_ports {usb_dn}]
