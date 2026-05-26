`timescale 1ns/1ps
`default_nettype none




module uart_self_check_tb;

 
    localparam CLK_PERIOD    = 20;          // ns
    localparam TX_FRAME_CLKS = 240_000;     // sys_clk cycles to wait for TX frame
    localparam RX_BIT_CLKS   = 20_832;      
    localparam RESET_CLKS    = 20;
    localparam SETTLE_CLKS   = 5_000;

  
    reg        sys_clk      = 0;
    reg        sys_rst      = 1;    // active-LOW
    reg        xmitH        = 0;
    reg  [7:0] xmit_dataH   = 0;
    reg        uart_REC_dataH = 1;  // idle HIGH

    wire       uart_XMIT_dataH;
    wire       xmit_done;
    wire       xmit_active;
    wire       rec_busy;
    wire       rec_ready;
    wire [7:0] rec_data;


    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;


    top_tx #(.d(8)) dut (
        .sys_clk         (sys_clk),
        .sys_rst         (sys_rst),
        .xmitH           (xmitH),
        .xmit_dataH      (xmit_dataH),
        .uart_REC_dataH  (uart_REC_dataH),   // driven by TB independently
        .uart_XMIT_dataH (uart_XMIT_dataH),
        .xmit_done       (xmit_done),
        .xmit_active     (xmit_active),
        .rec_busy        (rec_busy),
        .rec_ready       (rec_ready),
        .rec_data        (rec_data)
    );


    always #(CLK_PERIOD/2) sys_clk = ~sys_clk;


    initial begin
        $dumpfile("uart_self_check_tb.vcd");
        $dumpvars(0, uart_self_check_tb);
    end


    task do_reset;
        begin
            @(posedge sys_clk); #1;
            sys_rst = 0;
            repeat(RESET_CLKS) @(posedge sys_clk);
            sys_rst = 1;
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask


    task tx_send_byte;
        input [7:0]       data;
        input [200*8-1:0] name;
        begin
            @(posedge sys_clk); #1;
            xmit_dataH = data;
            xmitH      = 1;
            @(posedge sys_clk); #1;
            xmitH      = 0;

            repeat(TX_FRAME_CLKS) @(posedge sys_clk); #1;

            test_count = test_count + 1;
            if (xmit_done && !xmit_active && uart_XMIT_dataH === 1'b1) begin
                $display("[TX-PASS] %-22s  sent=0x%02h  done=%0b active=%0b line=%0b",
                         name, data, xmit_done, xmit_active, uart_XMIT_dataH);
                pass_count = pass_count + 1;
            end else begin
                $display("[TX-FAIL] %-22s  sent=0x%02h  done=%0b active=%0b line=%0b",
                         name, data, xmit_done, xmit_active, uart_XMIT_dataH);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask


    task tx_send_byte_check_signals;
        input [7:0]       data;
        input [200*8-1:0] name;
        reg   active_seen;
        integer timeout;
        begin
            active_seen = 0;

            @(posedge sys_clk); #1;
            xmit_dataH = data;
            xmitH      = 1;
            @(posedge sys_clk); #1;
            xmitH      = 0;

            timeout = 0;
            while (!xmit_active && timeout < 6000) begin
                @(posedge sys_clk); #1; timeout = timeout + 1;
            end
            if (xmit_active) active_seen = 1;

            repeat(TX_FRAME_CLKS) @(posedge sys_clk); #1;

            test_count = test_count + 1;
            if (active_seen && xmit_done && !xmit_active) begin
                $display("[TX-PASS] %-22s  sent=0x%02h  active_seen=%0b done=%0b",
                         name, data, active_seen, xmit_done);
                pass_count = pass_count + 1;
            end else begin
                $display("[TX-FAIL] %-22s  sent=0x%02h  active_seen=%0b done=%0b active=%0b",
                         name, data, active_seen, xmit_done, xmit_active);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask


    task tx_back_to_back;
        input [7:0]       data1, data2;
        input [200*8-1:0] name;
        begin
            @(posedge sys_clk); #1;
            xmit_dataH = data1;
            xmitH      = 1;              
            repeat(TX_FRAME_CLKS) @(posedge sys_clk);

            xmit_dataH = data2;
            repeat(TX_FRAME_CLKS) @(posedge sys_clk);
            xmitH = 0;
            repeat(TX_FRAME_CLKS) @(posedge sys_clk); #1;

            test_count = test_count + 1;
            if (xmit_done && !xmit_active) begin
                $display("[TX-PASS] %-22s  d1=0x%02h d2=0x%02h  done=%0b",
                         name, data1, data2, xmit_done);
                pass_count = pass_count + 1;
            end else begin
                $display("[TX-FAIL] %-22s  d1=0x%02h d2=0x%02h  done=%0b active=%0b",
                         name, data1, data2, xmit_done, xmit_active);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask


    task tx_reset_mid_tx;
        input [7:0]       data;
        input [200*8-1:0] name;
        begin
            @(posedge sys_clk); #1;
            xmit_dataH = data;
            xmitH      = 1;
            @(posedge sys_clk); #1;
            xmitH      = 0;

            // wait until 3 bits into the data field
            repeat(RX_BIT_CLKS * 3) @(posedge sys_clk);

            sys_rst = 0;
            repeat(RESET_CLKS) @(posedge sys_clk);
            sys_rst = 1;
            repeat(SETTLE_CLKS) @(posedge sys_clk);

            test_count = test_count + 1;
            if (!xmit_active && uart_XMIT_dataH === 1'b1) begin
                $display("[TX-PASS] %-22s  rst_mid_tx: line=%0b active=%0b",
                         name, uart_XMIT_dataH, xmit_active);
                pass_count = pass_count + 1;
            end else begin
                $display("[TX-FAIL] %-22s  rst_mid_tx: line=%0b active=%0b  <--NOT IDLE",
                         name, uart_XMIT_dataH, xmit_active);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask


    task rx_send_byte;
        input [7:0]       data;
        input [200*8-1:0] name;
        integer b;
        begin
            
            @(posedge sys_clk); #1;
            uart_REC_dataH = 0;
            repeat(RX_BIT_CLKS) @(posedge sys_clk);

            
            for (b = 0; b < 8; b = b + 1) begin
                #1; uart_REC_dataH = data[b];
                repeat(RX_BIT_CLKS) @(posedge sys_clk);
            end

    
            #1; uart_REC_dataH = 1;
            repeat(RX_BIT_CLKS) @(posedge sys_clk);

            
            repeat(RX_BIT_CLKS) @(posedge sys_clk); #1;

            test_count = test_count + 1;
            if (rec_data === data && rec_ready && !rec_busy) begin
                $display("[RX-PASS] %-22s  sent=0x%02h  got=0x%02h  ready=%0b busy=%0b",
                         name, data, rec_data, rec_ready, rec_busy);
                pass_count = pass_count + 1;
            end else begin
                $display("[RX-FAIL] %-22s  sent=0x%02h  got=0x%02h  ready=%0b busy=%0b",
                         name, data, rec_data, rec_ready, rec_busy);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask

    task rx_false_start;
        input [200*8-1:0] name;
        integer glitch_clks;
        begin
           
            glitch_clks = RX_BIT_CLKS * 6 / 16;

            @(posedge sys_clk); #1;
            uart_REC_dataH = 0;            
            repeat(glitch_clks) @(posedge sys_clk);
            #1;
            uart_REC_dataH = 1;           
            repeat(SETTLE_CLKS) @(posedge sys_clk); #1;

            
            test_count = test_count + 1;
            if (!rec_busy && rec_ready) begin
                $display("[RX-PASS] %-22s  false_start: busy=%0b ready=%0b (stayed idle)",
                         name, rec_busy, rec_ready);
                pass_count = pass_count + 1;
            end else begin
                $display("[RX-FAIL] %-22s  false_start: busy=%0b ready=%0b (should be idle)",
                         name, rec_busy, rec_ready);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask


    task rx_reset_mid_rx;
        input [7:0]       data;
        input [200*8-1:0] name;
        begin
            
            @(posedge sys_clk); #1;
            uart_REC_dataH = 0;           // start bit
            repeat(RX_BIT_CLKS) @(posedge sys_clk);
            #1; uart_REC_dataH = data[0];
            repeat(RX_BIT_CLKS * 3) @(posedge sys_clk);

            // assert reset 
            sys_rst = 0;
            repeat(RESET_CLKS) @(posedge sys_clk);
            sys_rst = 1;
            uart_REC_dataH = 1;           // restore idle line
            repeat(SETTLE_CLKS) @(posedge sys_clk); #1;

            test_count = test_count + 1;
            if (!rec_busy && rec_ready) begin
                $display("[RX-PASS] %-22s  rst_mid_rx: busy=%0b ready=%0b",
                         name, rec_busy, rec_ready);
                pass_count = pass_count + 1;
            end else begin
                $display("[RX-FAIL] %-22s  rst_mid_rx: busy=%0b ready=%0b  <--NOT IDLE",
                         name, rec_busy, rec_ready);
                fail_count = fail_count + 1;
            end
            repeat(SETTLE_CLKS) @(posedge sys_clk);
        end
    endtask

 
    task verify_tx_idle;
        input [200*8-1:0] name;
        begin
            repeat(SETTLE_CLKS) @(posedge sys_clk); #1;
            test_count = test_count + 1;
            if (uart_XMIT_dataH === 1'b1 && xmit_done && !xmit_active) begin
                $display("[TX-PASS] %-22s  tx idle: line=%0b done=%0b active=%0b",
                         name, uart_XMIT_dataH, xmit_done, xmit_active);
                pass_count = pass_count + 1;
            end else begin
                $display("[TX-FAIL] %-22s  tx idle: line=%0b done=%0b active=%0b",
                         name, uart_XMIT_dataH, xmit_done, xmit_active);
                fail_count = fail_count + 1;
            end
        end
    endtask


    initial begin
        sys_rst       = 1;
        xmitH         = 0;
        xmit_dataH    = 8'h00;
        uart_REC_dataH = 1;

        do_reset;

        $display("==============================================================");
        $display("  UART Self-Checking TB  — Separate TX / RX  (2400 @ 50MHz) ");
        $display("==============================================================\n");

 
        $display("--- TX-G1: Idle Line After Reset ---");
        verify_tx_idle("TX_IDLE_RESET");

   
        $display("\n--- TX-G2: Signal Handshake ---");
        tx_send_byte_check_signals(8'hA5, "TX_HSHK_A5");
        tx_send_byte_check_signals(8'h5A, "TX_HSHK_5A");
        tx_send_byte_check_signals(8'hFF, "TX_HSHK_FF");
        tx_send_byte_check_signals(8'h00, "TX_HSHK_00");


        $display("\n--- TX-G3: Walking Ones ---");
        tx_send_byte(8'b00000001, "TX_WALK1_B0");
        tx_send_byte(8'b00000010, "TX_WALK1_B1");
        tx_send_byte(8'b00000100, "TX_WALK1_B2");
        tx_send_byte(8'b00001000, "TX_WALK1_B3");
        tx_send_byte(8'b00010000, "TX_WALK1_B4");
        tx_send_byte(8'b00100000, "TX_WALK1_B5");
        tx_send_byte(8'b01000000, "TX_WALK1_B6");
        tx_send_byte(8'b10000000, "TX_WALK1_B7");

        $display("\n--- TX-G4: Walking Zeros ---");
        tx_send_byte(8'b11111110, "TX_WALK0_B0");
        tx_send_byte(8'b11111101, "TX_WALK0_B1");
        tx_send_byte(8'b11111011, "TX_WALK0_B2");
        tx_send_byte(8'b11110111, "TX_WALK0_B3");
        tx_send_byte(8'b11101111, "TX_WALK0_B4");
        tx_send_byte(8'b11011111, "TX_WALK0_B5");
        tx_send_byte(8'b10111111, "TX_WALK0_B6");
        tx_send_byte(8'b01111111, "TX_WALK0_B7");


        $display("\n--- TX-G5: Boundary Values ---");
        tx_send_byte(8'h00, "TX_NULL");
        tx_send_byte(8'hFF, "TX_ALL_ONES");
        tx_send_byte(8'h7F, "TX_MID_LOW");
        tx_send_byte(8'h80, "TX_MID_HIGH");
        tx_send_byte(8'h0F, "TX_LOW_NIB");
        tx_send_byte(8'hF0, "TX_HIGH_NIB");
        tx_send_byte(8'h55, "TX_ALT_55");
        tx_send_byte(8'hAA, "TX_ALT_AA");


        $display("\n--- TX-G6: Back-to-Back (done->start) ---");
        tx_back_to_back(8'hAA, 8'h55, "TX_B2B_AA55");
        tx_back_to_back(8'h0F, 8'hF0, "TX_B2B_0FF0");
        tx_back_to_back(8'h12, 8'h34, "TX_B2B_1234");
        tx_back_to_back(8'hFF, 8'h00, "TX_B2B_FF00");

        $display("\n--- TX-G7: Async Reset Mid-TX ---");
        tx_reset_mid_tx(8'h55, "TX_RST_MID_55");
        tx_reset_mid_tx(8'hAA, "TX_RST_MID_AA");
        tx_reset_mid_tx(8'hFF, "TX_RST_MID_FF");
        verify_tx_idle("TX_IDLE_AFTER_RST");


        $display("\n--- TX-G8: Sequential 0x00-0x1F ---");
        begin : tx_seq
            integer i;
            for (i = 0; i <= 31; i = i + 1)
                tx_send_byte(i[7:0], "TX_SEQ");
        end

       
        $display("\n--- TX-G9: Reset from Idle ---");
        do_reset;
        verify_tx_idle("TX_IDLE_RST_IDLE");

       
        $display("\n--- RX-G1: Walking Ones ---");
        rx_send_byte(8'b00000001, "RX_WALK1_B0");
        rx_send_byte(8'b00000010, "RX_WALK1_B1");
        rx_send_byte(8'b00000100, "RX_WALK1_B2");
        rx_send_byte(8'b00001000, "RX_WALK1_B3");
        rx_send_byte(8'b00010000, "RX_WALK1_B4");
        rx_send_byte(8'b00100000, "RX_WALK1_B5");
        rx_send_byte(8'b01000000, "RX_WALK1_B6");
        rx_send_byte(8'b10000000, "RX_WALK1_B7");

       
        $display("\n--- RX-G2: Walking Zeros ---");
        rx_send_byte(8'b11111110, "RX_WALK0_B0");
        rx_send_byte(8'b11111101, "RX_WALK0_B1");
        rx_send_byte(8'b11111011, "RX_WALK0_B2");
        rx_send_byte(8'b11110111, "RX_WALK0_B3");
        rx_send_byte(8'b11101111, "RX_WALK0_B4");
        rx_send_byte(8'b11011111, "RX_WALK0_B5");
        rx_send_byte(8'b10111111, "RX_WALK0_B6");
        rx_send_byte(8'b01111111, "RX_WALK0_B7");

       
        $display("\n--- RX-G3: Boundary Values ---");
        rx_send_byte(8'h00, "RX_NULL");
        rx_send_byte(8'hFF, "RX_ALL_ONES");
        rx_send_byte(8'h7F, "RX_MID_LOW");
        rx_send_byte(8'h80, "RX_MID_HIGH");
        rx_send_byte(8'h0F, "RX_LOW_NIB");
        rx_send_byte(8'hF0, "RX_HIGH_NIB");
        rx_send_byte(8'hA5, "RX_A5");
        rx_send_byte(8'h5A, "RX_5A");
        rx_send_byte(8'h55, "RX_ALT_55");
        rx_send_byte(8'hAA, "RX_ALT_AA");

       
        $display("\n--- RX-G4: False Start Glitch (data_out->idle) ---");
        rx_false_start("RX_FALSE_START_1");
        rx_false_start("RX_FALSE_START_2");
        rx_false_start("RX_FALSE_START_3");
      
        rx_send_byte(8'hA5, "RX_AFTER_FALSE1");
        rx_send_byte(8'h5A, "RX_AFTER_FALSE2");

       
        $display("\n--- RX-G5: Async Reset Mid-RX ---");
        rx_reset_mid_rx(8'h55, "RX_RST_MID_55");
        rx_reset_mid_rx(8'hAA, "RX_RST_MID_AA");
       
        rx_send_byte(8'hBE, "RX_AFTER_RST1");
        rx_send_byte(8'hEF, "RX_AFTER_RST2");

        
        $display("\n--- RX-G6: Sequential 0x00-0x1F ---");
        begin : rx_seq
            integer j;
            for (j = 0; j <= 31; j = j + 1)
                rx_send_byte(j[7:0], "RX_SEQ");
        end

       
        $display("\n--- RX-G7: ASCII ---");
        rx_send_byte(8'h41, "RX_ASCII_A");
        rx_send_byte(8'h5A, "RX_ASCII_Z");
        rx_send_byte(8'h61, "RX_ASCII_a");
        rx_send_byte(8'h39, "RX_ASCII_9");

    
        $display("\n==============================================================");
        $display("  RESULTS  Total: %0d   Pass: %0d   Fail: %0d",
                 test_count, pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** %0d TEST(S) FAILED — open waveform for details ***",
                     fail_count);
        $display("==============================================================");
        #500;
        $finish;
    end

endmodule
