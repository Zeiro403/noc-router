`timescale 1ns/1ps
module crossbar #(
    parameter int NUM_PORTS = 5,
    parameter int FLIT_W    = 34
)(
    input  logic [NUM_PORTS-1:0][FLIT_W-1:0] in_flit,
    input  logic [NUM_PORTS-1:0]             in_valid,

    input  logic [NUM_PORTS-1:0][NUM_PORTS-1:0] select,

    output logic [NUM_PORTS-1:0][FLIT_W-1:0] out_flit,
    output logic [NUM_PORTS-1:0]             out_valid
);

    always_comb begin

        out_flit  = '0;
        out_valid = '0;

        for (int o = 0; o < NUM_PORTS; o++) begin

            for (int i = 0; i < NUM_PORTS; i++) begin

                if (select[o][i]) begin
                    out_flit[o]  = in_flit[i];
                    out_valid[o] = in_valid[i];
                end

            end
        end
    end

`ifndef SYNTHESIS
    always_comb begin
        for (int o = 0; o < NUM_PORTS; o++) begin
            assert ($onehot0(select[o]))
                else $error("Multiple inputs selected for output %0d", o);
        end

        for (int i = 0; i < NUM_PORTS; i++) begin
            int selected_count;

            selected_count = 0;

            for (int o = 0; o < NUM_PORTS; o++)
                selected_count += int'(select[o][i]);

            assert (selected_count <= 1)
                else $error("Input %0d selected by multiple outputs", i);
        end
    end
`endif

endmodule
