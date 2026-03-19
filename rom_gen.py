# Save as rom_gen.py
import sys

# Usage: python rom_gen.py <menu.bin>
#
# Generates game.hex for $readmemh into rom_memory[0:49151] (48KB BRAM).
#
# Memory map (CPU address space):
#   $4000-$7FFF  → BRAM index    0-16383  (game titles + SGM RAM — NOT from ROM binary)
#   $8000-$FFFF  → BRAM index 16384-49151 (menu ROM binary)
#
# Supported input sizes:
#   32KB (0x8000) — 32K menu ROM, preceded by 16KB of zeros in BRAM
#   48KB (0xC000) — legacy 48K menu ROM, placed directly (no padding needed)

BRAM_SIZE  = 49152   # total BRAM: 48KB covering $4000-$FFFF
ROM_OFFSET = 16384   # ROM starts at $8000 → BRAM index 16384

input_file = sys.argv[1]
output_file = "game.hex"

with open(input_file, "rb") as f:
    rom_data = f.read()

rom_size = len(rom_data)

if rom_size == 32768:
    # 32K ROM: pad lower 16K with zeros, place ROM at $8000 offset
    image = bytes(ROM_OFFSET) + rom_data
    print(f"32K ROM: padded {ROM_OFFSET} zero bytes at front → 48KB image.")
elif rom_size == 49152:
    # Legacy 48K ROM: place directly
    image = rom_data
    print(f"48K ROM: placed directly.")
else:
    print(f"Warning: unexpected ROM size {rom_size} bytes (expected 32KB or 48KB).")
    # Best-effort: right-align into BRAM
    pad = max(0, BRAM_SIZE - rom_size)
    image = bytes(pad) + rom_data

# Trim or pad to exactly BRAM_SIZE
if len(image) > BRAM_SIZE:
    image = image[:BRAM_SIZE]
elif len(image) < BRAM_SIZE:
    image = image + bytes(BRAM_SIZE - len(image))

with open(output_file, "w") as f:
    for byte in image:
        f.write(f"{byte:02x}\n")

print(f"Wrote {output_file} ({len(image)} bytes → {BRAM_SIZE} BRAM slots).")