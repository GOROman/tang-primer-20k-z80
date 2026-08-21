module hdmi_psg_debug (
    input  wire         clk_pixel,
    input  wire         reset,
    input  wire [127:0] psg_regs,
    input  wire [3:0]   psg_selected,
    input  wire [127:0] psg2_regs,
    input  wire [3:0]   psg2_selected,
    input  wire [95:0]  z80_regs,
    input  wire [7:0]   z80_r,
    input  wire [127:0] ram_dump,
    input  wire [3:0]   volume_level,
    output wire         active,
    output wire         hsync,
    output wire         vsync,
    output reg  [7:0]   red,
    output reg  [7:0]   green,
    output reg  [7:0]   blue
);
    // VGA-compatible 640x480p60, 25.2 MHz pixel clock, negative sync on TMDS.
    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_SYNC   = 96;
    localparam H_TOTAL  = 800;
    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_TOTAL  = 525;

    reg [10:0] h_count;
    reg [9:0]  v_count;
    reg [127:0] regs_meta;
    reg [127:0] regs_video;
    reg [3:0] selected_meta;
    reg [3:0] selected_video;
    reg [127:0] regs2_meta;
    reg [127:0] regs2_video;
    reg [3:0] selected2_meta;
    reg [3:0] selected2_video;
    reg [95:0] z80_meta;
    reg [95:0] z80_video;
    reg [7:0] r_meta;
    reg [7:0] r_video;
    reg [127:0] ram_meta;
    reg [127:0] ram_video;
    reg [3:0] volume_meta;
    reg [3:0] volume_video;

    wire [10:0] pixel_x = h_count;
    wire [9:0] pixel_y = v_count;

    assign active = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign hsync = (h_count >= H_ACTIVE + H_FRONT) &&
                   (h_count <  H_ACTIVE + H_FRONT + H_SYNC);
    assign vsync = (v_count >= V_ACTIVE + V_FRONT) &&
                   (v_count <  V_ACTIVE + V_FRONT + V_SYNC);

    always @(posedge clk_pixel or posedge reset) begin
        if (reset) begin
            h_count        <= 11'd0;
            v_count        <= 10'd0;
            regs_meta      <= 128'd0;
            regs_video     <= 128'd0;
            selected_meta  <= 4'd0;
            selected_video <= 4'd0;
            regs2_meta      <= 128'd0;
            regs2_video     <= 128'd0;
            selected2_meta  <= 4'd0;
            selected2_video <= 4'd0;
            z80_meta         <= 96'd0;
            z80_video        <= 96'd0;
            r_meta            <= 8'd0;
            r_video           <= 8'd0;
            ram_meta          <= 128'd0;
            ram_video         <= 128'd0;
            volume_meta      <= 4'd1;
            volume_video     <= 4'd1;
        end else begin
            regs_meta      <= psg_regs;
            regs_video     <= regs_meta;
            selected_meta  <= psg_selected;
            selected_video <= selected_meta;
            regs2_meta      <= psg2_regs;
            regs2_video     <= regs2_meta;
            selected2_meta  <= psg2_selected;
            selected2_video <= selected2_meta;
            z80_meta         <= z80_regs;
            z80_video        <= z80_meta;
            r_meta            <= z80_r;
            r_video           <= r_meta;
            ram_meta           <= ram_dump;
            ram_video          <= ram_meta;
            volume_meta      <= volume_level;
            volume_video     <= volume_meta;

            if (h_count == H_TOTAL - 1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 11'd1;
            end
        end
    end

    function [7:0] reg_value;
        input [127:0] values;
        input [3:0] index;
        begin
            case (index)
                4'h0: reg_value = values[7:0];
                4'h1: reg_value = values[15:8];
                4'h2: reg_value = values[23:16];
                4'h3: reg_value = values[31:24];
                4'h4: reg_value = values[39:32];
                4'h5: reg_value = values[47:40];
                4'h6: reg_value = values[55:48];
                4'h7: reg_value = values[63:56];
                4'h8: reg_value = values[71:64];
                4'h9: reg_value = values[79:72];
                4'hA: reg_value = values[87:80];
                4'hB: reg_value = values[95:88];
                4'hC: reg_value = values[103:96];
                4'hD: reg_value = values[111:104];
                4'hE: reg_value = values[119:112];
                default: reg_value = values[127:120];
            endcase
        end
    endfunction

    function [7:0] ram_value;
        input [127:0] values;
        input [3:0] index;
        begin
            case (index)
                4'h0: ram_value = values[7:0];
                4'h1: ram_value = values[15:8];
                4'h2: ram_value = values[23:16];
                4'h3: ram_value = values[31:24];
                4'h4: ram_value = values[39:32];
                4'h5: ram_value = values[47:40];
                4'h6: ram_value = values[55:48];
                4'h7: ram_value = values[63:56];
                4'h8: ram_value = values[71:64];
                4'h9: ram_value = values[79:72];
                4'hA: ram_value = values[87:80];
                4'hB: ram_value = values[95:88];
                4'hC: ram_value = values[103:96];
                4'hD: ram_value = values[111:104];
                4'hE: ram_value = values[119:112];
                default: ram_value = values[127:120];
            endcase
        end
    endfunction

    function [15:0] z80_value;
        input [95:0] values;
        input [2:0] index;
        begin
            case (index)
                3'd0: z80_value = values[15:0];
                3'd1: z80_value = values[31:16];
                3'd2: z80_value = values[47:32];
                3'd3: z80_value = values[63:48];
                3'd4: z80_value = values[79:64];
                default: z80_value = values[95:80];
            endcase
        end
    endfunction

    function [7:0] hex_char;
        input [3:0] value;
        begin
            if (value < 10)
                hex_char = 8'h30 + value;
            else
                hex_char = 8'h41 + value - 10;
        end
    endfunction

    function [7:0] font_row;
        input [7:0] character;
        input [2:0] row;
        begin
            font_row = 8'h00;
            case (character)
                "0": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h6E; 3:font_row=8'h76; 4:font_row=8'h66; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "1": case (row) 0:font_row=8'h18; 1:font_row=8'h38; 2:font_row=8'h18; 3:font_row=8'h18; 4:font_row=8'h18; 5:font_row=8'h18; 6:font_row=8'h7E; default:font_row=0; endcase
                "2": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h06; 3:font_row=8'h0C; 4:font_row=8'h30; 5:font_row=8'h60; 6:font_row=8'h7E; default:font_row=0; endcase
                "3": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h06; 3:font_row=8'h1C; 4:font_row=8'h06; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "4": case (row) 0:font_row=8'h0C; 1:font_row=8'h1C; 2:font_row=8'h3C; 3:font_row=8'h6C; 4:font_row=8'h7E; 5:font_row=8'h0C; 6:font_row=8'h0C; default:font_row=0; endcase
                "5": case (row) 0:font_row=8'h7E; 1:font_row=8'h60; 2:font_row=8'h7C; 3:font_row=8'h06; 4:font_row=8'h06; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "6": case (row) 0:font_row=8'h1C; 1:font_row=8'h30; 2:font_row=8'h60; 3:font_row=8'h7C; 4:font_row=8'h66; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "7": case (row) 0:font_row=8'h7E; 1:font_row=8'h66; 2:font_row=8'h0C; 3:font_row=8'h18; 4:font_row=8'h18; 5:font_row=8'h18; 6:font_row=8'h18; default:font_row=0; endcase
                "8": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h3C; 4:font_row=8'h66; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "9": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h3E; 4:font_row=8'h06; 5:font_row=8'h0C; 6:font_row=8'h38; default:font_row=0; endcase
                "A": case (row) 0:font_row=8'h18; 1:font_row=8'h3C; 2:font_row=8'h66; 3:font_row=8'h66; 4:font_row=8'h7E; 5:font_row=8'h66; 6:font_row=8'h66; default:font_row=0; endcase
                "B": case (row) 0:font_row=8'h7C; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h7C; 4:font_row=8'h66; 5:font_row=8'h66; 6:font_row=8'h7C; default:font_row=0; endcase
                "C": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h60; 3:font_row=8'h60; 4:font_row=8'h60; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "D": case (row) 0:font_row=8'h78; 1:font_row=8'h6C; 2:font_row=8'h66; 3:font_row=8'h66; 4:font_row=8'h66; 5:font_row=8'h6C; 6:font_row=8'h78; default:font_row=0; endcase
                "E": case (row) 0:font_row=8'h7E; 1:font_row=8'h60; 2:font_row=8'h60; 3:font_row=8'h7C; 4:font_row=8'h60; 5:font_row=8'h60; 6:font_row=8'h7E; default:font_row=0; endcase
                "F": case (row) 0:font_row=8'h7E; 1:font_row=8'h60; 2:font_row=8'h60; 3:font_row=8'h7C; 4:font_row=8'h60; 5:font_row=8'h60; 6:font_row=8'h60; default:font_row=0; endcase
                "P": case (row) 0:font_row=8'h7C; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h7C; 4:font_row=8'h60; 5:font_row=8'h60; 6:font_row=8'h60; default:font_row=0; endcase
                "S": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h60; 3:font_row=8'h3C; 4:font_row=8'h06; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "G": case (row) 0:font_row=8'h3C; 1:font_row=8'h66; 2:font_row=8'h60; 3:font_row=8'h6E; 4:font_row=8'h66; 5:font_row=8'h66; 6:font_row=8'h3C; default:font_row=0; endcase
                "H": case (row) 0:font_row=8'h66; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h7E; 4:font_row=8'h66; 5:font_row=8'h66; 6:font_row=8'h66; default:font_row=0; endcase
                "L": case (row) 0:font_row=8'h60; 1:font_row=8'h60; 2:font_row=8'h60; 3:font_row=8'h60; 4:font_row=8'h60; 5:font_row=8'h60; 6:font_row=8'h7E; default:font_row=0; endcase
                "M": case (row) 0:font_row=8'h63; 1:font_row=8'h77; 2:font_row=8'h7F; 3:font_row=8'h6B; 4:font_row=8'h63; 5:font_row=8'h63; 6:font_row=8'h63; default:font_row=0; endcase
                "R": case (row) 0:font_row=8'h7C; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h7C; 4:font_row=8'h6C; 5:font_row=8'h66; 6:font_row=8'h66; default:font_row=0; endcase
                "V": case (row) 0:font_row=8'h66; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h66; 4:font_row=8'h66; 5:font_row=8'h3C; 6:font_row=8'h18; default:font_row=0; endcase
                "Z": case (row) 0:font_row=8'h7E; 1:font_row=8'h06; 2:font_row=8'h0C; 3:font_row=8'h18; 4:font_row=8'h30; 5:font_row=8'h60; 6:font_row=8'h7E; default:font_row=0; endcase
                ":": case (row) 1:font_row=8'h18; 2:font_row=8'h18; 4:font_row=8'h18; 5:font_row=8'h18; default:font_row=0; endcase
                default: font_row = 8'h00;
            endcase
        end
    endfunction

    reg text_on;
    reg selected_area;
    reg [7:0] character;
    reg [7:0] bits;
    reg [3:0] register_index;
    reg [7:0] register_data;
    reg [2:0] glyph_row;
    reg [2:0] glyph_col;
    reg [2:0] character_pos;
    reg [10:0] local_x;
    reg [9:0] local_y;
    reg pane_two;
    reg [15:0] z80_data;
    reg [7:0] ram_data;
    reg [3:0] ram_char_pos;
    integer row_index;
    integer ram_byte_index;

    always @* begin
        text_on = 1'b0;
        selected_area = 1'b0;
        character = 8'h20;
        bits = 8'h00;
        register_index = 4'h0;
        register_data = 8'h00;
        glyph_row = 3'd0;
        glyph_col = 3'd0;
        character_pos = 3'd0;
        local_x = 11'd0;
        local_y = 10'd0;
        pane_two = 1'b0;
        z80_data = 16'd0;
        ram_data = 8'd0;
        ram_char_pos = 4'd0;
        row_index = 0;
        ram_byte_index = 0;

        // Headers: PSG1 and PSG2, 4x scale.
        if (((pixel_x >= 256) && (pixel_x < 384)) ||
            ((pixel_x >= 448) && (pixel_x < 576))) begin
          if ((pixel_y >= 32) && (pixel_y < 64)) begin
            pane_two = (pixel_x >= 400);
            local_x = pane_two ? (pixel_x - 448) : (pixel_x - 256);
            local_y = pixel_y - 32;
            character_pos = local_x[6:5];
            glyph_col = local_x[4:2];
            glyph_row = local_y[4:2];
            case (character_pos)
                0: character = "P";
                1: character = "S";
                2: character = "G";
                default: character = pane_two ? "2" : "1";
            endcase
            bits = font_row(character, glyph_row);
            text_on = bits[7-glyph_col];
          end
        end

        // RAM dump header: RAM:2000, 2x scale.
        if ((pixel_x >= 48) && (pixel_x < 176) &&
            (pixel_y >= 368) && (pixel_y < 384)) begin
            local_x = pixel_x - 48;
            local_y = pixel_y - 368;
            character_pos = local_x[6:4];
            glyph_col = local_x[3:1];
            glyph_row = local_y[3:1];
            case (character_pos)
                0: character = "R";
                1: character = "A";
                2: character = "M";
                3: character = ":";
                4: character = "2";
                default: character = "0";
            endcase
            bits = font_row(character, glyph_row);
            text_on = bits[7-glyph_col];
        end

        // Four rows of four bytes: RAM 2000h through 200Fh, 2x scale.
        if ((pixel_x >= 48) && (pixel_x < 240) &&
            (pixel_y >= 400) && (pixel_y < 464)) begin
            row_index = (pixel_y - 400) >> 4;
            local_x = pixel_x - 48;
            local_y = (pixel_y - 400) & 10'h00F;
            ram_char_pos = local_x[7:4];
            glyph_col = local_x[3:1];
            glyph_row = local_y[3:1];
            case (ram_char_pos)
                0, 1: ram_byte_index = row_index * 4;
                3, 4: ram_byte_index = row_index * 4 + 1;
                6, 7: ram_byte_index = row_index * 4 + 2;
                default: ram_byte_index = row_index * 4 + 3;
            endcase
            ram_data = ram_value(ram_video, ram_byte_index[3:0]);
            case (ram_char_pos)
                0, 3, 6, 9: character = hex_char(ram_data[7:4]);
                1, 4, 7, 10: character = hex_char(ram_data[3:0]);
                default: character = 8'h20;
            endcase
            bits = font_row(character, glyph_row);
            text_on = bits[7-glyph_col];
        end

        // Z80 header, 4x scale.
        if ((pixel_x >= 56) && (pixel_x < 152) &&
            (pixel_y >= 32) && (pixel_y < 64)) begin
            local_x = pixel_x - 56;
            local_y = pixel_y - 32;
            character_pos = local_x[6:5];
            glyph_col = local_x[4:2];
            glyph_row = local_y[4:2];
            case (character_pos)
                0: character = "Z";
                1: character = "8";
                default: character = "0";
            endcase
            bits = font_row(character, glyph_row);
            text_on = bits[7-glyph_col];
        end

        // One vertical Rn:XX list per PSG, 2x scale, all 16 registers.
        if ((pixel_y >= 96) && (pixel_y < 352)) begin
            row_index = (pixel_y - 96) >> 4;
            if (row_index < 16) begin
                if ((pixel_x >= 280) && (pixel_x < 360)) begin
                    pane_two = 1'b0;
                    local_x = pixel_x - 280;
                end else if ((pixel_x >= 472) && (pixel_x < 552)) begin
                    pane_two = 1'b1;
                    local_x = pixel_x - 472;
                end

                if (((pixel_x >= 280) && (pixel_x < 360)) ||
                    ((pixel_x >= 472) && (pixel_x < 552))) begin
                    register_index = row_index[3:0];
                    local_y = (pixel_y - 96) & 10'h00F;
                    selected_area = pane_two ?
                        (register_index == selected2_video) :
                        (register_index == selected_video);
                    register_data = pane_two ?
                        reg_value(regs2_video, register_index) :
                        reg_value(regs_video, register_index);
                    character_pos = local_x[6:4];
                    glyph_col = local_x[3:1];
                    glyph_row = local_y[3:1];
                    case (character_pos)
                        0: character = "R";
                        1: character = hex_char(register_index);
                        2: character = ":";
                        3: character = hex_char(register_data[7:4]);
                        default: character = hex_char(register_data[3:0]);
                    endcase
                    bits = font_row(character, glyph_row);
                    text_on = bits[7-glyph_col];
                end
            end
        end


        // Live PC and R plus AF, BC, DE, HL and SP snapshots, 2x scale.
        if ((pixel_x >= 48) && (pixel_x < 160) &&
            (pixel_y >= 96) && (pixel_y < 320)) begin
            row_index = (pixel_y - 96) >> 5;
            local_y = (pixel_y - 96) & 10'h01F;
            if ((row_index < 7) && (local_y < 16)) begin
                local_x = pixel_x - 48;
                character_pos = local_x[6:4];
                glyph_col = local_x[3:1];
                glyph_row = local_y[3:1];
                if (row_index == 6) begin
                    case (character_pos)
                        0: character = "R";
                        1: character = ":";
                        2: character = hex_char(r_video[7:4]);
                        3: character = hex_char(r_video[3:0]);
                        default: character = 8'h20;
                    endcase
                end else begin
                    z80_data = z80_value(z80_video, row_index[2:0]);
                    case (character_pos)
                        0: begin
                            case (row_index)
                                0: character = "P";
                                1: character = "A";
                                2: character = "B";
                                3: character = "D";
                                4: character = "H";
                                default: character = "S";
                            endcase
                        end
                        1: begin
                            case (row_index)
                                0: character = "C";
                                1: character = "F";
                                2: character = "C";
                                3: character = "E";
                                4: character = "L";
                                default: character = "P";
                            endcase
                        end
                        2: character = ":";
                        3: character = hex_char(z80_data[15:12]);
                        4: character = hex_char(z80_data[11:8]);
                        5: character = hex_char(z80_data[7:4]);
                        default: character = hex_char(z80_data[3:0]);
                    endcase
                end
                bits = font_row(character, glyph_row);
                text_on = bits[7-glyph_col];
            end
        end

        // Volume percentage, 2x scale. V:000 through V:100.
        if ((pixel_x >= 64) && (pixel_x < 144) &&
            (pixel_y >= 336) && (pixel_y < 352)) begin
            local_x = pixel_x - 64;
            local_y = pixel_y - 336;
            character_pos = local_x[6:4];
            glyph_col = local_x[3:1];
            glyph_row = local_y[3:1];
            case (character_pos)
                0: character = "V";
                1: character = ":";
                2: character = (volume_video == 10) ? "1" : "0";
                3: character = (volume_video == 10) ? "0" : hex_char(volume_video);
                default: character = "0";
            endcase
            bits = font_row(character, glyph_row);
            text_on = bits[7-glyph_col];
        end

        if (!active) begin
            red = 8'h00;
            green = 8'h00;
            blue = 8'h00;
        end else if (text_on && selected_area) begin
            red = 8'hFF;
            green = 8'hD0;
            blue = 8'h30;
        end else if (text_on) begin
            red = 8'hE8;
            green = 8'hF0;
            blue = 8'hFF;
        end else if (selected_area) begin
            red = 8'h20;
            green = 8'h38;
            blue = 8'h58;
        end else begin
            red = 8'h08;
            green = 8'h10;
            blue = 8'h20;
        end
    end
endmodule
