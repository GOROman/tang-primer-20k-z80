module audio_mixer (
    input  wire [9:0]  psg_sound,
    output wire [15:0] pcm_left,
    output wire [15:0] pcm_right
);
    // JT49's summed output is unipolar. A gain of 3 gives about 9.4% of the
    // previous x32 level; the Dock audio path removes the DC component.
    wire [15:0] pcm = psg_sound * 16'd3;

    assign pcm_left  = pcm;
    assign pcm_right = pcm;
endmodule
