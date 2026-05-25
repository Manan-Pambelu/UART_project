`timescale 1ns / 1ps
`default_nettype none

module U_rec(
   input  wire  clk,
   input  wire  rst,
   input  wire  baud_tick,          
   input  wire  uart_rec_dataH,
   output reg  [7:0]rec_dataH,
   output wire  rec_readyH,
   output wire  rec_busy
);
 
parameter idle     = 2'b00;
parameter start    = 2'b01;
parameter data_rec = 2'b10;
parameter stop     = 2'b11;
 
reg [1:0]c_state;
reg [1:0]n_state;
reg [7:0]shift_rec;
reg [3:0]count;
reg [3:0]count_bit;
reg FF1,FF2;
wire INP=FF2;
 
//synchronizer
   always @(posedge baud_tick or negedge rst)
begin
    if (!rst)
    begin
        FF1 <= 1'b1;
        FF2 <= 1'b1;
    end
    else
    begin
        FF1 <= uart_rec_dataH;
        FF2 <= FF1;
    end
end
 
//state register
   always @(posedge baud_tick or negedge rst)
begin
    if (!rst)
        c_state <= idle;
    else
        c_state <= n_state;
end
 
   always @(posedge baud_tick or negedge rst)
begin
    if (!rst)
    begin
        count     <= 4'd0;
        count_bit <= 4'd0;
        shift_rec <= 8'd0;
    end
    else if (baud_tick)   
    begin
        if (count == 4'd15)
        begin
            count<= 4'd0;
            count_bit<= count_bit+1;
 
            if (c_state== data_rec)
                shift_rec <={INP, shift_rec[7:1]};
        end
        else
        begin
        
            if (c_state == stop)
            begin
                rec_dataH <= shift_rec;
            end
            
            if (c_state==idle)
            begin
                count <=(INP == 1'b0)? 4'd8:4'd0;
                count_bit<=4'd0;
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
        idle:n_state = (INP == 1'b0)? start:idle;
        start:n_state = (count_bit == 4'd1)? data_rec:start;
        data_rec:n_state = (count_bit == 4'd9)? stop:data_rec;
        stop:n_state = (count_bit == 4'd10 && count == 4'd0)? idle:stop;
        default:n_state = idle;
    endcase
end
 

   always @(posedge baud_tick or negedge rst)
begin
    if (!rst)
    begin
        rec_dataH <= 8'd0;
        
    end
    else
    begin
        
        if (c_state == stop && count == 4'd15 && count_bit == 4'd10)
        begin
            rec_dataH <= shift_rec;
         
        end
    end
end
 
assign rec_busy=(c_state!= idle);
assign rec_readyH=(c_state== idle);

 
endmodule
