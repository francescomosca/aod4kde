CXX ?= g++
CXXFLAGS = -O2 -fPIC -DQT_NO_VERSION_TAGGING $(shell pkg-config --cflags Qt6Core Qt6DBus) -I/usr/include/KF6/KI18n -I/usr/include/KF6
LDFLAGS = $(shell pkg-config --libs Qt6Core Qt6DBus) -lKF6I18n

all: aod-helper

aod-helper: aod-helper.cpp ../common/ConfigManager.h ../common/ExtensionScanner.h
	$(CXX) $(CXXFLAGS) aod-helper.cpp $(LDFLAGS) -o aod-helper

clean:
	rm -f aod-helper

.PHONY: all clean

