
task automatic test_fifo_stress();

    noc_packet pkt;
    bit saw_full;

    $display("TEST: fifo_stress");

    pkt = create_packet(
        2, 1,
        1, 2,
        1,
        8
    );

    scoreboard.expect_packet(pkt, TB_NORTH, TB_EAST);

    saw_full = 0;

    @(negedge clk);
    out_east.ready = 1'b0;

    fork
        begin
            drv_north.send_packet(pkt);
        end

        begin
            // Allow the FIFO to fill while East is stalled.
            repeat (20) @(negedge clk);

            if (!in_ready[TB_NORTH])
                saw_full = 1;

            if (!saw_full)
                $fatal(1, "Input FIFO never became full");

            $display("FIFO STRESS: Full condition detected");

            // Release downstream backpressure.
            out_east.ready = 1'b1;
        end
    join

    wait_for_completion(300);

    scoreboard.check_complete();

    $display("TEST fifo_stress PASSED");

endtask
