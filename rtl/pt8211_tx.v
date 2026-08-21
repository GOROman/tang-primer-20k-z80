module pt8211_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] pcm_left,
    input  wire [15:0] pcm_right,
    output reg         hp_bck,
    output reg         hp_ws,
    output reg         hp_din,
    output reg         pa_en
);
    // Fractional edge generator: 3.072 MHz BCK edges from 27 MHz.
    // Two edges form one 1.536 MHz BCK period; 32 bits form 48 kHz audio.
    localparam [24:0] SYS_HZ  = 25'd27000000;
    localparam [24:0] EDGE_HZ = 25'd3072000;

    reg [24:0] edge_acc;
    reg [4:0]  bit_index;
    reg [15:0] left_latched;
    reg [15:0] right_latched;
    reg [19:0] amp_delay;

    wire [25:0] edge_sum = {1'b0, edge_acc} + {1'b0, EDGE_HZ};
    wire edge_tick = (edge_sum >= SYS_HZ);
    wire [25:0] edge_remainder = edge_sum - {1'b0, SYS_HZ};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_acc     <= 25'd0;
            hp_bck       <= 1'b0;
            hp_ws        <= 1'b0;
            hp_din       <= 1'b0;
            bit_index    <= 5'd0;
            left_latched <= 16'd0;
            right_latched<= 16'd0;
            amp_delay    <= 20'd0;
            pa_en        <= 1'b0;
        end else begin
            if (edge_tick)
                edge_acc <= edge_remainder[24:0];
            else
                edge_acc <= edge_sum[24:0];

            // Enable the amplifier only after the DAC clocks and zero-valued
            // reset frames have been running for about 39 ms at 27 MHz.
            if (!pa_en) begin
                amp_delay <= amp_delay + 20'd1;
                if (&amp_delay)
                    pa_en <= 1'b1;
            end

            if (edge_tick) begin
                hp_bck <= ~hp_bck;

                // Update DIN and WS only on BCK falling edges. PT8211 then
                // samples stable data on the following rising edge.
                if (hp_bck) begin
                    if (bit_index == 5'd31) begin
                        bit_index     <= 5'd0;
                        hp_ws         <= 1'b0;
                        left_latched  <= pcm_left;
                        right_latched <= pcm_right;
                        hp_din        <= pcm_right[15];
                    end else begin
                        bit_index <= bit_index + 5'd1;
                        if (bit_index == 5'd15) begin
                            hp_ws  <= 1'b1;
                            hp_din <= left_latched[15];
                        end else if (bit_index < 5'd15) begin
                            hp_din <= right_latched[14-bit_index];
                        end else begin
                            hp_din <= left_latched[30-bit_index];
                        end
                    end
                end
            end
        end
    end
endmodule
