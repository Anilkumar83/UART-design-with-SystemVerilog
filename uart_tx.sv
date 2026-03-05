`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.08.2025 12:55:02
// Design Name: 
// Module Name: uart_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        tx_start,
    input  logic [7:0]  tx_data,
    input  logic        parity_en,
    input  logic        parity_odd,
    output logic        tx_line,
    output logic        tx_busy
);

    localparam DIV_COUNT = CLK_FREQ / BAUD_RATE;
    localparam TOTAL_BITS = 10 + 1; // start + 8 data + parity + stop (optional)

    logic [10:0] shift_reg;
    logic [3:0]  bit_idx;
    logic [15:0] clk_cnt;
    logic        sending;
    logic        parity;

    always_comb begin
        parity = parity_odd ? ~^tx_data : ^tx_data;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_line   <= 1;
            tx_busy   <= 0;
            shift_reg <= 0;
            bit_idx   <= 0;
            clk_cnt   <= 0;
            sending   <= 0;
        end else begin
            if (tx_start && !tx_busy) begin
                shift_reg <= {1'b1, parity_en ? parity : 1'b0, tx_data, 1'b0};
                bit_idx   <= parity_en ? 10 : 9;
                tx_busy   <= 1;
                sending   <= 1;
                clk_cnt   <= DIV_COUNT;
                tx_line   <= 0; // Start bit
            end else if (sending) begin
                if (clk_cnt == 0) begin
                    shift_reg <= shift_reg >> 1;
                    bit_idx   <= bit_idx - 1;
                    tx_line   <= shift_reg[0];
                    clk_cnt   <= DIV_COUNT;
                    if (bit_idx == 0) begin
                        tx_busy <= 0;
                        sending <= 0;
                        tx_line <= 1;
                    end
                end else begin
                    clk_cnt <= clk_cnt - 1;
                end
            end
        end
    end
endmodule

module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        rx_line,
    input  logic        parity_en,
    input  logic        parity_odd,
    output logic [7:0]  rx_data,
    output logic        rx_valid,
    output logic        parity_error,
    output logic        frame_error
);

    localparam DIV_COUNT = CLK_FREQ / BAUD_RATE;
    localparam HALF_DIV  = DIV_COUNT / 2;

    typedef enum logic [2:0] {
        IDLE, START, DATA, PARITY, STOP
    } state_t;

    state_t state;
    logic [3:0] bit_idx;
    logic [15:0] clk_cnt;
    logic [7:0] data_reg;
    logic       rx_parity;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= IDLE;
            rx_data       <= 0;
            rx_valid      <= 0;
            bit_idx       <= 0;
            clk_cnt       <= 0;
            parity_error  <= 0;
            frame_error   <= 0;
        end else begin
            rx_valid <= 0;
            case (state)
                IDLE: if (!rx_line) begin
                    state    <= START;
                    clk_cnt  <= HALF_DIV;
                end
                START: if (clk_cnt == 0) begin
                    state    <= DATA;
                    clk_cnt  <= DIV_COUNT;
                    bit_idx  <= 0;
                end else clk_cnt <= clk_cnt - 1;

                DATA: if (clk_cnt == 0) begin
                    data_reg <= {rx_line, data_reg[7:1]};
                    clk_cnt  <= DIV_COUNT;
                    bit_idx  <= bit_idx + 1;
                    if (bit_idx == 7)
                        state <= parity_en ? PARITY : STOP;
                end else clk_cnt <= clk_cnt - 1;

                PARITY: if (clk_cnt == 0) begin
                    rx_parity <= rx_line;
                    state     <= STOP;
                    clk_cnt   <= DIV_COUNT;
                end else clk_cnt <= clk_cnt - 1;

                STOP: if (clk_cnt == 0) begin
                    rx_valid     <= 1;
                    rx_data      <= data_reg;
                    parity_error <= parity_en ? (parity_odd ? ~^data_reg != rx_parity : ^data_reg != rx_parity) : 0;
                    frame_error  <= ~rx_line;
                    state        <= IDLE;
                end else clk_cnt <= clk_cnt - 1;
            endcase
        end
    end
endmodule
module uart_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        tx_start,
    input  logic [7:0]  tx_data,
    input  logic        parity_en,
    input  logic        parity_odd,
    input  logic        rx_line,
    output logic        tx_line,
    output logic        tx_busy,
    output logic [7:0]  rx_data,
    output logic        rx_valid,
    output logic        parity_error,
    output logic        frame_error
);

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .parity_en(parity_en),
        .parity_odd(parity_odd),
        .tx_line(tx_line),
        .tx_busy(tx_busy)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx_line(rx_line),
        .parity_en(parity_en),
        .parity_odd(parity_odd),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .parity_error(parity_error),
        .frame_error(frame_error)
    );

endmodule

