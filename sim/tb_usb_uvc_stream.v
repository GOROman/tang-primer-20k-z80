`timescale 1ns/1ps

module tb_usb_uvc_stream;
    reg clk_usb = 1'b0;
    reg reset = 1'b1;
    reg frame_start = 1'b0;
    reg stream_ready = 1'b1;
    reg [127:0] psg_regs = 128'd0;
    reg [3:0] psg_selected = 4'd8;
    wire stream_valid;
    wire stream_first;
    wire stream_last;
    wire [7:0] stream_payload;

    integer total_bytes = 0;
    integer packet_bytes = 0;
    integer packets = 0;
    integer video_bytes = 0;
    integer eof_headers = 0;
    integer errors = 0;

    always #8.333 clk_usb = ~clk_usb;

    usb_uvc_stream dut (
        .clk_usb(clk_usb),
        .reset(reset),
        .frame_start(frame_start),
        .psg_regs(psg_regs),
        .psg_selected(psg_selected),
        .stream_valid(stream_valid),
        .stream_ready(stream_ready),
        .stream_first(stream_first),
        .stream_last(stream_last),
        .stream_payload(stream_payload)
    );

    always @(posedge clk_usb) begin
        if (!reset && stream_valid && stream_ready) begin
            if (packet_bytes == 0) begin
                packets = packets + 1;
                if (!stream_first || stream_payload != 8'd2) begin
                    $display("FAIL: packet %0d header length/first", packets);
                    errors = errors + 1;
                end
            end else if (packet_bytes == 1) begin
                if (stream_payload[7:2] != 0) begin
                    $display("FAIL: packet %0d header flags", packets);
                    errors = errors + 1;
                end
                if (stream_payload[1])
                    eof_headers = eof_headers + 1;
            end else begin
                if (video_bytes < 4) begin
                    case (video_bytes)
                        0: if (stream_payload != 8'd29) errors = errors + 1;
                        1: if (stream_payload != 8'd136) errors = errors + 1;
                        2: if (stream_payload != 8'd29) errors = errors + 1;
                        3: if (stream_payload != 8'd124) errors = errors + 1;
                    endcase
                end
                video_bytes = video_bytes + 1;
            end

            total_bytes = total_bytes + 1;
            packet_bytes = packet_bytes + 1;
            if (stream_last) begin
                packet_bytes = 0;
            end
        end
    end

    initial begin
        repeat (4) @(posedge clk_usb);
        reset <= 1'b0;
        @(posedge clk_usb);
        frame_start <= 1'b1;
        @(posedge clk_usb);
        frame_start <= 1'b0;

        wait (!stream_valid && video_bytes == 614400);
        repeat (4) @(posedge clk_usb);

        if (packets != 1205) begin
            $display("FAIL: packet count %0d", packets);
            errors = errors + 1;
        end
        if (total_bytes != 616810) begin
            $display("FAIL: total bytes %0d", total_bytes);
            errors = errors + 1;
        end
        if (eof_headers != 1) begin
            $display("FAIL: EOF header count %0d", eof_headers);
            errors = errors + 1;
        end
        if (errors == 0)
            $display("PASS: UVC packets=%0d video_bytes=%0d total_bytes=%0d", packets, video_bytes, total_bytes);
        else
            $fatal(1, "UVC stream errors=%0d", errors);
        $finish;
    end
endmodule
