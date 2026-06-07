// Twin symmetric laggy inner-join.
// AND gate + two identical laggy prefix trees. No fast tree, no speculation.

module inner_join_unit #(
    parameter int T = 128,
    parameter int LAGGY_LAT = 128
)(
    input logic clk,
    input logic rst_n,
    input logic [T-1:0] bm_a,
    input logic [T-1:0] bm_b,
    input logic valid_in,
    output logic [T-1:0] valid_mask,
    output logic [T-1:0][$clog2(T+1)-1:0] prefix_a,
    output logic [T-1:0][$clog2(T+1)-1:0] prefix_b,
    output logic [$clog2(T+1)-1:0] total,
    output logic join_done
);

logic [T-1:0] and_mask;
assign and_mask = bm_a & bm_b;

logic done_a, done_b;
logic [T-1:0][$clog2(T+1)-1:0] raw_a, raw_b;
logic [$clog2(T+1)-1:0] total_a, total_b;

laggy_prefix_sum #(.WIDTH(T), .LATENCY(LAGGY_LAT)) u_laggy_a (
    .clk(clk), .rst_n(rst_n),
    .start(valid_in), .data_in(and_mask),
    .done(done_a), .prefix_out(raw_a), .total_out(total_a)
);

laggy_prefix_sum #(.WIDTH(T), .LATENCY(LAGGY_LAT)) u_laggy_b (
    .clk(clk), .rst_n(rst_n),
    .start(valid_in), .data_in(and_mask),
    .done(done_b), .prefix_out(raw_b), .total_out(total_b)
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_mask <= '0;
        prefix_a <= '0;
        prefix_b <= '0;
        total <= '0;
        join_done <= 1'b0;
    end else begin
        join_done <= 1'b0;
        if (done_a && done_b) begin
            valid_mask <= and_mask;
            prefix_a <= raw_a;
            prefix_b <= raw_b;
            total <= total_a;
            join_done <= 1'b1;
        end else if (!done_a && !done_b && !valid_in) begin
            valid_mask <= '0;
        end
    end
end

endmodule
