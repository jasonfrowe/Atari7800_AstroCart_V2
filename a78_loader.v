// ============================================================================
// Atari 7800 .a78 Header Parser
// Extracts cartridge configuration from .a78 file header
// ============================================================================

module a78_header_parser (
    input wire clk,
    input wire reset_n,
    
    // Control
    input wire start_parse,          // Start parsing header
    input wire [7:0] header_byte,    // Byte from header
    input wire header_byte_valid,    // Byte valid strobe
    output reg parse_done,          // Parsing complete
    
    // Parsed header fields
    output reg [255:0] cart_name,    // 32 character name (not 16!)
    output reg [31:0] cart_size,     // ROM size in bytes  
    output reg [15:0] cart_type,     // Cartridge type (16 bits!)
    output reg cart_has_pokey,       // POKEY chip present
    output reg cart_has_ram,         // Cartridge RAM
    output reg [15:0] pokey_addr,    // POKEY address ($440, $450, $800, $4000)
    output reg [7:0] controller_1,   // Controller 1 type
    output reg [7:0] controller_2,   // Controller 2 type
    output reg tv_type               // 0=NTSC, 1=PAL
);

    // .a78 Header Format (128 bytes total) - Official Specification
    // Offset  Size  Description
    // 0       1     Header version
    // 1-16    16    'ATARI7800' magic text
    // 17-48   32    Cartridge title (padded with 0)
    // 49-52   4     ROM size without header (little-endian)
    // 53-54   2     Cartridge type (16-bit flags)
    //               bit 0:  POKEY at $4000
    //               bit 1:  SuperGame bank switched
    //               bit 2:  SuperGame RAM at $4000
    //               bit 3:  ROM at $4000
    //               bit 4:  Bank 6 at $4000
    //               bit 5:  Banked RAM
    //               bit 6:  POKEY at $450
    //               bit 7:  Mirror RAM at $4000
    //               bit 8:  Activision banking
    //               bit 9:  Absolute banking
    //               bit 10: POKEY at $440
    //               bit 11: YM2151 at $460/$461
    //               bit 12: Souper
    //               bit 13: Banksets
    //               bit 14: Halt banked RAM
    //               bit 15: POKEY at $800
    // 55      1     Controller 1 type
    // 56      1     Controller 2 type
    // 57      1     TV type (bit 0: 0=NTSC, 1=PAL)
    // 58      1     Save device
    // 59-62   4     Reserved
    // 63      1     Slot passthrough device
    // 64      1     v4+ mapper
    // 65      1     v4+ mapper options
    // 66-67   2     v4+ audio
    // 68-69   2     v4+ interrupt
    // 70-99   30    Reserved
    // 100-127 28    Header end magic text
    
    reg [7:0] byte_count;
    reg [7:0] header_buffer [0:127];
    
    localparam IDLE = 0;
    localparam RECEIVING = 1;
    localparam PARSING = 2;
    localparam DONE = 3;
    
    reg [1:0] state;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            byte_count <= 0;
            parse_done <= 0;
            cart_name <= 256'd0;
            cart_size <= 32'd0;
            cart_type <= 16'd0;
            cart_has_pokey <= 0;
            cart_has_ram <= 0;
            pokey_addr <= 16'd0;
            controller_1 <= 8'd0;
            controller_2 <= 8'd0;
            tv_type <= 0;
        end else begin
            case (state)
                IDLE: begin
                    parse_done <= 0;
                    if (start_parse) begin
                        byte_count <= 0;
                        state <= RECEIVING;
                    end
                end
                
                RECEIVING: begin
                    if (header_byte_valid) begin
                        header_buffer[byte_count] <= header_byte;
                        
                        if (byte_count == 127) begin
                            state <= PARSING;
                        end else begin
                            byte_count <= byte_count + 1;
                        end
                    end
                end
                
                PARSING: begin
                    // Extract cartridge name (bytes 17-48, 32 bytes)
                    cart_name[255:248] <= header_buffer[17];
                    cart_name[247:240] <= header_buffer[18];
                    cart_name[239:232] <= header_buffer[19];
                    cart_name[231:224] <= header_buffer[20];
                    cart_name[223:216] <= header_buffer[21];
                    cart_name[215:208] <= header_buffer[22];
                    cart_name[207:200] <= header_buffer[23];
                    cart_name[199:192] <= header_buffer[24];
                    cart_name[191:184] <= header_buffer[25];
                    cart_name[183:176] <= header_buffer[26];
                    cart_name[175:168] <= header_buffer[27];
                    cart_name[167:160] <= header_buffer[28];
                    cart_name[159:152] <= header_buffer[29];
                    cart_name[151:144] <= header_buffer[30];
                    cart_name[143:136] <= header_buffer[31];
                    cart_name[135:128] <= header_buffer[32];
                    cart_name[127:120] <= header_buffer[33];
                    cart_name[119:112] <= header_buffer[34];
                    cart_name[111:104] <= header_buffer[35];
                    cart_name[103:96]  <= header_buffer[36];
                    cart_name[95:88]   <= header_buffer[37];
                    cart_name[87:80]   <= header_buffer[38];
                    cart_name[79:72]   <= header_buffer[39];
                    cart_name[71:64]   <= header_buffer[40];
                    cart_name[63:56]   <= header_buffer[41];
                    cart_name[55:48]   <= header_buffer[42];
                    cart_name[47:40]   <= header_buffer[43];
                    cart_name[39:32]   <= header_buffer[44];
                    cart_name[31:24]   <= header_buffer[45];
                    cart_name[23:16]   <= header_buffer[46];
                    cart_name[15:8]    <= header_buffer[47];
                    cart_name[7:0]     <= header_buffer[48];
                    
                    // Extract ROM size (bytes 49-52, little-endian)
                    cart_size[7:0]    <= header_buffer[49];
                    cart_size[15:8]   <= header_buffer[50];
                    cart_size[23:16]  <= header_buffer[51];
                    cart_size[31:24]  <= header_buffer[52];
                    
                    // Extract cartridge type (bytes 53-54, 16-bit, little-endian)
                    cart_type[7:0]    <= header_buffer[53];
                    cart_type[15:8]   <= header_buffer[54];
                    
                    // Determine POKEY presence and address from cart_type bits
                    // bit 0: POKEY at $4000
                    // bit 6: POKEY at $450
                    // bit 10: POKEY at $440
                    // bit 15: POKEY at $800
                    if (header_buffer[54][7]) begin  // bit 15
                        cart_has_pokey <= 1;
                        pokey_addr <= 16'h0800;
                    end else if (header_buffer[54][2]) begin  // bit 10
                        cart_has_pokey <= 1;
                        pokey_addr <= 16'h0440;
                    end else if (header_buffer[53][6]) begin  // bit 6
                        cart_has_pokey <= 1;
                        pokey_addr <= 16'h0450;
                    end else if (header_buffer[53][0]) begin  // bit 0
                        cart_has_pokey <= 1;
                        pokey_addr <= 16'h4000;
                    end else begin
                        cart_has_pokey <= 0;
                        pokey_addr <= 16'h0000;
                    end
                    
                    // Check for cartridge RAM (bit 5: banked RAM, bit 2: supergame RAM)
                    cart_has_ram <= header_buffer[53][5] | header_buffer[53][2];
                    
                    // Controller types (bytes 55-56)
                    controller_1 <= header_buffer[55];
                    controller_2 <= header_buffer[56];
                    
                    // TV type (byte 57, bit 0)
                    tv_type <= header_buffer[57][0];
                    
                    state <= DONE;
                end
                
                DONE: begin
                    parse_done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule


