`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: inner_join_unit
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
module inner_join_unit #(
    parameter BM_WIDTH = 128,
    parameter OFF_W = 7,
    parameter W_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter T = 4,
    parameter N_ADDERS = 8
)(
    input logic clk,
    input logic rst_n,
    input logic start_i,
    input logic [BM_WIDTH-1:0] bm_a,
    input logic [BM_WIDTH-1:0] bm_b,
    input logic [W_WIDTH-1:0] fiber_b_data [0:BM_WIDTH-1],
    input logic [T-1:0] fiber_a_data [0:BM_WIDTH-1],
    output logic [T-1:0][ACC_WIDTH-1:0] result,
    output logic done_o,
    output logic ready_o
);

    typedef enum logic [1:0] {IDLE, WAIT_COLD, SCAN, DONE_ST} state_t;
    state_t state;

    logic laggy_start_a, laggy_start_b;
    logic [BM_WIDTH-1:0][OFF_W-1:0] offset_a, offset_b;
    logic laggy_done_a, laggy_done_b;

    laggy_prefix_sum #(
        .BM_WIDTH(BM_WIDTH), .N_ADDERS(N_ADDERS), .OFF_W(OFF_W)
    ) u_laggy_a (
        .clk(clk), .rst_n(rst_n), .start_i(laggy_start_a), .bm_in(bm_a),
        .offset_out(offset_a), .pop_count(), .done_o(laggy_done_a)
    );

    laggy_prefix_sum #(
        .BM_WIDTH(BM_WIDTH), .N_ADDERS(N_ADDERS), .OFF_W(OFF_W)
    ) u_laggy_b (
        .clk(clk), .rst_n(rst_n), .start_i(laggy_start_b), .bm_in(bm_b),
        .offset_out(offset_b), .pop_count(), .done_o(laggy_done_b)
    );

    logic [BM_WIDTH-1:0] and_work;
    logic [OFF_W-1:0] pe_pos;
    logic pe_valid;

    priority_encoder #(.WIDTH(BM_WIDTH), .OUT_W(OFF_W)) u_pe (
        .in(and_work), .pos(pe_pos), .valid(pe_valid)
    );

    logic [BM_WIDTH-1:0][OFF_W-1:0] offset_a_latch;
    logic [BM_WIDTH-1:0][OFF_W-1:0] offset_b_latch;

    logic [BM_WIDTH-1:0] and_next;
    logic next_pending;
    logic warm_path;

    logic [T-1:0][ACC_WIDTH-1:0] acc;

    integer t;
    assign ready_o = (state == SCAN) && !next_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            and_work <= '0;
            and_next <= '0;
            next_pending <= 1'b0;
            warm_path <= 1'b0;
            done_o <= 1'b0;
            laggy_start_a <= 1'b0;
            laggy_start_b <= 1'b0;
            for (t = 0; t < T; t++) begin
                acc[t] <= '0;
                result[t] <= '0;
            end
        end else begin
            done_o <= 1'b0;
            laggy_start_a <= 1'b0;
            laggy_start_b <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_i) begin
                        and_work <= bm_a & bm_b;
                        laggy_start_a <= 1'b1;
                        laggy_start_b <= 1'b1;
                        state <= WAIT_COLD;
                    end
                end

                WAIT_COLD: begin
                    if (laggy_done_a && laggy_done_b) begin
                        offset_a_latch <= offset_a;
                        offset_b_latch <= offset_b;
                        for (t = 0; t < T; t++) acc[t] <= '0;
                        if (warm_path) begin
                            and_work <= and_next;
                            next_pending <= 1'b0;
                            warm_path <= 1'b0;
                        end
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    if (start_i && !next_pending) begin
                        and_next <= bm_a & bm_b;
                        laggy_start_a <= 1'b1;
                        laggy_start_b <= 1'b1;
                        next_pending <= 1'b1;
                    end
                    if (pe_valid) begin
                        for (t = 0; t < T; t++) begin
                            if (fiber_a_data[offset_a_latch[pe_pos]][t])
                                acc[t] <= acc[t] +
                                    {{(ACC_WIDTH-W_WIDTH){fiber_b_data[offset_b_latch[pe_pos]][W_WIDTH-1]}},
                                     fiber_b_data[offset_b_latch[pe_pos]]};
                        end
                        and_work <= and_work & (and_work - 1'b1);
                    end else begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    for (t = 0; t < T; t++) result[t] <= acc[t];
                    done_o <= 1'b1;
                    if (next_pending) begin
                        if (laggy_done_a && laggy_done_b) begin
                            offset_a_latch <= offset_a;
                            offset_b_latch <= offset_b;
                            and_work <= and_next;
                            for (t = 0; t < T; t++) acc[t] <= '0;
                            next_pending <= 1'b0;
                            state <= SCAN;
                        end else begin
                            warm_path <= 1'b1;
                            state <= WAIT_COLD;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
