
task automatic test_local();

    noc_packet pkt;

    $display("TEST: local - West to Local");

    pkt = create_packet(
        1, 1,
        0, 1,
        2,
        0
    );

    scoreboard.expect_packet(pkt, TB_WEST, TB_LOCAL);

    drv_west.send_packet(pkt);

    wait_for_completion(100);

    scoreboard.check_complete();

    $display("TEST local PASSED");

endtask
