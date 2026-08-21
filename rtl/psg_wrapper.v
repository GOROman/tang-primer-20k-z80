module psg_wrapper (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] addr,
    input  wire [7:0] din,
    input  wire       wr,
    output wire [7:0] dout,
    output wire [9:0] sound
);
    reg [3:0] enable_div;
    wire psg_clk_en = (enable_div == 4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            enable_div <= 4'd0;
        else
            enable_div <= enable_div + 4'd1;
    end

    jt49 #(
        .CLKDIV(3)
    ) u_jt49 (
        .rst_n   (rst_n),
        .clk     (clk),
        .clk_en  (psg_clk_en),
        .addr    (addr),
        .cs_n    (~wr),
        .wr_n    (~wr),
        .din     (din),
        .sel     (1'b1),
        .dout    (dout),
        .sound   (sound),
        .A       (),
        .B       (),
        .C       (),
        .sample  (),
        .IOA_in  (8'hFF),
        .IOA_out (),
        .IOA_oe  (),
        .IOB_in  (8'hFF),
        .IOB_out (),
        .IOB_oe  ()
    );
endmodule
