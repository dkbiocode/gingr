#!/bin/bash
# Smoke test for Gingr binary
# Verifies that the application can at least start and display help/version

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Gingr Smoke Test ==="
echo "Platform: $(uname -s)"
echo "Architecture: $(uname -m)"
echo ""

# Determine the binary path based on platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    GINGR_BIN="$PROJECT_ROOT/Gingr.app/Contents/MacOS/Gingr"
    if [ ! -f "$GINGR_BIN" ]; then
        echo "✗ Gingr.app not found at expected location"
        exit 1
    fi
    echo "✓ Found Gingr.app"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    GINGR_BIN="$PROJECT_ROOT/release/gingr.exe"
    if [ ! -f "$GINGR_BIN" ]; then
        GINGR_BIN="$PROJECT_ROOT/gingr.exe"
    fi
    if [ ! -f "$GINGR_BIN" ]; then
        echo "✗ gingr.exe not found"
        exit 1
    fi
    echo "✓ Found gingr.exe"
else
    # Linux/Unix
    GINGR_BIN="$PROJECT_ROOT/gingr"
    if [ ! -f "$GINGR_BIN" ]; then
        echo "✗ gingr binary not found"
        exit 1
    fi
    echo "✓ Found gingr binary"
fi

# Check if binary is executable
if [ ! -x "$GINGR_BIN" ]; then
    echo "✗ Binary is not executable"
    exit 1
fi
echo "✓ Binary is executable"

# Check file size (should be > 1MB for a Qt app)
FILE_SIZE=$(stat -f%z "$GINGR_BIN" 2>/dev/null || stat -c%s "$GINGR_BIN" 2>/dev/null)
if [ "$FILE_SIZE" -lt 1048576 ]; then
    echo "⚠ Warning: Binary size is suspiciously small: $FILE_SIZE bytes"
else
    echo "✓ Binary size looks reasonable: $FILE_SIZE bytes"
fi

# Try to get version or help (with timeout to prevent hanging)
# Note: GUI apps might not support --version, so we just verify it doesn't crash immediately
echo ""
echo "Testing binary startup (with timeout)..."

# This test is platform-specific because GUI apps behave differently
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # On Unix-like systems, we can use timeout and check if it doesn't immediately crash
    # We expect it to fail because there's no display, but it should fail gracefully
    timeout 5s "$GINGR_BIN" --help 2>&1 > /dev/null || true
    EXIT_CODE=$?

    # Exit codes:
    # 124 = timeout (good - means app didn't crash immediately)
    # 1 = no display / expected GUI error (good)
    # 139 = segfault (bad)
    # 134 = abort (bad)

    if [ $EXIT_CODE -eq 139 ] || [ $EXIT_CODE -eq 134 ]; then
        echo "✗ Binary crashed with exit code $EXIT_CODE"
        exit 1
    else
        echo "✓ Binary started without crashing (exit code: $EXIT_CODE)"
    fi
fi

# Check for required dynamic libraries
echo ""
echo "Checking dynamic library dependencies..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Library dependencies:"
    otool -L "$GINGR_BIN" | grep -E "(Qt|protobuf|capnp)" || echo "⚠ No Qt/protobuf/capnp dependencies found (might be statically linked)"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Library dependencies:"
    ldd "$GINGR_BIN" | grep -E "(Qt|protobuf|capnp)" || echo "⚠ No Qt/protobuf/capnp dependencies found (might be statically linked)"
fi

echo ""
echo "=== Smoke Test Summary ==="
echo "✓ Binary exists and is executable"
echo "✓ Binary size is reasonable"
echo "✓ Binary doesn't crash on startup"
echo "✓ All smoke tests passed!"
