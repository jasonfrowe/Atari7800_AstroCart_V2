module diag_rom (
    input [15:0] a_stable,
    
    // SD / State inputs
    input [3:0] sd_state,
    input [9:0] byte_index,
    input [9:0] current_sector,
    input [7:0] last_byte_captured,
    input [31:0] checksum,
    input [31:0] psram_checksum,
    
    // Latches
    input [31:0] latch_p2,
    input [31:0] latch_p3,
    input [7:0]  latch_p4,
    input [7:0]  latch_p5,
    input [7:0]  latch_p6,
    input [31:0] latch_p7,
    
    // First Bytes Array (flattened for port list)
    input [7:0] fb0, input [7:0] fb1, input [7:0] fb2, input [7:0] fb3,
    
    output reg [7:0] data_out
);

    // Hex-to-ASCII converter helper
    function [7:0] to_hex_ascii (input [3:0] nibble);
        to_hex_ascii = (nibble < 10) ? (8'h30 + nibble) : (8'h37 + nibble);
    endfunction

    always @* begin
        case (a_stable[7:4])
            4'h0: begin // $x400: SD Word 0 (A9 50 85 3C)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h53; // 'S'
                    4'h1: data_out = 8'h44; // 'D'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(fb0[7:4]);
                    4'h4: data_out = to_hex_ascii(fb0[3:0]);
                    4'h5: data_out = 8'h20;
                    4'h6: data_out = to_hex_ascii(fb1[7:4]);
                    4'h7: data_out = to_hex_ascii(fb1[3:0]);
                    4'h8: data_out = 8'h20;
                    4'h9: data_out = to_hex_ascii(fb2[7:4]);
                    4'hA: data_out = to_hex_ascii(fb2[3:0]);
                    4'hB: data_out = 8'h20;
                    4'hC: data_out = to_hex_ascii(fb3[7:4]);
                    4'hD: data_out = to_hex_ascii(fb3[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h1: begin // $x410: ST/BC
                case (a_stable[3:0])
                    4'h0: data_out = 8'h53; // 'S'
                    4'h1: data_out = 8'h54; // 'T'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(sd_state);
                    4'h4: data_out = 8'h20; 
                    4'h5: data_out = 8'h42; // 'B'
                    4'h6: data_out = 8'h43; // 'C'
                    4'h7: data_out = 8'h3A;
                    4'h8: data_out = to_hex_ascii({2'b0, byte_index[9:8]});
                    4'h9: data_out = to_hex_ascii(byte_index[7:4]);
                    4'hA: data_out = to_hex_ascii(byte_index[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h2: begin // $x420: SC/L
                case (a_stable[3:0])
                    4'h0: data_out = 8'h53; // 'S'
                    4'h1: data_out = 8'h43; // 'C'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii({1'b0, current_sector[6:4]});
                    4'h4: data_out = to_hex_ascii(current_sector[3:0]);
                    4'h5: data_out = 8'h20;
                    4'h6: data_out = 8'h4C; // 'L' (Last Byte)
                    4'h7: data_out = 8'h3A;
                    4'h8: data_out = to_hex_ascii(last_byte_captured[7:4]);
                    4'h9: data_out = to_hex_ascii(last_byte_captured[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h3: begin // $x430: First Bytes Peak
                case (a_stable[3:0])
                    4'h0: data_out = 8'h48; // 'H'
                    4'h1: data_out = 8'h3A; // ':'
                    4'h2: data_out = to_hex_ascii(fb0[7:4]);
                    4'h3: data_out = to_hex_ascii(fb0[3:0]);
                    4'h4: data_out = 8'h20;
                    4'h5: data_out = to_hex_ascii(fb1[7:4]);
                    4'h6: data_out = to_hex_ascii(fb1[3:0]);
                    4'h7: data_out = 8'h20;
                    4'h8: data_out = to_hex_ascii(fb2[7:4]);
                    4'h9: data_out = to_hex_ascii(fb2[3:0]);
                    4'hA: data_out = 8'h20;
                    4'hB: data_out = to_hex_ascii(fb3[7:4]);
                    4'hC: data_out = to_hex_ascii(fb3[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h4: begin // $x440: Checksum (C:XXXXXXXX)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h43; // 'C'
                    4'h1: data_out = 8'h3A; // ':'
                    4'h2: data_out = to_hex_ascii(checksum[31:28]);
                    4'h3: data_out = to_hex_ascii(checksum[27:24]);
                    4'h4: data_out = to_hex_ascii(checksum[23:20]);
                    4'h5: data_out = to_hex_ascii(checksum[19:16]); 
                    4'h6: data_out = to_hex_ascii(checksum[15:12]);
                    4'h7: data_out = to_hex_ascii(checksum[11:8]);
                    4'h8: data_out = to_hex_ascii(checksum[7:4]);
                    4'h9: data_out = to_hex_ascii(checksum[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h5: begin // $x450: P0:XXXXXXXX (PSRAM Checksum)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h30; // '0'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(psram_checksum[31:28]);
                    4'h4: data_out = to_hex_ascii(psram_checksum[27:24]);
                    4'h5: data_out = to_hex_ascii(psram_checksum[23:20]);
                    4'h6: data_out = to_hex_ascii(psram_checksum[19:16]);
                    4'h7: data_out = to_hex_ascii(psram_checksum[15:12]);
                    4'h8: data_out = to_hex_ascii(psram_checksum[11:8]);
                    4'h9: data_out = to_hex_ascii(psram_checksum[7:4]);
                    4'hA: data_out = to_hex_ascii(psram_checksum[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h6: begin // $x460: P2:XX (crc_burst word 1)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h32; // '2'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(latch_p2[31:28]);
                    4'h4: data_out = to_hex_ascii(latch_p2[27:24]);
                    4'h5: data_out = to_hex_ascii(latch_p2[23:20]);
                    4'h6: data_out = to_hex_ascii(latch_p2[19:16]);
                    4'h7: data_out = to_hex_ascii(latch_p2[15:12]);
                    4'h8: data_out = to_hex_ascii(latch_p2[11:8]);
                    4'h9: data_out = to_hex_ascii(latch_p2[7:4]);
                    4'hA: data_out = to_hex_ascii(latch_p2[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h7: begin // $x470: P3:XX (crc_burst word 2)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h33; // '3'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(latch_p3[31:28]);
                    4'h4: data_out = to_hex_ascii(latch_p3[27:24]);
                    4'h5: data_out = to_hex_ascii(latch_p3[23:20]);
                    4'h6: data_out = to_hex_ascii(latch_p3[19:16]);
                    4'h7: data_out = to_hex_ascii(latch_p3[15:12]);
                    4'h8: data_out = to_hex_ascii(latch_p3[11:8]);
                    4'h9: data_out = to_hex_ascii(latch_p3[7:4]);
                    4'hA: data_out = to_hex_ascii(latch_p3[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            4'h8: begin // $x480: P4:XX (Addr Mid)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h34; // '4'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(latch_p4[7:4]);
                    4'h4: data_out = to_hex_ascii(latch_p4[3:0]);
                    4'h5: data_out = 8'h41; // 'A'
                    4'h6: data_out = 8'h32; // '2'
                    default: data_out = 8'h20;
                endcase
            end
            4'h9: begin // $x490: P5:XX (Burst LSB)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h35; // '5'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(latch_p5[7:4]);
                    4'h4: data_out = to_hex_ascii(latch_p5[3:0]);
                    4'h5: data_out = 8'h42; // 'B'
                    4'h6: data_out = 8'h30; // '0'
                    default: data_out = 8'h20;
                endcase
            end
            4'hA: begin // $x4A0: P6:XX (Load Addr LSB)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h36; // '6'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(latch_p6[7:4]);
                    4'h4: data_out = to_hex_ascii(latch_p6[3:0]);
                    4'h5: data_out = 8'h4C; // 'L' (Load)
                    4'h6: data_out = 8'h44; // 'D'
                    default: data_out = 8'h20;
                endcase
            end
            4'hB: begin // $x4B0: P7:XX (32-bit Raw Peak)
                case (a_stable[3:0])
                    4'h0: data_out = 8'h50; // 'P'
                    4'h1: data_out = 8'h37; // '7'
                    4'h2: data_out = 8'h3A; // ':'
                    4'h3: data_out = to_hex_ascii(latch_p7[31:28]);
                    4'h4: data_out = to_hex_ascii(latch_p7[27:24]);
                    4'h5: data_out = to_hex_ascii(latch_p7[23:20]);
                    4'h6: data_out = to_hex_ascii(latch_p7[19:16]);
                    4'h7: data_out = to_hex_ascii(latch_p7[15:12]);
                    4'h8: data_out = to_hex_ascii(latch_p7[11:8]);
                    4'h9: data_out = to_hex_ascii(latch_p7[7:4]);
                    4'hA: data_out = to_hex_ascii(latch_p7[3:0]);
                    default: data_out = 8'h20;
                endcase
            end
            default: data_out = 8'h20;
        endcase
    end
endmodule
