GOWIN_ROOT ?= /Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE
GOWIN_SH ?= $(GOWIN_ROOT)/bin/gw_sh

.PHONY: init build sim clean

init:
	git submodule update --init --recursive

build:
	DYLD_LIBRARY_PATH=$(GOWIN_ROOT)/lib DYLD_FRAMEWORK_PATH=$(GOWIN_ROOT)/lib $(GOWIN_SH) run.tcl

sim:
	cd rtl && iverilog -g2005 -o ../sim/top_sim \
		../sim/tb_top.v reset_sync.v soc_memory.v io_decoder.v \
		psg_wrapper.v audio_mixer.v pt8211_tx.v z80_soc.v top.v \
		../third_party/tv80/rtl/core/tv80n.v \
		../third_party/tv80/rtl/core/tv80_core.v \
		../third_party/tv80/rtl/core/tv80_mcode.v \
		../third_party/tv80/rtl/core/tv80_alu.v \
		../third_party/tv80/rtl/core/tv80_reg.v \
		../third_party/jt49/hdl/jt49.v \
		../third_party/jt49/hdl/jt49_cen.v \
		../third_party/jt49/hdl/jt49_div.v \
		../third_party/jt49/hdl/jt49_eg.v \
		../third_party/jt49/hdl/jt49_exp.v \
		../third_party/jt49/hdl/jt49_noise.v
	cd rtl && vvp ../sim/top_sim

clean:
	rm -rf impl
	rm -f sim/top_sim sim/top.vcd
