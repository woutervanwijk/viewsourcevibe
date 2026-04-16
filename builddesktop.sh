#!/bin/bash

set -e  # Exit on error

echo "=== View Source Vibe Desktop Build ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Clean everything first
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean

# Function to build a platform
build_platform() {
    local platform=$1
    local output_msg=$2
    
    echo ""
    echo -e "${YELLOW}Building for $platform...${NC}"
    
    if flutter build $platform --release 2>&1; then
        echo -e "${GREEN}✓ $platform build successful!${NC}"
        echo -e "${GREEN}  $output_msg${NC}"
        return 0
    else
        echo -e "${RED}✗ $platform build failed!${NC}"
        return 1
    fi
}

# Build macOS
if build_platform "macos" "Output: build/View Source Vibe.app"; then
    rm -drf "build/View Source Vibe.app" 2>/dev/null || true
    mv "build/macos/Build/Products/Release/View Source Vibe.app" "build/View Source Vibe.app" 2>/dev/null
    echo -e "${GREEN}  Moved to: build/View Source Vibe.app${NC}"
else
    echo -e "${RED}macOS build failed, continuing...${NC}"
fi

# Build Windows
if build_platform "windows" "Output: build/windows/runner/Release/"; then
    echo -e "${GREEN}  Ready for distribution${NC}"
else
    echo -e "${RED}Windows build failed, continuing...${NC}"
fi

# Build Linux
if build_platform "linux" "Output: build/linux/x64/release/bundle/"; then
    echo -e "${GREEN}  Ready for distribution${NC}"
else
    echo -e "${RED}Linux build failed, continuing...${NC}"
fi

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo ""
echo "Build Outputs:"
echo "  • macOS:   $(pwd)/build/View Source Vibe.app"
echo "  • Windows: $(pwd)/build/windows/runner/Release/"
echo "  • Linux:   $(pwd)/build/linux/x64/release/bundle/"
echo ""