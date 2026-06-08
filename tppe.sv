`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: tppe
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
module tppe #(
    parameter BM_WIDTH = 128,
    parameter OFF_W = 7,
    parameter W_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter T = 4,
    parameter N_ADDERS = 8,
    parameter THRESHOLD = 1
)(
    input logic clk,
    input logic rst_n,
    input logic start_i,
    input logic [BM_WIDTH-1:0] bm_b,
    input logic [W_WIDTH-1:0] fiber_b_data [0:BM_WIDTH-1],
    input logic [BM_WIDTH-1:0] bm_a,
    input logic [T-1:0] fiber_a_data [0:BM_WIDTH-1],
    output logic [T-1:0] spike_out,
    output logic done_o,
    output logic ready_o
);

    logic [T-1:0][ACC_WIDTH-1:0] ij_result;
    logic ij_done;

    inner_join_unit #(
        .BM_WIDTH(BM_WIDTH),
        .OFF_W(OFF_W),
        .W_WIDTH(W_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .T(T),
        .N_ADDERS(N_ADDERS)
    ) u_ij (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start_i),
        .bm_a(bm_a),
        .bm_b(bm_b),
        .fiber_b_data(fiber_b_data),
        .fiber_a_data(fiber_a_data),
        .result(ij_result),
        .done_o(ij_done),
        .ready_o(ready_o)
    );

    p_lif #(
        .T(T),
        .ACC_WIDTH(ACC_WIDTH),
        .THRESHOLD(THRESHOLD)
    ) u_plif (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(ij_done),
        .membrane(ij_result),
        .spike_out(spike_out),
        .valid_o(done_o)
    );

endmodule
