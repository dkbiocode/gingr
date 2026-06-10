// Cap'n Proto stream adapters for ThreadPipe
// Allows ThreadPipe to work with Cap'n Proto's MessageReader/Writer

#ifndef ThreadPipeStream_h
#define ThreadPipeStream_h

#include "ThreadPipe.h"
#include <kj/io.h>

class ThreadPipeInputStream : public kj::InputStream {
public:
    explicit ThreadPipeInputStream(ThreadPipe* pipe) : pipe_(pipe) {}

    size_t tryRead(void* buffer, size_t minBytes, size_t maxBytes) override {
        size_t totalRead = 0;
        char* buf = static_cast<char*>(buffer);

        while (totalRead < minBytes) {
            ssize_t bytesRead = pipe_->read(buf + totalRead, maxBytes - totalRead);

            if (bytesRead < 0) {
                // Error
                return totalRead;
            }

            if (bytesRead == 0) {
                // EOF
                break;
            }

            totalRead += bytesRead;
        }

        return totalRead;
    }

private:
    ThreadPipe* pipe_;
};

class ThreadPipeOutputStream : public kj::OutputStream {
public:
    explicit ThreadPipeOutputStream(ThreadPipe* pipe) : pipe_(pipe) {}

    void write(const void* buffer, size_t size) override {
        const char* buf = static_cast<const char*>(buffer);
        size_t totalWritten = 0;

        while (totalWritten < size) {
            ssize_t bytesWritten = pipe_->write(buf + totalWritten, size - totalWritten);

            if (bytesWritten < 0) {
                // Error
                throw std::runtime_error("ThreadPipe write error");
            }

            totalWritten += bytesWritten;
        }
    }

    void write(kj::ArrayPtr<const kj::ArrayPtr<const kj::byte>> pieces) override {
        for (auto& piece : pieces) {
            write(piece.begin(), piece.size());
        }
    }

private:
    ThreadPipe* pipe_;
};

#endif
