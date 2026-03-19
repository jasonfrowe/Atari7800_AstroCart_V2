`timescale 1ns / 1ps

module smart_blinkers (
    input clk,
    input phi2_safe,
    input [15:0] a_stable,
    input is_pokey,
    input is_2200,
    input rw_safe,
    input buf_oe,
    input buf_dir,
    input psram_busy,
    input psram_rd_req,
    input pll_lock,
    input game_loaded,
    input write_pending,
    output [5:0] led
);
    reg [25:0] hb;
    always @(posedge clk) hb <= hb + 1'b1;
    assign led[0] = !pll_lock;
    assign led[1] = !game_loaded;
    assign led[2] = !phi2_safe;
    assign led[3] = !buf_dir;
    assign led[4] = !psram_busy;
    assign led[5] = !hb[25];
endmodule
