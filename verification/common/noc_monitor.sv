`timescale 1ns/1ps
import noc_tb_pkg::flit_t;
import noc_tb_pkg::noc_observed_packet;
class noc_monitor;

    virtual noc_output_if.mon vif;

    int port_id;

    mailbox #(noc_observed_packet) observed_mb;

    noc_observed_packet current_pkt;

    bit collecting;

    function new(
        virtual noc_output_if.mon vif_arg,
        int port_id_arg,
        mailbox #(noc_observed_packet) observed_mb_arg
    );
        this.vif = vif_arg;
        this.port_id = port_id_arg;
        this.observed_mb = observed_mb_arg;

        this.current_pkt = null;
        this.collecting = 0;
    endfunction

    task run();

        bit [31:0] h;
        int expected_flits;

        flit_t sampled_flit;

        forever begin

            @(posedge vif.clk);

            if (!vif.rst_n) begin
                current_pkt = null;
                collecting = 0;
                continue;
            end

            // Capture only successful handshakes.
            if (!(vif.valid && vif.ready))
                continue;

            sampled_flit = vif.flit;

            // ----------------------------------
            // Start of packet
            // ----------------------------------

            if (sampled_flit[33]) begin

                if (collecting)
                    $fatal(1,
                        "MONITOR[%0d]: SOP before previous EOP",
                        port_id
                    );

                current_pkt = new(port_id);
                collecting = 1;

            end
            else if (!collecting) begin

                $fatal(1,
                    "MONITOR[%0d]: Body flit without SOP",
                    port_id
                );

            end

            // ----------------------------------
            // Append accepted flit
            // ----------------------------------

            current_pkt.flits.push_back(sampled_flit);

            // ----------------------------------
            // End of packet
            // ----------------------------------

            if (sampled_flit[32]) begin

                h = current_pkt.header();
                expected_flits = int'(h[7:0]) + 1;

                if (current_pkt.flits.size() != expected_flits)
                    $fatal(1,
                        "MONITOR[%0d]: Expected %0d flits, got %0d",
                        port_id,
                        expected_flits,
                        current_pkt.flits.size()
                    );

                observed_mb.put(current_pkt);

                $display(
                    "[%0t] MONITOR[%0d]: Packet received (%0d flits)",
                    $time,
                    port_id,
                    current_pkt.flits.size()
                );

                current_pkt = null;
                collecting = 0;

            end

        end

    endtask

endclass
