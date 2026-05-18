module uart_top(sys_clk,sys_rst_l,xmitH,xmit_dataH,uart_rec_dataH,uart_XMIT_dataH,xmit_doneH,rec_readyH,rec_dataH,rec_busy,xmit_active);
input wire sys_clk,sys_rst_l,xmitH,uart_rec_dataH;
input wire [7:0]xmit_dataH;
output wire uart_XMIT_dataH,xmit_doneH,rec_readyH,rec_busy,xmit_active;
output wire [7:0]rec_dataH;

wire baud_tick;

Baud B(.clk(sys_clk), .sys_rst_l(sys_rst_l), .baud_tick(baud_tick));

U_xmit Tx(.clk(sys_clk), .rst(sys_rst_l), .baud_tick(baud_tick),
            .xmitH(xmitH), .xmit_dataH(xmit_dataH), .xmit_active(xmit_active),
            .xmit_doneH(xmit_doneH), .uart_xmit_dataH(uart_XMIT_dataH));

U_rec Rx(.clk(sys_clk),.rst(sys_rst_l),  .baud_tick(baud_tick),
            .uart_rec_dataH(uart_XMIT_dataH),   .rec_dataH(rec_dataH),
            .rec_readyH(rec_readyH), .rec_busy(rec_busy));		
		
endmodule
