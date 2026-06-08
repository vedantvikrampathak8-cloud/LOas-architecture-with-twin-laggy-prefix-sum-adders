`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: top_loas
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
module top_loas #(
    parameter BM_WIDTH = 128,
    parameter OFF_W = 7,
    parameter W_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter T = 4,
    parameter N_TPPE = 16,
    parameter N_ADDERS = 8,
    parameter THRESHOLD = 1
)(
    input logic clk,
    input logic rst_n,
    input logic start_i,
    input logic [BM_WIDTH-1:0] bm_b,
    input logic [W_WIDTH-1:0] fiber_b_data [0:BM_WIDTH-1],
    input logic [BM_WIDTH-1:0] bm_a [0:N_TPPE-1],
    input logic [T-1:0] fiber_a_data [0:N_TPPE-1][0:BM_WIDTH-1],
    output logic [N_TPPE-1:0][T-1:0] spike_out,
    output logic [N_TPPE-1:0] done_o,
    output logic [N_TPPE-1:0] ready_o
);

    genvar i, j;
    generate
        for (i = 0; i < N_TPPE; i++) begin : tppe_array
            logic [T-1:0] fiber_a_local [0:BM_WIDTH-1];
            for (j = 0; j < BM_WIDTH; j++) begin : assign_fa
                assign fiber_a_local[j] = fiber_a_data[i][j];
            end
            tppe #(
                .BM_WIDTH(BM_WIDTH),
                .OFF_W(OFF_W),
                .W_WIDTH(W_WIDTH),
                .ACC_WIDTH(ACC_WIDTH),
                .T(T),
                .N_ADDERS(N_ADDERS),
                .THRESHOLD(THRESHOLD)
            ) u_tppe (
                .clk(clk),
                .rst_n(rst_n),
                .start_i(start_i),
                .bm_b(bm_b),
                .fiber_b_data(fiber_b_data),
                .bm_a(bm_a[i]),
                .fiber_a_data(fiber_a_local),
                .spike_out(spike_out[i]),
                .done_o(done_o[i]),
                .ready_o(ready_o[i])
            );
        end
    endgenerate

endmodule
