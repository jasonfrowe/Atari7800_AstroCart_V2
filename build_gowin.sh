#!/bin/bash
# Build script for Atari 7800 AstroCart using Gowin IDE
# This script synthesizes the design using Gowin IDE command line tools

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Atari 7800 AstroCart FPGA Build${NC}"
echo -e "${GREEN}======================================${NC}"

# Check if menu ROM is up to date
echo -e "\n${YELLOW}Step 1: Checking menu ROM...${NC}"
if [ ! -f "menu/menu.bas.bin" ]; then
    echo -e "${RED}Error: menu/menu.bas.bin not found!${NC}"
    echo "Please compile menu.bas first using 7800basic"
    exit 1
fi

echo "Generating game.hex from menu ROM..."
python3 rom_gen.py menu/menu.bas.bin
# python3 rom_gen.py astrowing.bin
echo -e "${GREEN}✓ game.hex generated${NC}"

# Find Gowin IDE installation
GOWIN_IDE="/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/bin"
if [ ! -d "$GOWIN_IDE" ]; then
    echo -e "${RED}Error: Gowin IDE not found at $GOWIN_IDE${NC}"
    echo "Please install Gowin IDE or update the path in this script"
    exit 1
fi

echo -e "\n${YELLOW}Step 2: Synthesizing with Gowin IDE...${NC}"
echo "Using Gowin IDE at: $GOWIN_IDE"

# Save current directory first
PROJECT_DIR="$(pwd)"
BUILD_TCL="$PROJECT_DIR/build.tcl"

# Create TCL script for synthesis with absolute paths
cat > "$BUILD_TCL" << EOF
# Gowin IDE synthesis script
set_device GW1NR-LV9QN88PC6/I5 -name GW1NR-9C
add_file -type verilog "$PROJECT_DIR/top.v"
add_file -type verilog "$PROJECT_DIR/sd_controller.v"
add_file -type verilog "$PROJECT_DIR/psram_controller.v"
add_file -type verilog "$PROJECT_DIR/cart_loader.v"
add_file -type verilog "$PROJECT_DIR/a78_loader.v"
add_file -type verilog "$PROJECT_DIR/diag_rom.v"
add_file -type verilog "$PROJECT_DIR/pokey_advanced.v"
add_file -type verilog "$PROJECT_DIR/smart_blinkers.v"
add_file -type verilog "$PROJECT_DIR/gowin_pll.v"
add_file -type cst "$PROJECT_DIR/atari.cst"
set_option -top_module top
set_option -verilog_std sysv2017
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1
set_option -output_base_name Atari7800_AstroCart
run all
EOF

# Set library paths for Gowin tools
IDE_LIB="/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib"
export DYLD_LIBRARY_PATH="$IDE_LIB:$DYLD_LIBRARY_PATH"
export DYLD_FRAMEWORK_PATH="$IDE_LIB:$DYLD_FRAMEWORK_PATH"

# Change to IDE directory so relative library paths work
cd "$GOWIN_IDE"

# Run Gowin shell with TCL script
if [ -f "./gw_sh" ]; then
    echo "Running gw_sh from IDE directory..."
    echo "TCL script: $BUILD_TCL"
    ./gw_sh "$BUILD_TCL"
    RESULT=$?
    cd - > /dev/null
    if [ $RESULT -ne 0 ]; then
        echo -e "${RED}gw_sh failed with exit code $RESULT${NC}"
        exit $RESULT
    fi
elif [ -f "./gw_ide" ]; then
    # Alternative: use gw_ide in batch mode
    echo "Running gw_ide in batch mode..."
    ./gw_ide -batch "$BUILD_TCL"
    RESULT=$?
    cd - > /dev/null
    if [ $RESULT -ne 0 ]; then
        echo -e "${RED}gw_ide failed with exit code $RESULT${NC}"
        exit $RESULT
    fi
else
    cd - > /dev/null
    echo -e "${RED}Error: Cannot find Gowin command line tool${NC}"
    echo "Available tools in $GOWIN_IDE:"
    ls -la "$GOWIN_IDE/" | grep -E "(gw_|gowin)" || echo "None found"
    echo ""
    echo "Please run synthesis manually in Gowin IDE GUI"
    exit 1
fi

# Copy bitstream to project directory
echo "Copying bitstream to project directory..."
BITSTREAM_PATH="$GOWIN_IDE/impl/pnr/Atari7800_AstroCart.fs"
if [ -f "$BITSTREAM_PATH" ]; then
    cp "$BITSTREAM_PATH" "$PROJECT_DIR/"
    echo -e "${GREEN}✓ Bitstream copied to Atari7800_AstroCart.fs${NC}"
else
    echo -e "${YELLOW}Warning: Bitstream file not found at expected location${NC}"
fi

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Bitstream file: Atari7800_AstroCart.fs"
echo ""
echo "To program the FPGA, run:"
echo "  ./program.sh"
echo ""
