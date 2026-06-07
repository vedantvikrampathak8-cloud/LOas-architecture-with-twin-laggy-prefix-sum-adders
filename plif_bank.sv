// Parallel LIF bank. T comparators fire in one shot.
// LEAK_SHIFT=0 hard-resets v_mem. LEAK_SHIFT>0 applies arithmetic right-shift at frame_start.
// All comparisons are signed so negative accumulations never false-fire.

module plif_bank #(
    parameter int ACC_WIDTH = 32,
    parameter int T = 128,
    parameter int THRESHOLD = 256,
    parameter int LEAK_SHIFT = 0
)(
    input logic clk,
    input logic rst_n,
    input logic frame_start,
    input logic signed [T-1:0][ACC_WIDTH-1:0] acc_in,
    input logic acc_valid,
    output logic [T-1:0] spike_out,
    output logic spike_valid
);

logic signed [T-1:0][ACC_WIDTH-1:0] v_mem;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        v_mem <= '0;
    end else if (frame_start) begin
        if (LEAK_SHIFT == 0) begin
            v_mem <= '0;
        end else begin
            for (int t = 0; t < T; t++)
                v_mem[t] <= v_mem[t] >>> LEAK_SHIFT;
        end
    end else if (acc_valid) begin
        for (int t = 0; t < T; t++)
            v_mem[t] <= $signed(v_mem[t]) + $signed(acc_in[t]);
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spike_out <= '0;
        spike_valid <= 1'b0;
    end else if (frame_start) begin
        spike_out <= '0;
        spike_valid <= 1'b0;
    end else if (acc_valid) begin
        spike_valid <= 1'b1;
        for (int t = 0; t < T; t++)
            spike_out[t] <= (($signed(v_mem[t]) + $signed(acc_in[t])) >=
                $signed(ACC_WIDTH'(signed'(THRESHOLD)))) ? 1'b1 : 1'b0;
    end else begin
        spike_out <= '0;
        spike_valid <= 1'b0;
    end
end

endmodule
