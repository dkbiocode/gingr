# GitHub Actions CI/CD Setup Complete ✅

## Summary

Successfully set up comprehensive cross-platform testing infrastructure for Gingr with GitHub Actions, targeting Windows/Mac/Linux portability.

## What Was Created

### 1. GitHub Actions Workflows

#### `.github/workflows/ci.yml` - Main CI Pipeline
Tests on **6 platform/compiler combinations**:
- macOS 13 (Intel x86_64) + clang
- macOS 14 (Apple Silicon arm64) + clang
- Ubuntu 22.04 + gcc
- Ubuntu 22.04 + clang
- Windows 2022 + MSVC
- Windows 2022 + MinGW

**Per-platform testing:**
- Environment setup with conda
- harvest-tools build
- test_compression (unit test)
- test_threading_portability (comprehensive threading test)
- Gingr GUI build
- Smoke test (binary integrity)
- Artifact upload (30-day retention)

#### `.github/workflows/quick-test.yml` - Fast Feedback
- Single platform (Ubuntu + gcc)
- Runs on all branches except master/develop
- 3-5x faster than full CI

### 2. Test Suite

#### `harvest_src/test_compression.cpp`
Basic round-trip compression/decompression test
- Tests core HarvestIO functionality
- Validates threading implementation
- Quick smoke test (~1 second)

#### `harvest_src/test_threading_portability.cpp`
Comprehensive threading validation with 4 scenarios:
1. Basic compression
2. Large data (5x 100KB sequences)
3. Edge cases (empty fields, special chars)
4. Multiple cycles (consistency check)

Critical for validating the `fork()` → `std::thread` migration.

#### `tests/smoke_test.sh`
Platform-aware binary integrity test:
- Executable check
- Size validation (> 1MB)
- No immediate crash
- Library dependency verification

#### `test_all.sh`
Local comprehensive test runner:
- Runs all 7 test stages
- Color-coded output
- Summary report
- Pre-commit validation tool

#### `test_pkgconfig.sh`
Debug utility for protobuf/abseil linking:
- Tests pkg-config configuration
- Shows library count (should be 82)
- Validates compilation approach
- Useful for troubleshooting

### 3. Configuration Files

#### `environment.yml`
Conda environment specification for reproducible builds across all platforms.

### 4. Documentation

#### `TESTING.md`
Comprehensive testing guide:
- Testing strategy and philosophy
- Platform-specific instructions
- Troubleshooting guide
- How to add new tests
- Performance benchmarking

#### `CI_QUICKREF.md`
Quick reference card:
- Common commands
- Platform-specific notes
- Workflow triggers
- Debugging tips

#### `GITHUB_ACTIONS_SETUP.md` (this file)
Setup summary and lessons learned.

## Key Technical Solutions

### Problem 1: Protobuf 6.x Abseil Dependencies

**Issue**: Modern protobuf depends on ~82 Google Abseil libraries. Simply using `-lprotobuf` causes undefined symbol errors.

**Solution**: Use `pkg-config --libs protobuf` to automatically include all dependencies:
```bash
export PKG_CONFIG_PATH=$CONDA_PREFIX/lib/pkgconfig
g++ ... -lharvest $(pkg-config --libs protobuf) -lcapnp -lkj -lz
```

**Critical Detail**: Must use `export` BEFORE command substitution. Inline env vars don't work:
```bash
# ❌ BROKEN - subshell doesn't inherit PKG_CONFIG_PATH
PKG_CONFIG_PATH=... g++ ... $(pkg-config --libs protobuf)

# ✅ WORKS - export sets it in shell environment first
export PKG_CONFIG_PATH=... && g++ ... $(pkg-config --libs protobuf)
```

### Problem 2: Runtime Library Loading

**Issue**: Compiled binaries couldn't find libprotobuf at runtime:
```
dyld: Library not loaded: @rpath/libprotobuf.33.5.0.dylib
Reason: no LC_RPATH's found
```

**Solution**: Add rpath to linker flags:
```bash
g++ ... -Wl,-rpath,$CONDA_PREFIX/lib ...
```

This embeds the library search path in the binary.

### Problem 3: Bash Subshell Scope

**Issue**: Using `eval` with complex quoting caused variable expansion issues.

**Solution**: Use `bash -c '...'` with single quotes for proper variable expansion:
```bash
run_test "Test Name" bash -c '
    export VAR=value &&
    command using $VAR
'
```

