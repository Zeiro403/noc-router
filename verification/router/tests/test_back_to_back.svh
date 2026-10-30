
task automatic test_back_to_back();

    noc_packet pkt0;
    noc_packet pkt1;
    noc_packet pkt2;

    $display("TEST: back_to_back");

    pkt0 = create_packet(2, 1, 1, 2, 1, 2);
    pkt1 = create_packet(2, 1, 1, 2, 2, 3);
    pkt2 = create_packet(2, 1, 1, 2, 3, 0);

    scoreboard.expect_packet(pkt0, TB_NORTH, TB_EAST);
    scoreboard.expect_packet(pkt1, TB_NORTH, TB_EAST);
    scoreboard.expect_packet(pkt2, TB_NORTH, TB_EAST);

    drv_north.send_packet(pkt0);
    drv_north.send_packet(pkt1);
    drv_north.send_packet(pkt2);

    wait_for_completion(200);

    scoreboard.check_complete();

    $display("TEST back_to_back PASSED");

endtask
