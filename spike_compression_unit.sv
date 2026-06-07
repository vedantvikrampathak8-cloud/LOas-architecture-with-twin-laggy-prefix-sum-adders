// Packs 1-bit spikes into T-bit bitmask words. Two-cycle pipeline.

module spike_compression_unit #(
    parameter int T = 128,
    parameter int N_NEURONS = 8
)(
    input logic clk,
    input logic rst_n,
    input logic [N_NEURONS-1:0][T-1:0] spike_in,
    input logic valid_in,
    output logic [N_NEURONS-1:0][T-1:0] spike_vec,
    output logic [$clog2(N_NEURONS+1)-1:0] nnz_count,
    output logic valid_out
);

logic [N_NEURONS-1:0][T-1:0] s1_spike;
logic s1_valid;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_spike <= '0;
        s1_valid <= 1'b0;
    end else begin
        s1_spike <= spike_in;
        s1_valid <= valid_in;
    end
end

logic [N_NEURONS-1:0] any_spike;
always_comb begin
    for (int n = 0; n < N_NEURONS; n++)
        any_spike[n] = |s1_spike[n];
end

logic [$clog2(N_NEURONS+1)-1:0] nnz_comb;
always_comb begin
    nnz_comb = '0;
    for (int n = 0; n < N_NEURONS; n++)
        nnz_comb = nnz_comb + {{($clog2(N_NEURONS+1)-1){1'b0}}, any_spike[n]};
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spike_vec <= '0;
        nnz_count <= '0;
        valid_out <= 1'b0;
    end else begin
        spike_vec <= s1_spike;
        nnz_count <= nnz_comb;
        valid_out <= s1_valid;
    end
end

endmodule
