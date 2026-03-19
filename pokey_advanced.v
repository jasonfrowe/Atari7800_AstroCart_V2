module pokey_advanced (
    input clk,              // 27MHz System Clock
    input enable_179mhz,    // 1.79MHz Tick Enable (Main heartbeat)
    input reset_n,          // Active Low Reset
    
    // Bus Interface
    input [3:0] addr,       // Register Address (0-F)
    input [7:0] din,        // Data Input (Write)
    input we,               // Write Enable
    
    // Audio Output
    output reg audio_pwm    // 1-bit PWM Audio
);

    // ========================================================================
    // 1. REGISTERS
    // ========================================================================
    reg [7:0] audf [0:3]; // Frequencies
    reg [7:0] audc [0:3]; // Control (Vol + Dist)
    reg [7:0] audctl;     // Control
    
    // Poly Counters
    reg [3:0]  poly4 = 4'b1011;
    reg [4:0]  poly5 = 5'b10101;
    reg [16:0] poly17 = 17'b10101010101010101; 
    
    reg [15:0] counter [0:3]; 
    reg [3:0]  chan_out;    

    // ========================================================================
    // 2. CLOCK DIVIDERS (The Missing Link)
    // ========================================================================
    // POKEY defaults to 64kHz (1.79MHz / 28).
    // It can also do 15kHz (1.79MHz / 114).
    
    reg [4:0] count_64k;   // Count to 28
    reg [6:0] count_15k;   // Count to 114
    
    reg tick_64khz;
    reg tick_15khz;

    always @(posedge clk) begin
        tick_64khz <= 0;
        tick_15khz <= 0;
        
        if (enable_179mhz) begin
            // Generate 64kHz Pulse
            if (count_64k == 27) begin // 0..27 = 28 ticks
                count_64k <= 0;
                tick_64khz <= 1;
            end else begin
                count_64k <= count_64k + 1;
            end

            // Generate 15kHz Pulse
            if (count_15k == 113) begin // 0..113 = 114 ticks
                count_15k <= 0;
                tick_15khz <= 1;
            end else begin
                count_15k <= count_15k + 1;
            end
        end
    end

    // ========================================================================
    // 3. WRITE LOGIC
    // ========================================================================
    always @(posedge clk) begin
        if (!reset_n) begin
            audctl <= 0;
            audc[0]<=0; audc[1]<=0; audc[2]<=0; audc[3]<=0;
            audf[0]<=0; audf[1]<=0; audf[2]<=0; audf[3]<=0;
        end else if (we) begin
            case (addr)
                0: audf[0] <= din;
                1: audc[0] <= din;
                2: audf[1] <= din;
                3: audc[1] <= din;
                4: audf[2] <= din;
                5: audc[2] <= din;
                6: audf[3] <= din;
                7: audc[3] <= din;
                8: audctl <= din;
            endcase
        end
    end

    // ========================================================================
    // 4. POLY NOISE GENERATORS (Run at 1.79MHz always)
    // ========================================================================
    wire p4_next = !(poly4[3] ^ poly4[2]);
    wire p5_next = !(poly5[4] ^ poly5[2]);
    wire p17_next = !(poly17[16] ^ poly17[4]);
    
    always @(posedge clk) begin
        if (enable_179mhz) begin
            poly4 <= {poly4[2:0], p4_next};
            poly5 <= {poly5[3:0], p5_next};
            poly17 <= {poly17[15:0], p17_next};
        end
    end

    // ========================================================================
    // 5. CHANNEL TIMING
    // ========================================================================
    
    wire link_12 = audctl[4];
    wire link_34 = audctl[3];
    wire use_15khz = audctl[0]; // 1 = Use 15kHz instead of 64kHz

    integer i;
    reg channel_tick; // Variable to determine if this specific channel should step

    always @(posedge clk) begin
        // We evaluate every clock cycle, but only act if the RIGHT tick happens
        for (i=0; i<4; i=i+1) begin
            
            // --- SELECT CLOCK SOURCE ---
            // Default: 64kHz (or 15kHz if Bit 0 set)
            // Override: Ch 1 & 3 can run at 1.79MHz if Bit 6/5 set.
            channel_tick = (use_15khz) ? tick_15khz : tick_64khz;

            if (i == 0 && audctl[6]) channel_tick = enable_179mhz;
            if (i == 2 && audctl[5]) channel_tick = enable_179mhz;
            
            // --- CHANNEL UPDATE LOGIC ---
            if (channel_tick) begin
                
                // If Linked Slave (High Byte), do nothing
                if (!((i==1 && link_12) || (i==3 && link_34))) begin
                    
                    if (counter[i] == 0) begin
                        // 1. RELOAD
                        if (i==0 && link_12) 
                            counter[i] <= {audf[1], audf[0]}; 
                        else if (i==2 && link_34) 
                            counter[i] <= {audf[3], audf[2]}; 
                        else 
                            counter[i] <= audf[i];

                        // 2. OUTPUT
                        case (audc[i][7:5])
                            3'b000: chan_out[i] <= poly17[16] && poly5[4]; // Gritty
                            3'b001: chan_out[i] <= poly5[4];               // Metallic
                            3'b010: chan_out[i] <= poly17[16] && poly5[4]; 
                            3'b011: chan_out[i] <= poly5[4];               
                            3'b100: chan_out[i] <= poly17[16];             // White Noise
                            3'b101: chan_out[i] <= ~chan_out[i];           // Pure Tone
                            3'b110: chan_out[i] <= poly17[16];             
                            3'b111: chan_out[i] <= ~chan_out[i];           // Pure Tone
                        endcase

                    end else begin
                        counter[i] <= counter[i] - 1;
                    end
                end
            end
        end
    end

    // ========================================================================
    // 6. MIXER & PWM
    // ========================================================================
    reg [5:0] mixed_audio; 
    integer k;

    always @(*) begin
        mixed_audio = 0;
        for (k=0; k<4; k=k+1) begin
            if (chan_out[k]) begin
                mixed_audio = mixed_audio + audc[k][3:0];
            end
        end
    end

    reg [5:0] pwm_counter = 0;
    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 1;
        audio_pwm <= (pwm_counter < mixed_audio);
    end

endmodule