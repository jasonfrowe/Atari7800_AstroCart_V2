`timescale 1ns / 1ps

module diag_rom (
    input [15:0] a_stable,
    input [3:0] sd_state,
    input [9:0] byte_index,
    input [9:0] current_sector,
    input [7:0] last_byte_captured,
    input [31:0] checksum,
    input [31:0] psram_checksum,
    input [31:0] latch_p2,
    input [31:0] latch_p3,
    input [7:0] latch_p4,
    input [7:0] latch_p5,
    input [7:0] latch_p6,
    input [31:0] latch_p7,
    input [7:0] fb0,
    input [7:0] fb1,
    input [7:0] fb2,
    input [7:0] fb3,
    output reg [7:0] data_out
);
    always @* begin
        case (a_stable[3:0])
            4'h0: data_out = 8'h44;
            4'h1: data_out = 8'h49;
            4'h2: data_out = 8'h41;
            4'h3: data_out = 8'h47;
            default: data_out = 8'h20;
        endcase
    end
endmodule
