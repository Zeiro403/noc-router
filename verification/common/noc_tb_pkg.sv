`timescale 1ns/1ps
package noc_tb_pkg;

    // ------------------------------------------
    // Router configuration
    // ------------------------------------------

    localparam int TB_NUM_PORTS = 5;
    localparam int FLIT_W    = 34;
    // localparam int DATA_W    = 32;

    typedef logic [FLIT_W-1:0] flit_t;

    // ------------------------------------------
    // Port identifiers
    // ------------------------------------------

    typedef enum int {
        TB_NORTH = 0,
        TB_SOUTH = 1,
        TB_EAST  = 2,
        TB_WEST  = 3,
        TB_LOCAL = 4
    } port_id_t;

    // ------------------------------------------
    // Packet transaction
    // ------------------------------------------

    class noc_packet;

        rand bit [3:0] dest_x;
        rand bit [3:0] dest_y;

        rand bit [3:0] src_x;
        rand bit [3:0] src_y;

        rand bit [3:0] txn_id;
        rand bit [3:0] pkt_type;

        rand int unsigned payload_len;

        rand bit [31:0] payload[];

        // --------------------------------------
        // Randomization constraints
        // --------------------------------------

        constraint c_destination {
            dest_x inside {[0:2]};
            dest_y inside {[0:2]};
        }

        constraint c_source {
            src_x inside {[0:2]};
            src_y inside {[0:2]};
        }

        constraint c_length {
            payload_len inside {[0:8]};
        }

        constraint c_type {
            pkt_type inside {[0:3]};
        }

        // --------------------------------------
        // Construct 32-bit header
        // --------------------------------------

        function bit [31:0] get_header();

            bit [31:0] header;

            header = '0;

            header[31:28] = pkt_type;
            header[27:24] = dest_x;
            header[23:20] = dest_y;
            header[19:16] = src_x;
            header[15:12] = src_y;
            header[11:8]  = txn_id;
            header[7:0]   = 8'(payload_len);

            return header;

        endfunction

        // --------------------------------------
        // Convert packet into flits
        // --------------------------------------

        function void to_flits(ref flit_t flits[$]);

            flit_t flit;

            flits.delete();

            if (payload.size() != payload_len) begin
                $fatal(
                    1,
                    "PACKET: payload_len=%0d but array_size=%0d",
                    payload_len,
                    payload.size()
                );
            end

            // Header
            flit = {
                1'b1,
                (payload_len == 0),
                get_header()
            };

            flits.push_back(flit);

            // Payload
            for (int i = 0; i < payload.size(); i++) begin

                flit = {
                    1'b0,
                    (i == payload.size()-1),
                    payload[i]
                };

                flits.push_back(flit);

            end

        endfunction

        // --------------------------------------
        // Display packet
        // --------------------------------------

        function void print();

            $display(
                "PKT: src=(%0d,%0d) dest=(%0d,%0d) id=%0d type=%0d payload=%0d",
                src_x, src_y,
                dest_x, dest_y,
                txn_id, pkt_type,
                payload_len
            );

        endfunction

    endclass


    class noc_observed_packet;

        int output_port;

        flit_t flits[$];

        function new(int output_port_arg);
            this.output_port = output_port_arg;
        endfunction

        function bit [31:0] header();
            if (flits.size() == 0)
                return '0;

            return flits[0][31:0];
        endfunction

        function int dest_x();
            bit [31:0] h;
            h = header();
            return int'(h[27:24]);
        endfunction

        function int dest_y();
            bit [31:0] h;
            h = header();
            return int'(h[23:20]);
        endfunction

        function void print();
            $display(
                "OBSERVED: output=%0d flits=%0d",
                output_port, flits.size()
            );
        endfunction

    endclass


endpackage
