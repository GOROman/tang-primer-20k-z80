GOWIN_ROOT ?= /Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE
GOWIN_SH ?= $(GOWIN_ROOT)/bin/gw_sh

.PHONY: init firmware uvc-core build sim sim-uvc clean

init:
	git submodule update --init --recursive

firmware:
	mkdir -p firmware/generated
	z80asm --list=firmware/generated/boot.lst \
		--output=firmware/generated/boot.bin firmware/boot/boot.asm
	z80asm --list=firmware/generated/psg_demo.lst \
		--output=firmware/generated/psg_demo.bin firmware/psg_demo/main.asm
	python3 tools/bin2hex.py firmware/generated/boot.bin firmware/generated/boot.hex
	python3 tools/bin2hex.py firmware/generated/psg_demo.bin firmware/generated/psg_demo.hex \
		--size 57344

uvc-core:
	AMARANTH_USE_YOSYS=system python3 tools/generate_uvc_core.py

build: firmware
	python3 tools/prepare_hdmi_tx.py
	DYLD_LIBRARY_PATH=$(GOWIN_ROOT)/lib DYLD_FRAMEWORK_PATH=$(GOWIN_ROOT)/lib $(GOWIN_SH) run.tcl

sim: firmware
	cd rtl && iverilog -g2005 -DSIMULATION -o ../sim/top_sim \
		../sim/tb_top.v reset_sync.v soc_memory.v io_decoder.v \
		psg_wrapper.v audio_mixer.v pt8211_tx.v hdmi_psg_debug.v z80_soc.v top.v \
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

sim-uvc:
	cd rtl && iverilog -g2005 -o ../sim/uvc_sim \
		../sim/tb_usb_uvc_stream.v psg_debug_pixel.v usb_uvc_stream.v
	cd rtl && vvp ../sim/uvc_sim

clean:
	rm -rf impl
	rm -f sim/top_sim sim/uvc_sim sim/top.vcd firmware/generated/*.bin firmware/generated/*.lst
