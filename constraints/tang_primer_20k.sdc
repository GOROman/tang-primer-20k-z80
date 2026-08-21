create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_generated_clock -name clk_cpu -source [get_ports {clk}] -divide_by 8 [get_nets {u_soc/cpu_div[2]}]
