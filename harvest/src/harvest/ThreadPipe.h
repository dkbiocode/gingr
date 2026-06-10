// Thread-safe pipe replacement for cross-platform compatibility
// Replaces Unix pipe() + fork() with std::thread + mutex/condition_variable
//
// This allows Windows portability while maintaining identical behavior

#ifndef ThreadPipe_h
#define ThreadPipe_h

#include <mutex>
#include <condition_variable>
#include <vector>
#include <algorithm>
#include <cstddef>

class ThreadPipe {
public:
    ThreadPipe() : closed_(false), error_(false) {}

    // Write data to the pipe (called by writer thread)
    // Returns number of bytes written, or -1 on error
    ssize_t write(const void* buf, size_t count) {
        std::unique_lock<std::mutex> lock(mutex_);

        if (error_) {
            return -1;
        }

        if (closed_) {
            return 0;
        }

        const char* data = static_cast<const char*>(buf);
        buffer_.insert(buffer_.end(), data, data + count);

        // Notify reader that data is available
        cv_.notify_one();

        return count;
    }

    // Read data from the pipe (called by reader thread)
    // Returns number of bytes read, 0 on EOF, or -1 on error
    ssize_t read(void* buf, size_t count) {
        std::unique_lock<std::mutex> lock(mutex_);

        // Wait for data to become available or pipe to close
        cv_.wait(lock, [this] { return !buffer_.empty() || closed_ || error_; });

        if (error_) {
            return -1;
        }

        if (buffer_.empty() && closed_) {
            return 0;  // EOF
        }

        size_t bytes_to_read = std::min(count, buffer_.size());
        char* dest = static_cast<char*>(buf);

        std::copy(buffer_.begin(), buffer_.begin() + bytes_to_read, dest);
        buffer_.erase(buffer_.begin(), buffer_.begin() + bytes_to_read);

        return bytes_to_read;
    }

    // Close the write end of the pipe
    void closeWrite() {
        std::unique_lock<std::mutex> lock(mutex_);
        closed_ = true;
        cv_.notify_all();
    }

    // Signal an error condition
    void setError() {
        std::unique_lock<std::mutex> lock(mutex_);
        error_ = true;
        cv_.notify_all();
    }

private:
    std::mutex mutex_;
    std::condition_variable cv_;
    std::vector<char> buffer_;
    bool closed_;
    bool error_;
};

#endif
