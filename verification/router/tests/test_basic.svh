
task automatic test_basic();

    noc_packet pkt;

    $display("TEST: basic - North to East");

    pkt = create_packet(
        2, 1,  // Destination
        1, 2,  // Source
        1,     // Transaction ID
        2      // Payload length
    );

    scoreboard.expect_packet(pkt, TB_NORTH, TB_EAST);

    drv_north.send_packet(pkt);

    wait_for_completion(100);

    scoreboard.check_complete();

    $display("TEST basic PASSED");

endtask
