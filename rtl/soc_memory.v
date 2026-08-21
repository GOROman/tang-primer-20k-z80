module soc_memory (
    input  wire        clk,
    input  wire [15:0] addr,
    input  wire [7:0]  din,
    input  wire        mreq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    output reg  [7:0]  dout
);
    reg [7:0] memory [0:65535];

    initial begin
        // Gowin resolves this path relative to this RTL source file.
        $readmemh("../firmware/boot.hex", memory, 0, 131);
    end

    always @(posedge clk) begin
        if (!mreq_n && !rd_n)
            dout <= memory[addr];

        if (!mreq_n && !wr_n && (addr >= 16'h2000))
            memory[addr] <= din;
    end
endmodule
