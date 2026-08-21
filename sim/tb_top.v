`timescale 1ns/1ps

module tb_top;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire [5:0] led;
    wire pa_en;
    wire hp_din;
    wire hp_ws;
    wire hp_bck;

    integer psg_writes = 0;
    integer bck_edges = 0;
    integer led_writes = 0;
    integer max_pcm = 0;
    reg saw_ram_execution = 1'b0;
    reg saw_boot_stage = 1'b0;
    reg saw_ram_stage = 1'b0;
    reg saw_app_stage = 1'b0;
    reg saw_psg_stage = 1'b0;
    reg saw_loop_led1 = 1'b0;
    reg saw_loop_led0 = 1'b0;

    always #18.518 clk = ~clk;

    top dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .led    (led),
        .PA_EN  (pa_en),
        .HP_DIN (hp_din),
        .HP_WS  (hp_ws),
        .HP_BCK (hp_bck)
    );

    always @(posedge dut.u_soc.u_io.psg_wr)
        psg_writes = psg_writes + 1;

    always @(posedge hp_bck)
        bck_edges = bck_edges + 1;

    always @(posedge clk) begin
        if (dut.u_soc.pcm_left > max_pcm)
            max_pcm = dut.u_soc.pcm_left;
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
        #600000000;

        if (psg_writes < 10) begin
            $display("FAIL: only %0d PSG writes", psg_writes);
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
            (dut.u_soc.psg_regs[79:72] != 8'h0C) ||
            (dut.u_soc.psg_regs[87:80] != 8'h0C)) begin
            $display("FAIL: PSG shadow registers do not match firmware writes");
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

        $display("PASS: RAM execution=yes LED writes=%0d PSG writes=%0d BCK edges=%0d PCM peak=%0d",
                 led_writes, psg_writes, bck_edges, max_pcm);
        $finish;
    end
endmodule
