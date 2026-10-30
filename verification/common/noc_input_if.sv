`timescale 1ns/1ps
interface noc_input_if #(
    parameter int FLIT_W = 34
)(
    input logic clk
);

    logic rst_n;

    logic [FLIT_W-1:0] flit;
    logic valid;
    logic ready;

    // Driver drives flit and valid.
    // Router drives ready.

    modport dut (
        input  clk,
        input  rst_n,
        input  flit,
        input  valid,
        output ready
    );

    modport tb (
        input  clk,
        input  rst_n,
        input  ready,
        output flit,
        output valid
    );

endinterface
