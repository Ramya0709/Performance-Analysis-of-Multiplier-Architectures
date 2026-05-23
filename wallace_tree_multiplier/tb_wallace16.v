`timescale 1ns/1ps
module tb_wallace16;
    reg  [15:0] A, B;
    wire [31:0] P;
    integer     errors;
    integer     i, j;
    reg  [31:0] expected;

    wallace16 dut (.A(A), .B(B), .P(P));

    initial begin
        errors = 0;

        // Corner cases
        A=0; B=0; #5; if(P!==0) begin $display("FAIL 0x0"); errors=errors+1; end
        A=1; B=1; #5; if(P!==1) begin $display("FAIL 1x1"); errors=errors+1; end
        A=16'hFFFF; B=16'hFFFF; #5; expected=32'hFFFE_0001;
          if(P!==expected) begin $display("FAIL FFFFxFFFF got %0h exp %0h",P,expected); errors=errors+1; end
        A=16'd12345; B=16'd6789; #5; expected=12345*6789;
          if(P!==expected) begin $display("FAIL 12345x6789 got %0d exp %0d",P,expected); errors=errors+1; end
        A=16'd50000; B=16'd60000; #5; expected=50000*60000;
          if(P!==expected) begin $display("FAIL 50000x60000 got %0d exp %0d",P,expected); errors=errors+1; end
        A=16'd32768; B=16'd32768; #5; expected=32768*32768;
          if(P!==expected) begin $display("FAIL 32768x32768 got %0d exp %0d",P,expected); errors=errors+1; end

        // Exhaustive small range 0..255
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 256; j = j + 1) begin
                A = i[15:0]; B = j[15:0]; #1;
                expected = i * j;
                if (P !== expected) begin
                    $display("FAIL: %0d x %0d = %0d (got %0d)", i, j, expected, P);
                    errors = errors + 1;
                end
            end

        $display("==============================");
        if (errors == 0)
            $display("ALL TESTS PASSED  (256x256 exhaustive + spot checks)");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("==============================");
        $finish;
    end
endmodule
