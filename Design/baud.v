`timescale 1ns / 1ps
`default_nettype none

module Baud #(parameter baud_rate = 9600,parameter sys_clk   = 100_000_000,parameter OVERSAMPLE = 16)
(input  wire clk, input wire sys_rst_l, output reg  baud_tick);
 
localparam integer Div = (sys_clk / (baud_rate * OVERSAMPLE));
 
reg [31:0] count;

 localparam integer Divv = (sys_clk / (baud_rate ));

always @(posedge clk or negedge sys_rst_l)
begin
    if (!sys_rst_l)
    begin
        count     <= 32'd0;
        baud_tick <= 1'b0;
    end
    else
    begin
        if (count == Div - 1)
        begin
            count     <= 32'd0;
            baud_tick <= 1'b1;
        end
        else
        begin
            count     <= count + 1;
            baud_tick <= 1'b0;
        end
    end
end

 
endmodule

