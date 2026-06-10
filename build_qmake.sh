#!/bin/bash
# Build script for qmake-based Gingr build
# Ensures conda environment is properly configured

set -e

# Check if conda environment is activated
if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "ERROR: No conda environment activated!"
    echo "Please run: conda activate gingr-build"
    exit 1
fi

echo "Building Gingr with qmake..."
echo "Conda environment: $CONDA_DEFAULT_ENV"
echo "CONDA_PREFIX: $CONDA_PREFIX"
echo ""

# Set pkg-config path for protobuf dependencies
export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig

# Clean previous build
echo "Cleaning previous build..."
make clean 2>/dev/null || true
rm -rf lib/ gingr_app/Gingr.app Gingr.app

# Create build directories (qmake doesn't create nested dirs automatically)
mkdir -p harvest/build/obj harvest/build/moc
mkdir -p gingr_app/build/obj gingr_app/build/moc gingr_app/build/rcc

# Run qmake
echo ""
echo "Running qmake..."
qmake

# Build
echo ""
echo "Building harvest library and Gingr..."
make -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo ""
echo "================================"
echo "Build complete!"
echo "================================"
if [ -d "gingr_app/Gingr.app" ]; then
    echo "✓ Gingr.app created successfully"
    ls -lh gingr_app/Gingr.app/Contents/MacOS/Gingr

    # Install: move to top level directory
    echo ""
    echo "Installing Gingr.app to top level..."
    mv gingr_app/Gingr.app ./
    echo "✓ Installed: ./Gingr.app"
    echo ""
    echo "To run Gingr:"
    echo "  open Gingr.app"
    echo "  or: ./Gingr.app/Contents/MacOS/Gingr"
else
    echo "✗ Build may have failed - Gingr.app not found"
    exit 1
fi
