`timescale 1ns/1ps

module tb_top;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg vol_down_n = 1'b1;
    reg vol_up_n = 1'b1;
    wire [5:0] led;
    wire pa_en;
    wire hp_din;
    wire hp_ws;
    wire hp_bck;

    integer psg1_writes = 0;
    integer psg2_writes = 0;
    integer bck_edges = 0;
    integer led_writes = 0;
    integer max_pcm = 0;
    integer pc_changes = 0;
    integer r_changes = 0;
    reg [15:0] last_pc = 16'd0;
    reg [7:0] last_r = 8'd0;
    reg saw_ram_execution = 1'b0;
    reg saw_boot_stage = 1'b0;
    reg saw_ram_stage = 1'b0;
    reg saw_app_stage = 1'b0;
    reg saw_psg_stage = 1'b0;
    reg saw_loop_led1 = 1'b0;
    reg saw_loop_led0 = 1'b0;
    reg saw_noise_period = 1'b0;
    reg saw_kick_noise = 1'b0;
    reg saw_snare_noise = 1'b0;
    reg saw_hat_noise = 1'b0;
    reg saw_noise_enable = 1'b0;
    reg saw_envelope_shape = 1'b0;
    reg saw_volume_zero = 1'b0;
    reg saw_volume_restore = 1'b0;
    reg saw_z80_snapshot = 1'b0;

    always #18.518 clk = ~clk;

    top dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .vol_down_n(vol_down_n),
        .vol_up_n(vol_up_n),
        .led    (led),
        .PA_EN  (pa_en),
        .HP_DIN (hp_din),
        .HP_WS  (hp_ws),
        .HP_BCK (hp_bck)
    );

    always @(posedge dut.u_soc.u_io.psg_wr) begin
        psg1_writes = psg1_writes + 1;
    end

    always @(posedge dut.u_soc.u_io.psg2_wr) begin
        psg2_writes = psg2_writes + 1;
        if (dut.u_soc.u_io.psg2_addr == 4'd6)
            saw_noise_period = 1'b1;
        if ((dut.u_soc.u_io.psg2_addr == 4'd6) &&
            (dut.u_soc.u_io.psg2_din == 8'h1F))
            saw_kick_noise = 1'b1;
        if ((dut.u_soc.u_io.psg2_addr == 4'd6) &&
            (dut.u_soc.u_io.psg2_din == 8'h08))
            saw_snare_noise = 1'b1;
        if ((dut.u_soc.u_io.psg2_addr == 4'd6) &&
            (dut.u_soc.u_io.psg2_din == 8'h02))
            saw_hat_noise = 1'b1;
        if ((dut.u_soc.u_io.psg2_addr == 4'd7) &&
            (dut.u_soc.u_io.psg2_din == 8'h1C))
            saw_noise_enable = 1'b1;
        if ((dut.u_soc.u_io.psg2_addr == 4'd13) &&
            (dut.u_soc.u_io.psg2_din == 8'h0E))
            saw_envelope_shape = 1'b1;
    end

    always @(posedge hp_bck)
        bck_edges = bck_edges + 1;

    always @(posedge clk) begin
        if (dut.u_soc.pcm_left > max_pcm)
            max_pcm = dut.u_soc.pcm_left;
        if (dut.u_soc.volume_level == 0)
            saw_volume_zero = 1'b1;
        if (saw_volume_zero && (dut.u_soc.volume_level == 1))
            saw_volume_restore = 1'b1;
        if (dut.u_soc.z80_regs[15:0] != 16'h0000)
            saw_z80_snapshot = 1'b1;
        if (dut.u_soc.z80_regs[15:0] != last_pc) begin
            pc_changes = pc_changes + 1;
            last_pc = dut.u_soc.z80_regs[15:0];
        end
        if (dut.u_soc.z80_r != last_r) begin
            r_changes = r_changes + 1;
            last_r = dut.u_soc.z80_r;
        end
    end

    initial begin
        // S2 lowers 10% to mute; after release, S3 restores 10%.
        #10000000 vol_down_n = 1'b0;
        #25000000 vol_down_n = 1'b1;
        #5000000  vol_up_n = 1'b0;
        #25000000 vol_up_n = 1'b1;
    end

    always @(posedge clk) begin
        if (dut.u_soc.u_io.write_start &&
            (dut.u_soc.cpu_addr[7:0] == 8'hB0)) begin
            led_writes = led_writes + 1;
            case (dut.u_soc.cpu_dout[5:0])
                6'h20: saw_boot_stage = 1'b1;
                6'h10: saw_ram_stage  = 1'b1;
                6'h08: saw_app_stage  = 1'b1;
                6'h04: saw_psg_stage  = 1'b1;
                6'h02: saw_loop_led1  = 1'b1;
                6'h01: saw_loop_led0  = 1'b1;
                default: ;
            endcase
        end
    end

    always @(posedge clk) begin
        if (!dut.u_soc.mreq_n && !dut.u_soc.rd_n &&
            (dut.u_soc.cpu_addr == 16'h2000))
            saw_ram_execution = 1'b1;
    end

    initial begin
`ifdef DUMP_VCD
        $dumpfile("../sim/top.vcd");
        $dumpvars(0, tb_top);
