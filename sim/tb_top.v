`timescale 1ns/1ps

module tb_top;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire led;
    wire pa_en;
    wire hp_din;
    wire hp_ws;
    wire hp_bck;

    integer psg_writes = 0;
    integer bck_edges = 0;
    reg saw_ram_execution = 1'b0;

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
        if (!dut.u_soc.mreq_n && !dut.u_soc.rd_n &&
            (dut.u_soc.cpu_addr == 16'h2000))
            saw_ram_execution = 1'b1;
    end

    initial begin
        $dumpfile("../sim/top.vcd");
        $dumpvars(0, tb_top);
        #1000 rst_n = 1'b1;
        #2000000;

        if (psg_writes < 10) begin
            $display("FAIL: only %0d PSG writes", psg_writes);
            $finish;
        end
        if (!saw_ram_execution) begin
            $display("FAIL: Z80 did not fetch code from RAM at 2000h");
            $finish;
        end
        if (bck_edges < 100) begin
            $display("FAIL: only %0d BCK rising edges", bck_edges);
            $finish;
        end
        if (led !== 1'b0) begin
            $display("FAIL: RAM test LED did not indicate success");
            $finish;
        end

        $display("PASS: RAM execution=yes PSG writes=%0d BCK edges=%0d",
                 psg_writes, bck_edges);
        $finish;
    end
endmodule
