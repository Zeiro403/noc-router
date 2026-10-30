`timescale 1ns/1ps
import noc_tb_pkg::flit_t;
import noc_tb_pkg::noc_packet;
class noc_driver;

    virtual noc_input_if.tb vif;

    int port_id;

    function new(
        virtual noc_input_if.tb vif_arg,
        int port_id_arg
    );
        this.vif = vif_arg;
        this.port_id = port_id_arg;
    endfunction

    // ------------------------------------------
    // Initialize driver outputs
    // ------------------------------------------

    task reset_signals();
        vif.valid = 1'b0;
        vif.flit  = '0;
    endtask

    // ------------------------------------------
    // Send one flit
    // ------------------------------------------

    task send_flit(input flit_t flit);

        // Drive signals away from rising edge.
        @(negedge vif.clk);

        vif.flit  = flit;
        vif.valid = 1'b1;

        // Wait for an accepted transfer.
        do begin
            @(posedge vif.clk);
        end while (!vif.ready);

        // Deassert valid before the next rising edge.
        @(negedge vif.clk);

        vif.valid = 1'b0;

    endtask

    // ------------------------------------------
    // Send a complete packet
    // ------------------------------------------

    task send_packet(input noc_packet pkt);

        flit_t flits[$];

        pkt.to_flits(flits);

        $display(
            "[%0t] DRIVER[%0d]: Sending %0d flits",
            $time, port_id, flits.size()
        );

        foreach (flits[i]) begin
            send_flit(flits[i]);
        end

        $display(
            "[%0t] DRIVER[%0d]: Packet accepted",
            $time, port_id
        );

    endtask

endclass
