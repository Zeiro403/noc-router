// Deterministic constrained pseudo-random router traffic.
// Every random value is bounded to a legal range. Independent per-port
// PRNG states make stimulus reproducible for a given +SEED.

localparam int RANDOM_PORTS = 5;
localparam int RANDOM_PKTS_PER_PORT = 20;
noc_packet random_packets[RANDOM_PORTS][RANDOM_PKTS_PER_PORT];

function automatic bit [31:0] random_step(input bit [31:0] x);
    bit [31:0] v;
    v = (x == 0) ? 32'h6D2B79F5 : x;
    v ^= v << 13;
    v ^= v >> 17;
    v ^= v << 5;
    return v;
endfunction

task automatic random_send_port(input int port);
    bit [31:0] rng;
    int gap_cycles;

    rng = random_step(32'(seed) ^ (32'h9E3779B9 * 32'(port + 1)));

    for (int n = 0; n < RANDOM_PKTS_PER_PORT; n++) begin
        rng = random_step(rng);
        gap_cycles = int'(rng % 4);
        repeat (gap_cycles) @(negedge clk);
        

        case (port)
            TB_NORTH: drv_north.send_packet(random_packets[port][n]);
            TB_SOUTH: drv_south.send_packet(random_packets[port][n]);
            TB_EAST:  drv_east.send_packet(random_packets[port][n]);
            TB_WEST:  drv_west.send_packet(random_packets[port][n]);
            TB_LOCAL: drv_local.send_packet(random_packets[port][n]);
            default: $fatal(1, "RANDOM: Invalid input port");
        endcase
    end
endtask

bit random_stalls_enable;

task automatic random_backpressure();
    bit [31:0] rng;
    int stall_count[RANDOM_PORTS];
    bit [RANDOM_PORTS-1:0] ready_mask;

    rng = random_step(32'(seed) ^ 32'hA341316C);
    for (int p = 0; p < RANDOM_PORTS; p++)
        stall_count[p] = 0;

    // All outputs are updated on falling edges, away from DUT sampling.
    // Force a ready cycle after at most 7 consecutive stalled cycles.
    while (random_stalls_enable) begin
        @(negedge clk);
        if (!random_stalls_enable) break;
        ready_mask = '0;
        for (int p = 0; p < RANDOM_PORTS; p++) begin
            rng = random_step(rng);
            if ((rng % 4) != 0 || stall_count[p] >= 7) begin
                ready_mask[p] = 1'b1;
                stall_count[p] = 0;
            end else begin
                ready_mask[p] = 1'b0;
                stall_count[p]++;
            end
        end
        out_north.ready = ready_mask[TB_NORTH];
        out_south.ready = ready_mask[TB_SOUTH];
        out_east.ready  = ready_mask[TB_EAST];
        out_west.ready  = ready_mask[TB_WEST];
        out_local.ready = ready_mask[TB_LOCAL];
    end
endtask

task automatic test_random();
    bit [31:0] rng;
    int dx;
    int dy;
    int len;
    int total;
    int seed_local;

    seed_local = seed;
    total = RANDOM_PORTS * RANDOM_PKTS_PER_PORT;
    $display("TEST random: seed=%0d packets=%0d", seed_local, total);

    // Generate ALL expected packets before starting any drivers.
    // Registration order for each input matches injection order.
    for (int p = 0; p < RANDOM_PORTS; p++) begin
        rng = random_step(32'(seed_local) ^ (32'h85EBCA6B * 32'(p + 1)));
        for (int n = 0; n < RANDOM_PKTS_PER_PORT; n++) begin
            rng = random_step(rng);
            dx = int'(rng % 3);
            rng = random_step(rng);
            dy = int'(rng % 3);
            rng = random_step(rng);
            // One header-only packet per input, otherwise 1..8 payload flits.
            len = (n == 0) ? 0 : 1 + int'(rng % 8);

            random_packets[p][n] = create_packet(
                4'(dx), 4'(dy), 4'(p % 3), 4'(p / 3), n, len
            );
            rng = random_step(rng);
            random_packets[p][n].pkt_type = 4'(rng % 4);

            // Unique signature in the first payload flit avoids ambiguity
            // when the 4-bit transaction ID wraps after 16 packets.
            if (len > 0) begin
                random_packets[p][n].payload[0] =
                    32'hC0000000 | (32'(p) << 16) | 32'(n);
                for (int j = 1; j < len; j++) begin
                    rng = random_step(rng);
                    random_packets[p][n].payload[j] = rng;
                end
            end

            // XY output selection for center router (1,1).
            if (dx > 1)
                scoreboard.expect_packet(random_packets[p][n], p, TB_EAST);
            else if (dx < 1)
                scoreboard.expect_packet(random_packets[p][n], p, TB_WEST);
            else if (dy > 1)
                scoreboard.expect_packet(random_packets[p][n], p, TB_NORTH);
            else if (dy < 1)
                scoreboard.expect_packet(random_packets[p][n], p, TB_SOUTH);
            else
                scoreboard.expect_packet(random_packets[p][n], p, TB_LOCAL);
        end
    end

    // Run the stall generator concurrently with the five packet drivers.
    random_stalls_enable = 1'b1;
    fork
        random_backpressure();
        begin
            fork
                random_send_port(TB_NORTH);
                random_send_port(TB_SOUTH);
                random_send_port(TB_EAST);
                random_send_port(TB_WEST);
                random_send_port(TB_LOCAL);
            join
            random_stalls_enable = 1'b0;
        end
    join

    // Restore ready signals on a falling edge.
    @(negedge clk);
    out_north.ready = 1'b1;
    out_south.ready = 1'b1;
    out_east.ready  = 1'b1;
    out_west.ready  = 1'b1;
    out_local.ready = 1'b1;

    wait_for_completion(2000);
    scoreboard.check_complete();
    if (scoreboard.matched_count != total)
        $fatal(1, "RANDOM: matched %0d, expected %0d", scoreboard.matched_count, total);
    $display("TEST random PASSED seed=%0d packets=%0d", seed_local, total);
endtask
