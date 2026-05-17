`timescale 1ns / 1ps
`default_nettype none

module U_xmit (
    input  wire clk,
    input  wire rst,
    input  wire baud_tick,   
    input  wire xmitH,
    input  wire [7:0]xmit_dataH,
    output wire xmit_active,
    output reg  xmit_doneH,
    output reg  uart_xmit_dataH
);
 
parameter idle= 2'b00;
parameter start= 2'b01;
parameter data= 2'b10;
parameter stop= 2'b11;
 
reg [1:0]c_state;
reg [1:0]n_state;
reg [3:0]count;
reg [3:0]count_bit;
reg [7:0]shift;
 
//state register
always @(posedge clk or negedge rst)
begin
    if (!rst)
        c_state <= idle;
    else
        c_state <= n_state;
end
 

always @(posedge clk or negedge rst)
begin
    if (!rst)
    begin
        count     <= 4'd0;
        count_bit <= 4'd0;
        shift     <= 8'd0;
        xmit_doneH <= 1'b0;
    end
    
    else //if (baud_tick)   
    begin
        xmit_doneH <= 1'b0;   
 
        if (c_state == idle && xmitH)
        begin
            shift     <= xmit_dataH;
            count     <= 4'd0;
            count_bit <= 4'd0;
        end
 
        if (count == 4'd15)
        begin
            count     <= 4'd0;
            count_bit <= count_bit + 1;
 
            if (c_state == data)
                shift <= shift >> 1;
           
            if (c_state == stop && count_bit == 4'd9)
                xmit_doneH <= 1'b1;
        end
        else
        begin
            if (c_state == idle)
            begin
                count     <= 4'd0;
                count_bit <= 4'd0;
            end
            else
                count <= count + 1;
        end
    end
end
 
//next state logic 
always @(*)
begin
    case (c_state)
             idle: n_state = xmitH?start:idle;
             start: n_state = (count == 4'd15)?data:start;
             data: n_state = (count_bit == 4'd8 && count==4'd15)?stop:data;
             stop: n_state = (count == 4'd15)?idle:stop;
             default: n_state = idle;
    endcase
end
 
//serial output
always @(*)
begin
    if (!rst)
        uart_xmit_dataH = 1'b1;
    else
        case (c_state)
            idle: uart_xmit_dataH = 1'b1;
            start: uart_xmit_dataH = 1'b0;
            data: uart_xmit_dataH = shift[0];
            stop: uart_xmit_dataH = 1'b1;
            default: uart_xmit_dataH = 1'b1;
        endcase
end
 
assign xmit_active =(c_state!=idle);
 
endmodule
