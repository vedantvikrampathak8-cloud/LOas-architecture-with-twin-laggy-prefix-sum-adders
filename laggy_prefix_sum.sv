// Sequential bottom-up prefix sum with 1-deep input queue.
// Handles back-to-back K-frames spaced closer than LATENCY cycles.
// Used as a twin pair in inner_join_unit.

module laggy_prefix_sum #(
    parameter int WIDTH = 128,
    parameter int LATENCY = 128
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [WIDTH-1:0] data_in,
    output logic done,
    output logic [WIDTH-1:0][$clog2(WIDTH+1)-1:0] prefix_out,
    output logic [$clog2(WIDTH+1)-1:0] total_out
);

localparam int SUM_W = $clog2(WIDTH + 1);
localparam int BITS_PER_CYCLE = (WIDTH + LATENCY - 1) / LATENCY;

logic [WIDTH-1:0] q_data;
logic q_valid;
logic [WIDTH-1:0] captured;
logic [WIDTH-1:0][SUM_W-1:0] accum;
logic [$clog2(LATENCY+1)-1:0] cycle_cnt;
logic running;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q_data <= '0;
        q_valid <= 1'b0;
        captured <= '0;
        accum <= '0;
        cycle_cnt <= '0;
        running <= 1'b0;
        done <= 1'b0;
        prefix_out <= '0;
        total_out <= '0;
    end else begin
        done <= 1'b0;

        if (start) begin
            if (!running) begin
                captured <= data_in;
                accum[0] <= {{(SUM_W-1){1'b0}}, data_in[0]};
                cycle_cnt <= 1;
                running <= 1'b1;
                q_valid <= 1'b0;
            end else begin
                q_data <= data_in;
                q_valid <= 1'b1;
            end
        end else if (running) begin
            for (int b = 0; b < BITS_PER_CYCLE; b++) begin
                if (((int'(cycle_cnt) - 1) * BITS_PER_CYCLE + 1 + b) < WIDTH) begin
                    accum[(int'(cycle_cnt)-1)*BITS_PER_CYCLE+1+b] <=
                        accum[(int'(cycle_cnt)-1)*BITS_PER_CYCLE+b] +
                        {{(SUM_W-1){1'b0}}, captured[(int'(cycle_cnt)-1)*BITS_PER_CYCLE+1+b]};
                end
            end

            if (cycle_cnt == LATENCY[$clog2(LATENCY+1)-1:0]) begin
                prefix_out <= accum;
                total_out <= accum[WIDTH-1];
                done <= 1'b1;
                running <= 1'b0;
                cycle_cnt <= '0;

                if (q_valid) begin
                    captured <= q_data;
                    accum[0] <= {{(SUM_W-1){1'b0}}, q_data[0]};
                    cycle_cnt <= 1;
                    running <= 1'b1;
                    q_valid <= 1'b0;
                end
            end else begin
                cycle_cnt <= cycle_cnt + 1;
            end
        end
    end
end

endmodule
