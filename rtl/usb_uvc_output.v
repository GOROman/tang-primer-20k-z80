module usb_uvc_output (
    input  wire         rst_n,
    input  wire [127:0] psg_regs,
    input  wire [3:0]   psg_selected,
    output wire         ulpi_rst,
    input  wire         ulpi_clk,
    input  wire         ulpi_dir,
    input  wire         ulpi_nxt,
    output wire         ulpi_stp,
    inout  wire [7:0]   ulpi_data,
    output wire         usb_clock_alive,
    output reg          usb_dir_seen,
    output reg          usb_nxt_seen
);
    wire clk_usb = ~ulpi_clk;
    reg [4:0] reset_count;
    wire usb_reset = ~reset_count[4];
    reg [127:0] regs_meta;
    reg [127:0] regs_usb;
    reg [3:0] selected_meta;
    reg [3:0] selected_usb;

    always @(posedge clk_usb or negedge rst_n) begin
        if (!rst_n) begin
            reset_count   <= 5'd0;
            regs_meta     <= 128'd0;
            regs_usb      <= 128'd0;
            selected_meta <= 4'd0;
            selected_usb  <= 4'd0;
            usb_dir_seen  <= 1'b0;
            usb_nxt_seen  <= 1'b0;
        end else begin
            if (!reset_count[4])
                reset_count <= reset_count + 5'd1;
            regs_meta     <= psg_regs;
            regs_usb      <= regs_meta;
            selected_meta <= psg_selected;
            selected_usb  <= selected_meta;
            if (ulpi_dir)
                usb_dir_seen <= 1'b1;
            if (ulpi_nxt)
                usb_nxt_seen <= 1'b1;
        end
    end

    assign usb_clock_alive = reset_count[4];

    wire [7:0] ulpi_data_in = ulpi_data;
    wire [7:0] ulpi_data_out;
    wire ulpi_data_oe;
    assign ulpi_data = ulpi_data_oe ? ulpi_data_out : 8'hZZ;
    assign ulpi_rst = 1'b1;

    wire frame_start;
    wire streaming;
    wire stream_valid;
    wire stream_ready;
    wire stream_first;
    wire stream_last;
    wire [7:0] stream_payload;

    usb_uvc_stream u_stream (
        .clk_usb        (clk_usb),
        .reset          (usb_reset),
        .frame_start    (frame_start & streaming),
        .psg_regs       (regs_usb),
        .psg_selected   (selected_usb),
        .stream_valid   (stream_valid),
        .stream_ready   (stream_ready),
        .stream_first   (stream_first),
        .stream_last    (stream_last),
        .stream_payload (stream_payload)
    );

    usb_uvc_core u_core (
        .usb_clk        (clk_usb),
        .usb_rst        (usb_reset),
        .ulpi_dir       (ulpi_dir),
        .ulpi_nxt       (ulpi_nxt),
        .ulpi_data_i    (ulpi_data_in),
        .ulpi_stp       (ulpi_stp),
        .ulpi_data_o    (ulpi_data_out),
        .ulpi_data_oe   (ulpi_data_oe),
        .stream_valid   (stream_valid),
        .stream_ready   (stream_ready),
        .stream_first   (stream_first),
        .stream_last    (stream_last),
        .stream_payload (stream_payload),
        .frame_start    (frame_start),
        .streaming      (streaming)
    );
endmodule