`endif
        #1000 rst_n = 1'b1;
        #300000000;

        if ((psg1_writes < 10) || (psg2_writes < 20)) begin
            $display("FAIL: PSG writes PSG1=%0d PSG2=%0d",
                     psg1_writes, psg2_writes);
            $finish;
        end
        if (!saw_ram_execution) begin
            $display("FAIL: Z80 did not fetch code from RAM at 2000h");
            $finish;
        end
        if (led_writes < 6) begin
            $display("FAIL: only %0d LED writes", led_writes);
            $finish;
        end
        if (!saw_noise_period) begin
            $display("FAIL: Z80 did not program PSG noise period register 6");
            $finish;
        end
        if (!(saw_kick_noise && saw_snare_noise && saw_hat_noise)) begin
            $display("FAIL: missing PSG noise drums kick=%0d snare=%0d hat=%0d",
                     saw_kick_noise, saw_snare_noise, saw_hat_noise);
            $finish;
        end
        if (dut.u_soc.ram_dump[31:0] != 32'hB0D3083E) begin
            $display("FAIL: HDMI RAM dump starts %08x",
                     dut.u_soc.ram_dump[31:0]);
            $finish;
        end
        if (!saw_noise_enable) begin
            $display("FAIL: Z80 did not enable PSG noise in mixer register 7");
            $finish;
        end
        if (!saw_envelope_shape) begin
            $display("FAIL: Z80 did not retrigger PSG2 envelope shape");
            $finish;
        end
        if (!(saw_volume_zero && saw_volume_restore) ||
            (dut.u_soc.volume_level != 1)) begin
            $display("FAIL: volume buttons zero=%0d restore=%0d level=%0d",
                     saw_volume_zero, saw_volume_restore,
                     dut.u_soc.volume_level);
            $finish;
        end
        if (!saw_z80_snapshot ||
            (dut.u_soc.z80_regs[15:13] != 3'b001) ||
            (dut.u_soc.z80_regs[95:92] != 4'hF) ||
            (pc_changes < 10) || (r_changes < 10)) begin
            $display("FAIL: Z80 debug PC=%04x SP=%04x R=%02x PCchg=%0d Rchg=%0d",
                     dut.u_soc.z80_regs[15:0],
                     dut.u_soc.z80_regs[95:80], dut.u_soc.z80_r,
                     pc_changes, r_changes);
            $finish;
        end
        if (bck_edges < 100) begin
            $display("FAIL: only %0d BCK rising edges", bck_edges);
            $finish;
        end
        if (pa_en !== 1'b1) begin
            $display("FAIL: PA_EN did not become active");
            $finish;
        end
        if ((dut.u_soc.psg_regs[7:0] != 8'h93) ||
            (dut.u_soc.psg_regs[15:8] != 8'h01) ||
            (dut.u_soc.psg_regs[63:56] != 8'h38) ||
            (dut.u_soc.psg_regs[71:64] != 8'h07) ||
            (dut.u_soc.psg_regs[79:72] != 8'h06) ||
            (dut.u_soc.psg_regs[87:80] != 8'h06)) begin
            $display("FAIL: PSG1 shadow registers do not match canon chord");
            $finish;
        end
        if ((dut.u_soc.psg2_regs[63:56] != 8'h1C) ||
            (dut.u_soc.psg2_regs[71:64] != 8'h10) ||
            (dut.u_soc.psg2_regs[79:72] != 8'h10) ||
            (dut.u_soc.psg2_regs[87:80] != 8'h00) ||
            (dut.u_soc.psg2_regs[95:88] != 8'h00) ||
            (dut.u_soc.psg2_regs[103:96] != 8'h01) ||
            (dut.u_soc.psg2_regs[111:104] != 8'h0E) ||
            (dut.u_soc.psg2_regs[23:16] !=
             (dut.u_soc.psg2_regs[7:0] + 8'd2))) begin
            $display("FAIL: PSG2 shadow registers do not match detune/envelope/noise");
            $finish;
        end
        if ((max_pcm == 0) || (max_pcm > 3069)) begin
            $display("FAIL: PCM peak %0d is outside 10-percent gain range", max_pcm);
            $finish;
        end
        if (!(saw_boot_stage && saw_ram_stage && saw_app_stage &&
              saw_psg_stage && saw_loop_led1 && saw_loop_led0)) begin
            $display("FAIL: missing LED stage: boot=%0d ram=%0d app=%0d psg=%0d loop1=%0d loop0=%0d",
                     saw_boot_stage, saw_ram_stage, saw_app_stage,
                     saw_psg_stage, saw_loop_led1, saw_loop_led0);
            $finish;
        end

        $display("PASS: RAM=yes DUMP=%08x PSG1=%0d PSG2=%0d Z80PC=%04x SP=%04x R=%02x PCchg=%0d Rchg=%0d VOL=%0d detune=yes triangle-envelope=yes drums=yes LED=%0d BCK=%0d PCM=%0d",
                 dut.u_soc.ram_dump[31:0],
                 psg1_writes, psg2_writes, dut.u_soc.z80_regs[15:0],
                 dut.u_soc.z80_regs[95:80], dut.u_soc.z80_r,
                 pc_changes, r_changes, dut.u_soc.volume_level,
                 led_writes, bck_edges, max_pcm);
        $finish;
    end
endmodule
