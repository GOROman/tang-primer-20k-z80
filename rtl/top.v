module top (
    input  wire clk,
    input  wire rst_n,
    input  wire vol_down_n,
    input  wire vol_up_n,
    output wire [5:0] led,
    output wire PA_EN,
    output wire HP_DIN,
    output wire HP_WS,
    output wire HP_BCK,
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n,
    output wire       ulpi_rst,
    input  wire       ulpi_clk,
    input  wire       ulpi_dir,
    input  wire       ulpi_nxt,
    output wire       ulpi_stp,
    inout  wire [7:0] ulpi_data
);
    wire reset_n_int;
    wire [15:0] pcm_left;
    wire [15:0] pcm_right;
    wire [5:0] debug_led;
    wire [127:0] psg_regs;
    wire [3:0] psg_selected;
    wire [127:0] psg2_regs;
    wire [3:0] psg2_selected;
    wire [95:0] z80_regs;
    wire [7:0] z80_r;
    wire [127:0] ram_dump;
    wire [3:0] volume_level;
    wire usb_clock_alive;
    wire usb_dir_seen;
    wire usb_nxt_seen;

    reset_sync u_reset (
        .clk         (clk),
        .rst_n_async (rst_n),
        .rst_n       (reset_n_int)
    );

    z80_soc u_soc (
        .clk_sys   (clk),
        .rst_n     (reset_n_int),
        .vol_down_n(vol_down_n),
        .vol_up_n  (vol_up_n),
        .pcm_left  (pcm_left),
        .pcm_right (pcm_right),
        .debug_led (debug_led),
        .psg_regs  (psg_regs),
        .psg_selected (psg_selected),
        .psg2_regs (psg2_regs),
        .psg2_selected (psg2_selected),
        .z80_regs (z80_regs),
        .z80_r    (z80_r),
        .ram_dump (ram_dump),
        .volume_level(volume_level)
    );

    pt8211_tx u_audio_tx (
        .clk       (clk),
        .rst_n     (reset_n_int),
        .pcm_left  (pcm_left),
        .pcm_right (pcm_right),
        .hp_bck    (HP_BCK),
        .hp_ws     (HP_WS),
        .hp_din    (HP_DIN),
        .pa_en     (PA_EN)
    );

    // The six Dock LEDs are active-low.
    assign led = ~(debug_led | {usb_clock_alive, usb_dir_seen, usb_nxt_seen, 3'b000});

`ifdef SIMULATION
    assign O_tmds_clk_p  = 1'b0;
    assign O_tmds_clk_n  = 1'b0;
    assign O_tmds_data_p = 3'b000;
    assign O_tmds_data_n = 3'b000;
    assign ulpi_rst       = 1'b1;
    assign ulpi_stp       = 1'b0;
    assign ulpi_data      = 8'hZZ;
    assign usb_clock_alive = 1'b0;
    assign usb_dir_seen    = 1'b0;
    assign usb_nxt_seen    = 1'b0;
`else
    hdmi_output u_hdmi (
        .clk_27m       (clk),
        .rst_n         (reset_n_int),
        .psg_regs      (psg_regs),
        .psg_selected  (psg_selected),
        .psg2_regs     (psg2_regs),
        .psg2_selected (psg2_selected),
        .z80_regs      (z80_regs),
        .z80_r         (z80_r),
        .ram_dump      (ram_dump),
        .volume_level  (volume_level),
        .tmds_clk_p    (O_tmds_clk_p),
        .tmds_clk_n    (O_tmds_clk_n),
        .tmds_data_p   (O_tmds_data_p),
        .tmds_data_n   (O_tmds_data_n)
    );

    usb_uvc_output u_usb_uvc (
        .rst_n         (reset_n_int),
        .psg_regs      (psg_regs),
        .psg_selected  (psg_selected),
        .ulpi_rst      (ulpi_rst),
        .ulpi_clk      (ulpi_clk),
        .ulpi_dir      (ulpi_dir),
        .ulpi_nxt      (ulpi_nxt),
        .ulpi_stp      (ulpi_stp),
        .ulpi_data     (ulpi_data),
        .usb_clock_alive (usb_clock_alive),
        .usb_dir_seen    (usb_dir_seen),
        .usb_nxt_seen    (usb_nxt_seen)
    );
`endif
endmodule
