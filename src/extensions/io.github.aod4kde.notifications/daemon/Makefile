CXX ?= g++
BUILD_DIR = ../../../../build/notifications
QT_LIBEXEC = $(shell pkg-config --variable=libexecdir Qt6Core 2>/dev/null)
MOC = $(shell if [ -x "$(QT_LIBEXEC)/moc" ]; then echo "$(QT_LIBEXEC)/moc"; elif which moc-qt6 >/dev/null 2>&1; then which moc-qt6; else echo moc; fi)
CXXFLAGS = -O2 -fPIC -DQT_NO_VERSION_TAGGING $(shell pkg-config --cflags Qt6Gui Qt6Core) -I$(BUILD_DIR)
LDFLAGS = $(shell pkg-config --libs Qt6Gui Qt6Core)

BIN_DIR = ../bin
TARGET = $(BIN_DIR)/aod-ext-notifications

all: $(TARGET)

moc: $(BUILD_DIR)/aod-ext-notifications.moc

$(TARGET): aod-ext-notifications.cpp $(BUILD_DIR)/aod-ext-notifications.moc
	@mkdir -p $(BIN_DIR)
	$(CXX) $(CXXFLAGS) aod-ext-notifications.cpp $(LDFLAGS) -o $(TARGET)

$(BUILD_DIR)/aod-ext-notifications.moc: aod-ext-notifications.cpp
	@mkdir -p $(BUILD_DIR)
	$(MOC) aod-ext-notifications.cpp -o $(BUILD_DIR)/aod-ext-notifications.moc

clean:
	rm -rf $(BUILD_DIR) $(TARGET)

.PHONY: all moc clean
