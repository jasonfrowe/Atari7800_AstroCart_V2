#!/usr/bin/env python3
"""
Write Atari 7800 game files to raw SD card blocks for FPGA cartridge loader.

WARNING: This writes directly to raw device blocks and will DESTROY any
existing filesystem on the SD card!

Game Layout:
- Block 0: Reserved
- Block 1-100: Game 0
- Block 101-200: Game 1
- Block 201-300: Game 2
- etc.
"""

import sys
import os
import struct

BLOCK_SIZE = 512
BLOCKS_PER_GAME = 1024

def write_game_to_blocks(sd_device, game_file, game_number):
    """Write a game file to specific SD card blocks."""
    
    # Calculate starting block
    start_block = 1 + (game_number * BLOCKS_PER_GAME)
    
    # Read game file
    with open(game_file, 'rb') as f:
        game_data = f.read()
        
    # [FPGA FIX] Pad the 128-byte A78 header to a full 512-byte block.
    # This ensures the actual ROM payload starts perfectly aligned at the beginning 
    # of the very next SD card block (Block N+1), drastically simplifying the FPGA loader!
    if len(game_data) > 128:
        header = game_data[:128]
        payload = game_data[128:]
        padded_header = header + (b'\x00' * 384)
        game_data = padded_header + payload
    
    game_size = len(game_data)
    blocks_needed = (game_size + BLOCK_SIZE - 1) // BLOCK_SIZE
    
    if blocks_needed > BLOCKS_PER_GAME:
        print(f"Error: Game is too large ({game_size} bytes, needs {blocks_needed} blocks)")
        print(f"Maximum size is {BLOCKS_PER_GAME * BLOCK_SIZE} bytes")
        return False
    
    print(f"Writing {os.path.basename(game_file)}:")
    print(f"  Size: {game_size} bytes")
    print(f"  Blocks: {blocks_needed}")
    print(f"  Location: blocks {start_block}-{start_block + blocks_needed - 1}")
    
    # Open SD card device
    try:
        with open(sd_device, 'r+b') as sd:
            # Seek to starting block
            offset = start_block * BLOCK_SIZE
            sd.seek(offset)
            
            # Write game data
            sd.write(game_data)
            
            # Pad last block with zeros if needed
            remainder = game_size % BLOCK_SIZE
            if remainder > 0:
                padding = BLOCK_SIZE - remainder
                sd.write(b'\x00' * padding)
            
            sd.flush()
            os.fsync(sd.fileno())
            
        print(f"  ✓ Written successfully!")
        return True
        
    except PermissionError:
        print(f"Error: Permission denied. Try running with sudo:")
        print(f"  sudo {' '.join(sys.argv)}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    if len(sys.argv) < 3:
        print("Usage: sudo ./write_games_to_sd.py /dev/diskN game0.a78 [game1.a78 ...]")
        print()
        print("Example:")
        print("  sudo ./write_games_to_sd.py /dev/disk4 astrowing.a78")
        print()
        print("WARNING: This will DESTROY the filesystem on the SD card!")
        print()
        print("Find your SD card device with:")
        print("  diskutil list")
        print()
        print("Unmount it first with:")
        print("  diskutil unmountDisk /dev/diskN")
        sys.exit(1)
    
    sd_device = sys.argv[1]
    game_files = sys.argv[2:]
    
    # Verify device exists
    if not os.path.exists(sd_device):
        print(f"Error: Device {sd_device} not found")
        print()
        print("Run 'diskutil list' to find your SD card")
        sys.exit(1)
    
    # Safety check
    if '/dev/disk0' in sd_device or '/dev/disk1' in sd_device:
        print("Error: Refusing to write to disk0 or disk1 (likely your main drive!)")
        sys.exit(1)
    
    print("="*60)
    print("WARNING: This will write raw data to SD card blocks!")
    print("Any existing filesystem will be DESTROYED!")
    print("="*60)
    print(f"SD Card: {sd_device}")
    print(f"Games to write: {len(game_files)}")
    for i, game in enumerate(game_files):
        print(f"  Game {i}: {game}")
    print()
    
    response = input("Type 'YES' to continue: ")
    if response != 'YES':
        print("Aborted.")
        sys.exit(0)
    
    print()
    
    # Write each game
    success_count = 0
    for i, game_file in enumerate(game_files):
        if not os.path.exists(game_file):
            print(f"Error: Game file not found: {game_file}")
            continue
        
        if write_game_to_blocks(sd_device, game_file, i):
            success_count += 1
        print()
    
    print(f"Complete! {success_count}/{len(game_files)} games written successfully.")
    print()
    print("You can now insert the SD card into your Tang Nano 9K!")

if __name__ == '__main__':
    main()
