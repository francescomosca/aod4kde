CXX ?= g++
CXXFLAGS = -O2 -fPIC -DQT_NO_VERSION_TAGGING $(shell pkg-config --cflags Qt6Core Qt6DBus)
LDFLAGS = $(shell pkg-config --libs Qt6Core Qt6DBus)

BIN_DIR = ../bin
TARGET = $(BIN_DIR)/aod-ext-sensors

all: $(TARGET)

$(TARGET): aod-ext-sensors.cpp
	@mkdir -p $(BIN_DIR)
	$(CXX) $(CXXFLAGS) aod-ext-sensors.cpp $(LDFLAGS) -o $(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all clean

