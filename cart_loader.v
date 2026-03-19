`timescale 1ns / 1ps

module cart_loader (
    input clk_sys,
    input clk_sd,
    input reset,
    input [15:0] a_stable,
    input [7:0] d,
    input rw_safe,
    input phi2_safe,
    input trigger_we,
    output sd_cs,
    output sd_mosi,
    input sd_miso,
    output sd_clk,
    input psram_busy,
    output reg psram_wr_req,
    output reg [22:0] psram_write_addr_latched,
    output reg [15:0] acc_word0,
    output reg game_loaded,
    output reg switch_pending,
    output reg [3:0] sd_state,
    output reg busy,
    output reg write_pending,
    output reg bram_we,
    output reg [15:0] bram_addr,
    output reg [7:0] bram_data,
    output reg [31:0] cart_rom_size,
    output reg cart_has_pokey,
    output reg [15:0] cart_pokey_addr,
    output reg [3:0] cart_mapper,
    output reg cart_ram_at_4000,
    output reg [3:0] cart_sgm_fixed_bank
);
    assign sd_cs = 1'b1;
    assign sd_mosi = 1'b1;
    assign sd_clk = clk_sd;

    always @(posedge clk_sys) begin
        if (reset) begin
            psram_wr_req <= 1'b0;
            psram_write_addr_latched <= 23'd0;
            acc_word0 <= 16'd0;
            game_loaded <= 1'b0;
            switch_pending <= 1'b0;
            sd_state <= 4'd0;
            busy <= 1'b0;
            write_pending <= 1'b0;
            bram_we <= 1'b0;
            bram_addr <= 16'd0;
            bram_data <= 8'd0;
            cart_rom_size <= 32'd49152;
            cart_has_pokey <= 1'b1;
            cart_pokey_addr <= 16'h0450;
            cart_mapper <= 4'd0;
            cart_ram_at_4000 <= 1'b0;
            cart_sgm_fixed_bank <= 4'd0;
        end else begin
            psram_wr_req <= 1'b0;
            bram_we <= 1'b0;
        end
    end
endmodule
