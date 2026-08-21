module io_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  port,
    input  wire [7:0]  cpu_dout,
    input  wire        iorq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    input  wire [7:0]  psg_dout,
    input  wire [7:0]  psg2_dout,
    output reg  [3:0]  psg_addr,
    output reg  [7:0]  psg_din,
    output reg         psg_wr,
    output reg  [127:0] psg_regs,
    output reg  [3:0]  psg2_addr,
    output reg  [7:0]  psg2_din,
    output reg         psg2_wr,
    output reg  [127:0] psg2_regs,
    output reg  [95:0] z80_regs,
    output reg  [5:0]  debug_led,
    output reg  [7:0]  cpu_din
);
    reg io_write_prev;
    wire io_write = !iorq_n && !wr_n;
    wire write_start = io_write && !io_write_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            io_write_prev <= 1'b0;
            psg_addr      <= 4'd0;
            psg_din       <= 8'd0;
            psg_wr        <= 1'b0;
            psg_regs      <= 128'd0;
            psg2_addr     <= 4'd0;
            psg2_din      <= 8'd0;
            psg2_wr       <= 1'b0;
            psg2_regs     <= 128'd0;
            z80_regs      <= 96'd0;
            debug_led     <= 6'b000000;
        end else begin
            io_write_prev <= io_write;
            psg_wr        <= 1'b0;
            psg2_wr       <= 1'b0;

            if (write_start) begin
                case (port)
                    8'hA0: psg_addr <= cpu_dout[3:0];
                    8'hA1: begin
                        psg_din <= cpu_dout;
                        psg_wr  <= 1'b1;
                        case (psg_addr)
                            4'h0: psg_regs[7:0]     <= cpu_dout;
                            4'h1: psg_regs[15:8]    <= cpu_dout;
                            4'h2: psg_regs[23:16]   <= cpu_dout;
                            4'h3: psg_regs[31:24]   <= cpu_dout;
                            4'h4: psg_regs[39:32]   <= cpu_dout;
                            4'h5: psg_regs[47:40]   <= cpu_dout;
                            4'h6: psg_regs[55:48]   <= cpu_dout;
                            4'h7: psg_regs[63:56]   <= cpu_dout;
                            4'h8: psg_regs[71:64]   <= cpu_dout;
                            4'h9: psg_regs[79:72]   <= cpu_dout;
                            4'hA: psg_regs[87:80]   <= cpu_dout;
                            4'hB: psg_regs[95:88]   <= cpu_dout;
                            4'hC: psg_regs[103:96]  <= cpu_dout;
                            4'hD: psg_regs[111:104] <= cpu_dout;
                            4'hE: psg_regs[119:112] <= cpu_dout;
                            4'hF: psg_regs[127:120] <= cpu_dout;
                        endcase
                    end
                    8'hA2: psg2_addr <= cpu_dout[3:0];
                    8'hA3: begin
                        psg2_din <= cpu_dout;
                        psg2_wr  <= 1'b1;
                        case (psg2_addr)
                            4'h0: psg2_regs[7:0]     <= cpu_dout;
                            4'h1: psg2_regs[15:8]    <= cpu_dout;
                            4'h2: psg2_regs[23:16]   <= cpu_dout;
                            4'h3: psg2_regs[31:24]   <= cpu_dout;
                            4'h4: psg2_regs[39:32]   <= cpu_dout;
                            4'h5: psg2_regs[47:40]   <= cpu_dout;
                            4'h6: psg2_regs[55:48]   <= cpu_dout;
                            4'h7: psg2_regs[63:56]   <= cpu_dout;
                            4'h8: psg2_regs[71:64]   <= cpu_dout;
                            4'h9: psg2_regs[79:72]   <= cpu_dout;
                            4'hA: psg2_regs[87:80]   <= cpu_dout;
                            4'hB: psg2_regs[95:88]   <= cpu_dout;
                            4'hC: psg2_regs[103:96]  <= cpu_dout;
                            4'hD: psg2_regs[111:104] <= cpu_dout;
                            4'hE: psg2_regs[119:112] <= cpu_dout;
                            4'hF: psg2_regs[127:120] <= cpu_dout;
                        endcase
                    end
                    8'hB0: debug_led <= cpu_dout[5:0];
                    8'hC0: z80_regs[7:0]   <= cpu_dout; // PC low
                    8'hC1: z80_regs[15:8]  <= cpu_dout; // PC high
                    8'hC2: z80_regs[31:24] <= cpu_dout; // A
                    8'hC3: z80_regs[23:16] <= cpu_dout; // F
                    8'hC4: z80_regs[47:40] <= cpu_dout; // B
                    8'hC5: z80_regs[39:32] <= cpu_dout; // C
                    8'hC6: z80_regs[63:56] <= cpu_dout; // D
                    8'hC7: z80_regs[55:48] <= cpu_dout; // E
                    8'hC8: z80_regs[79:72] <= cpu_dout; // H
                    8'hC9: z80_regs[71:64] <= cpu_dout; // L
                    8'hCA: z80_regs[87:80] <= cpu_dout; // SP low
                    8'hCB: z80_regs[95:88] <= cpu_dout; // SP high
                    default: ;
                endcase
            end
        end
    end

    always @* begin
        cpu_din = 8'hFF;
        if (!iorq_n && !rd_n && (port == 8'hA1))
            cpu_din = psg_dout;
        else if (!iorq_n && !rd_n && (port == 8'hA3))
            cpu_din = psg2_dout;
    end
endmodule
