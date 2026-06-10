// Comprehensive threading portability test
// Tests that the threading-based compression works identically on all platforms
// This is critical for Windows compatibility where fork() is not available

#include "src/harvest/HarvestIO.h"
#include <iostream>
#include <cstdio>
#include <cstring>
#include <sys/stat.h>
#include <vector>
#include <string>

using namespace std;

// Test data generator
string generateSequence(size_t length) {
    const char* bases = "ACGT";
    string seq;
    seq.reserve(length);
    for (size_t i = 0; i < length; i++) {
        seq += bases[i % 4];
    }
    return seq;
}

// Test 1: Basic compression/decompression
bool test_basic_compression() {
    cout << "\n--- Test 1: Basic Compression/Decompression ---" << endl;
    const char* testFile = "test_basic.ggr";

    HarvestIO writer;
    writer.referenceList.addReference("Ref1", "Test reference", "ACGTACGTACGT");

    try {
        writer.writeHarvest(testFile);
    } catch (const exception& e) {
        cerr << "✗ Write failed: " << e.what() << endl;
        return false;
    }

    HarvestIO reader;
    try {
        if (!reader.loadHarvest(testFile)) {
            cerr << "✗ Read failed" << endl;
            return false;
        }
    } catch (const exception& e) {
        cerr << "✗ Read failed: " << e.what() << endl;
        return false;
    }

    // Verify
    if (reader.referenceList.getReferenceCount() != 1) {
        cerr << "✗ Reference count mismatch" << endl;
        return false;
    }

    const Reference& ref = reader.referenceList.getReference(0);
    if (ref.sequence != "ACGTACGTACGT") {
        cerr << "✗ Sequence mismatch" << endl;
        return false;
    }

    remove(testFile);
    cout << "✓ Basic compression test passed" << endl;
    return true;
}

// Test 2: Large data compression
bool test_large_data() {
    cout << "\n--- Test 2: Large Data Compression ---" << endl;
    const char* testFile = "test_large.ggr";

    HarvestIO writer;

    // Create multiple large references
    for (int i = 0; i < 5; i++) {
        string name = "LargeRef" + to_string(i);
        string seq = generateSequence(100000);  // 100KB sequence
        writer.referenceList.addReference(name, "Large test sequence", seq);
    }

    try {
        writer.writeHarvest(testFile);
    } catch (const exception& e) {
        cerr << "✗ Write failed: " << e.what() << endl;
        return false;
    }

    // Check file was actually compressed (should be < uncompressed size)
    struct stat st;
    if (stat(testFile, &st) == 0) {
        cout << "Compressed file size: " << st.st_size << " bytes" << endl;
        // 5 * 100KB = 500KB uncompressed, should be much smaller compressed
        if (st.st_size > 400000) {
            cerr << "⚠ Warning: File may not be properly compressed" << endl;
        }
    }

    HarvestIO reader;
    try {
        if (!reader.loadHarvest(testFile)) {
            cerr << "✗ Read failed" << endl;
            return false;
        }
    } catch (const exception& e) {
        cerr << "✗ Read failed: " << e.what() << endl;
        return false;
    }

    // Verify all references
    if (reader.referenceList.getReferenceCount() != 5) {
        cerr << "✗ Reference count mismatch: expected 5, got "
             << reader.referenceList.getReferenceCount() << endl;
        return false;
    }

    for (int i = 0; i < 5; i++) {
        const Reference& ref = reader.referenceList.getReference(i);
        if (ref.sequence.length() != 100000) {
            cerr << "✗ Sequence length mismatch for ref " << i << endl;
            return false;
        }
    }

    remove(testFile);
    cout << "✓ Large data compression test passed" << endl;
    return true;
}

// Test 3: Empty/edge cases
bool test_edge_cases() {
    cout << "\n--- Test 3: Edge Cases ---" << endl;
    const char* testFile = "test_edge.ggr";

    HarvestIO writer;

    // Add reference with empty description
    writer.referenceList.addReference("EmptyDesc", "", "ACGT");

    // Add reference with special characters in name
    writer.referenceList.addReference("Ref_with-special.chars", "Test", "NNNNACGT");

    try {
        writer.writeHarvest(testFile);
    } catch (const exception& e) {
        cerr << "✗ Write failed: " << e.what() << endl;
        return false;
    }

    HarvestIO reader;
    try {
        if (!reader.loadHarvest(testFile)) {
            cerr << "✗ Read failed" << endl;
            return false;
        }
    } catch (const exception& e) {
        cerr << "✗ Read failed: " << e.what() << endl;
        return false;
    }

    if (reader.referenceList.getReferenceCount() != 2) {
        cerr << "✗ Reference count mismatch" << endl;
        return false;
    }

    remove(testFile);
    cout << "✓ Edge cases test passed" << endl;
    return true;
}

// Test 4: Multiple read/write cycles
bool test_multiple_cycles() {
    cout << "\n--- Test 4: Multiple Read/Write Cycles ---" << endl;
    const char* testFile = "test_cycles.ggr";

    string originalSeq = generateSequence(1000);

    for (int cycle = 0; cycle < 3; cycle++) {
        cout << "  Cycle " << (cycle + 1) << "..." << endl;

        HarvestIO writer;
        writer.referenceList.addReference("CycleTest", "Cycle test", originalSeq);

        try {
            writer.writeHarvest(testFile);
        } catch (const exception& e) {
            cerr << "✗ Write failed on cycle " << cycle << ": " << e.what() << endl;
            return false;
        }

        HarvestIO reader;
        try {
            if (!reader.loadHarvest(testFile)) {
                cerr << "✗ Read failed on cycle " << cycle << endl;
                return false;
            }
        } catch (const exception& e) {
            cerr << "✗ Read failed on cycle " << cycle << ": " << e.what() << endl;
            return false;
        }

        const Reference& ref = reader.referenceList.getReference(0);
        if (ref.sequence != originalSeq) {
            cerr << "✗ Sequence mismatch on cycle " << cycle << endl;
            return false;
        }
    }

    remove(testFile);
    cout << "✓ Multiple cycles test passed" << endl;
    return true;
}

int main(int argc, char* argv[]) {
    cout << "==================================================" << endl;
    cout << "   Gingr Threading Portability Test Suite" << endl;
    cout << "==================================================" << endl;
    cout << "Platform: " <<
#ifdef _WIN32
        "Windows"
#elif __APPLE__
        "macOS"
#elif __linux__
        "Linux"
#else
        "Unix"
#endif
        << endl;

#ifdef USE_THREADING
    cout << "Threading mode: ENABLED (std::thread)" << endl;
#else
    cout << "Threading mode: DISABLED (using fork())" << endl;
#endif

    cout << "==================================================" << endl;

    int passed = 0;
    int total = 4;

    if (test_basic_compression()) passed++;
    if (test_large_data()) passed++;
    if (test_edge_cases()) passed++;
    if (test_multiple_cycles()) passed++;

    cout << "\n==================================================" << endl;
    cout << "Test Results: " << passed << "/" << total << " passed" << endl;
    cout << "==================================================" << endl;

    if (passed == total) {
        cout << "✓ ALL TESTS PASSED!" << endl;
        return 0;
    } else {
        cout << "✗ SOME TESTS FAILED" << endl;
        return 1;
    }
}
