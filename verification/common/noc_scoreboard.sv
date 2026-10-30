`ifndef NOC_SCOREBOARD_SV
`define NOC_SCOREBOARD_SV
`timescale 1ns/1ps

import noc_tb_pkg::flit_t;
import noc_tb_pkg::noc_packet;
import noc_tb_pkg::noc_observed_packet;
import noc_tb_pkg::TB_NUM_PORTS;

class noc_scoreboard;

    class expected_packet;
        int id;
        int input_port;
        int output_port;
        flit_t flits[$];
    endclass

    expected_packet expected[$];
    mailbox #(noc_observed_packet) observed_mb;

    int next_id;
    int expected_count;
    int received_count;
    int matched_count;

    function new(mailbox #(noc_observed_packet) observed_mb_arg);
        this.observed_mb = observed_mb_arg;
        next_id = 0;
        expected_count = 0;
        received_count = 0;
        matched_count = 0;
    endfunction

    // Register before injection. input_port is the physical router ingress,
    // not the source coordinates carried in the packet header.
    function void expect_packet(noc_packet pkt, int input_port, int output_port);
        expected_packet entry;
        flit_t serialized[$];

        if (pkt == null)
            $fatal(1, "SCOREBOARD: Null expected packet");
        if (input_port < 0 || input_port >= TB_NUM_PORTS)
            $fatal(1, "SCOREBOARD: Invalid ingress port %0d", input_port);
        if (output_port < 0 || output_port >= TB_NUM_PORTS)
            $fatal(1, "SCOREBOARD: Invalid egress port %0d", output_port);

        pkt.to_flits(serialized);
        entry = new();
        entry.id = next_id;
        entry.input_port = input_port;
        entry.output_port = output_port;
        foreach (serialized[i])
            entry.flits.push_back(serialized[i]);
        expected.push_back(entry);
        next_id++;
        expected_count++;
        $display("[%0t] SCOREBOARD: Registered id=%0d input=%0d output=%0d flits=%0d",
                 $time, entry.id, input_port, output_port, entry.flits.size());
    endfunction

    function automatic bit packets_match(expected_packet exp,
                                          noc_observed_packet obs);
        if (exp == null || obs == null)
            return 0;
        if (exp.output_port != obs.output_port)
            return 0;
        if (exp.flits.size() != obs.flits.size())
            return 0;
        foreach (exp.flits[i]) begin
            if (exp.flits[i] !== obs.flits[i])
                return 0;
        end
        return 1;
    endfunction

    function void check_packet(noc_observed_packet obs);
        int match_index;
        int ingress;

        if (obs == null)
            $fatal(1, "SCOREBOARD: Null observed packet");

        received_count++;
        match_index = -1;
        foreach (expected[i]) begin
            if (packets_match(expected[i], obs)) begin
                match_index = i;
                break;
            end
        end
        if (match_index == -1)
            $fatal(1, "SCOREBOARD: Unexpected or corrupted packet on output %0d",
                   obs.output_port);

        ingress = expected[match_index].input_port;
        // An input has one FIFO and one packet owner at a time. No later
        // packet from that ingress may complete before an earlier one.
        for (int i = 0; i < match_index; i++) begin
            if (expected[i].input_port == ingress)
                $fatal(1, "SCOREBOARD: Packet ordering violation: id=%0d overtook id=%0d on ingress %0d",
                       expected[match_index].id, expected[i].id, ingress);
        end

        $display("[%0t] SCOREBOARD PASS: id=%0d input=%0d output=%0d",
                 $time, expected[match_index].id, ingress, obs.output_port);
        expected.delete(match_index);
        matched_count++;
    endfunction

    task run();
        noc_observed_packet obs;
        forever begin
            observed_mb.get(obs);
            check_packet(obs);
        end
    endtask

    function bit is_complete();
        return expected.size() == 0 &&
               received_count == expected_count &&
               matched_count == expected_count;
    endfunction

    function void report();
        $display("\n========== NoC SCOREBOARD ==========");
        $display("Expected : %0d", expected_count);
        $display("Received : %0d", received_count);
        $display("Matched  : %0d", matched_count);
        $display("Pending  : %0d", expected.size());
        $display("====================================");
    endfunction

    function void check_complete();
        report();
        if (!is_complete()) begin
            foreach (expected[i])
                $display("MISSING: id=%0d input=%0d output=%0d",
                         expected[i].id, expected[i].input_port,
                         expected[i].output_port);
            $fatal(1, "SCOREBOARD: Verification incomplete");
        end
        $display("SCOREBOARD: ALL PACKETS MATCHED");
    endfunction

endclass
`endif
