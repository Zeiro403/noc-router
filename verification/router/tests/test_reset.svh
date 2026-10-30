
task automatic test_reset();

    noc_packet interrupted_pkt;
    noc_packet recovery_pkt;

    flit_t interrupted_flits[$];

    bit header_visible;

    $display("TEST: reset");

    // ------------------------------------------
    // Prepare an interrupted packet
    // ------------------------------------------

    interrupted_pkt = create_packet(
        2, 1,
        1, 2,
        6,
        3
    );

    interrupted_pkt.to_flits(interrupted_flits);

    // Stall East before injecting the header.
    @(negedge clk);
    out_east.ready = 1'b0;

    // Inject only the header.
    drv_north.send_flit(interrupted_flits[0]);

    // Wait until the header is presented.
    header_visible = 0;

    for (int cycle = 0; cycle < 40; cycle++) begin
        @(negedge clk);

        if (out_valid[TB_EAST]) begin
            header_visible = 1;
            break;
        end
    end

    if (!header_visible)
        $fatal(1, "RESET: Header never reached East");

    if (out_flit[TB_EAST] !== interrupted_flits[0])
        $fatal(1, "RESET: Incorrect stalled header");

    // ------------------------------------------
    // Assert reset during stalled packet
    // ------------------------------------------

    rst_n = 1'b0;

    repeat (4) @(negedge clk);

    if (out_valid !== '0)
        $fatal(1, "RESET: Output valid not cleared");

    if (in_valid !== '0)
        $fatal(1, "RESET: Input driver still active");

    // No completed packet was expected from the
    // interrupted transaction.

    rst_n = 1'b1;

    @(negedge clk);
    out_east.ready = 1'b1;

    repeat (3) @(negedge clk);

    // ------------------------------------------
    // Verify recovery
    // ------------------------------------------

    recovery_pkt = create_packet(
        2, 1,
        1, 2,
        7,
        2
    );

    scoreboard.expect_packet(
        recovery_pkt,
        TB_NORTH, TB_EAST);

    drv_north.send_packet(recovery_pkt);

    wait_for_completion(150);

    scoreboard.check_complete();

    $display("TEST reset PASSED");

endtask
