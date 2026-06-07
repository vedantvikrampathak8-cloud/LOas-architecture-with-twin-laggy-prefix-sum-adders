// Testbench for evolved_top at T=128, W_WIDTH=8.
// Cycle-count driven. No polling loops. Vivado XSim safe.
// Pipeline depth at T=128: ~400 DRAIN cycles covers LAGGY_LAT + T + margin.

`timescale 1ns / 1ps

module tb_evolved_top;

localparam int T = 128;
localparam int K = 2;
localparam int M = 8;
localparam int N_TPPE = 8;
localparam int W_WIDTH = 8;
localparam int ACC_WIDTH = 32;
localparam int THRESHOLD = 10;
localparam int LEAK_SHIFT = 0;
localparam int LAGGY_LAT = 128;
localparam int DRAIN_CYCLES = 400;

localparam int FRM0_WAIT = 2;
localparam int FRM1_WAIT = 8;
localparam int POST_WAIT = DRAIN_CYCLES + 18;
localparam int TILE_GAP = 6;

localparam [T-1:0] MASK_ALL  = {T{1'b1}};
localparam [T-1:0] MASK_NONE = {T{1'b0}};
localparam [T-1:0] MASK_ALT  = 128'h55555555555555555555555555555555;
localparam [T-1:0] MASK_LO32 = {{96{1'b0}}, {32{1'b1}}};

logic clk, rst_n;
logic start, busy, output_valid;
logic [M-1:0][T-1:0] spike_in_raw;
logic spike_frame_valid;
logic signed [M-1:0][W_WIDTH-1:0] weight_in;
logic [M-1:0][T-1:0] weight_bm_b;
logic [M-1:0][T-1:0] spike_out_frame;

evolved_top #(
    .T(T), .K(K), .M(M), .N_TPPE(N_TPPE),
    .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH),
    .THRESHOLD(THRESHOLD), .LEAK_SHIFT(LEAK_SHIFT),
    .LAGGY_LAT(LAGGY_LAT), .DRAIN_CYCLES(DRAIN_CYCLES)
) dut (
    .clk(clk), .rst_n(rst_n), .start(start), .busy(busy),
    .output_valid(output_valid),
    .spike_in_raw(spike_in_raw), .spike_frame_valid(spike_frame_valid),
    .weight_in(weight_in), .weight_bm_b(weight_bm_b),
    .spike_out_frame(spike_out_frame)
);

initial clk = 1'b0;
always #5 clk = ~clk;

reg [M*T-1:0] snap [0:15];
integer snap_idx;
initial snap_idx = 0;
always @(posedge clk)
    if (output_valid) begin
        snap[snap_idx] = spike_out_frame;
        snap_idx = snap_idx + 1;
    end

task drive_tile;
    input [M*T-1:0] sp;
    input [M*W_WIDTH-1:0] wt;
    input [M*T-1:0] bm;
    begin
        spike_in_raw = sp;
        weight_in = wt;
        weight_bm_b = bm;
        spike_frame_valid = 1'b0;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        repeat(FRM0_WAIT) @(posedge clk);
        spike_frame_valid = 1'b1; @(posedge clk); spike_frame_valid = 1'b0;
        repeat(FRM1_WAIT) @(posedge clk);
        spike_frame_valid = 1'b1; @(posedge clk); spike_frame_valid = 1'b0;
        repeat(POST_WAIT) @(posedge clk);
    end
endtask

task check;
    input [M*T-1:0] got;
    input [M*T-1:0] exp;
    input [8*8:1] lbl;
    begin
        if (got === exp)
            $display("  [%s]  PASS", lbl);
        else
            $display("  [%s]  FAIL  got=%0h  exp=%0h", lbl, got, exp);
    end
endtask

function [M*T-1:0] fill_mask;
    input [T-1:0] m;
    integer n;
    begin
        for (n = 0; n < M; n = n+1)
            fill_mask[n*T +: T] = m;
    end
endfunction

function [M*W_WIDTH-1:0] fill_weight;
    input signed [W_WIDTH-1:0] w;
    integer n;
    begin
        for (n = 0; n < M; n = n+1)
            fill_weight[n*W_WIDTH +: W_WIDTH] = w;
    end
endfunction

initial begin
    $dumpfile("tb_evolved_top.vcd");
    $dumpvars(0, tb_evolved_top);

    rst_n = 1'b0; start = 1'b0; spike_frame_valid = 1'b0;
    spike_in_raw = '0; weight_in = '0; weight_bm_b = '0;
    repeat(4) @(posedge clk); rst_n = 1'b1; repeat(4) @(posedge clk);

    $display("\n=== T1: dense, weight=6, acc=12 > 10, all fire ===");
    drive_tile(fill_mask(MASK_ALL), fill_weight(8'sd6), fill_mask(MASK_ALL));
    check(snap[snap_idx-1], {(M*T){1'b1}}, "T1      ");
    repeat(TILE_GAP) @(posedge clk);

    $display("\n=== T2: dense, weight=4, acc=8 < 10, no fire ===");
    drive_tile(fill_mask(MASK_ALL), fill_weight(8'sd4), fill_mask(MASK_ALL));
    check(snap[snap_idx-1], {(M*T){1'b0}}, "T2      ");
    repeat(TILE_GAP) @(posedge clk);

    $display("\n=== T3: zero bitmask, zero-bypass, no fire ===");
    drive_tile(fill_mask(MASK_NONE), fill_weight(8'sd15), fill_mask(MASK_ALL));
    check(snap[snap_idx-1], {(M*T){1'b0}}, "T3      ");
    repeat(TILE_GAP) @(posedge clk);

    $display("\n=== T4: disjoint bitmasks, AND=0, no fire ===");
    drive_tile(
        fill_mask({{64{1'b0}}, {64{1'b1}}}),
        fill_weight(8'sd15),
        fill_mask({{64{1'b1}}, {64{1'b0}}})
    );
    check(snap[snap_idx-1], {(M*T){1'b0}}, "T4      ");
    repeat(TILE_GAP) @(posedge clk);

    $display("\n=== T5: alternating bitmask, even bits fire ===");
    drive_tile(fill_mask(MASK_ALT), fill_weight(8'sd6), fill_mask(MASK_ALT));
    check(snap[snap_idx-1], fill_mask(MASK_ALT), "T5      ");
    repeat(TILE_GAP) @(posedge clk);

    $display("\n=== T6: coalescing, lower 32 bits, weight=12, fire ===");
    drive_tile(fill_mask(MASK_LO32), fill_weight(8'sd12), fill_mask(MASK_LO32));
    check(snap[snap_idx-1], fill_mask(MASK_LO32), "T6      ");
    repeat(TILE_GAP) @(posedge clk);

    $display("\n=== All tests complete ===");
    $finish;
end

endmodule
