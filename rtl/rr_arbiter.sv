`timescale 1ns/1ps
module rr_arbiter #(
    parameter int NUM_REQ = 5
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [NUM_REQ-1:0] request,
    input  logic               advance,

    output logic [NUM_REQ-1:0] grant,
    output logic               grant_valid
);

    localparam int PTR_W =
        (NUM_REQ > 1) ? $clog2(NUM_REQ) : 1;

    logic [PTR_W-1:0] priority_ptr;
    logic [PTR_W-1:0] next_priority;

    integer idx;

    always_comb begin
        grant = '0;
        grant_valid = 1'b0;
        next_priority = priority_ptr;

        for (int i = 0; i < NUM_REQ; i++) begin

            idx = int'(priority_ptr) + i;

            if (idx >= NUM_REQ)
                idx = idx - NUM_REQ;

            if (!grant_valid && request[idx]) begin
                grant[idx] = 1'b1;
                grant_valid = 1'b1;

                if (idx == NUM_REQ-1)
                    next_priority = '0;
                else
                    next_priority = PTR_W'(idx + 1);
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            priority_ptr <= '0;

        else if (advance && grant_valid)
            priority_ptr <= next_priority;
    end

endmodule
