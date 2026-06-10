// Test program to verify compression/decompression behavior
// This tests the current fork()-based implementation and will be used
// to verify the threading-based replacement produces identical results

#include "src/harvest/HarvestIO.h"
#include <iostream>
#include <cstdio>
#include <cstring>
#include <sys/stat.h>

using namespace std;

int main(int argc, char* argv[]) {
    const char* testFile = "test_harvest.ggr";

    cout << "=== Testing HarvestIO Compression/Decompression ===" << endl;

    // Create a HarvestIO object with some simple test data
    HarvestIO writer;

    // Add a simple reference
    writer.referenceList.addReference("TestReference", "Test description", "ACGTACGTACGT");

    // Write the data (this uses fork() for compression)
    cout << "Writing compressed file: " << testFile << endl;
    try {
        writer.writeHarvest(testFile);
        cout << "✓ Write completed successfully" << endl;
    } catch (const exception& e) {
        cerr << "✗ Write failed: " << e.what() << endl;
        return 1;
    }

    // Read the data back (this uses fork() for decompression)
    cout << "Reading compressed file: " << testFile << endl;

    // Check if file exists and has size
    struct stat st;
    if (stat(testFile, &st) != 0) {
        cerr << "✗ File doesn't exist: " << testFile << endl;
        return 1;
    }
    cout << "File exists, size: " << st.st_size << " bytes" << endl;

    HarvestIO reader;
    try {
        bool success = reader.loadHarvest(testFile);
        cout << "loadHarvest returned: " << (success ? "true" : "false") << endl;
        if (!success) {
            cerr << "✗ Read failed (loadHarvest returned false)" << endl;
            return 1;
        }
        cout << "✓ Read completed successfully" << endl;
    } catch (const exception& e) {
        cerr << "✗ Read failed with exception: " << e.what() << endl;
        return 1;
    }

    // Verify the data matches
    cout << "Verifying data integrity..." << endl;

    if (reader.referenceList.getReferenceCount() != 1) {
        cerr << "✗ Reference count mismatch: expected 1, got "
             << reader.referenceList.getReferenceCount() << endl;
        return 1;
    }

    const Reference& ref = reader.referenceList.getReference(0);
    if (ref.name != "TestReference") {
        cerr << "✗ Name mismatch: expected 'TestReference', got '"
             << ref.name << "'" << endl;
        return 1;
    }

    if (ref.sequence != "ACGTACGTACGT") {
        cerr << "✗ Sequence mismatch: expected 'ACGTACGTACGT', got '"
             << ref.sequence << "'" << endl;
        return 1;
    }

    cout << "✓ Data integrity verified!" << endl;

    // Clean up test file
    remove(testFile);

    cout << "\n=== All tests passed! ===" << endl;
    return 0;
}
