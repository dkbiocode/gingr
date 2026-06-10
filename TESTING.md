# Gingr Testing Strategy

## Overview

Gingr uses a multi-layered testing strategy to ensure cross-platform portability across macOS, Linux, and Windows. The testing infrastructure focuses on three key areas:

1. **Build Verification** - Ensures the code compiles on all platforms
2. **Unit Tests** - Tests core functionality (compression, I/O)
3. **Integration Tests** - Tests the complete application workflow

## GitHub Actions CI/CD Pipeline

### Workflow: `.github/workflows/ci.yml`

The main CI workflow tests on the following platforms:

| Platform | OS Version | Compiler | Architecture |
|----------|------------|----------|--------------|
| macOS    | 13 (Intel) | clang    | x86_64       |
| macOS    | 14 (M1/M2) | clang    | arm64        |
| Linux    | Ubuntu 22.04 | gcc    | x86_64       |
| Linux    | Ubuntu 22.04 | clang  | x86_64       |
| Windows  | 2022       | MSVC     | x64          |
| Windows  | 2022       | MinGW    | x64          |

### What Gets Tested

Each platform runs the following tests:

1. **Environment Setup**
   - Conda environment creation
   - Dependency installation (Qt, protobuf, capnproto)
   - Compiler verification

2. **Build Tests**
   - harvest-tools library compilation
   - Gingr GUI application compilation
   - Binary existence verification

3. **Unit Tests**
   - `test_compression` - Basic compression/decompression
   - `test_threading_portability` - Comprehensive threading tests

4. **Smoke Tests**
   - Binary executable check
   - Library dependency verification
   - Basic startup test (no immediate crash)

5. **Artifact Generation**
   - Packaged binaries for each platform
   - 30-day retention for debugging

## Local Testing

### Running Tests Locally

#### Build and Run All Tests

```bash
# Build everything
./install.sh

# Run compression test
cd harvest_src
./test_compression

# Run comprehensive threading test
./test_threading_portability

# Run smoke test
cd ..
./tests/smoke_test.sh
```

#### Run Specific Tests

```bash
# Just harvest-tools tests
cd harvest_src
make check

# Just Gingr build verification
qmake && make
```

### Platform-Specific Testing

#### macOS

```bash
# Build with threading enabled (for testing Windows-compatible code path)
cd harvest_src
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17 -DUSE_THREADING=1" \
LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib" \
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX
make clean && make -j4

# Run tests to verify threading mode works
./test_compression
./test_threading_portability

# Verify app bundle
open Gingr.app
```

#### Linux

```bash
# Standard build
./install.sh

# Run under valgrind for memory leak detection
valgrind --leak-check=full ./harvest_src/test_compression

# Run under thread sanitizer
cd harvest_src
make clean
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17 -fsanitize=thread" \
LDFLAGS="-L$CONDA_PREFIX/lib -fsanitize=thread" \
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX
make -j4
./test_threading_portability
```

#### Windows

```bash
# Using MinGW
export CC=gcc
export CXX=g++
./install.sh

# Using MSVC (from Visual Studio Developer Command Prompt)
cd harvest_src
cl /EHsc /std:c++17 /DUSE_THREADING=1 ^
   /I"%CONDA_PREFIX%\include" /Isrc ^
   test_compression.cpp src/harvest/*.cpp ^
   /link /LIBPATH:"%CONDA_PREFIX%\lib" ^
   protobuf.lib capnp.lib kj.lib zlib.lib

test_compression.exe
```

## Test Coverage

### Unit Tests

#### `test_compression.cpp`

**Purpose**: Basic round-trip compression test

**What it tests**:
- Write HarvestIO data to compressed file
- Read HarvestIO data from compressed file
- Verify data integrity after compression/decompression

**Critical for**:
- Threading implementation correctness
- zlib integration
- Cap'n Proto serialization

**Building Locally**:
```bash
cd harvest_src
export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig
g++ -std=c++17 \
    -I$CONDA_PREFIX/include -Isrc \
    test_compression.cpp \
    -L$CONDA_PREFIX/lib \
    -Wl,-rpath,$CONDA_PREFIX/lib \
    -lharvest $(pkg-config --libs protobuf) -lcapnp -lkj -lz \
    -o test_compression
./test_compression
```

