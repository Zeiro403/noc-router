`timescale 1ns/1ps
interface noc_output_if #(
    parameter int FLIT_W = 34
)(
    input logic clk
);

    logic rst_n;

    logic [FLIT_W-1:0] flit;
    logic valid;
    logic ready;

    modport dut (
        input  clk,
        input  rst_n,
        input  ready,
        output flit,
        output valid
    );

    modport mon (
        input clk,
        input rst_n,
        input flit,
        input valid,
        input ready
    );

endinterface
