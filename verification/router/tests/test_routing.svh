
task automatic test_routing();

    noc_packet pkt;
    int txn;

    $display("TEST: routing - All input/output combinations");

    txn = 0;

    for (int input_port = 0; input_port < 5; input_port++) begin

        for (int output_port = 0; output_port < 5; output_port++) begin

            case (output_port)
                TB_NORTH: pkt = create_packet(1, 2, 1, 1, txn, 1);
                TB_SOUTH: pkt = create_packet(1, 0, 1, 1, txn, 1);
                TB_EAST:  pkt = create_packet(2, 1, 1, 1, txn, 1);
                TB_WEST:  pkt = create_packet(0, 1, 1, 1, txn, 1);
                TB_LOCAL: pkt = create_packet(1, 1, 1, 1, txn, 1);
                default: $fatal(1, "Invalid output port");
            endcase

            scoreboard.expect_packet(pkt, input_port, output_port);

            case (input_port)
                TB_NORTH: drv_north.send_packet(pkt);
                TB_SOUTH: drv_south.send_packet(pkt);
                TB_EAST:  drv_east.send_packet(pkt);
                TB_WEST:  drv_west.send_packet(pkt);
                TB_LOCAL: drv_local.send_packet(pkt);
                default: $fatal(1, "Invalid input port");
            endcase

            wait_for_completion(100);

            $display(
                "ROUTING PASS: input=%0d output=%0d",
                input_port, output_port
            );

            txn++;

        end

    end

    scoreboard.check_complete();

    $display("TEST routing PASSED");

endtask
