module smart_blinkers (
    input clk,              // sys_clk (e.g. 81MHz)
    input phi2_safe,

    input [15:0] a_stable,
    input is_pokey,
    input is_2200,

    input rw_safe,
    input buf_oe,
    input buf_dir,

    input psram_busy,
    input psram_rd_req,

    input pll_lock,
    input game_loaded,
    input write_pending,

    output [5:0] led
);

    // ========================================================================
    // DEBUG (Smart Visualizer - Atari Active Gated)
    // ========================================================================
    // PHI2 Activity Detector: Only enable LED triggers when Atari is running.
    
    reg phi2_prev;
    reg atari_active;
    reg [22:0] activity_timer;
    
    localparam ACTIVITY_TIMEOUT = 23'h330000; // ~50ms at 67.5MHz-81MHz
    
    always @(posedge clk) begin
        phi2_prev <= phi2_safe;
        
        // Detect PHI2 edge (rising or falling)
        if (phi2_safe != phi2_prev) begin
            atari_active <= 1;
            activity_timer <= ACTIVITY_TIMEOUT;
        end else if (activity_timer > 0) begin
            activity_timer <= activity_timer - 1;
        end else begin
            atari_active <= 0;
        end
    end
    
    // Smart Blinker Logic (Gated by atari_active)
    reg [22:0] timer_a15;   reg state_a15;
    reg [22:0] timer_pokey; reg state_pokey;
    reg [22:0] timer_rw;    reg state_rw;
    reg [22:0] timer_oe;    reg state_oe;
    reg [22:0] timer_2200;  reg state_2200;  // $2200 detector
    
    reg [24:0] heartbeat;

    localparam BLINK_DUR = 23'h4D0000; // ~75ms at 67.5MHz-81MHz

    always @(posedge clk) begin
        heartbeat <= heartbeat + 1;

        // --- A15 Smart Blinker ---
        if (state_a15) begin
            if (timer_a15 == 0) begin
                state_a15 <= 0;
                timer_a15 <= BLINK_DUR;
            end else timer_a15 <= timer_a15 - 1;
        end else begin
            if (timer_a15 > 0) timer_a15 <= timer_a15 - 1;
            else if (atari_active && !a_stable[15]) begin // GATED
                state_a15 <= 1;
                timer_a15 <= BLINK_DUR;
            end
        end

        // --- POKEY Smart Blinker ---
        if (state_pokey) begin
            if (timer_pokey == 0) begin
                state_pokey <= 0;
                timer_pokey <= BLINK_DUR;
            end else timer_pokey <= timer_pokey - 1;
        end else begin
            if (timer_pokey > 0) timer_pokey <= timer_pokey - 1;
            else if (atari_active && is_pokey) begin // GATED
                state_pokey <= 1;
                timer_pokey <= BLINK_DUR;
            end
        end

        // --- RW Smart Blinker ---
        if (state_rw) begin
            if (timer_rw == 0) begin
                state_rw <= 0;
                timer_rw <= BLINK_DUR;
            end else timer_rw <= timer_rw - 1;
        end else begin
            if (timer_rw > 0) timer_rw <= timer_rw - 1;
            else if (atari_active && !rw_safe) begin // GATED
                state_rw <= 1;
                timer_rw <= BLINK_DUR;
            end
        end

        // --- OE Smart Blinker ---
        if (state_oe) begin
            if (timer_oe == 0) begin
                state_oe <= 0;
                timer_oe <= BLINK_DUR;
            end else timer_oe <= timer_oe - 1;
        end else begin
            if (timer_oe > 0) timer_oe <= timer_oe - 1;
            else if (atari_active && !buf_oe) begin // GATED
                state_oe <= 1;
                timer_oe <= BLINK_DUR;
            end
        end
        
        // --- $2200 Smart Blinker (Menu Control) ---
        if (state_2200) begin
            if (timer_2200 == 0) begin
                state_2200 <= 0;
                timer_2200 <= BLINK_DUR;
            end else timer_2200 <= timer_2200 - 1;
        end else begin
            if (timer_2200 > 0) timer_2200 <= timer_2200 - 1;
            else if (atari_active && is_2200 && !rw_safe) begin // GATED - Write to $2200
                state_2200 <= 1;
                timer_2200 <= BLINK_DUR;
            end
        end
    end
    
    // --- Direction / Drive Blinker Logic ---
    reg state_dir;
    reg [22:0] timer_dir;
    
    // Blink when we switch to Output Mode (DIR=1)
    always @(posedge clk) begin
        if (state_dir) begin
             if (timer_dir == 0) begin
                 state_dir <= 0;
                 timer_dir <= BLINK_DUR;
             end else timer_dir <= timer_dir - 1;
        end else begin
             if (timer_dir > 0) timer_dir <= timer_dir - 1;
             else if (buf_dir == 1'b1) begin // Trigger on OUTPUT direction
                 state_dir <= 1;
                 timer_dir <= BLINK_DUR;
             end
        end
    end

    // --- PSRAM Read Blinker Logic ---
    reg state_read;
    reg [22:0] timer_read;
    
    // Blink when Data is Valid (Read Complete)
    always @(posedge clk) begin
        if (state_read) begin
             if (timer_read == 0) begin
                 state_read <= 0;
                 timer_read <= BLINK_DUR;
             end else timer_read <= timer_read - 1;
        end else begin
             if (timer_read > 0) timer_read <= timer_read - 1;
             else if (!psram_busy && psram_rd_req) begin // Trigger on Read Data Valid
                 state_read <= 1;
                 timer_read <= BLINK_DUR;
             end
        end
    end

    // LED Assignments (Full Loader Mode)
    // Active LOW LEDs. 
    assign led[0] = !pll_lock;      // ON when Locked
    assign led[1] = game_loaded;    // ON when Game Mode
    assign led[2] = !phi2_safe;     // ON when PHI2 activity
    assign led[3] = !state_dir;     // ON when Driving Bus (Output Mode)
    assign led[4] = write_pending;  // ON when Write active
    assign led[5] = !state_2200;    // ON when Reading (Active Low)

endmodule
