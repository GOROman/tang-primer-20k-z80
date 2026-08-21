module soc_memory (
    input  wire        clk,
    input  wire [15:0] addr,
    input  wire [7:0]  din,
    input  wire        mreq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    output reg  [7:0]  dout,
    output wire [127:0] debug_dump
);
    reg [7:0] memory [0:65535];
    reg [7:0] debug_memory [0:15];

    assign debug_dump = {
        debug_memory[15], debug_memory[14], debug_memory[13], debug_memory[12],
        debug_memory[11], debug_memory[10], debug_memory[9],  debug_memory[8],
        debug_memory[7],  debug_memory[6],  debug_memory[5],  debug_memory[4],
        debug_memory[3],  debug_memory[2],  debug_memory[1],  debug_memory[0]
    };

    initial begin
        // Gowin resolves this path relative to this RTL source file.
        $readmemh("../firmware/generated/boot.hex", memory, 0, 37);
        $readmemh("../firmware/generated/psg_demo.hex", memory, 8192);
        $readmemh("../firmware/generated/psg_demo.hex", debug_memory, 0, 15);
    end

    always @(posedge clk) begin
        if (!mreq_n && !rd_n)
            dout <= memory[addr];

        if (!mreq_n && !wr_n && (addr >= 16'h2000)) begin
            memory[addr] <= din;
            if (addr < 16'h2010)
                debug_memory[addr[3:0]] <= din;
        end
    end
endmodule
