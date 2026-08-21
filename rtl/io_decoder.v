module io_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  port,
    input  wire [7:0]  cpu_dout,
    input  wire        iorq_n,
    input  wire        rd_n,
    input  wire        wr_n,
    input  wire [7:0]  psg_dout,
    output reg  [3:0]  psg_addr,
    output reg  [7:0]  psg_din,
    output reg         psg_wr,
    output reg         debug_led,
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
            debug_led     <= 1'b0;
        end else begin
            io_write_prev <= io_write;
            psg_wr        <= 1'b0;

            if (write_start) begin
                case (port)
                    8'hA0: psg_addr <= cpu_dout[3:0];
                    8'hA1: begin
                        psg_din <= cpu_dout;
                        psg_wr  <= 1'b1;
                    end
                    8'hB0: debug_led <= cpu_dout[0];
                    default: ;
                endcase
            end
        end
    end

    always @* begin
        cpu_din = 8'hFF;
        if (!iorq_n && !rd_n && (port == 8'hA1))
            cpu_din = psg_dout;
    end
endmodule
