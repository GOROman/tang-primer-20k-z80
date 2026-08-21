module z80_soc (
    input  wire        clk_sys,
    input  wire        rst_n,
    output wire [15:0] pcm_left,
    output wire [15:0] pcm_right,
    output wire [5:0]  debug_led,
    output wire [127:0] psg_regs,
    output wire [3:0]  psg_selected
);
    reg [2:0] cpu_div;
    wire clk_cpu = cpu_div[2];

    wire [15:0] cpu_addr;
    wire [7:0]  cpu_dout;
    wire [7:0]  cpu_din;
    wire [7:0]  mem_dout;
    wire [7:0]  io_dout;
    wire        mreq_n;
    wire        iorq_n;
    wire        rd_n;
    wire        wr_n;

    wire [3:0] psg_addr;
    wire [7:0] psg_din;
    wire [7:0] psg_dout;
    wire       psg_wr;
    wire [9:0] psg_sound;

    assign psg_selected = psg_addr;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)
            cpu_div <= 3'd0;
        else
            cpu_div <= cpu_div + 3'd1;
    end

    assign cpu_din = (!iorq_n && !rd_n) ? io_dout : mem_dout;

    tv80n #(
        .Mode(0),
        .T2Write(0),
        .IOWait(1)
    ) u_cpu (
        .reset_n (rst_n),
        .clk     (clk_cpu),
        .wait_n  (1'b1),
        .int_n   (1'b1),
        .nmi_n   (1'b1),
        .busrq_n (1'b1),
        .di      (cpu_din),
        .A       (cpu_addr),
        .dout    (cpu_dout),
        .m1_n    (),
        .mreq_n  (mreq_n),
        .iorq_n  (iorq_n),
        .rd_n    (rd_n),
        .wr_n    (wr_n),
        .rfsh_n  (),
        .halt_n  (),
        .busak_n ()
    );

    soc_memory u_memory (
        .clk    (clk_sys),
        .addr   (cpu_addr),
        .din    (cpu_dout),
        .mreq_n (mreq_n),
        .rd_n   (rd_n),
        .wr_n   (wr_n),
        .dout   (mem_dout)
    );

    io_decoder u_io (
        .clk       (clk_sys),
        .rst_n     (rst_n),
        .port      (cpu_addr[7:0]),
        .cpu_dout  (cpu_dout),
        .iorq_n    (iorq_n),
        .rd_n      (rd_n),
        .wr_n      (wr_n),
        .psg_dout  (psg_dout),
        .psg_addr  (psg_addr),
        .psg_din   (psg_din),
        .psg_wr    (psg_wr),
        .psg_regs  (psg_regs),
        .debug_led (debug_led),
        .cpu_din   (io_dout)
    );

    psg_wrapper u_psg (
        .clk   (clk_sys),
        .rst_n (rst_n),
        .addr  (psg_addr),
        .din   (psg_din),
        .wr    (psg_wr),
        .dout  (psg_dout),
        .sound (psg_sound)
    );

    audio_mixer u_mixer (
        .psg_sound (psg_sound),
        .pcm_left  (pcm_left),
        .pcm_right (pcm_right)
    );
endmodule
