// ============================================================
//  16x16 Wallace Tree Multiplier
//  Inputs : A[15:0], B[15:0]  (unsigned)
//  Output : P[31:0]           (32-bit product)
//
//  Architecture
//  ─────────────────────────────────────────────────────────
//  Stage 1 : Generate 16 partial-product rows (PP[0..15])
//             PP[k][i] = A[i] & B[k], shifted left k bits
//             (represented as a 32-bit vector at the correct weight)
//
//  Stage 2 : Wallace tree — 4 levels of CSAs reduce 16 rows → 2
//             Level 1 :  16 → 11  (5 CSAs, 1 row passes through)
//             Level 2 :  11 →  8  (3 CSAs, 2 rows pass through)
//             Level 3 :   8 →  6  (2 CSAs, 2 rows pass through)
//             Level 4 :   6 →  4  (2 CSAs)
//             Level 5 :   4 →  3  (1 CSA)
//             Level 6 :   3 →  2  (1 CSA)
//
//  Stage 3 : CLA adder on the final two rows.
// ============================================================
module wallace16 (
    input  wire [15:0] A,
    input  wire [15:0] B,
    output wire [31:0] P
);

    // ----------------------------------------------------------
    // Stage 1: Partial Products
    // PP[k] is a 32-bit number; A[i]&B[k] sits at bit position i+k
    // ----------------------------------------------------------
    wire [31:0] pp [0:15];
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : pp_gen
            assign pp[k] = {{(16-k){1'b0}},
                            (A & {16{B[k]}}),
                            {k{1'b0}}};
        end
    endgenerate

    // ----------------------------------------------------------
    // Stage 2: Wallace tree CSA reduction
    // Naming: s = sum out, c = carry out (already shifted left 1)
    // ----------------------------------------------------------

    // --- Level 1: reduce 16 → 11 (5 CSAs + 1 passthrough) ---
    wire [31:0] l1s0, l1c0, l1s1, l1c1, l1s2, l1c2, l1s3, l1c3, l1s4, l1c4;

    carry_save_adder #(32) L1_CSA0 (.a(pp[ 0]), .b(pp[ 1]), .c(pp[ 2]), .sum(l1s0), .carry(l1c0));
    carry_save_adder #(32) L1_CSA1 (.a(pp[ 3]), .b(pp[ 4]), .c(pp[ 5]), .sum(l1s1), .carry(l1c1));
    carry_save_adder #(32) L1_CSA2 (.a(pp[ 6]), .b(pp[ 7]), .c(pp[ 8]), .sum(l1s2), .carry(l1c2));
    carry_save_adder #(32) L1_CSA3 (.a(pp[ 9]), .b(pp[10]), .c(pp[11]), .sum(l1s3), .carry(l1c3));
    carry_save_adder #(32) L1_CSA4 (.a(pp[12]), .b(pp[13]), .c(pp[14]), .sum(l1s4), .carry(l1c4));
    // pp[15] passes through → 11 vectors total

    // Carry vectors have implicit left-shift of 1 (bit weight i+1)
    wire [31:0] l1c0_s, l1c1_s, l1c2_s, l1c3_s, l1c4_s;
    assign l1c0_s = {l1c0[30:0], 1'b0};
    assign l1c1_s = {l1c1[30:0], 1'b0};
    assign l1c2_s = {l1c2[30:0], 1'b0};
    assign l1c3_s = {l1c3[30:0], 1'b0};
    assign l1c4_s = {l1c4[30:0], 1'b0};

    // 11 vectors: l1s0,l1c0_s, l1s1,l1c1_s, l1s2,l1c2_s, l1s3,l1c3_s, l1s4,l1c4_s, pp[15]

    // --- Level 2: reduce 11 → 8 (3 CSAs + 2 passthrough) ---
    wire [31:0] l2s0, l2c0, l2s1, l2c1, l2s2, l2c2;

    carry_save_adder #(32) L2_CSA0 (.a(l1s0),   .b(l1c0_s), .c(l1s1),   .sum(l2s0), .carry(l2c0));
    carry_save_adder #(32) L2_CSA1 (.a(l1c1_s), .b(l1s2),   .c(l1c2_s), .sum(l2s1), .carry(l2c1));
    carry_save_adder #(32) L2_CSA2 (.a(l1s3),   .b(l1c3_s), .c(l1s4),   .sum(l2s2), .carry(l2c2));
    // l1c4_s, pp[15] pass through

    wire [31:0] l2c0_s, l2c1_s, l2c2_s;
    assign l2c0_s = {l2c0[30:0], 1'b0};
    assign l2c1_s = {l2c1[30:0], 1'b0};
    assign l2c2_s = {l2c2[30:0], 1'b0};

    // 8 vectors: l2s0,l2c0_s, l2s1,l2c1_s, l2s2,l2c2_s, l1c4_s, pp[15]

    // --- Level 3: reduce 8 → 6 (2 CSAs + 2 passthrough) ---
    wire [31:0] l3s0, l3c0, l3s1, l3c1;

    carry_save_adder #(32) L3_CSA0 (.a(l2s0),   .b(l2c0_s), .c(l2s1),   .sum(l3s0), .carry(l3c0));
    carry_save_adder #(32) L3_CSA1 (.a(l2c1_s), .b(l2s2),   .c(l2c2_s), .sum(l3s1), .carry(l3c1));
    // l1c4_s, pp[15] pass through

    wire [31:0] l3c0_s, l3c1_s;
    assign l3c0_s = {l3c0[30:0], 1'b0};
    assign l3c1_s = {l3c1[30:0], 1'b0};

    // 6 vectors: l3s0,l3c0_s, l3s1,l3c1_s, l1c4_s, pp[15]

    // --- Level 4: reduce 6 → 4 (2 CSAs) ---
    wire [31:0] l4s0, l4c0, l4s1, l4c1;

    carry_save_adder #(32) L4_CSA0 (.a(l3s0),   .b(l3c0_s), .c(l3s1),   .sum(l4s0), .carry(l4c0));
    carry_save_adder #(32) L4_CSA1 (.a(l3c1_s), .b(l1c4_s), .c(pp[15]), .sum(l4s1), .carry(l4c1));

    wire [31:0] l4c0_s, l4c1_s;
    assign l4c0_s = {l4c0[30:0], 1'b0};
    assign l4c1_s = {l4c1[30:0], 1'b0};

    // 4 vectors: l4s0, l4c0_s, l4s1, l4c1_s

    // --- Level 5: reduce 4 → 3 (1 CSA) ---
    wire [31:0] l5s0, l5c0;

    carry_save_adder #(32) L5_CSA0 (.a(l4s0),   .b(l4c0_s), .c(l4s1),   .sum(l5s0), .carry(l5c0));

    wire [31:0] l5c0_s;
    assign l5c0_s = {l5c0[30:0], 1'b0};

    // 3 vectors: l5s0, l5c0_s, l4c1_s

    // --- Level 6: reduce 3 → 2 (1 CSA) ---
    wire [31:0] l6s0, l6c0;

    carry_save_adder #(32) L6_CSA0 (.a(l5s0), .b(l5c0_s), .c(l4c1_s), .sum(l6s0), .carry(l6c0));

    wire [31:0] l6c0_s;
    assign l6c0_s = {l6c0[30:0], 1'b0};

    // ----------------------------------------------------------
    // Stage 3: Final CLA addition
    // ----------------------------------------------------------
    wire cout_unused;
    cla_adder #(32) FINAL_ADD (
        .a   (l6s0),
        .b   (l6c0_s),
        .cin (1'b0),
        .sum (P),
        .cout(cout_unused)
    );

endmodule
