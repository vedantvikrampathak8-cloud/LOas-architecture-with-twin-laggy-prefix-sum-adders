`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: p_lif
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
module p_lif #(
    parameter T = 4,
    parameter ACC_WIDTH = 32,
    parameter THRESHOLD = 1
)(
    input logic clk,
    input logic rst_n,
    input logic valid_i,
    input logic [T-1:0][ACC_WIDTH-1:0] membrane,
    output logic [T-1:0] spike_out,
    output logic valid_o
);

    logic [T-1:0] spikes;
    logic valid_r;

    genvar t;
    generate
        for (t = 0; t < T; t++) begin : lif_units
            assign spikes[t] = ($signed(membrane[t]) >= $signed(THRESHOLD[ACC_WIDTH-1:0])) ? 1'b1 : 1'b0;
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_out <= '0;
            valid_r <= 1'b0;
        end else begin
            valid_r <= valid_i;
            if (valid_i)
                spike_out <= spikes;
        end
    end

    assign valid_o = valid_r;

endmodule
