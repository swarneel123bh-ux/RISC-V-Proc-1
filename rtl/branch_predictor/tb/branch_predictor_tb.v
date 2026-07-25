`timescale 1ns / 1ps

// Testbench for branch_predictor.v
//
// Two halves:
//  A) Directed correctness checks -- exercise the exact FSM transitions of
//     YOUR table, BTB hit/miss, tag aliasing at a shared index, and
//     predict-after-training. Prints [PASS]/[FAIL] per check.
//  B) Accuracy benchmark -- drives a realistic branch stream (nested loops,
//     like Pong's fill_rect) through predict->resolve->update and reports
//     PREDICTION ACCURACY as a percentage. Re-run after swapping the counter
//     variant (comment/uncomment in branch_predictor.v) to compare.
//
// The predictor's predict port is combinational; the update port is
// synchronous. The bench mirrors how proc.v uses it: read predict_* for the
// PC being fetched, then a cycle later assert update_* with the real outcome.

module branch_predictor_tb;
  localparam IDX_BITS = 6;

  reg         clk, rstb;
  reg  [31:0] pc;
  wire        predict_taken;
  wire [31:0] predict_target;
  reg         update;
  reg  [31:0] new_pc;
  reg         update_taken;
  reg  [31:0] update_target;

  integer pass = 0, fail = 0;

  branch_predictor #(.IDX_BITS(IDX_BITS)) dut (
    .clk(clk), .rstb(rstb),
    .pc(pc), .predict_taken(predict_taken), .predict_target(predict_target),
    .update(update), .new_pc(new_pc),
    .update_taken(update_taken), .update_target(update_target)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  // Apply one resolved branch to the update port (one clock).
  task do_update;
    input [31:0] bpc;
    input        taken;
    input [31:0] tgt;
    begin
      @(negedge clk);
      update = 1'b1; new_pc = bpc; update_taken = taken; update_target = tgt;
      @(posedge clk);
      @(negedge clk);
      update = 1'b0;
    end
  endtask

  // Read the prediction for a given PC (combinational).
  task get_predict;
    input  [31:0] qpc;
    output        p_taken;
    output [31:0] p_tgt;
    begin
      pc = qpc; #1;
      p_taken = predict_taken;
      p_tgt   = predict_target;
    end
  endtask

  task expect_pred;
    input [255:0] name;
    input         got;
    input         exp;
    begin
      if (got === exp) begin
        pass = pass + 1;
        $display("[PASS] %0s: predict_taken=%b", name, got);
      end else begin
        fail = fail + 1;
        $display("[FAIL] %0s: predict_taken=%b expected %b", name, got, exp);
      end
    end
  endtask

  reg        pt;
  reg [31:0] ptg;

  // ---- benchmark state ----
  integer total, correct;
  integer i, j;

  initial begin
    rstb = 0; update = 0; new_pc = 0; update_taken = 0; update_target = 0;
    pc = 0;
    @(negedge clk); @(negedge clk);
    rstb = 1;
    @(negedge clk);

    // ============================================================
    //  A) DIRECTED CORRECTNESS
    // ============================================================
    $display("---- directed checks ----");

    // Unseen branch -> BTB miss -> must predict NOT taken
    get_predict(32'h0000_1000, pt, ptg);
    expect_pred("cold branch predicts NT", pt, 1'b0);

    // Branch @0x1000 target 0x1080. Reset counter=00. Train it TAKEN and
    // watch it climb to a taken prediction. With YOUR table:
    //   00 --T--> 01 (still MSB=0, predicts NT)
    //   01 --T--> 11 (MSB=1, predicts T)   <- becomes taken after 2 trains
    do_update(32'h0000_1000, 1'b1, 32'h0000_1080);   // 00->01
    get_predict(32'h0000_1000, pt, ptg);
    expect_pred("after 1 taken (state 01) still NT", pt, 1'b0);

    do_update(32'h0000_1000, 1'b1, 32'h0000_1080);   // 01->11
    get_predict(32'h0000_1000, pt, ptg);
    expect_pred("after 2 taken (state 11) predicts T", pt, 1'b1);

    // Target must be recorded in the BTB
    if (ptg === 32'h0000_1080) begin
      pass = pass + 1; $display("[PASS] BTB target = 0x%08h", ptg);
    end else begin
      fail = fail + 1; $display("[FAIL] BTB target = 0x%08h exp 0x00001080", ptg);
    end

    // From 11, one NOT-taken. YOUR table says 11 --NT--> 10 (still MSB=1).
    // (If your code sends 11--T-->01 etc, this reveals the mismatch.)
    do_update(32'h0000_1000, 1'b0, 32'h0000_1080);   // 11->10 per your table
    get_predict(32'h0000_1000, pt, ptg);
    expect_pred("11 then NT (state 10) still predicts T", pt, 1'b1);

    // Another NOT-taken: 10 --NT--> 00 per your table -> predicts NT
    do_update(32'h0000_1000, 1'b0, 32'h0000_1080);   // 10->00
    get_predict(32'h0000_1000, pt, ptg);
    expect_pred("10 then NT (state 00) predicts NT", pt, 1'b0);

    // Tag aliasing: a different PC with the SAME index but different tag must
    // MISS (not inherit the trained entry). idx uses pc[IDX_BITS+1:2]; adding
    // 2^(IDX_BITS+2) keeps idx the same, changes the tag.
    // Re-train 0x1000 to taken first.
    do_update(32'h0000_1000, 1'b1, 32'h0000_1080);
    do_update(32'h0000_1000, 1'b1, 32'h0000_1080);
    get_predict(32'h0000_1000 + (1 << (IDX_BITS+2)), pt, ptg);
    expect_pred("same idx, different tag -> MISS -> NT", pt, 1'b0);

    // ============================================================
    //  B) ACCURACY BENCHMARK
    // ============================================================
    // Model Pong's fill_rect: an outer loop of OUTER iterations, each running
    // an inner loop of INNER iterations. The inner branch is taken
    // (INNER-1) times then falls through once; the outer branch likewise.
    // This is the pattern a 2-bit predictor should nail after warm-up.
    $display("");
    $display("---- accuracy benchmark (nested loops) ----");

    rstb = 0; @(negedge clk); rstb = 1; @(negedge clk);   // clear tables
    total = 0; correct = 0;

    begin : bench
      localparam [31:0] INNER_BR = 32'h0000_2000;   // inner loop branch PC
      localparam [31:0] OUTER_BR = 32'h0000_2040;   // outer loop branch PC
      localparam        OUTER = 50;
      localparam        INNER = 20;

      for (i = 0; i < OUTER; i = i + 1) begin
        for (j = 0; j < INNER; j = j + 1) begin
          // inner branch: taken while j < INNER-1, else fall through
          get_predict(INNER_BR, pt, ptg);
          if (j < INNER-1) begin
            if (pt === 1'b1) correct = correct + 1;   // predicted taken, was taken
            total = total + 1;
            do_update(INNER_BR, 1'b1, 32'h0000_1F00);
          end else begin
            if (pt === 1'b0) correct = correct + 1;   // predicted NT, was NT
            total = total + 1;
            do_update(INNER_BR, 1'b0, 32'h0000_1F00);
          end
        end
        // outer branch
        get_predict(OUTER_BR, pt, ptg);
        if (i < OUTER-1) begin
          if (pt === 1'b1) correct = correct + 1;
          total = total + 1;
          do_update(OUTER_BR, 1'b1, 32'h0000_1E00);
        end else begin
          if (pt === 1'b0) correct = correct + 1;
          total = total + 1;
          do_update(OUTER_BR, 1'b0, 32'h0000_1E00);
        end
      end
    end

    $display("branches: %0d   correct: %0d", total, correct);
    // integer percent, no floats: correct*100/total
    $display(">>> PREDICTION ACCURACY: %0d.%02d %%",
             (correct*100)/total,
             ((correct*10000)/total) % 100);

    $display("");
    $display("==== directed: %0d passed, %0d failed ====", pass, fail);
    if (fail == 0) $display("DIRECTED TESTS PASSED");
    else           $display("DIRECTED TESTS FAILED (check FSM transitions vs your table)");
    $finish;
  end

  initial begin #500000; $display("[FAIL] timeout"); $finish; end
endmodule
