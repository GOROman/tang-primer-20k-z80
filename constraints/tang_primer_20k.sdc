create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_clock -name ulpi_clk -period 16.667 -waveform {0 5.75} [get_ports {ulpi_clk}]
set_clock_latency -source 0.4 [get_clocks {ulpi_clk}]
create_generated_clock -name clk_cpu -source [get_ports {clk}] -divide_by 8 [get_nets {u_soc/cpu_div[2]}]
