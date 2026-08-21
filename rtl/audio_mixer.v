module audio_mixer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        vol_down_n,
    input  wire        vol_up_n,
    input  wire [9:0]  psg1_sound,
    input  wire [9:0]  psg2_sound,
    output reg  [3:0]  volume_level,
    output wire [15:0] pcm_left,
    output wire [15:0] pcm_right
);
    // Each level is 10 percent. Level 1 preserves the original output:
    // (1023 + 1023) * 3 / 2 = 3069. Level 10 reaches 30690.
    localparam [19:0] DEBOUNCE_CYCLES = 20'd539999; // 20 ms at 27 MHz

    reg [1:0] down_sync;
    reg [1:0] up_sync;
    reg [19:0] down_count;
    reg [19:0] up_count;
    reg down_armed;
    reg up_armed;

    wire [10:0] summed = {1'b0, psg1_sound} + {1'b0, psg2_sound};
    wire [16:0] scaled = summed * 3 * volume_level;
    wire [15:0] pcm = scaled[16:1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            down_sync   <= 2'b11;
            up_sync     <= 2'b11;
            down_count  <= 20'd0;
            up_count    <= 20'd0;
            down_armed  <= 1'b1;
            up_armed    <= 1'b1;
            volume_level <= 4'd1;
        end else begin
            down_sync <= {down_sync[0], vol_down_n};
            up_sync   <= {up_sync[0], vol_up_n};

            if (down_sync[1]) begin
                down_count <= 20'd0;
                down_armed <= 1'b1;
            end else if (down_armed) begin
                if (down_count == DEBOUNCE_CYCLES) begin
                    down_count <= 20'd0;
                    down_armed <= 1'b0;
                    if (volume_level != 0)
                        volume_level <= volume_level - 4'd1;
                end else begin
                    down_count <= down_count + 20'd1;
                end
            end

            if (up_sync[1]) begin
                up_count <= 20'd0;
                up_armed <= 1'b1;
            end else if (up_armed) begin
                if (up_count == DEBOUNCE_CYCLES) begin
                    up_count <= 20'd0;
                    up_armed <= 1'b0;
                    if (volume_level < 10)
                        volume_level <= volume_level + 4'd1;
                end else begin
                    up_count <= up_count + 20'd1;
                end
            end
        end
    end

    assign pcm_left  = pcm;
    assign pcm_right = pcm;
endmodule
