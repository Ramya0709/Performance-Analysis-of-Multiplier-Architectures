// ============================================================
//  16x16 Array Multiplier  (unsigned)
//  Inputs  : A[15:0], B[15:0]
//  Output  : P[31:0]
//
//  Architecture
//  ────────────────────────────────────────────────────────────
//  Step 1: Generate 16 rows of partial products.
//          pp[k][i] = A[i] & B[k]
//          Row k contributes bits at positions i+k in the product.
//
//  Step 2: Add rows sequentially, one per adder stage.
//
//          Row 0 (pp[0]) seeds the accumulator — its bits are
//          the LSBs p[0] directly (no adder needed for pp[0]).
//
//          Row 1 (pp[1]): 15 half-adders for bits [1..15]
//                         (no carry into bit 1 from row 0 yet,
//                          but pp[0][0] feeds p[0] directly).
//          Actually: we implement a clean structure where:
//           - Bit 0 of product  = pp[0][0]  (no addition needed)
//           - Each subsequent row uses an N-bit ripple adder:
//             it sums the running partial result with the next
//             partial product row (properly aligned/shifted).
//
//  The running accumulator grows by 1 bit per row to hold carry.
//  After all 16 rows the accumulator is 32 bits.
//
//  Bit-accurate structure for row k (1 ≤ k ≤ 15):
//    acc_new[k .. k+15] = acc_old[k .. k+15] + pp[k][0..15]
//    acc_new[k-1]       = acc_old[k-1]  (bit k-1 is "frozen")
//    acc_new[k+16]      = carry_out from the adder
// ============================================================
module array16 (
    input  wire [15:0] A,
    input  wire [15:0] B,
    output wire [31:0] P
);

    // ----------------------------------------------------------
    // Step 1: Partial products
    //   pp[k] = 16-bit value of A & {16{B[k]}}
    // ----------------------------------------------------------
    wire [15:0] pp [0:15];
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : pp_rows
            assign pp[k] = A & {16{B[k]}};
        end
    endgenerate

    // ----------------------------------------------------------
    // Step 2: Sequential row addition
    //
    //  acc[row] holds the running partial sum after adding row 'row'.
    //  acc[row] is (row+16) bits wide to accommodate all carries.
    //  We model this as a fixed 32-bit array padded with zeros.
    // ----------------------------------------------------------

    // acc[0]: just pp[0] zero-extended to 32 bits (no adder)
    wire [31:0] acc [0:15];
    assign acc[0] = {16'b0, pp[0]};   // pp[0] sits at bits [15:0]

    // For rows 1..15: add pp[row] shifted left by 'row' bits
    // into the running accumulator.
    //
    // The adder for row k operates on bits [k+15 : k] of acc,
    // adding pp[k][15:0].  Bits below k are already final.
    // The carry out extends one bit above bit k+15.

    genvar r;
    generate
        for (r = 1; r < 16; r = r + 1) begin : adder_rows

            // Extract the 16-bit slice from the accumulator that
            // overlaps with pp[r] (aligned at bit position r).
            wire [15:0] acc_slice;
            assign acc_slice = acc[r-1][r+15 : r];

            // 16-bit ripple-carry adder
            wire [15:0] sum_bits;
            wire [15:0] carry_bits;
            wire        cout_final;

            // Bit 0 of this row: half adder (no carry in)
            half_adder HA (
                .a   (acc_slice[0]),
                .b   (pp[r][0]),
                .sum (sum_bits[0]),
                .cout(carry_bits[0])
            );

            // Bits 1..15: full adders chained
            genvar b;
            for (b = 1; b < 16; b = b + 1) begin : fa_chain
                full_adder FA (
                    .a   (acc_slice[b]),
                    .b   (pp[r][b]),
                    .cin (carry_bits[b-1]),
                    .sum (sum_bits[b]),
                    .cout(carry_bits[b])
                );
            end
            assign cout_final = carry_bits[15];

            // Reconstruct 32-bit accumulator for next stage:
            //  - bits [r-1 : 0]   unchanged from acc[r-1]
            //  - bits [r+15 : r]  = sum_bits
            //  - bit  [r+16]      = cout_final
            //  - bits above       = 0 (can never be set yet)
            assign acc[r] = { {(15-r){1'b0}},
                               cout_final,
                               sum_bits,
                               acc[r-1][r-1:0] };
        end
    endgenerate

    assign P = acc[15];

endmodule
