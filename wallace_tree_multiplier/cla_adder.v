// ============================================================
//  32-bit Carry-Lookahead Adder (4-bit blocks)
//  Used as the final adder in the Wallace tree.
// ============================================================
module cla_adder #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    wire [WIDTH:0] c;
    assign c[0] = cin;

    genvar blk, bit_i;
    generate
        for (blk = 0; blk < WIDTH/4; blk = blk + 1) begin : cla_block
            // Generate / Propagate per bit
            wire [3:0] g, p;
            // Group generate/propagate
            wire G, P;
            wire [3:0] c_int;

            assign g = a[blk*4+3:blk*4] & b[blk*4+3:blk*4];
            assign p = a[blk*4+3:blk*4] | b[blk*4+3:blk*4];

            // Lookahead carry computation
            assign G = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
            assign P = p[3] & p[2] & p[1] & p[0];

            assign c[blk*4+1] = g[0] | (p[0] & c[blk*4]);
            assign c[blk*4+2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[blk*4]);
            assign c[blk*4+3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[blk*4]);
            assign c[blk*4+4] = G | (P & c[blk*4]);

            // Sum bits
            for (bit_i = 0; bit_i < 4; bit_i = bit_i + 1) begin : sum_bits
                assign sum[blk*4 + bit_i] = a[blk*4 + bit_i] ^ b[blk*4 + bit_i] ^ c[blk*4 + bit_i];
            end
        end
    endgenerate

    assign cout = c[WIDTH];
endmodule
