`timescale 1ns/1ps

package noc_pkg;

    parameter int FLIT_WIDTH = 32;
    // parameter int NUM_PORTS  = 5;

    typedef struct packed {
        logic                  sop;
        logic                  eop;
        logic [FLIT_WIDTH-1:0] data;
    } flit_t;

    typedef enum logic [2:0] {
        NORTH = 3'd0,
        SOUTH = 3'd1,
        EAST  = 3'd2,
        WEST  = 3'd3,
        LOCAL = 3'd4
    } port_t;

endpackage
