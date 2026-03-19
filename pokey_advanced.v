`timescale 1ns / 1ps

module pokey_advanced (
    input clk,
    input enable_179mhz,
    input reset_n,
    input [3:0] addr,
    input [7:0] din,
    input we,
    output audio_pwm
);
    reg [7:0] tone;
    reg [7:0] ctr;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tone <= 8'h80;
            ctr <= 8'h00;
        end else begin
            if (we && enable_179mhz) tone <= din;
            ctr <= ctr + 1'b1;
        end
    end
    assign audio_pwm = (ctr < tone);
endmodule
