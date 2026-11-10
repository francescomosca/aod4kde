CXX ?= g++
BUILD_DIR = ../../build/tray
CXXFLAGS = -O2 -fPIC -DQT_NO_VERSION_TAGGING $(shell pkg-config --cflags Qt6Widgets Qt6Svg) -I/usr/include/KF6/KI18n -I/usr/include/KF6 -I. -I$(BUILD_DIR)
LDFLAGS = $(shell pkg-config --libs Qt6Widgets Qt6Svg) -lKF6I18n
QT_LIBEXEC = $(shell pkg-config --variable=libexecdir Qt6Core 2>/dev/null)
MOC = $(shell if [ -x "$(QT_LIBEXEC)/moc" ]; then echo "$(QT_LIBEXEC)/moc"; elif which moc-qt6 >/dev/null 2>&1; then which moc-qt6; else echo moc; fi)

SRCS = aod-tray.cpp ExtensionSupervisor.cpp
MOC_SRCS = $(BUILD_DIR)/moc_ExtensionSupervisor.cpp
OBJS = $(BUILD_DIR)/aod-tray.o $(BUILD_DIR)/ExtensionSupervisor.o $(BUILD_DIR)/moc_ExtensionSupervisor.o

all: aod-tray

moc: $(BUILD_DIR)/aod-tray.moc $(MOC_SRCS)

$(BUILD_DIR)/aod-tray.moc: aod-tray.cpp
	@mkdir -p $(BUILD_DIR)
	$(MOC) aod-tray.cpp -o $(BUILD_DIR)/aod-tray.moc

$(BUILD_DIR)/moc_ExtensionSupervisor.cpp: ExtensionSupervisor.h
	@mkdir -p $(BUILD_DIR)
	$(MOC) ExtensionSupervisor.h -o $(BUILD_DIR)/moc_ExtensionSupervisor.cpp

$(BUILD_DIR)/aod-tray.o: aod-tray.cpp $(BUILD_DIR)/aod-tray.moc ExtensionSupervisor.h ../common/ConfigManager.h
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c aod-tray.cpp -o $@

$(BUILD_DIR)/ExtensionSupervisor.o: ExtensionSupervisor.cpp ExtensionSupervisor.h ../common/ConfigManager.h ../common/ExtensionScanner.h
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c ExtensionSupervisor.cpp -o $@

$(BUILD_DIR)/moc_ExtensionSupervisor.o: $(BUILD_DIR)/moc_ExtensionSupervisor.cpp
	@mkdir -p $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

aod-tray: $(OBJS)
	$(CXX) $(OBJS) $(LDFLAGS) -o aod-tray

clean:
	rm -rf aod-tray $(BUILD_DIR)

.PHONY: all moc clean
