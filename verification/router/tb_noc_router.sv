
`timescale 1ns/1ps

module tb_noc_router;

    import noc_tb_pkg::*;

    // ------------------------------------------
    // Clock and reset
    // ------------------------------------------
    int seed;

    logic clk;
    logic rst_n = 1'b0;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------
    // DUT signals
    // ------------------------------------------

    logic [4:0][33:0] in_flit;
    logic [4:0]       in_valid;
    logic [4:0]       in_ready;

    logic [4:0][33:0] out_flit;
    logic [4:0]       out_valid;
    logic [4:0]       out_ready;

    // ------------------------------------------
    // Input interfaces
    // ------------------------------------------

    noc_input_if in_north(clk);
    noc_input_if in_south(clk);
    noc_input_if in_east(clk);
    noc_input_if in_west(clk);
    noc_input_if in_local(clk);

    // ------------------------------------------
    // Output interfaces
    // ------------------------------------------

    noc_output_if out_north(clk);
    noc_output_if out_south(clk);
    noc_output_if out_east(clk);
    noc_output_if out_west(clk);
    noc_output_if out_local(clk);

    // ------------------------------------------
    // Reset connections
    // ------------------------------------------

    assign in_north.rst_n = rst_n;
    assign in_south.rst_n = rst_n;
    assign in_east.rst_n  = rst_n;
    assign in_west.rst_n  = rst_n;
    assign in_local.rst_n = rst_n;

    assign out_north.rst_n = rst_n;
    assign out_south.rst_n = rst_n;
    assign out_east.rst_n  = rst_n;
    assign out_west.rst_n  = rst_n;
    assign out_local.rst_n = rst_n;

    // ------------------------------------------
    // Input connections
    // ------------------------------------------

    assign in_flit[0] = in_north.flit;
    assign in_flit[1] = in_south.flit;
    assign in_flit[2] = in_east.flit;
    assign in_flit[3] = in_west.flit;
    assign in_flit[4] = in_local.flit;

    assign in_valid = {
        in_local.valid,
        in_west.valid,
        in_east.valid,
        in_south.valid,
        in_north.valid
    };

    assign in_north.ready = in_ready[0];
    assign in_south.ready = in_ready[1];
    assign in_east.ready  = in_ready[2];
    assign in_west.ready  = in_ready[3];
    assign in_local.ready = in_ready[4];

    // ------------------------------------------
    // Output connections
    // ------------------------------------------

    assign out_north.flit = out_flit[0];
    assign out_south.flit = out_flit[1];
    assign out_east.flit  = out_flit[2];
    assign out_west.flit  = out_flit[3];
    assign out_local.flit = out_flit[4];

    assign out_north.valid = out_valid[0];
    assign out_south.valid = out_valid[1];
    assign out_east.valid  = out_valid[2];
    assign out_west.valid  = out_valid[3];
    assign out_local.valid = out_valid[4];

    assign out_ready = {
        out_local.ready,
        out_west.ready,
        out_east.ready,
        out_south.ready,
        out_north.ready
    };

    // ------------------------------------------
    // DUT
    // ------------------------------------------

    noc_router #(
        .ROUTER_X(4'd1),
        .ROUTER_Y(4'd1),
        .FIFO_DEPTH(4)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_flit   (in_flit),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .out_flit  (out_flit),
        .out_valid (out_valid),
        .out_ready (out_ready)
    );

    noc_assertions #(
        .PORTS(5),
        .FLIT_W(34)
    ) assertions_inst (
        .clk(clk),
        .rst_n(rst_n),
        .out_flit(out_flit),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );
    
    // ------------------------------------------
    // Verification objects
    // ------------------------------------------

    noc_driver drv_north;
    noc_driver drv_south;
    noc_driver drv_east;
    noc_driver drv_west;
    noc_driver drv_local;

    noc_monitor mon_north;
    noc_monitor mon_south;
    noc_monitor mon_east;
    noc_monitor mon_west;
    noc_monitor mon_local;

    mailbox #(noc_observed_packet) observed_mb;

    noc_scoreboard scoreboard;

    // ------------------------------------------
    // Packet factory
    // ------------------------------------------

    function automatic noc_packet create_packet(
        input logic [3:0] dx,
        input logic [3:0] dy,
        input logic [3:0] sx,
        input logic [3:0] sy,
        input int id,
        input int length
    );

        noc_packet pkt = new();

        pkt.dest_x = dx;
        pkt.dest_y = dy;
        pkt.src_x  = sx;
        pkt.src_y  = sy;

        pkt.txn_id  = 4'(id);
        pkt.pkt_type = 4'd0;

        pkt.payload_len = length;
        pkt.payload = new[length];

        for (int i = 0; i < length; i++) begin
            pkt.payload[i] =
                32'hA5000000 |
                (32'(id) << 16) |
                32'(i);
        end

        return pkt;

    endfunction

    // ------------------------------------------
    // Completion watchdog
    // ------------------------------------------

    task automatic wait_for_completion(
        input int max_cycles
    );

        for (int cycle = 0; cycle < max_cycles; cycle++) begin

            @(negedge clk);

            if (scoreboard.is_complete())
                return;

        end

        scoreboard.report();

        $fatal(
            1,
            "TIMEOUT: Scoreboard incomplete after %0d cycles",
            max_cycles
        );

    endtask

    // ------------------------------------------
    // Test scenarios
    // ------------------------------------------

    `include "test_basic.svh"
    `include "test_local.svh"
    `include "test_parallel.svh"
    `include "test_routing.svh"
    `include "test_contention.svh"
    `include "test_backpressure.svh"
    `include "test_fifo_stress.svh"
    `include "test_back_to_back.svh"
    `include "test_reset.svh"
    `include "test_fairness.svh"
    `include "test_random.svh"

    // ------------------------------------------
    // Main test dispatcher
    // ------------------------------------------

    initial begin : MAIN_TEST

        string test_name;

        if (!$value$plusargs("TEST=%s", test_name))
            test_name = "basic";

        if (!$value$plusargs("SEED=%d", seed))
            seed = 1;

        $display("================================");
        $display("NoC Router Verification");
        $display("Test: %s", test_name);
        $display("Seed: %0d", seed);
        $display("================================");

        // Initialize input drivers.
        in_north.valid = 0;
        in_south.valid = 0;
        in_east.valid  = 0;
        in_west.valid  = 0;
        in_local.valid = 0;

        in_north.flit = '0;
        in_south.flit = '0;
        in_east.flit  = '0;
        in_west.flit  = '0;
        in_local.flit = '0;

        // Receivers always ready for smoke tests.
        out_north.ready = 1;
        out_south.ready = 1;
        out_east.ready  = 1;
        out_west.ready  = 1;
        out_local.ready = 1;

        observed_mb = new();
        scoreboard  = new(observed_mb);

        drv_north = new(in_north, TB_NORTH);
        drv_south = new(in_south, TB_SOUTH);
        drv_east  = new(in_east, TB_EAST);
        drv_west  = new(in_west, TB_WEST);
        drv_local = new(in_local, TB_LOCAL);

        mon_north = new(out_north, TB_NORTH, observed_mb);
        mon_south = new(out_south, TB_SOUTH, observed_mb);
        mon_east  = new(out_east, TB_EAST, observed_mb);
        mon_west  = new(out_west, TB_WEST, observed_mb);
        mon_local = new(out_local, TB_LOCAL, observed_mb);

        // Start monitors and scoreboard.
        fork
            mon_north.run();
            mon_south.run();
            mon_east.run();
            mon_west.run();
            mon_local.run();
            scoreboard.run();
        join_none

        // Reset.
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        // Run exactly one test per simulation.
        case (test_name)

            "basic":    test_basic();
            "local":    test_local();
            "parallel": test_parallel();
            "routing":       test_routing();
            "contention":    test_contention();
            "backpressure":  test_backpressure();
            "fifo_stress":   test_fifo_stress();
            "back_to_back":  test_back_to_back();
            "reset":         test_reset();
            "fairness": test_fairness();
            "random": test_random();

            default: begin
                $fatal(
                    1,
                    "Unknown test: %s",
                    test_name
                );
            end

        endcase

        $display("");
        $display("================================");
        $display("TEST %s PASSED", test_name);
        $display("================================");

        $finish;

    end

    always @(posedge clk) begin
    if (rst_n) begin
        for (int p = 0; p < 5; p++) begin
            if (in_valid[p] && in_ready[p]) begin
                $display(
                    "[%0t] IN[%0d] SOP=%0b EOP=%0b DATA=%08h",
                    $time, p,
                    in_flit[p][33],
                    in_flit[p][32],
                    in_flit[p][31:0]
                );
            end

            if (out_valid[p] && out_ready[p]) begin
                $display(
                    "[%0t] OUT[%0d] SOP=%0b EOP=%0b DATA=%08h",
                    $time, p,
                    out_flit[p][33],
                    out_flit[p][32],
                    out_flit[p][31:0]
                );
            end
        end
    end
end

    // ------------------------------------------
    // Global timeout
    // ------------------------------------------

    initial begin
        #100000;
        $fatal(1, "GLOBAL SIMULATION TIMEOUT");
    end

endmodule
