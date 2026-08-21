set_device -name GW2A-18C GW2A-LV18PG256C8/I7
set_option -top_module top
set_option -verilog_std v2001
set_option -vhdl_std vhd2008
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1

add_file third_party/tv80/rtl/core/tv80n.v
add_file third_party/tv80/rtl/core/tv80_core.v
add_file third_party/tv80/rtl/core/tv80_mcode.v
add_file third_party/tv80/rtl/core/tv80_alu.v
add_file third_party/tv80/rtl/core/tv80_reg.v

add_file third_party/jt49/hdl/jt49.v
add_file third_party/jt49/hdl/jt49_cen.v
add_file third_party/jt49/hdl/jt49_div.v
add_file third_party/jt49/hdl/jt49_eg.v
add_file third_party/jt49/hdl/jt49_exp.v
add_file third_party/jt49/hdl/jt49_noise.v

add_file impl/generated/hdmi_tx_gw.vhd

add_file rtl/reset_sync.v
add_file rtl/soc_memory.v
add_file rtl/io_decoder.v
add_file rtl/psg_wrapper.v
add_file rtl/audio_mixer.v
add_file rtl/pt8211_tx.v
add_file rtl/hdmi_tx_wrapper.vhd
add_file rtl/hdmi_clock.v
add_file rtl/hdmi_psg_debug.v
add_file rtl/hdmi_output.v
add_file rtl/z80_soc.v
add_file rtl/top.v
add_file constraints/tang_primer_20k.cst
add_file constraints/tang_primer_20k.sdc

run all