**Note**: Modern protobuf (6.x+) requires Google Abseil libraries. Use `pkg-config --libs protobuf` to get all dependencies (~82 libraries).

#### `test_threading_portability.cpp`

**Purpose**: Comprehensive threading implementation validation

**What it tests**:
1. **Basic Compression** - Simple reference sequence
2. **Large Data** - 5x 100KB sequences (500KB total)
3. **Edge Cases** - Empty descriptions, special characters
4. **Multiple Cycles** - 3 read/write cycles to check consistency

**Critical for**:
- Windows portability (no fork())
- Thread safety
- Memory management
- Data integrity across platforms

### Integration Tests

#### `smoke_test.sh`

**Purpose**: Verify binary integrity and startup

**What it tests**:
- Binary exists and is executable
- Binary size is reasonable (> 1MB)
- Binary doesn't crash on immediate startup
- Required libraries are linked

**Critical for**:
- Package integrity
- Dynamic library linking
- Basic functionality

### Planned Future Tests

- [ ] **GUI Integration Tests** - Automated UI testing with Qt Test
- [ ] **File Format Tests** - Load real .ggr files from various sources
- [ ] **VCF Export Tests** - Verify VCF output format
- [ ] **Performance Tests** - Benchmark compression speed
- [ ] **Memory Leak Tests** - Valgrind on all platforms
- [ ] **Concurrent Access Tests** - Multiple simultaneous file operations

## Testing the Threading Implementation

The switch from `fork()` to `std::thread` is critical for Windows portability. Here's how to verify it works correctly:

### Compile with Threading Enabled

```bash
cd harvest_src
./bootstrap.sh

# Add -DUSE_THREADING=1 to enable threading code path
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17 -DUSE_THREADING=1" \
LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib" \
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX

make clean && make -j4
```

### Run Comparative Tests

```bash
# Test with fork() (default on Unix)
./test_compression > results_fork.txt

# Rebuild with threading
make clean
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17 -DUSE_THREADING=1" make -j4

# Test with threading
./test_compression > results_threading.txt

# Results should be identical
diff results_fork.txt results_threading.txt
```

### Known Platform Issues

#### macOS

- ✅ Fork-based implementation works
- ✅ Threading-based implementation works
- ⚠️ Must use `_exit()` instead of `exit()` in forked children (already fixed)
- ✅ No known issues

#### Linux

- ✅ Fork-based implementation should work
- 🟡 Threading-based implementation not yet tested on Linux
- 🟡 May need to test on different distributions (Ubuntu, CentOS, etc.)

#### Windows

- ❌ Fork-based implementation does not work (fork() unavailable)
- 🟡 Threading-based implementation ready to test
- 🟡 MSVC compilation not yet tested
- 🟡 MinGW compilation not yet tested
- ⚠️ May need to replace Unix I/O (`open()`, `read()`, `write()`) with `<fstream>`

## Continuous Integration Triggers

The CI pipeline runs on:

- **Push to `master` or `develop` branches**
- **Pull requests to `master` or `develop` branches**
- **Manual workflow dispatch** (via GitHub Actions UI)

## Interpreting CI Results

### Success Criteria

A successful build must:

1. ✅ Compile without errors on all 6 platform/compiler combinations
2. ✅ Pass all unit tests (`test_compression`, `test_threading_portability`)
3. ✅ Generate working binaries that pass smoke tests
4. ✅ Create uploadable artifacts

### Common Failures

| Failure Type | Likely Cause | How to Fix |
|--------------|--------------|------------|
| Compilation error | Missing header, syntax error | Check compiler warnings, verify includes |
| Link error (undefined symbols) | Missing protobuf/abseil libraries | Use `pkg-config --libs protobuf` with exported PKG_CONFIG_PATH |
| Link error | Missing library | Verify conda dependencies installed |
| Runtime error (library not loaded) | Missing rpath | Add `-Wl,-rpath,$CONDA_PREFIX/lib` to linker flags |
| Test failure | Logic bug, platform-specific behavior | Debug locally on that platform |
| Artifact missing | Binary not created | Check build output, verify binary path |

### Protobuf/Abseil Linking Issues

