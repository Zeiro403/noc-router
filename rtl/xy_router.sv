`timescale 1ns/1ps
module xy_router #(
    parameter logic [3:0] ROUTER_X = 4'd1,
    parameter logic [3:0] ROUTER_Y = 4'd1
)(
    input  logic [3:0] dest_x,
    input  logic [3:0] dest_y,

    output noc_pkg::port_t output_port
);

    import noc_pkg::*;

    always_comb begin

        if (dest_x > ROUTER_X)
            output_port = EAST;

        else if (dest_x < ROUTER_X)
            output_port = WEST;

        else if (dest_y > ROUTER_Y)
            output_port = NORTH;

        else if (dest_y < ROUTER_Y)
            output_port = SOUTH;

        else
            output_port = LOCAL;

    end

endmodule
