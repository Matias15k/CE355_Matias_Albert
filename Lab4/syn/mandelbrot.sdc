#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "50MHz" [get_ports clk_50]
derive_pll_clocks
derive_clock_uncertainty
set_false_path -from [get_ports {reset_n keys_n[*]}]
set_false_path -to [get_ports {hdmi_tx_clk hdmi_tx_d[*] hdmi_tx_hs hdmi_tx_vs hdmi_tx_de}]
set_false_path -from [get_ports {hdmi_tx_int i2c_sda}]
set_false_path -to [get_ports {i2c_scl i2c_sda}]
set viewport_regs [get_registers {*u_viewport|x0_r* *u_viewport|y0_r* *u_viewport|pixel_step_r*}]
set_multicycle_path -setup 4 -from $viewport_regs -to $viewport_regs
set_multicycle_path -hold 3 -from $viewport_regs -to $viewport_regs


