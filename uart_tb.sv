`timescale 1ns/1ps

module uart_tb;

    // Parameters
    localparam CLK_FREQ   = 50_000_000;
    localparam BAUD_RATE  = 115200;
    localparam CLK_PERIOD = 1_000_000_000 / CLK_FREQ;

    // DUT signals
    logic clk, rst;
    logic tx_start;
    logic [7:0] tx_data;
    logic parity_en, parity_odd;
    logic rx_line;
    logic tx_line;
    logic tx_busy;
    logic [7:0] rx_data;
    logic rx_valid;
    logic parity_error;
    logic frame_error;

    // Instantiate UART Top
    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .parity_en(parity_en),
        .parity_odd(parity_odd),
        .rx_line(rx_line),
        .tx_line(tx_line),
        .tx_busy(tx_busy),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .parity_error(parity_error),
        .frame_error(frame_error)
    );

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Connect TX to RX (loopback)
    assign rx_line = tx_line;

    task uart_send(input [7:0] data, input bit p_en, input bit p_odd);
        begin
            wait (!tx_busy);
            tx_data     = data;
            parity_en   = p_en;
            parity_odd  = p_odd;
            tx_start    = 1;
            @(posedge clk);
            tx_start    = 0;
            wait (rx_valid);
            $display("Sent: %h | Received: %h | Parity Error: %b | Frame Error: %b",
                    data, rx_data, parity_error, frame_error);
        end
    endtask

    initial begin
 
    $dumpfile("uart_wave.vcd");   // Create VCD file
    $dumpvars(0, uart_tb);        // Dump all variables in uart_tb

        $display("UART Testbench Start");
        clk = 0;
        rst = 1;
        tx_start = 0;
        parity_en = 0;
        parity_odd = 0;
        tx_data = 8'h00;

        #100;
        rst = 0;

        // Normal transmission, no parity
        uart_send(8'hA5, 0, 0);  // 10100101

        // Transmission with even parity
        uart_send(8'h5A, 1, 0);  // Even parity

        // Transmission with odd parity
        uart_send(8'h5A, 1, 1);  // Odd parity

        // Test parity error: inject wrong parity by overriding rx_line manually
        force dut.rx_inst.rx_line = 0;
        uart_send(8'hFF, 1, 0); // Should raise parity error
        release dut.rx_inst.rx_line;

        // Test frame error: inject wrong stop bit
        #200000;
        force dut.rx_inst.rx_line = 0;
        #100000;
        release dut.rx_inst.rx_line;

        #100000;
        $display("UART Testbench Done");
        $finish;
    end

endmodule
