`timescale 1ns / 1ps

module a78_header_parser (
    input wire clk,
    input wire reset_n,
    input wire start_parse,
    input wire [7:0] header_byte,
    input wire header_byte_valid,
    output reg parse_done,
    output reg [255:0] cart_name,
    output reg [31:0] cart_size,
    output reg [15:0] cart_type,
    output reg cart_has_pokey,
    output reg cart_has_ram,
    output reg [15:0] pokey_addr,
    output reg [7:0] controller_1,
    output reg [7:0] controller_2,
    output reg tv_type
);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            parse_done <= 1'b0;
            cart_name <= 256'd0;
            cart_size <= 32'd0;
            cart_type <= 16'd0;
            cart_has_pokey <= 1'b0;
            cart_has_ram <= 1'b0;
            pokey_addr <= 16'h0000;
            controller_1 <= 8'd0;
            controller_2 <= 8'd0;
            tv_type <= 1'b0;
        end else begin
            parse_done <= start_parse && header_byte_valid;
            if (start_parse && header_byte_valid) begin
                cart_name[7:0] <= header_byte;
                cart_size <= 32'd49152;
                cart_type <= 16'h0040;
                cart_has_pokey <= 1'b1;
                cart_has_ram <= 1'b0;
                pokey_addr <= 16'h0450;
                controller_1 <= 8'd1;
                controller_2 <= 8'd1;
                tv_type <= 1'b0;
            end
        end
    end
endmodule