**Symptom**: Undefined symbols for `absl::lts_20260107::log_internal::...`

**Cause**: Modern protobuf (6.x+) depends on Google Abseil library (~82 libraries). Manually specifying `-lprotobuf` is insufficient.

**Solution**:
```bash
export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig
g++ ... -lharvest $(pkg-config --libs protobuf) -lcapnp -lkj -lz
```

**Important**: The `export` must happen BEFORE the `$(pkg-config ...)` command substitution. Inline environment variables (`PKG_CONFIG_PATH=... g++ ...`) do NOT work because the subshell doesn't inherit them.

**Debug Tool**: Run `./test_pkgconfig.sh` to verify pkg-config setup.

## Debugging Failed CI Builds

### View Logs

1. Go to GitHub Actions tab
2. Click on the failed workflow run
3. Click on the failed job
4. Expand the failed step to see detailed logs

### Reproduce Locally

```bash
# Use the same conda environment as CI
conda env create -f environment.yml
conda activate gingr-build

# Build with same flags as CI
cd harvest_src
./bootstrap.sh
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17" \
LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib" \
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX
make -j4

# Run the test that failed
./test_compression
```

### Download Artifacts

Failed builds still upload artifacts if they got far enough:

1. Go to failed workflow run
2. Scroll to "Artifacts" section at bottom
3. Download the artifact for the platform that failed
4. Inspect the binary locally

## Performance Benchmarking

### Compression Performance

```bash
# Time the compression test
time ./test_compression

# Compare fork vs threading performance
# (Threading might be slightly slower due to memory copying)
```

### Memory Usage

```bash
# Monitor memory during large file operations
/usr/bin/time -l ./test_threading_portability  # macOS
/usr/bin/time -v ./test_threading_portability  # Linux
```

### Profile Threading

```bash
# Use system profiler
# macOS: Instruments.app
# Linux: perf or valgrind --tool=callgrind
```

## Adding New Tests

### Adding a Unit Test

1. Create test file in `harvest_src/test_*.cpp`
2. Add to `harvest_src/Makefile.am`:
   ```makefile
   check_PROGRAMS += test_newfeature
   TESTS += test_newfeature
   test_newfeature_SOURCES = test_newfeature.cpp src/harvest/...
   test_newfeature_CPPFLAGS = -Isrc -std=c++17 $(PROTOBUF_CFLAGS)
   test_newfeature_LDADD = $(PROTOBUF_LIBS) $(CAPNP_LIBS) -lz
   ```
3. Add to CI workflow if needed

### Adding an Integration Test

1. Create test script in `tests/test_*.sh`
2. Make executable: `chmod +x tests/test_*.sh`
3. Add to CI workflow under `integration-tests` job
4. Document in this file

## Platform-Specific Test Requirements

### macOS

- Requires Xcode Command Line Tools
- Qt apps must be code-signed for distribution (not needed for testing)
- Uses `.app` bundle format

### Linux

- Requires X11 or Wayland for GUI testing (use Xvfb for headless)
- May need to install libGL, libxcb, etc.
- Uses raw binary format

### Windows

- MSVC requires Visual Studio or Build Tools
- MinGW requires MSYS2 or similar
- Qt apps may need DLL bundling
- Uses `.exe` format

## Test Data

### Sample Files

Test data should be kept small and committed to the repository:

- `tests/data/sample.ggr` - Small reference file (< 1MB)
- `tests/data/large.ggr` - Larger reference file (optional, Git LFS)

### Generating Test Data

```python
# Use find_closest_relatives.py to generate test data
python find_closest_relatives.py --help
```

## Reporting Test Failures

When reporting a test failure, include:

1. **Platform**: macOS/Linux/Windows + version
2. **Compiler**: gcc/clang/MSVC + version
3. **Test name**: Which test failed
4. **Error output**: Full error message
5. **Environment**: Output of `conda list`
6. **Reproduction steps**: How to reproduce locally

## References

- [Qt Test Framework](https://doc.qt.io/qt-5/qtest-overview.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [conda-incubator/setup-miniconda](https://github.com/conda-incubator/setup-miniconda)
- [Autotools Testing](https://www.gnu.org/software/automake/manual/html_node/Tests.html)
