`timescale 1ps / 1fs

module tb_omdc_top();

    // -------------------------------------------------------------------------
    // 1. PHYSICAL LAYER PARAMETERS
    // -------------------------------------------------------------------------
    localparam real IDEAL_PERIOD_PS = 3100.198; // 322.56 MHz
    localparam real HKEX_PPM        = 25.0;     
    localparam real GTH_RJ_RMS      = 6.0;       
    
    reg clk_local = 0;
    reg rx_rec_clk = 0;

    always #(IDEAL_PERIOD_PS / 2.0) clk_local = ~clk_local;

    integer seed = 666;
    initial begin
        #( $urandom_range(0, 3100) ); 
        forever begin
            #( (IDEAL_PERIOD_PS * (1.0 - HKEX_PPM/1e6) / 2.0) + $dist_normal(seed, 0, GTH_RJ_RMS) ) rx_rec_clk = ~rx_rec_clk;
        end
    end

    // -------------------------------------------------------------------------
    // 2. SIGNAL DEFINITIONS
    // -------------------------------------------------------------------------
    reg [63:0] rx_data_mem [0:399999]; 
    reg [63:0] inject_rx_data;
    reg        rst_done;
    
    wire [31:0] tx_data;
    wire [3:0]  tx_ctrl;

    // Golden Model statistical counters
    integer total_golden_add_orders = 0;
    integer total_rtl_caught        = 0;

    // -------------------------------------------------------------------------
    // 3. DUT INSTANTIATION (STRICT DUAL-CLOCK DOMAIN ALIGNMENT)
    // -------------------------------------------------------------------------
    omdc_system_top dut (
        .tx_core_clk   (clk_local),       
        .rx_rec_clk    (rx_rec_clk),      
        .rx_data_in    (inject_rx_data),
        .rx_reset_done (rst_done),
        .tx_data_out   (tx_data),
        .tx_ctrl_out   (tx_ctrl)
    );

    wire internal_valid = dut.u_rx_parser.parsed_msg_valid;
    wire [15:0] internal_type = dut.u_rx_parser.parsed_msg_type;

    // -------------------------------------------------------------------------
    // 4. SIMULATION CONTROL LOGIC
    // -------------------------------------------------------------------------
    initial begin
        inject_rx_data = 64'h0707070707070707;
        rst_done = 0;
        
        $display("\n[SYS] Loading Data: F:/raw_data.hex");
        $readmemh("F:/raw_data.hex", rx_data_mem); 
        
        repeat(500) @(posedge clk_local);
        rst_done = 1;
        repeat(50) @(posedge rx_rec_clk);
        $display("[SYS] Link Up. Injecting with Jitter/PPM...");

        for (int i = 0; i < 400000; i++) begin
            if (rx_data_mem[i] === 64'hxxxxxxxxxxxxxxxx) break;
            @(posedge rx_rec_clk);
            #2100 inject_rx_data <= rx_data_mem[i]; 
        end

        repeat(100) @(posedge clk_local);
        
        $display("\n====================================================");
        $display("  [HKEX OMD-C PHYSICAL LAYER SIM REPORT]");
        $display("  Golden Model (Expected MsgType=30) : %0d", total_golden_add_orders);
        $display("  RTL Caught   (Actual Parsed)       : %0d", total_rtl_caught);
        
        if (total_golden_add_orders == total_rtl_caught && total_golden_add_orders > 0) begin
            $display("  RESULT: [PASSED] - RTL Data Path is Perfect.");
        } else begin
            $display("  RESULT: [FAILED] - Packet Loss or Logical Error!");
            $display("  Diff: %0d", (total_golden_add_orders - total_rtl_caught));
        end
        $display("====================================================\n");
        $finish;
    end

    // -------------------------------------------------------------------------
    // 5. GOLDEN MODEL (BEHAVIORAL OMD-C PARSER)
    // Strictly complies with HKEX OMD-C v1.45 Section 3.2 & 3.3
    // -------------------------------------------------------------------------
    byte raw_byte_q[$];
    
    // Extract byte stream into Queue (Remote clock domain simulating PHY output)
    always @(posedge rx_rec_clk) begin
        if (rst_done && inject_rx_data !== 64'h0707070707070707) begin
            // Physical layer bus mapping (Little-Endian / Byte Unpacking)
            raw_byte_q.push_back(inject_rx_data[7:0]);
            raw_byte_q.push_back(inject_rx_data[15:8]);
            raw_byte_q.push_back(inject_rx_data[23:16]);
            raw_byte_q.push_back(inject_rx_data[31:24]);
            raw_byte_q.push_back(inject_rx_data[39:32]);
            raw_byte_q.push_back(inject_rx_data[47:40]);
            raw_byte_q.push_back(inject_rx_data[55:48]);
            raw_byte_q.push_back(inject_rx_data[63:56]);
        end
    end

    // Golden Parser independent thread
    initial begin
        int msg_count;
        int msg_size;
        int msg_type;
        
        forever begin
            wait(raw_byte_q.size() > 18); // Wait for sufficient bytes to enter the queue
            
            // Search for D555 (SFD) physical alignment
            if (raw_byte_q[0] == 8'h55 && raw_byte_q[1] == 8'hD5) begin
                raw_byte_q.pop_front(); // Pop 55
                raw_byte_q.pop_front(); // Pop D5
                
                // Wait for 16-byte Packet Header to fall into the queue
                wait(raw_byte_q.size() >= 16);
                
                // Per Section 3.3, MsgCount is located at Offset 2
                msg_count = raw_byte_q[2];
                
                // Discard 16-byte Packet Header
                for(int i=0; i<16; i++) raw_byte_q.pop_front();
                
                // Per Section 3.2, parse Messages within the Packet sequentially
                for (int m = 0; m < msg_count; m++) begin
                    wait(raw_byte_q.size() >= 4); // MsgSize (2) + MsgType (2)
                    
                    // OMDC specifies the use of Little-Endian 
                    msg_size = {raw_byte_q[1], raw_byte_q[0]}; 
                    msg_type = {raw_byte_q[3], raw_byte_q[2]};
                    
                    if (msg_type == 30) begin
                        total_golden_add_orders++;
                    end
                    
                    // Align the pointer to the next Message (Discard current Message Payload)
                    wait(raw_byte_q.size() >= msg_size);
                    for(int i=0; i<msg_size; i++) raw_byte_q.pop_front();
                end
            end else begin
                // Unaligned, continuously slide the window
                raw_byte_q.pop_front();
            end
        end
    end

    // -------------------------------------------------------------------------
    // 6. RTL RESULT SAMPLING (LOCAL CLOCK DOMAIN)
    // -------------------------------------------------------------------------
    always @(posedge clk_local) begin
        if (rst_done && internal_valid) begin
            total_rtl_caught <= total_rtl_caught + 1;
        end
    end

endmodule
