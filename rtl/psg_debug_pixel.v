module psg_debug_pixel (
    input  wire [10:0]  pixel_x,
    input  wire [9:0]   pixel_y,
    input  wire [127:0] psg_regs,
    input  wire [3:0]   psg_selected,
    output reg  [1:0]   palette
);
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
                "R": case (row) 0:font_row=8'h7C; 1:font_row=8'h66; 2:font_row=8'h66; 3:font_row=8'h7C; 4:font_row=8'h6C; 5:font_row=8'h66; 6:font_row=8'h66; default:font_row=0; endcase
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
    integer row_index;

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
        row_index = 0;

        if ((pixel_x >= 272) && (pixel_x < 368) &&
            (pixel_y >= 48) && (pixel_y < 80)) begin
            local_x = pixel_x - 272;
            local_y = pixel_y - 48;
            character_pos = local_x[6:5];
            glyph_col = local_x[4:2];
            glyph_row = local_y[4:2];
            case (character_pos)
                0: character = "P";
                1: character = "S";
                default: character = "G";
            endcase
            bits = font_row(character, glyph_row);
            text_on = bits[7-glyph_col];
        end

        if ((pixel_y >= 128) && (pixel_y < 384)) begin
            row_index = (pixel_y - 128) >> 5;
            if (row_index < 8) begin
                if ((pixel_x >= 48) && (pixel_x < 208)) begin
                    local_x = pixel_x - 48;
                    register_index = row_index[3:0];
                end else if ((pixel_x >= 352) && (pixel_x < 512)) begin
                    local_x = pixel_x - 352;
                    register_index = row_index[3:0] + 4'd8;
                end

                if (((pixel_x >= 48) && (pixel_x < 208)) ||
                    ((pixel_x >= 352) && (pixel_x < 512))) begin
                    local_y = (pixel_y - 128) & 10'h01F;
                    selected_area = (register_index == psg_selected);
                    register_data = reg_value(psg_regs, register_index);
                    character_pos = local_x[7:5];
                    glyph_col = local_x[4:2];
                    glyph_row = local_y[4:2];
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

        if (text_on && selected_area)
            palette = 2'd3;
        else if (text_on)
            palette = 2'd2;
        else if (selected_area)
            palette = 2'd1;
        else
            palette = 2'd0;
    end
endmodule