// ============================================================================
// Game Loader - Integrates SD card, PSRAM, and header parser
// ============================================================================

module game_loader (
    input wire clk,
    input wire reset_n,
    
    // Control interface
    input wire [3:0] game_select,    // Which game to load (0-15)
    input wire load_game,            // Pulse to start loading
    output reg load_complete,        // Loading finished
    output reg load_error,           // Error occurred
    
    // Game info outputs
    output wire [255:0] game_name,
    output wire [31:0] game_size,
    output wire [15:0] cart_type,
    output wire has_pokey,
    output wire [15:0] pokey_addr,
    output wire [7:0] controller_1,
    output wire [7:0] controller_2,
    output wire tv_type,
    
    // PSRAM interface (where game gets loaded)
    output reg psram_write_req,
    output reg [21:0] psram_addr,
    output reg [7:0] psram_data,
    input wire psram_busy,
    
    // SD card interface 
    output reg sd_read_req,
    output reg [31:0] sd_block_addr,
    input wire [7:0] sd_data,
    input wire sd_data_valid,
    input wire sd_busy
);

    // State machine
    localparam IDLE = 0;
    localparam READ_HEADER = 1;
    localparam PARSE_HEADER = 2;
    localparam LOAD_ROM = 3;
    localparam DONE = 4;
    localparam ERROR = 5;
    
    reg [2:0] state;
    reg [7:0] header_byte;
    reg header_byte_valid;
    reg start_parse;
    wire parse_done;
    
    reg [21:0] write_addr;
    reg [15:0] byte_counter;
    
    // Header parser instance
    a78_header_parser parser (
        .clk(clk),
        .reset_n(reset_n),
        .start_parse(start_parse),
        .header_byte(header_byte),
        .header_byte_valid(header_byte_valid),
        .parse_done(parse_done),
        .cart_name(game_name),
        .cart_size(game_size),
        .cart_type(cart_type),
        .cart_has_pokey(has_pokey),
        .pokey_addr(pokey_addr),
        .cart_has_ram(),          // Not connected for now
        .controller_1(controller_1),
        .controller_2(controller_2),
        .tv_type(tv_type)
    );
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            load_complete <= 0;
            load_error <= 0;
            sd_read_req <= 0;
            psram_write_req <= 0;
            write_addr <= 0;
        end else begin
            // Default outputs
            sd_read_req <= 0;
            psram_write_req <= 0;
            header_byte_valid <= 0;
            start_parse <= 0;
            
            case (state)
                IDLE: begin
                    load_complete <= 0;
                    load_error <= 0;
                    
                    if (load_game) begin
                        // Calculate SD card block address for selected game
                        // Assuming games are stored sequentially
                        // Block 0 = directory, Blocks 1+ = games
                        sd_block_addr <= 32'd1 + (game_select * 32'd1024); // 1024 blocks per game max
                        byte_counter <= 0;
                        write_addr <= 0;
                        state <= READ_HEADER;
                    end
                end
                
                READ_HEADER: begin
                    // Read first 128 bytes (header) from SD card
                    if (!sd_busy) begin
                        sd_read_req <= 1;
                    end
                    
                    if (sd_data_valid) begin
                        header_byte <= sd_data;
                        header_byte_valid <= 1;
                        byte_counter <= byte_counter + 1;
                        
                        if (byte_counter == 127) begin
                            start_parse <= 1;
                            state <= PARSE_HEADER;
                        end
                    end
                end
                
                PARSE_HEADER: begin
                    if (parse_done) begin
                        byte_counter <= 0;
                        write_addr <= 22'h004000;  // Start at $4000
                        state <= LOAD_ROM;
                    end
                end
                
          LOAD_ROM: begin
                    // Load ROM data from SD to PSRAM
                    if (!sd_busy && !psram_busy) begin
                        sd_read_req <= 1;
                    end
                    
                    if (sd_data_valid && !psram_busy) begin
                        psram_addr <= write_addr;
                        psram_data <= sd_data;
                        psram_write_req <= 1;
                        write_addr <= write_addr + 1;
                        byte_counter <= byte_counter + 1;
                        
                        // Check if we've loaded entire ROM
                        if (byte_counter >= game_size[15:0]) begin
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    load_complete <= 1;
                    state <= IDLE;
                end
                
                ERROR: begin
                    load_error <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule
