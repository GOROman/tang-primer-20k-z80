module audio_mixer (
    input  wire [9:0]  psg_sound,
    output wire [15:0] pcm_left,
    output wire [15:0] pcm_right
);
    // JT49's summed output is unipolar. Scale it to a safe positive 16-bit
    // range; the Dock audio path removes the DC component.
    wire [15:0] pcm = {1'b0, psg_sound, 5'b00000};

    assign pcm_left  = pcm;
    assign pcm_right = pcm;
endmodule
