// Temporal Parallel Processing Element.
// One TPPE = one output neuron across all T timesteps.
// Pipeline: inner_join -> coalescing_bypass_buffer -> cascade_spine -> plif_bank

module tppe #(
    parameter int T = 128,
    parameter int W_WIDTH = 8,
    parameter int ACC_WIDTH = 32,
    parameter int THRESHOLD = 256,
    parameter int LEAK_SHIFT = 0,
    parameter int LAGGY_LAT = 128
)(
    input logic clk,
    input logic rst_n,
    input logic [T-1:0] bm_a,
    input logic [T-1:0] bm_b,
    input logic signed [W_WIDTH-1:0] weight_val,
    input logic valid_in,
    input logic frame_start,
    input logic tile_done,
    output logic [T-1:0] spike_out,
    output logic spike_valid
);

logic [T-1:0] join_mask;
logic [T-1:0][$clog2(T+1)-1:0] join_prefix_a, join_prefix_b;
logic [$clog2(T+1)-1:0] join_total;
logic join_done;

inner_join_unit #(.T(T), .LAGGY_LAT(LAGGY_LAT)) u_join (
    .clk(clk), .rst_n(rst_n),
    .bm_a(bm_a), .bm_b(bm_b), .valid_in(valid_in),
    .valid_mask(join_mask), .prefix_a(join_prefix_a),
    .prefix_b(join_prefix_b), .total(join_total), .join_done(join_done)
);

logic [T-1:0] coalesced_token;
logic signed [W_WIDTH-1:0] coalesced_weight;
logic token_valid, bypass_zero;

// TIMEOUT=2: tokens from the same K-frame (arriving within 2 cycles) are OR-merged.
// Tokens from different K-frames (LAGGY_LAT cycles apart) fire independently.
coalescing_bypass_buffer #(.T(T), .W_WIDTH(W_WIDTH), .TIMEOUT(2)) u_cbuf (
    .clk(clk), .rst_n(rst_n),
    .mask_in(join_mask), .weight_in(weight_val), .join_done(join_done),
    .token_out(coalesced_token), .weight_out(coalesced_weight),
    .token_valid(token_valid), .bypass_zero(bypass_zero)
);

logic signed [T-1:0][ACC_WIDTH-1:0] spine_acc;
logic spine_acc_valid;

cascade_spine #(.T(T), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_spine (
    .clk(clk), .rst_n(rst_n),
    .token_in(coalesced_token), .weight_in(coalesced_weight),
    .token_valid(token_valid), .frame_start(frame_start), .tile_done(tile_done),
    .acc_out(spine_acc), .acc_valid(spine_acc_valid)
);

plif_bank #(.ACC_WIDTH(ACC_WIDTH), .T(T), .THRESHOLD(THRESHOLD), .LEAK_SHIFT(LEAK_SHIFT)) u_plif (
    .clk(clk), .rst_n(rst_n),
    .frame_start(frame_start), .acc_in(spine_acc), .acc_valid(spine_acc_valid),
    .spike_out(spike_out), .spike_valid(spike_valid)
);

endmodule
