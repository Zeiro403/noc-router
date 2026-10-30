`timescale 1ns/1ps

module tb_xy_router;

    import noc_pkg::*;

    logic [3:0] dest_x;
    logic [3:0] dest_y;

    port_t output_port;

    xy_router #(
        .ROUTER_X(4'd1),
        .ROUTER_Y(4'd1)
    ) dut (
        .dest_x(dest_x),
        .dest_y(dest_y),
        .output_port(output_port)
    );

    task automatic check_route(
        input logic [3:0] x,
        input logic [3:0] y,
        input port_t expected
    );

        dest_x = x;
        dest_y = y;

        #1;

        if (output_port !== expected)
            $fatal(1,
                "Route failed: dest=(%0d,%0d), got=%0d, expected=%0d",
                x, y, output_port, expected
            );

        $display(
            "PASS: dest=(%0d,%0d), port=%s",
            x, y, expected.name()
        );

    endtask

    initial begin

        check_route(2, 1, EAST);
        check_route(0, 1, WEST);

        check_route(1, 2, NORTH);
        check_route(1, 0, SOUTH);

        check_route(1, 1, LOCAL);

        // X must take priority over Y.
        check_route(2, 2, EAST);
        check_route(0, 0, WEST);

        $display("ALL XY ROUTING TESTS PASSED");
        $finish;

    end

endmodule