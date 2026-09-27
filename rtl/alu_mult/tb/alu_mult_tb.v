`timescale 1ns / 1ps

module alu_mult_tb;

  // Signals
  reg [31:0] a, b;
  wire [31:0] mul_result;
  wire [31:0] mulh_result;
  wire [31:0] mulhu_result;
  wire [31:0] mulhsu_result;

  // Instantiate the multiplier
  alu_mult uut (
    .a(a),
    .b(b),
    .prod_lo(mul_result),       // MUL: lower 32 of unsigned*unsigned
    .prod_hi_s(mulh_result),    // MULH: upper 32 of signed*signed
    .prod_hi_u(mulhu_result),   // MULHU: upper 32 of unsigned*unsigned
    .prod_hi_su(mulhsu_result)  // MULHSU: upper 32 of signed*unsigned
  );

  // Test vectors
  integer test_count = 0;
  integer pass_count = 0;

  // Helper task for assertion
  task assert_mul(
    input [31:0] a_in,
    input [31:0] b_in,
    input [31:0] expected_mul,
    input [31:0] expected_mulh,
    input [31:0] expected_mulhu,
    input [31:0] expected_mulhsu,
    input [7:0] test_num
  );
    begin
      #1;  // Wait for combinational logic

      test_count = test_count + 4;

      $display("\n[TEST %0d] a=0x%08h (%0d), b=0x%08h (%0d)",
               test_num, a_in, $signed(a_in), b_in, $signed(b_in));

      // Check MUL (lower 32 bits of unsigned product)
      if (mul_result === expected_mul) begin
        $display("  ✓ MUL:    0x%08h", mul_result);
        pass_count = pass_count + 1;
      end else begin
        $display("  ✗ MUL:    0x%08h (expected 0x%08h)", mul_result, expected_mul);
      end

      // Check MULH (upper 32 bits of signed*signed product)
      if (mulh_result === expected_mulh) begin
        $display("  ✓ MULH:   0x%08h", mulh_result);
        pass_count = pass_count + 1;
      end else begin
        $display("  ✗ MULH:   0x%08h (expected 0x%08h)", mulh_result, expected_mulh);
      end

      // Check MULHU (upper 32 bits of unsigned*unsigned product)
      if (mulhu_result === expected_mulhu) begin
        $display("  ✓ MULHU:  0x%08h", mulhu_result);
        pass_count = pass_count + 1;
      end else begin
        $display("  ✗ MULHU:  0x%08h (expected 0x%08h)", mulhu_result, expected_mulhu);
      end

      // Check MULHSU (upper 32 bits of signed*unsigned product)
      if (mulhsu_result === expected_mulhsu) begin
        $display("  ✓ MULHSU: 0x%08h", mulhsu_result);
        pass_count = pass_count + 1;
      end else begin
        $display("  ✗ MULHSU: 0x%08h (expected 0x%08h)", mulhsu_result, expected_mulhsu);
      end
    end
  endtask

  initial begin
    $dumpfile("alu_mult_tb.vcd");
    $dumpvars(0, alu_mult_tb);

    $display("\n========================================");
    $display("   ALU Multiplier Testbench (Final)");
    $display("========================================");

    // Test 1: 0 * anything = 0
    a = 32'h00000000;
    b = 32'h12345678;
    assert_mul(32'h00000000, 32'h12345678,
               32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 1);

    // Test 2: 1 * n = n (unsigned)
    a = 32'h00000001;
    b = 32'h12345678;
    assert_mul(32'h00000001, 32'h12345678,
               32'h12345678, 32'h00000000, 32'h00000000, 32'h00000000, 2);

    // Test 3: Small values (7 * 9 = 63)
    a = 32'h00000007;
    b = 32'h00000009;
    assert_mul(32'h00000007, 32'h00000009,
               32'h0000003f, 32'h00000000, 32'h00000000, 32'h00000000, 3);

    // Test 4: 0x1000 * 0x1000 = 0x1000000
    a = 32'h00001000;
    b = 32'h00001000;
    assert_mul(32'h00001000, 32'h00001000,
               32'h01000000, 32'h00000000, 32'h00000000, 32'h00000000, 4);

    // Test 5: 0xFFFFFFFF * 0x00000002
    // signed: -1 * 2 = -2 = 0xfffffffffffffffe
    a = 32'hffffffff;
    b = 32'h00000002;
    assert_mul(32'hffffffff, 32'h00000002,
               32'hfffffffe, 32'hffffffff, 32'h00000001, 32'hffffffff, 5);

    // Test 6: Signed positive * Signed positive: 1000 * 2000 = 2000000
    a = 32'h000003e8;  // 1000
    b = 32'h000007d0;  // 2000
    assert_mul(32'h000003e8, 32'h000007d0,
               32'h001e8480, 32'h00000000, 32'h00000000, 32'h00000000, 6);

    // Test 7: 100 * -50 (as bits)
    // Signed: 100 * -50 = -5000 = 0xffffec78, upper = 0xffffffff
    // MULHSU: signed(100) * unsigned(0xffffffce) = 100 * 4294967246
    //   = 429496724600 = 0x636666649c, upper = 0x00000063
    a = 32'h00000064;  // 100
    b = 32'hffffffce;  // -50
    assert_mul(32'h00000064, 32'hffffffce,
               32'hffffec78, 32'hffffffff, 32'h00000063, 32'h00000063, 7);

    // Test 8: -100 * -50 (as bits)
    // Signed: -100 * -50 = 5000 = 0x1388, upper = 0
    // MULHU/MULHSU: 0xffffff9c * 0xffffffce as unsigned
    //   = 4294967196 * 4294967246 (large product), upper = 0xffffff6a
    a = 32'hffffff9c;  // -100
    b = 32'hffffffce;  // -50
    assert_mul(32'hffffff9c, 32'hffffffce,
               32'h00001388, 32'h00000000, 32'hffffff6a, 32'hffffff9c, 8);

    // Test 9: min_int * min_int
    // Signed: -2^31 * -2^31 = 2^62 (overflow) = 0x4000000000000000, upper = 0x40000000
    // Unsigned: 0x80000000 * 0x80000000 = 0x4000000000000000, upper = 0x40000000
    // MULHSU: signed(-2^31) * unsigned(2^31) = -2^62 = 0xc000000000000000, upper = 0xc0000000
    a = 32'h80000000;
    b = 32'h80000000;
    assert_mul(32'h80000000, 32'h80000000,
               32'h00000000, 32'h40000000, 32'h40000000, 32'hc0000000, 9);

    // Test 10: -1 * -1 = 1
    a = 32'hffffffff;  // -1
    b = 32'hffffffff;  // -1
    assert_mul(32'hffffffff, 32'hffffffff,
               32'h00000001, 32'h00000000, 32'hfffffffe, 32'hffffffff, 10);

    // Test 11: Power of 2: 2^16 * 2^16 = 2^32
    a = 32'h00010000;  // 2^16
    b = 32'h00010000;  // 2^16
    assert_mul(32'h00010000, 32'h00010000,
               32'h00000000, 32'h00000001, 32'h00000001, 32'h00000001, 11);

    // Test 12: 1000 * 1000 = 1000000
    a = 32'h000003e8;  // 1000
    b = 32'h000003e8;  // 1000
    assert_mul(32'h000003e8, 32'h000003e8,
               32'h000f4240, 32'h00000000, 32'h00000000, 32'h00000000, 12);

    // Summary
    $display("\n========================================");
    $display("   Test Summary: %0d/%0d passed", pass_count, test_count);
    $display("========================================\n");

    if (pass_count === test_count) begin
      $display("✓ All tests PASSED");
      $finish(0);
    end else begin
      $display("✗ Some tests FAILED");
      $finish(1);
    end
  end

endmodule
