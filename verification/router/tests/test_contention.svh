
task automatic test_contention();

    noc_packet pkt_n;
    noc_packet pkt_s;
    noc_packet pkt_e;
    noc_packet pkt_w;
    noc_packet pkt_l;

    $display("TEST: contention - Five inputs to East");

    pkt_n = create_packet(2, 1, 1, 2, 1, 3);
    pkt_s = create_packet(2, 1, 1, 0, 2, 4);
    pkt_e = create_packet(2, 1, 2, 1, 3, 2);
    pkt_w = create_packet(2, 1, 0, 1, 4, 5);
    pkt_l = create_packet(2, 1, 1, 1, 5, 3);

    scoreboard.expect_packet(pkt_n, TB_NORTH, TB_EAST);
    scoreboard.expect_packet(pkt_s, TB_SOUTH, TB_EAST);
    scoreboard.expect_packet(pkt_e, TB_EAST, TB_EAST);
    scoreboard.expect_packet(pkt_w, TB_WEST, TB_EAST);
    scoreboard.expect_packet(pkt_l, TB_LOCAL, TB_EAST);

    fork
        drv_north.send_packet(pkt_n);
        drv_south.send_packet(pkt_s);
        drv_east.send_packet(pkt_e);
        drv_west.send_packet(pkt_w);
        drv_local.send_packet(pkt_l);
    join

    wait_for_completion(300);

    scoreboard.check_complete();

    $display("TEST contention PASSED");

endtask
