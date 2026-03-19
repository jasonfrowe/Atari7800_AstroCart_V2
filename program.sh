#!/bin/bash
# Program script for Tang Nano 9K using openFPGALoader
# Flashes the Atari 7800 AstroCart bitstream to the FPGA

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Programming Tang Nano 9K${NC}"
echo -e "${GREEN}======================================${NC}"

# Check for bitstream file
BITSTREAM="Atari7800_AstroCart.fs"
if [ ! -f "$BITSTREAM" ]; then
    echo -e "${RED}Error: Bitstream file not found: $BITSTREAM${NC}"
    echo "Please run ./build_gowin.sh first"
    exit 1
fi

# Check if openFPGALoader is installed
if ! command -v openFPGALoader &> /dev/null; then
    echo -e "${RED}Error: openFPGALoader not found${NC}"
    echo "Install it with: brew install openfpgaloader"
    exit 1
fi

# Detect the board
echo -e "\n${YELLOW}Detecting Tang Nano 9K...${NC}"
if ! openFPGALoader --detect 2>&1 | grep -q "Gowin"; then
    echo -e "${RED}Error: Tang Nano 9K not detected${NC}"
    echo "Please check:"
    echo "  1. Board is connected via USB"
    echo "  2. USB cable supports data (not just power)"
    echo "  3. Board is powered on"
    exit 1
fi

echo -e "${GREEN}✓ Board detected${NC}"

# Ask user: SRAM or Flash?
echo -e "\n${YELLOW}Programming options:${NC}"
echo "  1) SRAM  - Fast, temporary (lost on power cycle)"
echo "  2) Flash - Permanent (survives power cycle, slower)"
echo ""
read -p "Select mode (1 or 2, default=1): " mode
mode=${mode:-1}

echo ""
if [ "$mode" = "2" ]; then
    echo -e "${YELLOW}Programming to Flash (permanent)...${NC}"
    openFPGALoader -b tangnano9k -f "$BITSTREAM"
else
    echo -e "${YELLOW}Programming to SRAM (temporary)...${NC}"
    openFPGALoader -b tangnano9k "$BITSTREAM"
fi

echo -e "\n${GREEN}======================================${NC}"
echo -e "${GREEN}Programming Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "The FPGA should now be running the Atari 7800 AstroCart design."
echo ""
echo "LED indicators:"
echo "  LED[0] - Bus output enable (on when driving)"
echo "  LED[1] - PLL locked (on when clock is ready)"
echo "  LED[2] - SD card initialized (off when ready)"
echo "  LED[3] - PSRAM ready (off when ready)"
echo "  LED[4] - Game load complete (off when done)"
echo "  LED[5] - Game loaded flag (off = menu, on = game)"
echo ""