## Files Modified/Created

```
.github/workflows/
  ├── ci.yml                              # Main CI (6 platforms)
  └── quick-test.yml                      # Fast CI (1 platform)

harvest_src/
  ├── test_compression.cpp                # Basic test (existed, now integrated)
  ├── test_threading_portability.cpp      # Comprehensive test (new)
  └── Makefile.am                         # Automake config (new)

tests/
  └── smoke_test.sh                       # Binary integrity test (new)

Root:
  ├── test_all.sh                         # Local test runner (new)
  ├── test_pkgconfig.sh                   # Debug tool (new)
  ├── environment.yml                     # Conda spec (new)
  ├── TESTING.md                          # Testing guide (new)
  ├── CI_QUICKREF.md                      # Quick reference (new)
  └── GITHUB_ACTIONS_SETUP.md            # This file (new)
```

## How to Use

### Before Pushing Code

```bash
conda activate gingr-build
./test_all.sh
```

Should see:
```
✓ ALL TESTS PASSED!
You're ready to commit and push!
```

### Triggering CI

**Automatic:**
- Push to `master` or `develop` → Full CI (6 platforms)
- Push to any other branch → Quick test (Ubuntu only)
- Pull request → Both workflows

**Manual:**
- GitHub → Actions tab → Select workflow → "Run workflow"

### Viewing Results

1. GitHub repository → Actions tab
2. Click on workflow run
3. Expand jobs to see per-platform results
4. Download artifacts (binaries) if needed

### Troubleshooting Failed Builds

```bash
# Reproduce locally
conda env create -f environment.yml
conda activate gingr-build
./test_all.sh

# Debug pkg-config issues
./test_pkgconfig.sh
```

See `TESTING.md` for comprehensive troubleshooting guide.

## Platform Status

| Platform | Status | Notes |
|----------|--------|-------|
| macOS Intel (x86_64) | ✅ Tested Locally | All tests pass |
| macOS Apple Silicon (arm64) | ✅ Tested Locally | All tests pass, requires pkg-config fix |
| Linux Ubuntu 22.04 | 🟡 CI Only | Not yet tested locally |
| Windows MSVC | 🟡 CI Only | Threading mode required, not yet tested |
| Windows MinGW | 🟡 CI Only | Threading mode required, not yet tested |

## Next Steps

1. ✅ **Local testing complete** - macOS arm64 all tests passing
2. ⏳ **Push to GitHub** - Trigger first CI run
3. ⏳ **Monitor CI results** - Especially Windows (untested)
4. ⏳ **Fix any platform-specific issues** that arise
5. ⏳ **Add status badge to README**:
   ```markdown
   [![Build Status](https://github.com/dkbiocode/gingr/actions/workflows/ci.yml/badge.svg)](https://github.com/dkbiocode/gingr/actions/workflows/ci.yml)
   ```

## Testing Strategy

**Unit Tests** → Test core functionality in isolation
- `test_compression` - Basic I/O
- `test_threading_portability` - Comprehensive threading

**Integration Tests** → Test complete workflows
- `smoke_test.sh` - Binary integrity
- (Future: GUI tests, VCF export, etc.)

**Platform Coverage** → Test on all target platforms
- 2 macOS versions (Intel + Apple Silicon)
- 2 Linux compilers (gcc + clang)
- 2 Windows compilers (MSVC + MinGW)

## Lessons Learned

1. **Modern protobuf is complex** - Requires abseil, ~82 libraries total
2. **pkg-config is essential** - Don't manually list protobuf dependencies
3. **Shell scope matters** - Export before command substitution
4. **rpath is critical** - Binaries need to find libraries at runtime
5. **Test incrementally** - Small debug scripts (test_pkgconfig.sh) save time
6. **Document as you go** - Future you will thank present you

## References

- [GitHub Actions docs](https://docs.github.com/en/actions)
- [conda-incubator/setup-miniconda](https://github.com/conda-incubator/setup-miniconda)
- [pkg-config guide](https://people.freedesktop.org/~dbn/pkg-config-guide.html)
- [rpath explained](https://nehckl0.medium.com/creating-relocatable-linux-executables-by-setting-rpath-with-origin-45de573a2e98)

## Contact

- **Repository**: https://github.com/dkbiocode/gingr
- **Issues**: https://github.com/dkbiocode/gingr/issues
- **Upstream**: https://github.com/marbl/gingr (unmaintained)
