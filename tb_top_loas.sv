`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: tb_top_loas;
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
module tb_top_loas;

    parameter BM_WIDTH = 128;
    parameter OFF_W = 7;
    parameter W_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter T = 4;
    parameter N_TPPE = 16;
    parameter N_ADDERS = 8;
    parameter THRESHOLD = 1;

    logic clk;
    logic rst_n;
    logic start_i;
    logic [BM_WIDTH-1:0] bm_b;
    logic [W_WIDTH-1:0] fiber_b_data [0:BM_WIDTH-1];
    logic [BM_WIDTH-1:0] bm_a [0:N_TPPE-1];
    logic [T-1:0] fiber_a_data [0:N_TPPE-1][0:BM_WIDTH-1];
    logic [N_TPPE-1:0][T-1:0] spike_out;
    logic [N_TPPE-1:0] done_o;
    logic [N_TPPE-1:0] ready_o;

    top_loas #(
        .BM_WIDTH(BM_WIDTH), .OFF_W(OFF_W), .W_WIDTH(W_WIDTH),
        .ACC_WIDTH(ACC_WIDTH), .T(T), .N_TPPE(N_TPPE),
        .N_ADDERS(N_ADDERS), .THRESHOLD(THRESHOLD)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start_i(start_i),
        .bm_b(bm_b), .fiber_b_data(fiber_b_data),
        .bm_a(bm_a), .fiber_a_data(fiber_a_data),
        .spike_out(spike_out), .done_o(done_o), .ready_o(ready_o)
    );

    always #5 clk = ~clk;

    integer cyc_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) cyc_cnt <= 0;
        else cyc_cnt <= cyc_cnt + 1;
    end

    task apply_reset;
        @(posedge clk);
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
    endtask

    task wait_done;
        integer timeout;
        timeout = 0;
        @(posedge clk); #1;
        while (done_o[0] !== 1'b1 && timeout < 4000) begin
            @(posedge clk); #1;
            timeout++;
        end
        if (timeout >= 4000)
            $display("TIMEOUT waiting for done");
    endtask

    integer i, j, cyc_f0, cyc_f1;

    initial begin
        clk = 0; rst_n = 0; start_i = 0;
        bm_b = '0;
        for (i = 0; i < BM_WIDTH; i++) fiber_b_data[i] = '0;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = '0;
            for (j = 0; j < BM_WIDTH; j++) fiber_a_data[i][j] = '0;
        end

        apply_reset();

        $display("T1: dense fire — 128 matches, all spikes 1111");
        bm_b = {BM_WIDTH{1'b1}};
        for (i = 0; i < BM_WIDTH; i++) fiber_b_data[i] = 8'h01;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = {BM_WIDTH{1'b1}};
            for (j = 0; j < BM_WIDTH; j++) fiber_a_data[i][j] = {T{1'b1}};
        end
        @(posedge clk); start_i = 1;
        @(posedge clk); start_i = 0;
        wait_done();
        for (i = 0; i < N_TPPE; i++)
            $display("T1 TPPE[%0d] spike=%b (expect 1111)", i, spike_out[i]);

        apply_reset();

        $display("T2: dense no-fire — 128 matches, all spikes 0000");
        bm_b = {BM_WIDTH{1'b1}};
        for (i = 0; i < BM_WIDTH; i++) fiber_b_data[i] = 8'h01;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = {BM_WIDTH{1'b1}};
            for (j = 0; j < BM_WIDTH; j++) fiber_a_data[i][j] = {T{1'b0}};
        end
        @(posedge clk); start_i = 1;
        @(posedge clk); start_i = 0;
        wait_done();
        for (i = 0; i < N_TPPE; i++)
            $display("T2 TPPE[%0d] spike=%b (expect 0000)", i, spike_out[i]);

        apply_reset();

        $display("T3: disjoint bitmasks — 0 matches");
        bm_b = 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
        for (i = 0; i < BM_WIDTH; i++) fiber_b_data[i] = 8'h02;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = 128'h55555555555555555555555555555555;
            for (j = 0; j < BM_WIDTH; j++) fiber_a_data[i][j] = {T{1'b1}};
        end
        @(posedge clk); start_i = 1;
        @(posedge clk); start_i = 0;
        wait_done();
        for (i = 0; i < N_TPPE; i++)
            $display("T3 TPPE[%0d] spike=%b (expect 0000)", i, spike_out[i]);

        apply_reset();

        $display("T4: 8 matches, spike=1010, weight=4");
        bm_b = 128'h000000000000000000000000000000FF;
        for (i = 0; i < BM_WIDTH; i++) fiber_b_data[i] = 8'h04;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = 128'h000000000000000000000000000000FF;
            for (j = 0; j < 8; j++) fiber_a_data[i][j] = 4'b1010;
            for (j = 8; j < BM_WIDTH; j++) fiber_a_data[i][j] = '0;
        end
        @(posedge clk); start_i = 1;
        @(posedge clk); start_i = 0;
        wait_done();
        for (i = 0; i < N_TPPE; i++)
            $display("T4 TPPE[%0d] spike=%b (expect 1010)", i, spike_out[i]);

        apply_reset();

        $display("T5: pipeline — frame0=128 matches, frame1=8 matches fired mid-scan");
        bm_b = {BM_WIDTH{1'b1}};
        for (i = 0; i < BM_WIDTH; i++) fiber_b_data[i] = 8'h01;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = {BM_WIDTH{1'b1}};
            for (j = 0; j < BM_WIDTH; j++) fiber_a_data[i][j] = {T{1'b1}};
        end
        @(posedge clk); start_i = 1;
        @(posedge clk); start_i = 0;

        repeat(50) @(posedge clk);

        bm_b = 128'h000000000000000000000000000000FF;
        for (i = 0; i < N_TPPE; i++) begin
            bm_a[i] = 128'h000000000000000000000000000000FF;
            for (j = 0; j < 8; j++) fiber_a_data[i][j] = 4'b1010;
            for (j = 8; j < BM_WIDTH; j++) fiber_a_data[i][j] = '0;
        end
        @(posedge clk); start_i = 1;
        @(posedge clk); start_i = 0;

        wait_done();
        cyc_f0 = cyc_cnt;
        $display("T5 frame0 done at cyc=%0d", cyc_f0);
        for (i = 0; i < N_TPPE; i++)
            $display("T5 frame0 TPPE[%0d] spike=%b (expect 1111)", i, spike_out[i]);

        wait_done();
        cyc_f1 = cyc_cnt;
        $display("T5 frame1 done at cyc=%0d delta=%0d (expect ~10, non-pipeline would be ~26)",
            cyc_f1, cyc_f1 - cyc_f0);
        for (i = 0; i < N_TPPE; i++)
            $display("T5 frame1 TPPE[%0d] spike=%b (expect 1010)", i, spike_out[i]);

        $display("Done.");
        $finish;
    end

endmodule
