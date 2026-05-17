`timescale 1ns / 1ps
`default_nettype none

module Baud #(parameter baud_rate = 9600,parameter sys_clk   = 100_000_000,parameter OVERSAMPLE = 16)
(input wire clk, input wire sys_rst_l, output reg  baud_rec ,baud_xmit);
	
localparam integer Div_rec = (sys_clk / (baud_rate * OVERSAMPLE));
localparam integer Div_xmit = (sys_clk / (baud_rate ));
 
reg [31:0] count_rec;
reg [31:0] count_xmit;
 
always @(posedge clk or negedge sys_rst_l)
begin
    if (!sys_rst_l)
    begin
        count_rec     <= 32'd0;
        baud_rec <= 1'b0;
    end
    else
    begin
        if (count_rec == Div_rec - 1)
        begin
            count_rec     <= 32'd0;
            baud_rec <= 1'b1;
        end
        else
        begin
            count_rec     <= count_rec + 1;
            baud_rec <= 1'b0;
        end
    end
end
 
always @(posedge clk or negedge sys_rst_l)
begin
    if (!sys_rst_l)
    begin
        count_xmit     <= 32'd0;
        baud_xmit <= 1'b0;
    end
    else
    begin
        if (count_xmit == Div_xmit - 1)
        begin
            count_xmit     <= 32'd0;
            baud_xmit <= 1'b1;
        end
        else
        begin
            count_xmit     <= count_xmit + 1;
            baud_xmit <= 1'b0;
        end
    end
end

endmodule
