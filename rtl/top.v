module top (
    input  wire clk,
    input  wire rst_n,
    output wire led,
    output wire PA_EN,
    output wire HP_DIN,
    output wire HP_WS,
    output wire HP_BCK
);
    wire reset_n_int;
    wire [15:0] pcm_left;
    wire [15:0] pcm_right;
    wire debug_led;

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
        .debug_led (debug_led)
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

    // The Dock LED is active-low.
    assign led = ~debug_led;
endmodule
