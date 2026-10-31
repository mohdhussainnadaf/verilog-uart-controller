`timescale 1ns / 1ps

module tb_uart_top();
    parameter DATA_WIDTH = 8;
    parameter CLK_PERIOD = 20;

    reg                   clk, rst_n;
    reg  [15:0]           dvsr;
    reg                   tx_start;
    reg  [DATA_WIDTH-1:0] tx_data_in;
    wire                  tx, tx_full, rx;
    reg                   rx_read;
    wire [DATA_WIDTH-1:0] rx_data_out;
    wire                  rx_empty, rx_frame_err;

    assign rx = tx;

    uart_top #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(16)) uut (
        .clk(clk), .rst_n(rst_n), .dvsr(dvsr),
        .tx_start(tx_start), .tx_data_in(tx_data_in),
        .tx(tx), .tx_full(tx_full), .rx(rx),
        .rx_read(rx_read), .rx_data_out(rx_data_out),
        .rx_empty(rx_empty), .rx_frame_err(rx_frame_err)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_top);
    end

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; dvsr = 16'd10; tx_start = 0; tx_data_in = 8'h00; rx_read = 0;
        #(CLK_PERIOD * 5); rst_n = 1; #(CLK_PERIOD * 5);

        $display("[%0t ns] --- Starting UART Data Transmission Test ---", $time);
        
        send_byte(8'hA5);
        send_byte(8'h3C);

        // Wait until 1st byte is fully received in RX FIFO
        @ (negedge rx_empty);
        #(CLK_PERIOD * 5);
        read_and_verify(8'hA5);

        // Wait until 2nd byte is fully received in RX FIFO
        @ (negedge rx_empty);
        #(CLK_PERIOD * 5);
        read_and_verify(8'h3C);

        $display("[%0t ns] --- All UART Tests Passed Successfully! ---", $time);
        $finish;
    end

    task send_byte(input [7:0] data);
        begin
            @(posedge clk); tx_data_in = data; tx_start = 1'b1;
            @(posedge clk); tx_start = 1'b0;
            $display("[%0t ns] Loaded 0x%h into TX FIFO", $time, data);
        end
    endtask

    task read_and_verify(input [7:0] expected_data);
        begin
            @(posedge clk); rx_read = 1'b1;
            @(posedge clk); rx_read = 1'b0;
            if (rx_data_out === expected_data)
                $display("[%0t ns] SUCCESS: Received 0x%h matching Expected 0x%h", $time, rx_data_out, expected_data);
            else begin
                $display("[%0t ns] ERROR: Received 0x%h, Expected 0x%h", $time, rx_data_out, expected_data);
                $stop;
            end
        end
    endtask
endmodule
