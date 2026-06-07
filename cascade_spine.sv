// T-stage shift-register pipeline. Stage s handles temporal slot s.
// Clock-enable on each accumulator: if pipe_token[s][s] == 0, the adder is frozen.

module cascade_spine #(
    parameter int T = 128,
    parameter int W_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    input logic clk,
    input logic rst_n,
    input logic [T-1:0] token_in,
    input logic signed [W_WIDTH-1:0] weight_in,
    input logic token_valid,
    input logic frame_start,
    input logic tile_done,
    output logic signed [T-1:0][ACC_WIDTH-1:0] acc_out,
    output logic acc_valid
);

logic [T-1:0] pipe_token [0:T-1];
logic signed [W_WIDTH-1:0] pipe_weight [0:T-1];
logic pipe_valid [0:T-1];
logic signed [T-1:0][ACC_WIDTH-1:0] accum;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipe_token[0] <= '0;
        pipe_weight[0] <= '0;
        pipe_valid[0] <= 1'b0;
    end else begin
        pipe_token[0] <= token_in;
        pipe_weight[0] <= weight_in;
        pipe_valid[0] <= token_valid;
    end
end

generate
    for (genvar s = 1; s < T; s++) begin : gen_pipe
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pipe_token[s] <= '0;
                pipe_weight[s] <= '0;
                pipe_valid[s] <= 1'b0;
            end else begin
                pipe_token[s] <= pipe_token[s-1];
                pipe_weight[s] <= pipe_weight[s-1];
                pipe_valid[s] <= pipe_valid[s-1];
            end
        end
    end
endgenerate

generate
    for (genvar s = 0; s < T; s++) begin : gen_acc
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                accum[s] <= '0;
            end else if (frame_start) begin
                accum[s] <= '0;
            end else if (pipe_valid[s] && pipe_token[s][s]) begin
                accum[s] <= accum[s] +
                    {{(ACC_WIDTH-W_WIDTH){pipe_weight[s][W_WIDTH-1]}}, pipe_weight[s]};
            end
        end
    end
endgenerate

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        acc_out <= '0;
        acc_valid <= 1'b0;
    end else if (frame_start) begin
        acc_out <= '0;
        acc_valid <= 1'b0;
    end else if (tile_done) begin
        acc_out <= accum;
        acc_valid <= 1'b1;
    end else begin
        acc_valid <= 1'b0;
    end
end

endmodule
