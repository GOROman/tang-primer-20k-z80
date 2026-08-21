module hdmi_output (
    input  wire         clk_27m,
    input  wire         rst_n,
    input  wire [127:0] psg_regs,
    input  wire [3:0]   psg_selected,
    input  wire [127:0] psg2_regs,
    input  wire [3:0]   psg2_selected,
    input  wire [95:0]  z80_regs,
    input  wire [7:0]   z80_r,
    input  wire [127:0] ram_dump,
    input  wire [3:0]   volume_level,
    output wire         tmds_clk_p,
    output wire         tmds_clk_n,
    output wire [2:0]   tmds_data_p,
    output wire [2:0]   tmds_data_n
);
    wire clk_pixel;
    wire clk_5x;
    wire pll_locked;
    wire video_reset = !(rst_n && pll_locked);
    wire active;
    wire hsync;
    wire vsync;
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    hdmi_clock u_clock (
        .clk_27m  (clk_27m),
        .reset_n  (rst_n),
        .clk_pixel(clk_pixel),
        .clk_5x   (clk_5x),
        .locked   (pll_locked)
    );

    hdmi_psg_debug u_debug (
        .clk_pixel   (clk_pixel),
        .reset       (video_reset),
        .psg_regs    (psg_regs),
        .psg_selected(psg_selected),
        .psg2_regs   (psg2_regs),
        .psg2_selected(psg2_selected),
        .z80_regs    (z80_regs),
        .z80_r       (z80_r),
        .ram_dump    (ram_dump),
        .volume_level(volume_level),
        .active      (active),
        .hsync       (hsync),
        .vsync       (vsync),
        .red         (red),
        .green       (green),
        .blue        (blue)
    );

    hdmi_tx_wrapper u_tx (
        .reset       (video_reset),
        .clk_pixel   (clk_pixel),
        .clk_5x      (clk_5x),
        .active      (active),
        .hsync       (hsync),
        .vsync       (vsync),
        .red         (red),
        .green       (green),
        .blue        (blue),
        .tmds_data_p (tmds_data_p),
        .tmds_data_n (tmds_data_n),
        .tmds_clk_p  (tmds_clk_p),
        .tmds_clk_n  (tmds_clk_n)
    );
endmodule
