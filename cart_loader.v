module cart_loader (
    input clk_sys,        // 81MHz system clock
    input clk_sd,         // 40.5MHz SD clock
    input reset,          // Active high reset (from PLL !lock)
    
    // Atari CPU interface
    input [15:0] a_stable,
    input [7:0]  d,
    input        rw_safe,
    input        phi2_safe,
    input        trigger_we,
    
    // SD Card physical interface
    output       sd_cs,
    output       sd_mosi,
    input        sd_miso,
    output       sd_clk,
    
    // PSRAM write interface (reads handled by top.v directly)
    input        psram_busy,
    output reg   psram_wr_req,
    output reg [22:0] psram_write_addr_latched,
    output reg [15:0] acc_word0,
    
    // Status outputs
    output reg   game_loaded,
    output reg   switch_pending,
    output reg [3:0] sd_state,
    output reg   busy,
    output reg   write_pending,
    
    // BRAM Write Interface (title scan -> menu RAM)
    output reg bram_we,
    output reg [15:0] bram_addr,
    output reg [7:0] bram_data,

    // Cart configuration (from header)
    output reg [31:0] cart_rom_size,
    output reg cart_has_pokey,
    output reg [15:0] cart_pokey_addr,
    output reg [3:0]  cart_mapper,      // 0=standard, 1=SuperGame
    output reg        cart_ram_at_4000, // 1=16KB BRAM mapped at $4000-$7FFF
    output reg [3:0]  cart_sgm_fixed_bank // last ROM bank index (registered)
);

    // SD Controller signals
    wire sd_ready;
    wire [7:0] sd_dout;
    wire sd_byte_available;
    wire [4:0] sd_status;
    
    reg sd_rd;
    reg [31:0] sd_address;
    wire sd_sclk_internal;

    sd_controller sd_ctrl (
        .cs(sd_cs),
        .mosi(sd_mosi),
        .miso(sd_miso),
        .sclk(sd_sclk_internal),
        .rd(sd_rd),
        .dout(sd_dout),
        .byte_available(sd_byte_available),
        .wr(1'b0),
        .din(8'h00),
        .ready_for_next_byte(),
        .reset(reset),
        .ready(sd_ready),
        .address(sd_address),
        .clk(clk_sd),
        .status(sd_status),
        .recv_data()
    );
    assign sd_clk = sd_sclk_internal;

    // -----------------------------------------------------------------------
    // 2-FF synchronizers: 40.5MHz SD domain → 81MHz clk_sys domain
    //
    // sd_ready = (state == IDLE) is COMBINATIONAL in sd_controller.v.
    // During SD state transitions, it can glitch high for nanoseconds.
    // At 81MHz (2× the SD clock), these glitches are wide enough to be
    // captured as valid pulses, triggering the "Abort on read error" path
    // in SD_WAIT/SD_SCAN_WAIT and cutting sector reads short → partial
    // PSRAM load → game crash.  This explains intermittent load failures
    // that disappear after an FPGA reprogram (fresh SD init).
    //
    // sd_byte_available is registered in sd_controller but still crosses
    // a clock domain; synchronize it too for metastability safety.
    // 2 FFs give 1/MTBF rate far below one failure per million years at 81MHz.
    // -----------------------------------------------------------------------
    reg sd_ready_r1, sd_ready_s;    // synchronized sd_ready
    reg sd_ba_r1,    sd_ba_s;       // synchronized sd_byte_available
    always @(posedge clk_sys) begin
        sd_ready_r1 <= sd_ready;
        sd_ready_s  <= sd_ready_r1;
        sd_ba_r1    <= sd_byte_available;
        sd_ba_s     <= sd_ba_r1;
    end

    // Simplified Sequential Loader
    localparam SD_IDLE       = 0;
    localparam SD_START      = 1;
    localparam SD_WAIT       = 2;
    localparam SD_DATA       = 3;
    localparam SD_NEXT       = 4;
    localparam SD_COMPLETE   = 5;
    localparam SD_DRAIN      = 9; // Wait for last PSRAM write to commit
    
    localparam SD_SCAN_START = 10;
    localparam SD_SCAN_WAIT  = 11;
    localparam SD_SCAN_DATA  = 12;
    localparam SD_SCAN_NEXT  = 13;

    // Internal tracking registers
    reg [9:0] current_sector;
    reg [9:0] byte_index;

    reg [7:0] sd_dout_reg;
    reg [22:0] psram_load_addr;
    reg [7:0] d_latched;
    
    // Address-based data capture logic
    reg trigger_we_prev;
    reg trigger_eval;
    reg trigger_lock_active;
    reg [7:0] drain_timer;
    reg [7:0] d_pipe [0:2];
    
    reg [4:0] scan_game_idx; // Scan up to 32 games

    // Header capture registers
    reg [7:0] h0;                 // Byte  0: version (4 = V4+ extended header)
    reg [7:0] h49, h50, h51, h52; // Bytes 49-52: ROM size
    reg [7:0] h53, h54;           // Bytes 53-54: flags (standard games)
    reg [7:0] h64, h65, h67;      // Bytes 64, 65, 67: V4+ mapper, opts, audio

    // How many SD sectors to load (header sector 0 + N data sectors).
    // Standard 48KB game: 512 (sectors 0-511, 511 data sectors covers 261KB > 48KB fine).
    // V4+ 256KB game:     513 (sectors 0-512, 512 data sectors = exactly 262144 bytes).
    reg [9:0] sector_limit;

    wire [31:0] size_be_wire = {h49, h50, h51, h52}; // Always BE per .a78 spec

    always @(posedge clk_sys) begin
        if (reset) begin
             sd_state <= SD_SCAN_START; // Start by scanning headers
             sd_rd <= 0;
             sd_address <= 1;
             byte_index <= 0;
             game_loaded <= 0;
             switch_pending <= 0;
             psram_wr_req <= 0;
             acc_word0 <= 0;
             write_pending <= 0;
             busy <= 1; // Busy during initial scan
             
             trigger_we_prev <= 0;
             trigger_eval <= 0;
             trigger_lock_active <= 0;
             
             current_sector <= 0;
             psram_load_addr <= 23'h000000;
             sd_dout_reg <= 0;
             drain_timer <= 0;
             
             scan_game_idx <= 0;
             bram_we <= 0;
             bram_addr <= 0;
             bram_data <= 0;

             cart_rom_size <= 49152;
             cart_has_pokey <= 1;
             cart_pokey_addr <= 16'h0450;
             cart_mapper <= 4'd0;
             cart_ram_at_4000 <= 0;
             cart_sgm_fixed_bank <= 4'd15; // default: bank 15 (256KB)
             sector_limit <= 10'd96;      // will be overwritten in SD_NEXT
        end else begin
             trigger_we_prev <= trigger_we;
             
             if (psram_wr_req) begin
                  psram_wr_req <= 0;
              end else if (write_pending && !psram_busy) begin
                   // [FIX] Gate writes when game loaded to prevent corruption
                   if (!game_loaded) psram_wr_req <= 1;
                   write_pending <= 0;
              end
             
              // Keep a history of the unsynchronized data bus 'd'
              // This is critical because trigger_we is built from a_stable and rw_safe,
              // which are delayed by top.v synchronizers (~3 cycles). 
              // By the time trigger_we evaluates or falls, the live 'd' bus has already changed
              // to the 6502's next instruction cycle!
              d_pipe[0] <= d;
              d_pipe[1] <= d_pipe[0];
              d_pipe[2] <= d_pipe[1];
              
              // Only evaluate the trigger command once the write pulse ENDS,
              // but grab the data from back in time when it was actually stable on the bus!
              if (trigger_we_prev && !trigger_we) begin
                  // Using d_pipe[2] grabs the data from exactly 3 sys_clk ticks ago (~37ns),
                  // properly aligning with the end of the delayed write cycle.
                  d_latched <= d_pipe[2];
                  trigger_eval <= 1;
              end else begin
                  trigger_eval <= 0;
              end
             
            case (sd_state)
                // --- NORMAL OPERATION ---
                SD_IDLE: begin
                    // TRIGGER: Only latch command when the SD controller is initialized and ready.
                    // Act purely on the transition edge of the write cycle to ignore noisy intermediate states.
                    if (trigger_eval && sd_ready_s) begin
                        
                        if (!game_loaded && (d_latched >= 8'h80 && d_latched <= 8'h8F)) begin
                            // The payload is the game index
                            // current_sector maps to Start_Block = 1 + (game_idx * 1024)
                            sd_address <= 1 + ((d_latched & 8'h7F) * 1024); 
                            current_sector <= 0;
                            
                            sd_state <= SD_START;
                            busy <= 1;
                            psram_load_addr <= 0;
                            
                            cart_rom_size <= 49152;
                            cart_has_pokey <= 1;
                            cart_pokey_addr <= 16'h0450;
                            cart_mapper <= 4'd0;
                            cart_ram_at_4000 <= 0;
                            sector_limit <= 10'd512;
                        end
                        else if (d_latched == 8'h5A) begin
                             // RELOAD: Magic Key 0x5A
                             sd_address <= 1;
                             sd_state <= SD_START;
                             current_sector <= 0;
                             psram_load_addr <= 23'h000000;
                             busy <= 1;
                             game_loaded <= 0;
                             switch_pending <= 0;
                        end
                        else if (d_latched == 8'h40) begin
                             sd_address <= 1;
                             sd_state <= SD_START;
                             current_sector <= 0;
                             psram_load_addr <= 23'h000000;
                             busy <= 1;
                             game_loaded <= 0;
                             switch_pending <= 0;
                        end
                    end
                end
                                 SD_START: begin
                     psram_wr_req <= 0;
                     if (sd_ready_s) begin
                         sd_rd <= 1; // Assert RD to kick off block load
                     end
                     else if (sd_rd) begin
                         sd_rd <= 0; // sd_ready_s went low, it heard us!
                         byte_index <= 0;
                         sd_state <= SD_WAIT;
                     end
                 end
                 
                 SD_WAIT: begin
                     // 4-Phase Handshake Drop:
                     if (sd_rd && !sd_ba_s) begin
                         sd_rd <= 0; // Drop ACK when we see it was received
                     end
                     
                     if (sd_ba_s && !sd_rd && !write_pending) begin
                         sd_dout_reg <= sd_dout;     // Capture Data
                         sd_rd <= 1;                 // Assert ACK
                         sd_state <= SD_DATA;        // Handle PSRAM Write
                     end else if (!sd_ba_s && !sd_rd && byte_index >= 512 && !write_pending) begin
                         sd_state <= SD_NEXT;
                     end else if (sd_ready_s && !sd_rd && byte_index < 512) begin
                         sd_state <= SD_NEXT; // Abort on read error
                     end
                 end
                  
                  SD_DATA: begin
                         if (current_sector > 0) begin
                             // Handle Payload Sectors (Sector > 0)
                             if (psram_load_addr[0] == 0) acc_word0[7:0] <= sd_dout_reg;
                             else acc_word0[15:8] <= sd_dout_reg;
                             
                             // Trigger Write on ODD byte
                             if (psram_load_addr[0] == 1'b1) begin
                                  write_pending <= 1;
                                  psram_write_addr_latched <= {psram_load_addr[22:1], 1'b0};
                             end
                             
                             psram_load_addr <= psram_load_addr + 1; 
                         end else begin
                             // Sector 0: Capture Header Bytes
                             case (byte_index)
                                  0: h0  <= sd_dout_reg;
                                 49: h49 <= sd_dout_reg;
                                 50: h50 <= sd_dout_reg;
                                 51: h51 <= sd_dout_reg;
                                 52: h52 <= sd_dout_reg;
                                 53: h53 <= sd_dout_reg;
                                 54: h54 <= sd_dout_reg;
                                 64: h64 <= sd_dout_reg;
                                 65: h65 <= sd_dout_reg;
                                 67: h67 <= sd_dout_reg;
                             endcase
                         end
                         
                         byte_index <= byte_index + 1;
                         sd_state <= SD_WAIT;
                  end

                 SD_NEXT: begin
                     psram_wr_req <= 0;
                     
                     // Analyze Header after Sector 0 is done
                     if (current_sector == 0) begin
                         cart_has_pokey <= 0;
                         cart_mapper <= 4'd0;
                         cart_ram_at_4000 <= 0;

                         if (h0 == 8'h04 && h64 != 8'h00) begin
                             // ---- V4+ Extended Header (SuperGame etc.) ----
                             // Guard: h0==4 alone is not enough — many standard games
                             // set h0=4 but leave h64=0 (standard mapper).
                             // Only use the V4+ SuperGame path when h64 is non-zero.
                             cart_rom_size       <= size_be_wire;
                             psram_load_addr     <= 23'h000000;       // Load full ROM from addr 0
                             // sector_limit = rom_size/512: loop reads exactly
                             // this many data sectors before stopping, so the
                             // last PSRAM write lands at ROM end (not 0x40000+).
                             sector_limit        <= size_be_wire[18:9]; // rom_bytes / 512
                             cart_mapper         <= h64[3:0];           // byte 64: mapper type
                             cart_ram_at_4000    <= h65[0];             // byte 65 bit0: RAM at $4000
                             // fixed bank = last bank index = (num_banks - 1).
                             // num_banks = rom_size / 16384 = size_be_wire[17:14].
                             // 4-bit natural underflow handles 256KB (16 banks
                             // → bits[17:14]=0 → 0-1=15) and 128KB (8→7). ✓
                             cart_sgm_fixed_bank <= size_be_wire[17:14] - 4'd1;
                             // byte 67: audio flags
                             if      (h67[1]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h0450; end
                             else if (h67[0]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h4000; end
                             else if (h67[2]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h0440; end
                             else if (h67[7]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h0800; end

                         end else begin
                             // ---- Standard (Astro Wing, Choplifter, etc.) ----
                             // .a78 spec stores size at bytes 49-52 in Big-Endian.
                             // size_be_wire is always the correct interpretation.
                             cart_rom_size   <= size_be_wire;
                             psram_load_addr <= 49152 - size_be_wire;
                             sector_limit    <= size_be_wire[18:9]; // rom_bytes / 512
                             // Flags: byte 53 = high flags, byte 54 = low flags
                             if      (h54[6]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h0450; end
                             else if (h54[0]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h4000; end
                             else if (h53[2]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h0440; end
                             else if (h53[7]) begin cart_has_pokey <= 1; cart_pokey_addr <= 16'h0800; end
                         end
                     end

                     if (current_sector < sector_limit) begin // Load up to sector_limit sectors
                          current_sector <= current_sector + 1;
                          sd_address <= sd_address + 1; // Advance true SD Block Address
                          sd_state <= SD_START;
                      end else begin
                          sd_state <= SD_DRAIN;
                          drain_timer <= 0;
                      end
                  end

                  SD_DRAIN: begin
                      // Wait ~400ns (32 cycles @ 81MHz) to ensure last write is committed
                      drain_timer <= drain_timer + 1;
                      if (drain_timer == 32) begin
                          sd_state <= SD_COMPLETE;
                          busy <= 0;
                      end
                  end
                 
                 SD_COMPLETE: begin
                     busy <= 0;
                     if (trigger_eval) begin
                         if (!game_loaded && d_latched == 8'hA5) begin
                             switch_pending <= 1;
                         end
                         else if (!game_loaded && (d_latched >= 8'h80 && d_latched <= 8'h8F) && !trigger_lock_active) begin
                             sd_address <= 1 + ((d_latched & 8'h7F) * 1024); 
                             current_sector <= 0;
                             sd_state <= SD_START;
                             busy <= 1;
                             psram_load_addr <= 0;
                             trigger_lock_active <= 1;
                         end
                         else if (d_latched == 8'h5A) begin
                             sd_state <= SD_START;
                             current_sector <= 0;
                             psram_load_addr <= 23'h000000;
                             busy <= 1;
                             game_loaded <= 0; 
                             switch_pending <= 0;
                         end
                     end
                     
                     if (switch_pending && a_stable == 16'hFFFC) begin
                         game_loaded <= 1;
                         switch_pending <= 0;
                     end
                 end
                 
                 // --- HEADER SCANNING (METADATA) ---
                 SD_SCAN_START: begin
                     // Read Block 1 + (Index * 1024)
                     // [FIX] Address is now pre-calculated to avoid race condition with sd_rd
                     byte_index <= 0;
                     bram_we <= 0;
                     
                     if (sd_ready_s) begin
                         sd_rd <= 1;
                     end
                     else if (sd_rd) begin
                         sd_rd <= 0;
                         sd_state <= SD_SCAN_WAIT;
                     end
                 end
                 
                 SD_SCAN_WAIT: begin
                     bram_we <= 0; // Pulse low
                     if (sd_rd && !sd_ba_s) sd_rd <= 0;
                     
                     if (sd_ba_s && !sd_rd) begin
                         sd_dout_reg <= sd_dout;
                         sd_rd <= 1;
                         sd_state <= SD_SCAN_DATA;
                     end else if (!sd_ba_s && !sd_rd && byte_index >= 512) begin
                         sd_state <= SD_SCAN_NEXT;
                     end else if (sd_ready_s && !sd_rd && byte_index < 512) begin
                         // [FIX] Abort if controller goes IDLE prematurely (timeout/error)
                         sd_state <= SD_SCAN_NEXT;
                     end
                 end
                 
                 SD_SCAN_DATA: begin
                     // Extract Title (Bytes 17-48)
                     // Map to BRAM $6000 + (GameIdx * 32) + CharIdx
                     if (byte_index >= 17 && byte_index <= 48) begin
                         bram_we <= 1;
                         bram_data <= sd_dout_reg;
                         // Base $6000 + Offset
                         bram_addr <= 16'h6000 + (scan_game_idx * 32) + (byte_index - 17);
                     end
                     
                     byte_index <= byte_index + 1;
                     sd_state <= SD_SCAN_WAIT;
                 end
                 
                 SD_SCAN_NEXT: begin
                     if (scan_game_idx < 15) begin // Scan first 16 games
                         scan_game_idx <= scan_game_idx + 1;
                         sd_address <= 1 + ((scan_game_idx + 1) * 1024); // [FIX] Pre-calculate for next slot
                         sd_state <= SD_SCAN_START;
                     end else begin
                         // Done scanning
                         sd_state <= SD_IDLE;
                         busy <= 0;
                     end
                 end
                 
             endcase
             
             // Unlock trigger only when the menu clears the trigger byte (e.g. to 0)
             if (d_latched == 0) trigger_lock_active <= 0;
             
        end
    end

endmodule
