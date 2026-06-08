`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.06.2026 16:39:43
// Design Name: 
// Module Name: priority_encoder
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
module priority_encoder #(
    parameter WIDTH = 128,
    parameter OUT_W = 7
)(
    input logic [WIDTH-1:0] in,
    output logic [OUT_W-1:0] pos,
    output logic valid
);

    logic [WIDTH-1:0] isolated;
    assign isolated = in & (~in + 1'b1);
    assign valid = |in;

    genvar k, m;
    generate
        for (k = 0; k < OUT_W; k++) begin : pos_bit_gen
            logic [WIDTH-1:0] contrib;
            for (m = 0; m < WIDTH; m++) begin : contrib_gen
                if ((m >> k) & 1) begin
                    assign contrib[m] = isolated[m];
                end else begin
                    assign contrib[m] = 1'b0;
                end
            end
            assign pos[k] = |contrib;
        end
    endgenerate

endmodule
