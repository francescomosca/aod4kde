CXX ?= g++
CXXFLAGS = -O2 -fPIC $(shell pkg-config --cflags Qt6Core)
LDFLAGS = $(shell pkg-config --libs Qt6Core)

BIN_DIR = ../bin
TARGET = $(BIN_DIR)/aod-ext-example

all: $(TARGET)

$(TARGET): main.cpp
	@mkdir -p $(BIN_DIR)
	$(CXX) $(CXXFLAGS) main.cpp $(LDFLAGS) -o $(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all clean

