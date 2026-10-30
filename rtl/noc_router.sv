`timescale 1ns/1ps
module noc_router #(
    parameter logic [3:0] ROUTER_X = 4'd1,
    parameter logic [3:0] ROUTER_Y = 4'd1,
    parameter int FIFO_DEPTH = 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [4:0][33:0] in_flit,
    input  logic [4:0]       in_valid,
    output logic [4:0]       in_ready,

    output logic [4:0][33:0] out_flit,
    output logic [4:0]       out_valid,
    input  logic [4:0]       out_ready
);

    import noc_pkg::*;

    localparam int PORTS  = 5;
    localparam int FLIT_W = 34;
    localparam int PORT_W = $clog2(PORTS);

    // Flit format:
    // [33]    SOP
    // [32]    EOP
    // [31:0]  Data

    localparam int SOP_BIT = 33;
    localparam int EOP_BIT = 32;

    // --------------------------------------------------
    // Output controller states
    // --------------------------------------------------

    typedef enum logic [1:0] {
        IDLE,
        PENDING,
        ACTIVE
    } output_state_t;

    output_state_t state [PORTS];

    // --------------------------------------------------
    // Input FIFO signals
    // --------------------------------------------------

    logic [PORTS-1:0][FLIT_W-1:0] fifo_data;
    logic [PORTS-1:0] fifo_valid;
    logic [PORTS-1:0] fifo_pop;

    // --------------------------------------------------
    // Routing signals
    // --------------------------------------------------

    port_t route [PORTS];

    // --------------------------------------------------
    // Arbitration signals
    // --------------------------------------------------

    logic [PORTS-1:0][PORTS-1:0] request;
    logic [PORTS-1:0][PORTS-1:0] grant;

    logic [PORTS-1:0] grant_valid;
    logic [PORTS-1:0] arb_advance;

    // --------------------------------------------------
    // Packet ownership
    // --------------------------------------------------

    logic [PORTS-1:0][PORT_W-1:0] owner;
    logic [PORTS-1:0] input_reserved;

    // --------------------------------------------------
    // Crossbar and transfer signals
    // --------------------------------------------------

    logic [PORTS-1:0][PORTS-1:0] select;
    logic [PORTS-1:0] transfer;

    // ==================================================
    // 1. Input FIFOs
    // ==================================================

    for (genvar i = 0; i < PORTS; i++) begin : GEN_FIFO

        input_fifo #(
            .WIDTH(FLIT_W),
            .DEPTH(FIFO_DEPTH)
        ) fifo_inst (
            .clk       (clk),
            .rst_n     (rst_n),

            .in_data   (in_flit[i]),
            .in_valid  (in_valid[i]),
            .in_ready  (in_ready[i]),

            .out_data  (fifo_data[i]),
            .out_valid (fifo_valid[i]),
            .out_ready (fifo_pop[i])
        );

    end

    // ==================================================
    // 2. XY Routing Units
    // ==================================================

    for (genvar i = 0; i < PORTS; i++) begin : GEN_ROUTE

        xy_router #(
            .ROUTER_X(ROUTER_X),
            .ROUTER_Y(ROUTER_Y)
        ) route_inst (
            .dest_x      (fifo_data[i][27:24]),
            .dest_y      (fifo_data[i][23:20]),
            .output_port (route[i])
        );

    end

    // ==================================================
    // 3. Determine Reserved Inputs
    // ==================================================

    always_comb begin

        input_reserved = '0;

        for (int o = 0; o < PORTS; o++) begin

            if (state[o] != IDLE)
                input_reserved[owner[o]] = 1'b1;

        end

    end

    // ==================================================
    // 4. Generate Arbitration Requests
    // ==================================================

    always_comb begin

        request = '0;

        for (int i = 0; i < PORTS; i++) begin

            // Only an unreserved input with a valid
            // header can request an output.

            if (fifo_valid[i] &&
                fifo_data[i][SOP_BIT] &&
                !input_reserved[i]) begin

                for (int o = 0; o < PORTS; o++) begin

                    if ((state[o] == IDLE) &&
                        (int'(route[i]) == o)) begin

                        request[o][i] = 1'b1;

                    end

                end

            end

        end

    end

    // ==================================================
    // 5. Round-Robin Output Arbiters
    // ==================================================

    for (genvar o = 0; o < PORTS; o++) begin : GEN_ARB

        rr_arbiter #(
            .NUM_REQ(PORTS)
        ) arb_inst (
            .clk         (clk),
            .rst_n       (rst_n),

            .request     (request[o]),
            .advance     (arb_advance[o]),

            .grant       (grant[o]),
            .grant_valid (grant_valid[o])
        );

    end

    // ==================================================
    // 6. Advance Arbitration on Allocation
    // ==================================================

    always_comb begin

        arb_advance = '0;

        for (int o = 0; o < PORTS; o++) begin

            if ((state[o] == IDLE) && grant_valid[o])
                arb_advance[o] = 1'b1;

        end

    end

    // ==================================================
    // 7. Crossbar Selection
    // ==================================================

    always_comb begin

        select = '0;

        for (int o = 0; o < PORTS; o++) begin

            // Only registered owners can use the
            // crossbar. New grants are registered first.

            if (state[o] != IDLE)
                select[o][owner[o]] = 1'b1;

        end

    end

    // ==================================================
    // 8. Crossbar
    // ==================================================

    crossbar #(
        .NUM_PORTS(PORTS),
        .FLIT_W(FLIT_W)
    ) xbar_inst (
        .in_flit   (fifo_data),
        .in_valid  (fifo_valid),

        .select    (select),

        .out_flit  (out_flit),
        .out_valid (out_valid)
    );

    // ==================================================
    // 9. Output Transfers and FIFO Pops
    // ==================================================

    always_comb begin

        fifo_pop = '0;
        transfer = '0;

        for (int o = 0; o < PORTS; o++) begin

            transfer[o] = out_valid[o] && out_ready[o];

            if ((state[o] != IDLE) && transfer[o]) begin

                fifo_pop[owner[o]] = 1'b1;

            end

        end

    end

    // ==================================================
    // 10. Packet Ownership State Machines
    // ==================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            for (int o = 0; o < PORTS; o++) begin

                state[o] <= IDLE;
                owner[o] <= '0;

            end

        end
        else begin

            for (int o = 0; o < PORTS; o++) begin

                case (state[o])

                    // ------------------------------
                    // IDLE: Wait for a new packet
                    // ------------------------------

                    IDLE: begin

                        if (grant_valid[o]) begin

                            for (int i = 0; i < PORTS; i++) begin

                                if (grant[o][i]) begin

                                    owner[o] <= PORT_W'(i);
                                    state[o] <= PENDING;

                                end

                            end

                        end

                    end

                    // ------------------------------
                    // PENDING: Wait for header transfer
                    // ------------------------------

                    PENDING: begin

                        if (transfer[o]) begin

                            // Single-flit packet:
                            // SOP and EOP together.

                            if (fifo_data[owner[o]][EOP_BIT])
                                state[o] <= IDLE;

                            else
                                state[o] <= ACTIVE;

                        end

                    end

                    // ------------------------------
                    // ACTIVE: Forward remaining flits
                    // ------------------------------

                    ACTIVE: begin

                        // Keep ownership during stalls
                        // and intermediate body flits.

                        if (transfer[o] &&
                            fifo_data[owner[o]][EOP_BIT]) begin

                            state[o] <= IDLE;

                        end

                    end

                    default: begin

                        state[o] <= IDLE;

                    end

                endcase

            end

        end

    end

endmodule
