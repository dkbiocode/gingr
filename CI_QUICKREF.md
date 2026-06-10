# GitHub Actions CI - Quick Reference

## Running Tests Locally Before Push

```bash
# Activate environment
conda activate gingr-build

# Run all tests (recommended before pushing)
./test_all.sh

# Or run individual tests
cd harvest_src
./test_compression
./test_threading_portability
cd ..
./tests/smoke_test.sh
```

## CI Workflows

### Main CI Pipeline: `.github/workflows/ci.yml`

**Triggers:**
- Push to `master` or `develop`
- Pull requests to `master` or `develop`
- Manual dispatch

**Platforms Tested:**
- macOS 13 (Intel x86_64) + clang
- macOS 14 (Apple Silicon arm64) + clang
- Ubuntu 22.04 + gcc
- Ubuntu 22.04 + clang
- Windows 2022 + MSVC
- Windows 2022 + MinGW

**What it does:**
1. Sets up conda environment
2. Builds harvest-tools
3. Runs compression tests
4. Builds Gingr
5. Runs smoke tests
6. Uploads artifacts (binaries)

### Quick Test: `.github/workflows/quick-test.yml`

**Triggers:**
- Push to any branch (except master/develop)
- Pull requests

**Platform:** Ubuntu 22.04 only (for speed)

**Use for:** Rapid feedback during development

## Test Files

| File | Purpose | Location |
|------|---------|----------|
| `test_compression.cpp` | Basic compression test | `harvest_src/` |
| `test_threading_portability.cpp` | Comprehensive threading tests | `harvest_src/` |
| `smoke_test.sh` | Binary integrity test | `tests/` |
| `test_all.sh` | Run all tests locally | Root |

## Common Commands

```bash
# Build with threading enabled (Windows compatibility mode)
cd harvest_src
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17 -DUSE_THREADING=1" \
LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib" \
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX
make clean && make -j4

# Test both fork and threading implementations
./test_compression                    # Uses current build
CPPFLAGS="-DUSE_THREADING=1" make     # Rebuild with threading
./test_compression                    # Test threading version

# Check which mode is active
./test_threading_portability | grep "Threading mode"
```

## Troubleshooting Failed Builds

### View CI Logs

1. GitHub → Actions tab
2. Click failed workflow
3. Click failed job
4. Expand failed step

### Reproduce Locally

```bash
# Use exact same environment as CI
conda env create -f environment.yml
conda activate gingr-build

# Build with same commands as CI
./test_all.sh
```

### Download Failed Artifacts

1. Go to workflow run page
2. Scroll to "Artifacts" section
3. Download platform-specific artifact
4. Inspect locally

## Platform-Specific Notes

### macOS
- Uses `.app` bundle
- Binary at `Gingr.app/Contents/MacOS/Gingr`
- Check libraries: `otool -L Gingr.app/Contents/MacOS/Gingr`

### Linux
- Uses raw binary `gingr`
- Check libraries: `ldd gingr`
- May need Xvfb for GUI tests

### Windows
- Uses `gingr.exe`
- Binary in `release/gingr.exe` or root
- MSVC requires Visual Studio environment
- MinGW requires MSYS2 environment

## Testing Threading vs Fork

The critical portability feature is the threading implementation:

```bash
# macOS/Linux default: fork() based
cd harvest_src
make clean
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX
make -j4
./test_threading_portability
# Should show: "Threading mode: DISABLED (using fork())"

# Windows-compatible: thread based
make clean
CPPFLAGS="-I$CONDA_PREFIX/include -std=c++17 -DUSE_THREADING=1" \
./configure --prefix=$CONDA_PREFIX \
            --with-protobuf=$CONDA_PREFIX \
            --with-capnp=$CONDA_PREFIX
make -j4
./test_threading_portability
# Should show: "Threading mode: ENABLED (std::thread)"
```

## CI Status Badges

Add to README.md:

```markdown
[![Build Status](https://github.com/dkbiocode/gingr/actions/workflows/ci.yml/badge.svg)](https://github.com/dkbiocode/gingr/actions/workflows/ci.yml)
```

## Manual Workflow Dispatch

To manually trigger a build:

1. GitHub → Actions tab
2. Select workflow (ci.yml or quick-test.yml)
3. Click "Run workflow"
4. Select branch
5. Click "Run workflow" button

## Artifact Retention

- Build artifacts kept for **30 days**
- Download from workflow run page
- Useful for testing binaries on other machines

## Performance Tips

### Speed Up Local Testing

```bash
# Only build what changed
make -j$(nproc)  # Instead of make clean && make

# Skip Gingr build if only testing harvest-tools
cd harvest_src && make check

# Use quick-test workflow for PRs (single platform)
```

### Speed Up CI

- Quick test workflow runs on every push (fast feedback)
- Full CI only on master/develop (comprehensive testing)
- Use draft PRs to avoid triggering CI until ready

## What to Check Before Pushing

- [ ] All tests pass locally (`./test_all.sh`)
- [ ] No compiler warnings
- [ ] Threading mode tested (if changed HarvestIO.cpp)
- [ ] Code formatted consistently
- [ ] Commit message is descriptive

## Getting Help

- **Documentation**: See `TESTING.md` for detailed testing info
- **Issues**: Report at https://github.com/dkbiocode/gingr/issues
- **CI Docs**: https://docs.github.com/en/actions
