#!/bin/bash
# Test script for harvest library compression/threading functionality

set -e

if [ -z "$CONDA_PREFIX" ]; then
    echo "ERROR: Conda environment not activated"
    echo "Please run: conda activate gingr-build"
    exit 1
fi

# Set pkg-config path
export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig

cd "$(dirname "$0")"

# Make sure parent library is built
if [ ! -f "../../lib/libharvest.a" ]; then
    echo "ERROR: libharvest.a not found. Please run ./build_qmake.sh first"
    exit 1
fi

echo "=== Building harvest library tests ==="

# Build test_compression
echo "Building test_compression..."
g++ -std=c++17 \
    -I.. \
    -I$CONDA_PREFIX/include \
    -o test_compression \
    test_compression.cpp \
    -L../../lib -lharvest \
    -L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib \
    $(pkg-config --libs protobuf) \
    -lcapnp -lkj -lz

# Build test_threading_portability
echo "Building test_threading_portability..."
g++ -std=c++17 \
    -I.. \
    -I$CONDA_PREFIX/include \
    -o test_threading_portability \
    test_threading_portability.cpp \
    -L../../lib -lharvest \
    -L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib \
    $(pkg-config --libs protobuf) \
    -lcapnp -lkj -lz

echo ""
echo "=== Running tests ==="

echo ""
echo "--- Test 1: Compression ---"
./test_compression

echo ""
echo "--- Test 2: Threading Portability ---"
./test_threading_portability

echo ""
echo "=== All tests completed ==="

# Cleanup test files
rm -f test_*.ggr
