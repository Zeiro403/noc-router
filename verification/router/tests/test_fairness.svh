
task automatic test_fairness();

    localparam int NUM_INPUTS = 5;
    localparam int PKTS_PER_INPUT = 10;
    localparam int TOTAL_PKTS = NUM_INPUTS * PKTS_PER_INPUT;

    noc_packet packets[NUM_INPUTS][PKTS_PER_INPUT];

    int sent_count[NUM_INPUTS];
    int input_port;

    $display("TEST: Router-level sustained contention");

    // ------------------------------------------
    // Create and register all expected packets
    // ------------------------------------------

    for (int p = 0; p < NUM_INPUTS; p++) begin

        sent_count[p] = 0;

        for (int n = 0; n < PKTS_PER_INPUT; n++) begin

            // All packets target East.
            packets[p][n] = create_packet(
                2, 1,
                1, 1,
                p * PKTS_PER_INPUT + n,
                2
            );

            scoreboard.expect_packet(
                packets[p][n],
                p,
                TB_EAST
            );

        end

    end

    // ------------------------------------------
    // Inject traffic concurrently
    // ------------------------------------------

    fork

        begin
            for (int n = 0; n < PKTS_PER_INPUT; n++) begin
                drv_north.send_packet(packets[TB_NORTH][n]);
                sent_count[TB_NORTH]++;
            end
        end

        begin
            for (int n = 0; n < PKTS_PER_INPUT; n++) begin
                drv_south.send_packet(packets[TB_SOUTH][n]);
                sent_count[TB_SOUTH]++;
            end
        end

        begin
            for (int n = 0; n < PKTS_PER_INPUT; n++) begin
                drv_east.send_packet(packets[TB_EAST][n]);
                sent_count[TB_EAST]++;
            end
        end

        begin
            for (int n = 0; n < PKTS_PER_INPUT; n++) begin
                drv_west.send_packet(packets[TB_WEST][n]);
                sent_count[TB_WEST]++;
            end
        end

        begin
            for (int n = 0; n < PKTS_PER_INPUT; n++) begin
                drv_local.send_packet(packets[TB_LOCAL][n]);
                sent_count[TB_LOCAL]++;
            end
        end

    join

    // ------------------------------------------
    // Wait for complete delivery
    // ------------------------------------------

    wait_for_completion(2000);

    scoreboard.check_complete();

    // ------------------------------------------
    // Check every input injected all packets
    // ------------------------------------------

    for (int p = 0; p < NUM_INPUTS; p++) begin

        if (sent_count[p] != PKTS_PER_INPUT)
            $fatal(
                1,
                "FAIRNESS: Input %0d sent only %0d packets",
                p,
                sent_count[p]
            );

    end

    if (scoreboard.matched_count != TOTAL_PKTS)
        $fatal(
            1,
            "FAIRNESS: Expected %0d matched packets, got %0d",
            TOTAL_PKTS,
            scoreboard.matched_count
        );

    $display("");
    $display("======================================");
    $display("ROUTER FAIRNESS TEST PASSED");
    $display("Inputs          : %0d", NUM_INPUTS);
    $display("Packets/input   : %0d", PKTS_PER_INPUT);
    $display("Total packets   : %0d", TOTAL_PKTS);
    $display("======================================");

endtask
