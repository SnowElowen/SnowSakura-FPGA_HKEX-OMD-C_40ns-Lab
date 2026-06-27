`timescale 1ps / 1fs

// ============================================================================
// SnowSakura-FPGA Public Physical Replay Testbench
// ----------------------------------------------------------------------------
// Public-safe purpose:
//   1. Stress the DUT as a black-box with recovered-clock drift, random jitter,
//      CDR settle behavior, reset_done bounce, PMA-style bus launch skew,
//      replay gaps, and post-reset observation.
//   2. Avoid disclosure of private RX alignment, parser, OMD-C message parsing,
//      arbitration, XDC, Pblock, LOC/BEL, or routing strategy.
//   3. Support public CI by producing a deterministic top-level TX signature.
//      The private lab may pass +EXPECT_SIG=<hex> without publishing the value.
//
// This TB intentionally does NOT use:
//   - dut.u_* hierarchical probes
//   - behavioral OMD-C golden parser
//   - MsgType / MsgSize / MsgCount decoding
//   - SOP / SFD scanning as pass/fail evidence
//   - private phase / offset / extractor / arbitration observability
//
// Compile mode:
//   Use SystemVerilog mode in Vivado/XSim.
// ============================================================================

module tb_omdc_top;

    // ------------------------------------------------------------------------
    // 1. PUBLIC PHYSICAL LAYER PARAMETERS
    // ------------------------------------------------------------------------
    localparam real IDEAL_PERIOD_PS       = 3100.198;  // ~322.56 MHz
    localparam real RX_PPM_OFFSET         = 25.0;      // recovered-clock ppm drift
    localparam int  GTH_RJ_RMS_PS         = 6;         // random jitter RMS in ps
    localparam int  GTH_DJ_PEAK_PS        = 18;        // bounded deterministic jitter peak
    localparam int  PMA_TCO_BASE_PS       = 180;       // public PMA parallel-bus launch delay
    localparam int  PMA_TCO_RAND_PS       = 90;        // public Tco variation range
    localparam int  BUS_INVALID_PS        = 25;        // invalid transition aperture after launch
    localparam int  RESET_CYCLES_LOCAL    = 500;
    localparam int  CDR_SETTLE_CYCLES_RX  = 192;
    localparam int  LINK_SETTLE_CYCLES_RX = 64;
    localparam int  POST_FLUSH_CYCLES     = 4096;
    localparam int  DEFAULT_MAX_WORDS     = 400000;
    localparam [63:0] IDLE64              = 64'h0707070707070707;

    // Public latency envelope only. This is intentionally loose and does not
    // disclose the private 36 ns timing contract.
    localparam int PUBLIC_MIN_LAT_CYCLES  = 1;
    localparam int PUBLIC_MAX_LAT_CYCLES  = 64;

    // ------------------------------------------------------------------------
    // 2. CLOCKS
    // ------------------------------------------------------------------------
    reg clk_local  = 1'b0;
    reg rx_rec_clk = 1'b0;

    integer seed = 32'h515A_15E6;
    integer half_cycle_count = 0;

    always #(IDEAL_PERIOD_PS / 2.0) clk_local = ~clk_local;

    function real abs_real(input real x);
        begin
            abs_real = (x < 0.0) ? -x : x;
        end
    endfunction

    function real rx_half_period_ps;
        integer rj;
        integer dj;
        real nominal_half;
        real hp;
        begin
            nominal_half = IDEAL_PERIOD_PS * (1.0 - RX_PPM_OFFSET / 1.0e6) / 2.0;

            // $dist_normal returns integer values. Clamp to prevent impossible
            // negative/near-zero half cycles in long simulation.
            rj = $dist_normal(seed, 0, GTH_RJ_RMS_PS);

            // Deterministic low-frequency wander. Public stress only, not a
            // disclosed CDR model.
            dj = ((half_cycle_count % 257) < 128)
                 ? ((GTH_DJ_PEAK_PS * (half_cycle_count % 128)) / 128)
                 : (GTH_DJ_PEAK_PS - ((GTH_DJ_PEAK_PS * (half_cycle_count % 128)) / 128));

            hp = nominal_half + rj + dj;

            if (hp < (IDEAL_PERIOD_PS * 0.35)) begin
                hp = IDEAL_PERIOD_PS * 0.35;
            end

            rx_half_period_ps = hp;
        end
    endfunction

    initial begin
        #( $urandom_range(0, 3100) );
        forever begin
            #(rx_half_period_ps());
            rx_rec_clk = ~rx_rec_clk;
            half_cycle_count = half_cycle_count + 1;
        end
    end

    // ------------------------------------------------------------------------
    // 3. DUT IO
    // ------------------------------------------------------------------------
    reg  [63:0] rx_data_mem [0:DEFAULT_MAX_WORDS-1];
    reg  [63:0] inject_rx_data = IDLE64;
    reg         rst_done       = 1'b0;

    wire [31:0] tx_data;
    wire [3:0]  tx_ctrl;

    omdc_system_top dut (
        .tx_core_clk   (clk_local),
        .rx_rec_clk    (rx_rec_clk),
        .rx_data_in    (inject_rx_data),
        .rx_reset_done (rst_done),
        .tx_data_out   (tx_data),
        .tx_ctrl_out   (tx_ctrl)
    );

    // ------------------------------------------------------------------------
    // 4. TEST CONTROL / PLUSARGS
    // ------------------------------------------------------------------------
    string raw_hex_path;
    integer max_words;
    reg [31:0] expect_sig;
    bit has_expect_sig;

    initial begin
        raw_hex_path = "raw_data.hex";
        max_words    = DEFAULT_MAX_WORDS;

        void'($value$plusargs("RAW_HEX=%s", raw_hex_path));
        void'($value$plusargs("MAX_WORDS=%d", max_words));
        void'($value$plusargs("SEED=%d", seed));

        has_expect_sig = $value$plusargs("EXPECT_SIG=%h", expect_sig);

        if (max_words > DEFAULT_MAX_WORDS) begin
            max_words = DEFAULT_MAX_WORDS;
        end
    end

    // ------------------------------------------------------------------------
    // 5. PUBLIC PHYSICAL SOURCE MODEL
    // ------------------------------------------------------------------------
    task automatic phy_drive_word(input [63:0] w);
        integer tco_ps;
        begin
            @(posedge rx_rec_clk);

            // Source parallel bus changes after a public PMA-like Tco window.
            // The temporary X aperture models transition invalidity, not
            // metastability in the design. It must not be sampled if setup/hold
            // discipline is correct.
            tco_ps = PMA_TCO_BASE_PS + $urandom_range(0, PMA_TCO_RAND_PS);
            #tco_ps;
            inject_rx_data <= 64'hxxxx_xxxx_xxxx_xxxx;
            #BUS_INVALID_PS;
            inject_rx_data <= w;
        end
    endtask

    task automatic phy_idle_cycles(input int n);
        begin
            for (int k = 0; k < n; k++) begin
                phy_drive_word(IDLE64);
            end
        end
    endtask

    task automatic cdr_settle_sequence;
        begin
            // Public CDR/byte-boundary settle patterns. These are deliberately
            // generic and do not disclose private alignment state.
            rst_done = 1'b0;

            for (int k = 0; k < CDR_SETTLE_CYCLES_RX; k++) begin
                @(posedge rx_rec_clk);
                case (k[2:0])
                    3'd0: inject_rx_data <= 64'hffff_ffff_ffff_ffff;
                    3'd1: inject_rx_data <= 64'h5555_5555_5555_5555;
                    3'd2: inject_rx_data <= 64'h1c1c_1c1c_1c1c_1c1c;
                    3'd3: inject_rx_data <= 64'h8787_8787_8787_8787;
                    default: inject_rx_data <= $random(seed);
                endcase
            end

            // One short reset_done bounce before final lock. Real GT bring-up
            // can expose this class of control hazard; the DUT must not rely on
            // a single unsynchronized edge in the local domain.
            repeat (4) @(posedge rx_rec_clk);
            rst_done <= 1'b1;
            repeat (3) @(posedge rx_rec_clk);
            rst_done <= 1'b0;
            repeat (17) @(posedge rx_rec_clk);

            rst_done <= 1'b1;
            phy_idle_cycles(LINK_SETTLE_CYCLES_RX);
        end
    endtask

    // ------------------------------------------------------------------------
    // 6. TB-LOCAL RESET SYNCHRONIZER FOR OBSERVATION ONLY
    // ------------------------------------------------------------------------
    reg rst_l1 = 1'b0;
    reg rst_l2 = 1'b0;
    reg rst_l3 = 1'b0;

    always @(posedge clk_local) begin
        rst_l1 <= rst_done;
        rst_l2 <= rst_l1;
        rst_l3 <= rst_l2;
    end

    wire observe_enable = rst_l3;

    // ------------------------------------------------------------------------
    // 7. PUBLIC BLACK-BOX OBSERVATION
    // ------------------------------------------------------------------------
    integer words_replayed            = 0;
    integer non_idle_words_replayed   = 0;
    integer idle_gap_words_inserted   = 0;
    integer tx_activity_words         = 0;
    integer xz_output_errors          = 0;
    integer reset_xz_errors           = 0;
    integer latency_cycles_to_first_tx = -1;

    reg [31:0] tx_signature = 32'h5A15_E10E;
    reg [31:0] local_cycle  = 32'd0;

    reg first_non_idle_toggle_rx = 1'b0;
    reg first_non_idle_seen_rx   = 1'b0;

    reg first_non_idle_s1 = 1'b0;
    reg first_non_idle_s2 = 1'b0;
    reg first_non_idle_s3 = 1'b0;
    reg first_non_idle_seen_local = 1'b0;
    reg [31:0] first_non_idle_local_cycle = 32'd0;
    reg first_tx_activity_seen = 1'b0;

    function [31:0] fold_tx_signature(
        input [31:0] sig_i,
        input [31:0] data_i,
        input [3:0]  ctrl_i
    );
        reg [31:0] x;
        begin
            x = sig_i ^ data_i ^ {28'h0, ctrl_i};
            fold_tx_signature = {x[26:0], x[31:27]} ^ 32'h9E37_79B9;
        end
    endfunction

    function bit public_tx_active(input [31:0] d, input [3:0] c);
        begin
            // Public activity proxy only. This is not protocol semantic decode.
            public_tx_active = (d !== 32'h0707_0707) || (c !== 4'hF);
        end
    endfunction

    always @(posedge rx_rec_clk) begin
        if (rst_done && inject_rx_data !== IDLE64 && !$isunknown(inject_rx_data)) begin
            if (!first_non_idle_seen_rx) begin
                first_non_idle_seen_rx   <= 1'b1;
                first_non_idle_toggle_rx <= ~first_non_idle_toggle_rx;
            end
        end
    end

    always @(posedge clk_local) begin
        local_cycle <= local_cycle + 1;

        first_non_idle_s1 <= first_non_idle_toggle_rx;
        first_non_idle_s2 <= first_non_idle_s1;
        first_non_idle_s3 <= first_non_idle_s2;

        if (observe_enable && (first_non_idle_s2 ^ first_non_idle_s3) && !first_non_idle_seen_local) begin
            first_non_idle_seen_local  <= 1'b1;
            first_non_idle_local_cycle <= local_cycle;
        end

        if (!observe_enable) begin
            if ($isunknown(tx_data) || $isunknown(tx_ctrl)) begin
                reset_xz_errors <= reset_xz_errors + 1;
            end
        end else begin
            if ($isunknown(tx_data) || $isunknown(tx_ctrl)) begin
                xz_output_errors <= xz_output_errors + 1;
            end else begin
                tx_signature <= fold_tx_signature(tx_signature, tx_data, tx_ctrl);

                if (public_tx_active(tx_data, tx_ctrl)) begin
                    tx_activity_words <= tx_activity_words + 1;

                    if (!first_tx_activity_seen) begin
                        first_tx_activity_seen <= 1'b1;
                        if (first_non_idle_seen_local) begin
                            latency_cycles_to_first_tx <= local_cycle - first_non_idle_local_cycle;
                        end
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // 8. MAIN REPLAY FLOW
    // ------------------------------------------------------------------------
    initial begin
        for (int i = 0; i < DEFAULT_MAX_WORDS; i++) begin
            rx_data_mem[i] = 64'hxxxx_xxxx_xxxx_xxxx;
        end

        $display("");
        $display("============================================================");
        $display(" SnowSakura-FPGA Public Physical Replay TB");
        $display("============================================================");
        $display("[TB] RAW_HEX      = %s", raw_hex_path);
        $display("[TB] MAX_WORDS    = %0d", max_words);
        $display("[TB] CLK_PERIOD   = %0.3f ps", IDEAL_PERIOD_PS);
        $display("[TB] RX_PPM       = %0.3f ppm", RX_PPM_OFFSET);
        $display("[TB] RX_RJ_RMS    = %0d ps", GTH_RJ_RMS_PS);
        $display("[TB] GTH_DJ_PEAK  = %0d ps", GTH_DJ_PEAK_PS);

        $readmemh(raw_hex_path, rx_data_mem);

        inject_rx_data = IDLE64;
        rst_done       = 1'b0;

        repeat (RESET_CYCLES_LOCAL) @(posedge clk_local);

        $display("[TB] Starting public CDR/reset settle sequence.");
        cdr_settle_sequence();

        $display("[TB] Link model stable. Starting public physical replay.");

        for (int i = 0; i < max_words; i++) begin
            if (rx_data_mem[i] === 64'hxxxx_xxxx_xxxx_xxxx) begin
                $display("[TB] Stop marker / end of initialized memory at word %0d", i);
                break;
            end

            phy_drive_word(rx_data_mem[i]);

            words_replayed = words_replayed + 1;
            if (rx_data_mem[i] !== IDLE64) begin
                non_idle_words_replayed = non_idle_words_replayed + 1;
            end

            // Public replay-gap stress. Deterministic and generic.
            // Does not reveal packet boundary policy.
            if ((i != 0) && ((i % 2048) == 0)) begin
                int gap_len;
                gap_len = 2 + (i % 7);
                idle_gap_words_inserted = idle_gap_words_inserted + gap_len;
                phy_idle_cycles(gap_len);
            end
        end

        phy_idle_cycles(128);

        repeat (POST_FLUSH_CYCLES) @(posedge clk_local);

        $display("");
        $display("============================================================");
        $display(" SnowSakura-FPGA Public Physical Replay Report");
        $display("============================================================");
        $display(" Words replayed                 : %0d", words_replayed);
        $display(" Non-idle words replayed        : %0d", non_idle_words_replayed);
        $display(" Public idle-gap words inserted : %0d", idle_gap_words_inserted);
        $display(" TX activity words              : %0d", tx_activity_words);
        $display(" Reset-phase X/Z observations   : %0d", reset_xz_errors);
        $display(" Post-reset X/Z output errors   : %0d", xz_output_errors);
        $display(" First TX activity latency      : %0d local cycles", latency_cycles_to_first_tx);
        $display(" TX black-box signature         : 0x%08h", tx_signature);

        if (words_replayed == 0) begin
            $fatal(1, "[FAIL] No replay data loaded. Check +RAW_HEX path.");
        end

        if (non_idle_words_replayed == 0) begin
            $fatal(1, "[FAIL] Replay source contained no non-idle words.");
        end

        if (xz_output_errors != 0) begin
            $fatal(1, "[FAIL] X/Z propagated to top-level TX outputs after reset synchronization.");
        end

        if (tx_activity_words == 0) begin
            $fatal(1, "[FAIL] No top-level TX activity observed.");
        end

        if (latency_cycles_to_first_tx < PUBLIC_MIN_LAT_CYCLES ||
            latency_cycles_to_first_tx > PUBLIC_MAX_LAT_CYCLES) begin
            $fatal(1, "[FAIL] First TX activity outside public latency envelope.");
        end

        if (has_expect_sig && (tx_signature !== expect_sig)) begin
            $fatal(1, "[FAIL] TX signature mismatch. expected=0x%08h actual=0x%08h",
                   expect_sig, tx_signature);
        end

        $display(" RESULT: [PUBLIC PHYSICAL PASS]");
        $display(" Meaning:");
        $display("   - recovered-clock drift/jitter replay completed");
        $display("   - CDR/reset_done bounce did not break black-box observation");
        $display("   - top-level TX stayed X/Z-clean after reset synchronization");
        $display("   - deterministic TX signature produced for private CI regression");
        $display("   - no parser/arbitration/internal hierarchy was disclosed");
        $display("============================================================");
        $display("");

        $finish;
    end

endmodule
