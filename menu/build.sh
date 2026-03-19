#!/bin/bash
# Build script for Atari 7800 menu program

# Set path to 7800basic
BASIC_PATH="/Users/rowe/Software/Atari7800/7800basic"

# Create gfx directory if it doesn't exist
mkdir -p gfx

echo "Building Atari 7800 Menu Program..."
echo "===================================="

# Check if font exists
if [ ! -f "gfx/menufont.png" ]; then
    echo "ERROR: gfx/menufont.png not found!"
    echo "Please create the menu font graphic first."
    echo "See gfx/README.md for instructions."
    exit 1
fi

# Compile the menu program
echo "Compiling menu.bas..."
${BASIC_PATH}/7800basic.sh menu.bas

# Check if compilation succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Compilation successful!"
    echo ""
    echo "Output files:"
    ls -lh menu.bas.bin menu.bas.a78 2>/dev/null
    echo ""
    echo "Menu ROM size: $(wc -c < menu.bas.bin) bytes"
    echo ""
    echo "To test in emulator:"
    echo "  open menu.bas.a78"
    echo ""
else
    echo ""
    echo "✗ Compilation failed!"
    echo "Check errors above."
    exit 1
fi
