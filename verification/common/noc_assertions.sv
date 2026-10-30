
`timescale 1ns/1ps

module noc_assertions #(
    parameter int PORTS  = 5,
    parameter int FLIT_W = 34
)(
    input logic clk,
    input logic rst_n,

    input logic [PORTS-1:0][FLIT_W-1:0] out_flit,
    input logic [PORTS-1:0] out_valid,
    input logic [PORTS-1:0] out_ready
);

    // ------------------------------------------
    // Assertions for every output port
    // ------------------------------------------

    for (genvar p = 0; p < PORTS; p++) begin : GEN_ASSERT

        // A valid flit cannot disappear or change
        // while downstream ready is low.

        a_stable_during_stall:
            assert property (
                @(posedge clk)
                disable iff (!rst_n)

                (out_valid[p] && !out_ready[p])
                |=> (out_valid[p] &&
                     $stable(out_flit[p]))
            )
            else $fatal(
                1,
                "ASSERT: Output %0d changed during stall",
                p
            );

        // Count transfers for coverage/debugging.
        c_output_transfer:
            cover property (
                @(posedge clk)
                disable iff (!rst_n)

                out_valid[p] && out_ready[p]
            );

        // Cover header stalls.
        c_header_stall:
            cover property (
                @(posedge clk)
                disable iff (!rst_n)

                out_valid[p] &&
                !out_ready[p] &&
                out_flit[p][33]
            );

        // Cover tail stalls.
        c_tail_stall:
            cover property (
                @(posedge clk)
                disable iff (!rst_n)

                out_valid[p] &&
                !out_ready[p] &&
                out_flit[p][32]
            );

    end

endmodule
