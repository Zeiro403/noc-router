`timescale 1ns/1ps

module tb_rr_arbiter;

    logic clk;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    logic rst_n;
    logic [4:0] request;
    logic advance;

    logic [4:0] grant;
    logic grant_valid;

    rr_arbiter #(
        .NUM_REQ(5)
    ) dut (
        .clk,
        .rst_n,
        .request,
        .advance,
        .grant,
        .grant_valid
    );

    task automatic check(
        input logic [4:0] expected
    );
        #1;

        if (grant !== expected)
            $fatal(1,
                "Grant mismatch: got %b expected %b",
                grant, expected
            );
    endtask

    task automatic accept_grant;
        @(negedge clk);
        advance = 1'b1;

        @(negedge clk);
        advance = 1'b0;
    endtask

    initial begin
        rst_n = 0;
        request = '0;
        advance = 0;

        repeat (3) @(negedge clk);
        rst_n = 1;

        // All five request simultaneously.
        request = 5'b11111;

        check(5'b00001);
        accept_grant();

        check(5'b00010);
        accept_grant();

        check(5'b00100);
        accept_grant();

        check(5'b01000);
        accept_grant();

        check(5'b10000);
        accept_grant();

        // Priority wraps around.
        check(5'b00001);

        // No request means no grant.
        request = 5'b00000;
        check(5'b00000);

        if (grant_valid !== 0)
            $fatal(1, "grant_valid should be zero");

        // Only West requests.
        request = 5'b01000;
        check(5'b01000);

        // Grant must remain stable without advance.
        repeat (3) @(negedge clk);
        check(5'b01000);

        $display("ALL ROUND-ROBIN TESTS PASSED");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Testbench timeout");
    end

endmodule
