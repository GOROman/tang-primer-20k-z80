module usb_uvc_stream (
    input  wire         clk_usb,
    input  wire         reset,
    input  wire         frame_start,
    input  wire [127:0] psg_regs,
    input  wire [3:0]   psg_selected,
    output wire         stream_valid,
    input  wire         stream_ready,
    output wire         stream_first,
    output wire         stream_last,
    output reg  [7:0]   stream_payload
);
    localparam [19:0] FRAME_BYTES = 20'd614400;

    reg active_frame;
    reg frame_id;
    reg [8:0] pair_x;
    reg [8:0] pixel_y;
    reg [1:0] pixel_phase;
    reg [8:0] packet_byte;
    reg [19:0] video_bytes_left;

    wire [10:0] pixel_x_even = {pair_x, 1'b0};
    wire [10:0] pixel_x_odd  = {pair_x, 1'b0} + 11'd1;
    wire [1:0] palette_even;
    wire [1:0] palette_odd;

    psg_debug_pixel u_even (
        .pixel_x      (pixel_x_even),
        .pixel_y      ({1'b0, pixel_y}),
        .psg_regs     (psg_regs),
        .psg_selected (psg_selected),
        .palette      (palette_even)
    );

    psg_debug_pixel u_odd (
        .pixel_x      (pixel_x_odd),
        .pixel_y      ({1'b0, pixel_y}),
        .psg_regs     (psg_regs),
        .psg_selected (psg_selected),
        .palette      (palette_odd)
    );

    function [7:0] y_value;
        input [1:0] color;
        begin
            case (color)
                2'd0: y_value = 8'd29;
                2'd1: y_value = 8'd61;
                2'd2: y_value = 8'd222;
                default: y_value = 8'd191;
            endcase
        end
    endfunction

    function [7:0] u_value;
        input [1:0] color;
        begin
            case (color)
                2'd0: u_value = 8'd136;
                2'd1: u_value = 8'd143;
                2'd2: u_value = 8'd136;
                default: u_value = 8'd51;
            endcase
        end
    endfunction

    function [7:0] v_value;
        input [1:0] color;
        begin
            case (color)
                2'd0: v_value = 8'd124;
                2'd1: v_value = 8'd113;
                2'd2: v_value = 8'd124;
                default: v_value = 8'd160;
            endcase
        end
    endfunction

    assign stream_valid = active_frame;
    assign stream_first = active_frame && (packet_byte == 0);
    assign stream_last = active_frame &&
                         ((packet_byte == 9'd511) ||
                          ((packet_byte >= 2) && (video_bytes_left == 1)));

    always @* begin
        if (packet_byte == 0)
            stream_payload = 8'd2;
        else if (packet_byte == 1)
            stream_payload = {6'b000000, (video_bytes_left <= 20'd510), frame_id};
        else begin
            case (pixel_phase)
                2'd0: stream_payload = y_value(palette_even);
                2'd1: stream_payload = u_value(palette_even);
                2'd2: stream_payload = y_value(palette_odd);
                default: stream_payload = v_value(palette_even);
            endcase
        end
    end

    always @(posedge clk_usb or posedge reset) begin
        if (reset) begin
            active_frame     <= 1'b0;
            frame_id         <= 1'b0;
            pair_x           <= 9'd0;
            pixel_y          <= 9'd0;
            pixel_phase      <= 2'd0;
            packet_byte      <= 9'd0;
            video_bytes_left <= FRAME_BYTES;
        end else begin
            if (frame_start && !active_frame) begin
                active_frame     <= 1'b1;
                pair_x           <= 9'd0;
                pixel_y          <= 9'd0;
                pixel_phase      <= 2'd0;
                packet_byte      <= 9'd0;
                video_bytes_left <= FRAME_BYTES;
            end else if (stream_valid && stream_ready) begin
                if (packet_byte >= 2) begin
                    video_bytes_left <= video_bytes_left - 20'd1;

                    if (pixel_phase == 2'd3) begin
                        pixel_phase <= 2'd0;
                        if (pair_x == 9'd319) begin
                            pair_x <= 9'd0;
                            if (pixel_y != 9'd479)
                                pixel_y <= pixel_y + 9'd1;
                        end else begin
                            pair_x <= pair_x + 9'd1;
                        end
                    end else begin
                        pixel_phase <= pixel_phase + 2'd1;
                    end

                    if (video_bytes_left == 1) begin
                        active_frame <= 1'b0;
                        frame_id     <= ~frame_id;
                        packet_byte  <= 9'd0;
                    end else if (packet_byte == 9'd511) begin
                        packet_byte <= 9'd0;
                    end else begin
                        packet_byte <= packet_byte + 9'd1;
                    end
                end else begin
                    packet_byte <= packet_byte + 9'd1;
                end
            end
        end
    end
endmodule
