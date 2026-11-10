CXX ?= g++
BUILD_DIR = ../../build/settings
CXXFLAGS = -O2 -fPIC -DQT_NO_VERSION_TAGGING $(shell pkg-config --cflags Qt6Widgets Qt6Quick Qt6Qml Qt6DBus) -I/usr/include/KF6/KI18n -I/usr/include/KF6 -I$(BUILD_DIR)
LDFLAGS = $(shell pkg-config --libs Qt6Widgets Qt6Quick Qt6Qml Qt6DBus) -lKF6I18n
QT_LIBEXEC = $(shell pkg-config --variable=libexecdir Qt6Core 2>/dev/null)
MOC = $(shell if [ -x "$(QT_LIBEXEC)/moc" ]; then echo "$(QT_LIBEXEC)/moc"; elif which moc-qt6 >/dev/null 2>&1; then which moc-qt6; else echo moc; fi)

all: aod-settings

moc: $(BUILD_DIR)/aod-settings.moc

$(BUILD_DIR)/aod-settings.moc: aod-settings.cpp
	@mkdir -p $(BUILD_DIR)
	$(MOC) aod-settings.cpp -o $(BUILD_DIR)/aod-settings.moc

aod-settings: aod-settings.cpp $(BUILD_DIR)/aod-settings.moc
	$(CXX) $(CXXFLAGS) aod-settings.cpp $(LDFLAGS) -o aod-settings

clean:
	rm -rf aod-settings $(BUILD_DIR)

.PHONY: all moc clean

