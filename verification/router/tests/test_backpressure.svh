
task automatic test_backpressure();

    noc_packet pkt_header;
    noc_packet pkt_body;

    $display("TEST: backpressure");

    // ------------------------------------------
    // Part A: Stall before header transfer
    // ------------------------------------------

    pkt_header = create_packet(2, 1, 1, 2, 1, 3);

    scoreboard.expect_packet(pkt_header, TB_NORTH, TB_EAST);

    @(negedge clk);
    out_east.ready = 1'b0;

    fork
        begin
            drv_north.send_packet(pkt_header);
        end

        begin
            repeat (20) @(negedge clk);

            if (!out_valid[TB_EAST])
                $fatal(1, "Header did not become valid");

            out_east.ready = 1'b1;
        end
    join

    wait_for_completion(150);

    $display("BACKPRESSURE: Header stall passed");

    // ------------------------------------------
    // Part B: Stall after header transfer
    // ------------------------------------------

    pkt_body = create_packet(2, 1, 1, 0, 2, 4);

    scoreboard.expect_packet(pkt_body, TB_SOUTH, TB_EAST);

    fork
        begin
            drv_south.send_packet(pkt_body);
        end

        begin
            // Wait until the header is accepted.
            do begin
                @(posedge clk);
            end while (!(out_valid[TB_EAST] &&
                         out_ready[TB_EAST] &&
                         out_flit[TB_EAST][33]));

            // Stop the next flit.
            @(negedge clk);
            out_east.ready = 1'b0;

            repeat (15) @(negedge clk);

            if (!out_valid[TB_EAST])
                $fatal(1, "Body did not become valid");

            out_east.ready = 1'b1;
        end
    join

    wait_for_completion(200);

    scoreboard.check_complete();

    $display("TEST backpressure PASSED");

endtask
