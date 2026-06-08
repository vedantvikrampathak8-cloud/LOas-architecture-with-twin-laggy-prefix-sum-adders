`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: laggy_prefix_sum
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
module laggy_prefix_sum #(
    parameter BM_WIDTH = 128,
    parameter N_ADDERS = 8,
    parameter OFF_W = 7
)(
    input logic clk,
    input logic rst_n,
    input logic start_i,
    input logic [BM_WIDTH-1:0] bm_in,
    output logic [BM_WIDTH-1:0][OFF_W-1:0] offset_out,
    output logic [OFF_W:0] pop_count,
    output logic done_o
);

    localparam STEPS = BM_WIDTH / N_ADDERS;

    logic [BM_WIDTH-1:0] bm_reg;
    logic [BM_WIDTH-1:0][OFF_W-1:0] offsets;
    logic [OFF_W:0] running_sum [0:N_ADDERS-1];
    logic [$clog2(STEPS):0] step;
    logic busy;
    logic pending;
    logic [BM_WIDTH-1:0] bm_pending;

    assign offset_out = offsets;
    assign done_o = ~busy & (step == STEPS);
    assign pop_count = running_sum[N_ADDERS-1];

    integer k;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            pending <= 1'b0;
            step <= '0;
            for (k = 0; k < N_ADDERS; k++) running_sum[k] <= '0;
        end else begin
            if (start_i && !busy) begin
                bm_reg <= bm_in;
                step <= '0;
                busy <= 1'b1;
                for (k = 0; k < N_ADDERS; k++) running_sum[k] <= '0;
            end else if (start_i && busy) begin
                pending <= 1'b1;
                bm_pending <= bm_in;
            end

            if (busy) begin
                for (k = 0; k < N_ADDERS; k++) begin : adder_loop
                    if ((step * N_ADDERS + k) < BM_WIDTH) begin
                        offsets[step * N_ADDERS + k] <= running_sum[k][OFF_W-1:0];
                        running_sum[k] <= running_sum[k] + {{OFF_W{1'b0}}, bm_reg[step * N_ADDERS + k]};
                    end
                end
                step <= step + 1;

                if (step == STEPS - 1) begin
                    busy <= 1'b0;
                    if (pending) begin
                        bm_reg <= bm_pending;
                        step <= '0;
                        busy <= 1'b1;
                        pending <= 1'b0;
                        for (k = 0; k < N_ADDERS; k++) running_sum[k] <= '0;
                    end
                end
            end
        end
    end

endmodule
