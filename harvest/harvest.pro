######################################################################
# harvest.pro - Minimal harvest library for Gingr
# Cross-platform build using qmake (no autoconf needed)
######################################################################

TEMPLATE = lib
CONFIG += staticlib
CONFIG -= qt
CONFIG += c++17

TARGET = harvest

# Output directory
DESTDIR = ../lib
OBJECTS_DIR = build/obj
MOC_DIR = build/moc

# Include paths
INCLUDEPATH += src

# Conda include path - use CONDA_PREFIX environment variable
# Windows uses Library/include subdirectory, Unix uses include directly
win32 {
    CONDA_INCLUDE = $$(CONDA_PREFIX)/Library/include
} else {
    CONDA_INCLUDE = $$(CONDA_PREFIX)/include
}
!isEmpty(CONDA_INCLUDE) {
    INCLUDEPATH += $$CONDA_INCLUDE
    message("Using conda include path: $$CONDA_INCLUDE")
} else {
    warning("CONDA_PREFIX not set - protobuf/capnp headers may not be found")
}

# Platform-specific settings
unix {
    # Ensure C++17 on Unix (Cap'n Proto requires C++14+)
    QMAKE_CXXFLAGS += -std=c++17

    macx {
        # macOS
        QMAKE_CXXFLAGS += -stdlib=libc++
        QMAKE_MACOSX_DEPLOYMENT_TARGET = 11.0
    } else {
        # Linux
        QMAKE_CXXFLAGS += -include src/harvest/memcpyLink.h -D_GNU_SOURCE
        QMAKE_CFLAGS += -include src/harvest/memcpyLink.h
    }
}

win32 {
    # Windows - enable threading mode
    DEFINES += USE_THREADING=1
    # Ensure C++17 on Windows (Cap'n Proto requires C++14+)
    QMAKE_CXXFLAGS += /std:c++17
}

# Protobuf/Cap'n Proto code generation
# These files are pre-generated and checked in, but you can regenerate with:
# cd src/harvest/pb && protoc --cpp_out=. harvest.proto
# cd src/harvest/capnp && capnp compile -oc++ harvest.capnp

# Note: If you need to regenerate, uncomment these rules:
# protobuf.name = protobuf
# protobuf.input = src/harvest/pb/harvest.proto
# protobuf.output = src/harvest/pb/harvest.pb.cc
# protobuf.commands = protoc --proto_path=src/harvest/pb --cpp_out=src/harvest/pb ${QMAKE_FILE_IN}
# protobuf.variable_out = SOURCES
# QMAKE_EXTRA_COMPILERS += protobuf

# capnproto.name = capnproto
# capnproto.input = src/harvest/capnp/harvest.capnp
# capnproto.output = src/harvest/capnp/harvest.capnp.c++
# capnproto.commands = capnp compile -oc++:src/harvest/capnp ${QMAKE_FILE_IN}
# capnproto.variable_out = SOURCES
# QMAKE_EXTRA_COMPILERS += capnproto

# Source files
HEADERS += \
    src/harvest/AnnotationList.h \
    src/harvest/exceptions.h \
    src/harvest/HarvestIO.h \
    src/harvest/LcbList.h \
    src/harvest/memcpyLink.h \
    src/harvest/parse.h \
    src/harvest/PhylogenyTree.h \
    src/harvest/PhylogenyTreeNode.h \
    src/harvest/ReferenceList.h \
    src/harvest/ThreadPipe.h \
    src/harvest/ThreadPipeStream.h \
    src/harvest/TrackList.h \
    src/harvest/VariantList.h \
    src/harvest/pb/harvest.pb.h \
    src/harvest/capnp/harvest.capnp.h

SOURCES += \
    src/harvest/AnnotationList.cpp \
    src/harvest/HarvestIO.cpp \
    src/harvest/LcbList.cpp \
    src/harvest/parse.cpp \
    src/harvest/PhylogenyTree.cpp \
    src/harvest/PhylogenyTreeNode.cpp \
    src/harvest/ReferenceList.cpp \
    src/harvest/TrackList.cpp \
    src/harvest/VariantList.cpp \
    src/harvest/pb/harvest.pb.cc \
    src/harvest/capnp/harvest.capnp.c++

# Linux needs memcpy wrapper
unix:!macx {
    SOURCES += src/harvest/memcpyWrap.c
}

# Installation
headers.path = $$quote($$(CONDA_PREFIX)/include)
headers.files = src/harvest/*.h

target.path = $$quote($$(CONDA_PREFIX)/lib)

INSTALLS += target headers
