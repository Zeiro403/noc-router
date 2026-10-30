
task automatic test_parallel();

    noc_packet pkt_a;
    noc_packet pkt_b;

    $display("TEST: parallel - Independent traffic");

    pkt_a = create_packet(
        2, 1,
        1, 2,
        3,
        3
    );

    pkt_b = create_packet(
        0, 1,
        1, 0,
        4,
        2
    );

    scoreboard.expect_packet(pkt_a, TB_NORTH, TB_EAST);
    scoreboard.expect_packet(pkt_b, TB_SOUTH, TB_WEST);

    fork
        drv_north.send_packet(pkt_a);
        drv_south.send_packet(pkt_b);
    join

    wait_for_completion(150);

    scoreboard.check_complete();

    $display("TEST parallel PASSED");

endtask
