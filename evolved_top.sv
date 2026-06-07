// Top-level accelerator. 6-state FSM drives N_TPPE array.
// DRAIN_CYCLES >= LAGGY_LAT + T + FRM_GAP + margin
// At T=128 default: LAGGY_LAT(128) + T(128) + ~10 + 20 = 286, default 400 is safe.

module evolved_top #(
    parameter int T = 128,
    parameter int K = 4,
    parameter int M = 8,
    parameter int N_TPPE = 8,
    parameter int W_WIDTH = 8,
    parameter int ACC_WIDTH = 32,
    parameter int THRESHOLD = 256,
    parameter int LEAK_SHIFT = 0,
    parameter int LAGGY_LAT = 128,
    parameter int DRAIN_CYCLES = 400
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    output logic busy,
    output logic output_valid,
    input logic [M-1:0][T-1:0] spike_in_raw,
    input logic spike_frame_valid,
    input logic signed [M-1:0][W_WIDTH-1:0] weight_in,
    input logic [M-1:0][T-1:0] weight_bm_b,
    output logic [M-1:0][T-1:0] spike_out_frame
);

typedef enum logic [2:0] {
    IDLE = 3'd0,
    RUNNING = 3'd1,
    DRAIN = 3'd2,
    FIRING = 3'd3,
    WAIT_PLIF = 3'd4,
    DONE = 3'd5
} state_t;

state_t state;
logic [$clog2(K+1)-1:0] cnt_k;
logic [$clog2(DRAIN_CYCLES+1)-1:0] drain_cnt;
logic frame_start_r;
logic tile_done_pulse;

assign tile_done_pulse = (state == FIRING);

logic [M-1:0][T-1:0] spike_vec;
logic [$clog2(M+1)-1:0] nnz_count;
logic scu_valid;
logic scu_valid_gated;

spike_compression_unit #(.T(T), .N_NEURONS(M)) u_scu (
    .clk(clk), .rst_n(rst_n),
    .spike_in(spike_in_raw),
    .valid_in(spike_frame_valid & (state == RUNNING)),
    .spike_vec(spike_vec), .nnz_count(nnz_count), .valid_out(scu_valid)
);

assign scu_valid_gated = scu_valid & (state == RUNNING);

logic [M-1:0][T-1:0] tppe_spike_out;
logic [M-1:0] tppe_spike_valid;

generate
    for (genvar i = 0; i < N_TPPE; i++) begin : gen_tppe
        tppe #(
            .T(T), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH),
            .THRESHOLD(THRESHOLD), .LEAK_SHIFT(LEAK_SHIFT), .LAGGY_LAT(LAGGY_LAT)
        ) u_tppe (
            .clk(clk), .rst_n(rst_n),
            .bm_a(spike_vec[i]), .bm_b(weight_bm_b[i]),
            .weight_val(weight_in[i]), .valid_in(scu_valid_gated),
            .frame_start(frame_start_r), .tile_done(tile_done_pulse),
            .spike_out(tppe_spike_out[i]), .spike_valid(tppe_spike_valid[i])
        );
    end
endgenerate

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        cnt_k <= '0;
        drain_cnt <= '0;
        frame_start_r <= 1'b0;
        busy <= 1'b0;
        output_valid <= 1'b0;
        spike_out_frame <= '0;
    end else begin
        frame_start_r <= 1'b0;
        output_valid <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    state <= RUNNING;
                    cnt_k <= '0;
                    frame_start_r <= 1'b1;
                    busy <= 1'b1;
                end
            end

            RUNNING: begin
                if (scu_valid_gated) begin
                    if (cnt_k == ($clog2(K+1))'(K - 1)) begin
                        state <= DRAIN;
                        drain_cnt <= DRAIN_CYCLES[$clog2(DRAIN_CYCLES+1)-1:0];
                        cnt_k <= '0;
                    end else begin
                        cnt_k <= cnt_k + 1;
                    end
                end
            end

            DRAIN: begin
                if (drain_cnt == 0) state <= FIRING;
                else drain_cnt <= drain_cnt - 1;
            end

            FIRING: state <= WAIT_PLIF;

            WAIT_PLIF: state <= DONE;

            DONE: begin
                for (int i = 0; i < N_TPPE; i++)
                    spike_out_frame[i] <= tppe_spike_out[i];
                output_valid <= 1'b1;
                busy <= 1'b0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
