module reset_sync (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n
);
    reg [1:0] sync_ff;
    reg [9:0] hold_count;
    reg       released;

    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async)
            sync_ff <= 2'b00;
        else
            sync_ff <= {sync_ff[0], 1'b1};
    end

    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            hold_count <= 10'd0;
            released   <= 1'b0;
        end else if (!sync_ff[1]) begin
            hold_count <= 10'd0;
            released   <= 1'b0;
        end else if (!released) begin
            if (&hold_count)
                released <= 1'b1;
            else
                hold_count <= hold_count + 10'd1;
        end
    end

    assign rst_n = released;
endmodule
