// ============================================================
//  N-bit Carry-Save Adder
//  Takes three N-bit vectors, outputs two N-bit vectors
//  (sum and carry) with no carry propagation — O(1) delay.
// ============================================================
module carry_save_adder #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    output wire [WIDTH-1:0] sum,
    output wire [WIDTH-1:0] carry    // carry[i] is the carry-out of bit i
                                     // (weight 2^(i+1), so shift left 1 on use)
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : csa_bits
            full_adder fa (
                .a   (a[i]),
                .b   (b[i]),
                .cin (c[i]),
                .sum  (sum[i]),
                .cout (carry[i])
            );
        end
    endgenerate
endmodule
