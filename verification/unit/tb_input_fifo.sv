`timescale 1ns/1ps

module tb_input_fifo;

    logic clk = 0;
    always #5 clk = ~clk;

    logic rst_n;

    logic [33:0] in_data;
    logic in_valid;
    logic in_ready;

    logic [33:0] out_data;
    logic out_valid;
    logic out_ready;

    input_fifo #(
        .WIDTH(34),
        .DEPTH(4)
    ) dut (
        .clk,
        .rst_n,
        .in_data,
        .in_valid,
        .in_ready,
        .out_data,
        .out_valid,
        .out_ready
    );

    task automatic push(input logic [33:0] data);
        @(negedge clk);
        in_data  = data;
        in_valid = 1;

        do @(posedge clk);
        while (!in_ready);

        @(negedge clk);
        in_valid = 0;
    endtask

    task automatic pop(input logic [33:0] expected);
        @(negedge clk);
        out_ready = 1;

        do @(posedge clk);
        while (!out_valid);

        if (out_data !== expected)
            $fatal(1, "FIFO mismatch: got %h expected %h",
                   out_data, expected);

        @(negedge clk);
        out_ready = 0;
    endtask

    initial begin
        rst_n     = 0;
        in_valid  = 0;
        out_ready = 0;
        in_data   = '0;

        repeat (3) @(negedge clk);
        rst_n = 1;

        push(34'h000000001);
        push(34'h000000002);
        push(34'h000000003);
        push(34'h000000004);

        if (in_ready !== 0)
            $fatal(1, "FIFO should be full");

        pop(34'h000000001);
        pop(34'h000000002);

        push(34'h000000005);
        push(34'h000000006);

        pop(34'h000000003);
        pop(34'h000000004);
        pop(34'h000000005);
        pop(34'h000000006);

        if (out_valid !== 0)
            $fatal(1, "FIFO should be empty");

        $display("FIFO BASIC TEST PASSED");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end

endmodule