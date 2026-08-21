module hdmi_clock (
    input  wire clk_27m,
    input  wire reset_n,
    output wire clk_pixel,
    output wire clk_5x,
    output wire locked
);
    wire clkoutp_unused;
    wire clkoutd_unused;
    wire clkoutd3_unused;

    // 27 MHz / 3 * 14 = 126 MHz. CLKDIV / 5 gives 25.2 MHz.
    rPLL u_pll (
        .CLKOUT   (clk_5x),
        .LOCK     (locked),
        .CLKOUTP  (clkoutp_unused),
        .CLKOUTD  (clkoutd_unused),
        .CLKOUTD3 (clkoutd3_unused),
        .RESET    (~reset_n),
        .RESET_P  (1'b0),
        .CLKIN    (clk_27m),
        .CLKFB    (1'b0),
        .FBDSEL   (6'b0),
        .IDSEL    (6'b0),
        .ODSEL    (6'b0),
        .PSDA     (4'b0),
        .DUTYDA   (4'b0),
        .FDLY     (4'b0)
    );

    defparam u_pll.FCLKIN = "27";
    defparam u_pll.DYN_IDIV_SEL = "false";
    defparam u_pll.IDIV_SEL = 2;
    defparam u_pll.DYN_FBDIV_SEL = "false";
    defparam u_pll.FBDIV_SEL = 13;
    defparam u_pll.DYN_ODIV_SEL = "false";
    defparam u_pll.ODIV_SEL = 4;
    defparam u_pll.PSDA_SEL = "0000";
    defparam u_pll.DYN_DA_EN = "true";
    defparam u_pll.DUTYDA_SEL = "1000";
    defparam u_pll.CLKOUT_FT_DIR = 1'b1;
    defparam u_pll.CLKOUTP_FT_DIR = 1'b1;
    defparam u_pll.CLKFB_SEL = "internal";
    defparam u_pll.CLKOUT_BYPASS = "false";
    defparam u_pll.CLKOUTP_BYPASS = "false";
    defparam u_pll.CLKOUTD_BYPASS = "false";
    defparam u_pll.DYN_SDIV_SEL = 2;
    defparam u_pll.CLKOUTD_SRC = "CLKOUT";
    defparam u_pll.CLKOUTD3_SRC = "CLKOUT";
    defparam u_pll.DEVICE = "GW2A-18C";

    CLKDIV u_clkdiv (
        .RESETN (reset_n & locked),
        .HCLKIN (clk_5x),
        .CLKOUT (clk_pixel),
        .CALIB  (1'b1)
    );
    defparam u_clkdiv.DIV_MODE = "5";
    defparam u_clkdiv.GSREN = "false";
endmodule
