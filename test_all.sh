#!/bin/bash
# Comprehensive local test script
# Run this before pushing to verify everything works

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Gingr Comprehensive Test Suite"
echo "=========================================="
echo ""

# Check if we're in a conda environment
if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo -e "${RED}✗ Not in a conda environment!${NC}"
    echo "Please activate the gingr-build environment first:"
    echo "  conda activate gingr-build"
    exit 1
fi

echo -e "${GREEN}✓ Conda environment: $CONDA_DEFAULT_ENV${NC}"
echo ""

# Function to run a test
run_test() {
    local test_name="$1"
    shift  # Remove first argument, rest are the command

    echo "----------------------------------------"
    echo "Running: $test_name"
    echo "----------------------------------------"

    # Run the command directly (not eval) in a subshell
    if ( "$@" ); then
        echo -e "${GREEN}✓ $test_name PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name FAILED${NC}"
        return 1
    fi
}

PASSED=0
FAILED=0
TOTAL=0

# Test 1: Build harvest-tools
((TOTAL++))
if run_test "Build harvest-tools" bash -c '
    cd harvest_src &&
    ./bootstrap.sh &&
    CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17" \
    LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib" \
    ./configure --prefix=$CONDA_PREFIX \
                --with-protobuf=$CONDA_PREFIX \
                --with-capnp=$CONDA_PREFIX &&
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2) &&
    make install
'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""

# Test 2: Build test_compression
((TOTAL++))
if run_test "Build test_compression" bash -c '
    cd harvest_src &&
    export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig &&
    g++ -std=c++17 \
        -I$CONDA_PREFIX/include -Isrc \
        test_compression.cpp \
        -L$CONDA_PREFIX/lib \
        -Wl,-rpath,$CONDA_PREFIX/lib \
        -lharvest $(pkg-config --libs protobuf) -lcapnp -lkj -lz \
        -o test_compression
'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""

# Test 3: Run test_compression
((TOTAL++))
if run_test "Run test_compression" bash -c 'cd harvest_src && ./test_compression'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""

# Test 4: Build test_threading_portability
((TOTAL++))
if run_test "Build test_threading_portability" bash -c '
    cd harvest_src &&
    export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig &&
    g++ -std=c++17 \
        -I$CONDA_PREFIX/include -Isrc \
        test_threading_portability.cpp \
        -L$CONDA_PREFIX/lib \
        -Wl,-rpath,$CONDA_PREFIX/lib \
        -lharvest $(pkg-config --libs protobuf) -lcapnp -lkj -lz \
        -o test_threading_portability
'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""

# Test 5: Run test_threading_portability
((TOTAL++))
if run_test "Run test_threading_portability" bash -c 'cd harvest_src && ./test_threading_portability'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""

# Test 6: Build Gingr
((TOTAL++))
if run_test "Build Gingr" bash -c '
    ./bootstrap.sh &&
    CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17" \
    LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib" \
    ./configure --prefix=$CONDA_PREFIX \
                --with-protobuf=$CONDA_PREFIX \
                --with-capnp=$CONDA_PREFIX \
                --with-harvest=$CONDA_PREFIX &&
    rm -f .qmake.stash &&
    qmake &&
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""

# Test 7: Smoke test
((TOTAL++))
if run_test "Smoke test" bash -c './tests/smoke_test.sh'; then
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo -e "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
else
    echo -e "Failed: 0"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo "You're ready to commit and push!"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo "Please fix the issues before pushing."
    exit 1
fi
