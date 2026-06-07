// Front-end gate between inner-join and cascade spine.
// Zero bypass: all-zero mask skips the spine in 1 cycle.
// Coalescing: sparse non-zero tokens are OR-merged if the next arrives within TIMEOUT cycles.

module coalescing_bypass_buffer #(
    parameter int T = 128,
    parameter int W_WIDTH = 8,
    parameter int TIMEOUT = 130
)(
    input logic clk,
    input logic rst_n,
    input logic [T-1:0] mask_in,
    input logic signed [W_WIDTH-1:0] weight_in,
    input logic join_done,
    output logic [T-1:0] token_out,
    output logic signed [W_WIDTH-1:0] weight_out,
    output logic token_valid,
    output logic bypass_zero
);

logic all_zero;
assign all_zero = (mask_in == '0);

logic [T-1:0] buf_mask;
logic signed [W_WIDTH-1:0] buf_weight;
logic [$clog2(TIMEOUT+1)-1:0] timeout_cnt;

typedef enum logic [1:0] {
    EMPTY = 2'd0,
    HOLDING = 2'd1,
    FLUSH = 2'd2
} buf_state_t;

buf_state_t buf_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        buf_mask <= '0;
        buf_weight <= '0;
        timeout_cnt <= '0;
        buf_state <= EMPTY;
        token_out <= '0;
        weight_out <= '0;
        token_valid <= 1'b0;
        bypass_zero <= 1'b0;
    end else begin
        token_valid <= 1'b0;
        bypass_zero <= 1'b0;

        case (buf_state)
            EMPTY: begin
                if (join_done) begin
                    if (all_zero) begin
                        bypass_zero <= 1'b1;
                    end else begin
                        buf_mask <= mask_in;
                        buf_weight <= weight_in;
                        timeout_cnt <= '0;
                        buf_state <= HOLDING;
                    end
                end
            end

            HOLDING: begin
                if (join_done) begin
                    if (all_zero) begin
                        bypass_zero <= 1'b1;
                        timeout_cnt <= timeout_cnt + 1;
                        if (timeout_cnt == TIMEOUT[$clog2(TIMEOUT+1)-1:0] - 1) begin
                            token_out <= buf_mask;
                            weight_out <= buf_weight;
                            token_valid <= 1'b1;
                            timeout_cnt <= '0;
                            buf_state <= EMPTY;
                        end
                    end else begin
                        token_out <= buf_mask | mask_in;
                        weight_out <= buf_weight;
                        token_valid <= 1'b1;
                        timeout_cnt <= '0;
                        buf_state <= EMPTY;
                    end
                end else begin
                    timeout_cnt <= timeout_cnt + 1;
                    if (timeout_cnt == TIMEOUT[$clog2(TIMEOUT+1)-1:0] - 1) begin
                        token_out <= buf_mask;
                        weight_out <= buf_weight;
                        token_valid <= 1'b1;
                        timeout_cnt <= '0;
                        buf_state <= EMPTY;
                    end
                end
            end

            FLUSH: begin
                token_out <= buf_mask;
                weight_out <= buf_weight;
                token_valid <= 1'b1;
                buf_state <= EMPTY;
            end

            default: buf_state <= EMPTY;
        endcase
    end
end

endmodule
