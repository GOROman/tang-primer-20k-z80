module top (
    input  wire clk,
    input  wire rst_n,
    output wire [5:0] led,
    output wire PA_EN,
    output wire HP_DIN,
    output wire HP_WS,
    output wire HP_BCK,
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);
    wire reset_n_int;
    wire [15:0] pcm_left;
    wire [15:0] pcm_right;
    wire [5:0] debug_led;
    wire [127:0] psg_regs;
    wire [3:0] psg_selected;

    reset_sync u_reset (
        .clk         (clk),
        .rst_n_async (rst_n),
        .rst_n       (reset_n_int)
    );

    z80_soc u_soc (
        .clk_sys   (clk),
        .rst_n     (reset_n_int),
        .pcm_left  (pcm_left),
        .pcm_right (pcm_right),
        .debug_led (debug_led),
        .psg_regs  (psg_regs),
        .psg_selected (psg_selected)
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
    assign led = ~debug_led;

`ifdef SIMULATION
    assign O_tmds_clk_p  = 1'b0;
    assign O_tmds_clk_n  = 1'b0;
    assign O_tmds_data_p = 3'b000;
    assign O_tmds_data_n = 3'b000;
`else
    hdmi_output u_hdmi (
        .clk_27m       (clk),
        .rst_n         (reset_n_int),
        .psg_regs      (psg_regs),
        .psg_selected  (psg_selected),
        .tmds_clk_p    (O_tmds_clk_p),
        .tmds_clk_n    (O_tmds_clk_n),
        .tmds_data_p   (O_tmds_data_p),
        .tmds_data_n   (O_tmds_data_n)
    );
`endif
endmodule
