`timescale 1ns/1ps

module tb_crossbar;

    localparam int NUM_PORTS = 5;
    localparam int FLIT_W = 34;

    logic [NUM_PORTS-1:0][FLIT_W-1:0] in_flit;
    logic [NUM_PORTS-1:0] in_valid;

    logic [NUM_PORTS-1:0][NUM_PORTS-1:0] select;

    logic [NUM_PORTS-1:0][FLIT_W-1:0] out_flit;
    logic [NUM_PORTS-1:0] out_valid;

    crossbar #(
        .NUM_PORTS(NUM_PORTS),
        .FLIT_W(FLIT_W)
    ) dut (
        .in_flit,
        .in_valid,
        .select,
        .out_flit,
        .out_valid
    );

    initial begin

        in_flit  = '0;
        in_valid = '1;
        select   = '0;

        for (int i = 0; i < NUM_PORTS; i++)
            in_flit[i] = FLIT_W'(100 + i);

        // North input -> East output
        select[2][0] = 1'b1;

        #1;

        if (out_flit[2] !== FLIT_W'(100))
            $fatal(1, "North -> East transfer failed");

        if (out_valid[2] !== 1'b1)
            $fatal(1, "East output should be valid");

        // Change connection: West input -> North output
        select = '0;
        select[0][3] = 1'b1;

        #1;

        if (out_flit[0] !== FLIT_W'(103))
            $fatal(1, "West -> North transfer failed");

        // Multiple independent transfers
        select = '0;

        select[0][3] = 1'b1; // West -> North
        select[1][4] = 1'b1; // Local -> South
        select[2][0] = 1'b1; // North -> East

        #1;

        if (out_flit[0] !== FLIT_W'(103) ||
            out_flit[1] !== FLIT_W'(104) ||
            out_flit[2] !== FLIT_W'(100))
            $fatal(1, "Multiple transfers failed");

        $display("ALL CROSSBAR TESTS PASSED");
        $finish;

    end

endmodule
