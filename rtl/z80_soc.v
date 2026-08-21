module z80_soc (
    input  wire        clk_sys,
    input  wire        rst_n,
    input  wire        vol_down_n,
    input  wire        vol_up_n,
    output wire [15:0] pcm_left,
    output wire [15:0] pcm_right,
    output wire [5:0]  debug_led,
    output wire [127:0] psg_regs,
    output wire [3:0]  psg_selected,
    output wire [127:0] psg2_regs,
    output wire [3:0]  psg2_selected,
    output wire [95:0] z80_regs,
    output wire [7:0]  z80_r,
    output wire [127:0] ram_dump,
    output wire [3:0]  volume_level
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
    wire        m1_n;
    wire [95:0] z80_snapshot_regs;
    reg [15:0] live_pc;
    reg [7:0] refresh_r;
    reg fetch_prev;
    wire fetch_active = !m1_n && !mreq_n && !rd_n;

    wire [3:0] psg_addr;
    wire [7:0] psg_din;
    wire [7:0] psg_dout;
    wire       psg_wr;
    wire [9:0] psg_sound;
    wire [3:0] psg2_addr;
    wire [7:0] psg2_din;
    wire [7:0] psg2_dout;
    wire       psg2_wr;
    wire [9:0] psg2_sound;

    assign psg_selected = psg_addr;
    assign psg2_selected = psg2_addr;
    assign z80_regs = {z80_snapshot_regs[95:16], live_pc};
    assign z80_r = refresh_r;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)
            cpu_div <= 3'd0;
        else
            cpu_div <= cpu_div + 3'd1;
    end

    // Capture the address of every opcode-fetch M1 cycle. R increments once
    // per M1 while preserving bit 7, matching the Z80 refresh-register rule.
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            live_pc    <= 16'd0;
            refresh_r  <= 8'd0;
            fetch_prev <= 1'b0;
        end else begin
            fetch_prev <= fetch_active;
            if (fetch_active && !fetch_prev) begin
                live_pc <= cpu_addr;
                refresh_r <= {refresh_r[7], refresh_r[6:0] + 7'd1};
            end
        end
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
        .m1_n    (m1_n),
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
        .dout   (mem_dout),
        .debug_dump(ram_dump)
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
        .psg2_dout (psg2_dout),
        .psg_addr  (psg_addr),
        .psg_din   (psg_din),
        .psg_wr    (psg_wr),
        .psg_regs  (psg_regs),
        .psg2_addr (psg2_addr),
        .psg2_din  (psg2_din),
        .psg2_wr   (psg2_wr),
        .psg2_regs (psg2_regs),
        .z80_regs  (z80_snapshot_regs),
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

    psg_wrapper u_psg2 (
        .clk   (clk_sys),
        .rst_n (rst_n),
        .addr  (psg2_addr),
        .din   (psg2_din),
        .wr    (psg2_wr),
        .dout  (psg2_dout),
        .sound (psg2_sound)
    );

    audio_mixer u_mixer (
        .clk        (clk_sys),
        .rst_n      (rst_n),
        .vol_down_n (vol_down_n),
        .vol_up_n   (vol_up_n),
        .psg1_sound (psg_sound),
        .psg2_sound (psg2_sound),
        .volume_level(volume_level),
        .pcm_left  (pcm_left),
        .pcm_right (pcm_right)
    );
endmodule
