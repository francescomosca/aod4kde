SUBDIRS = src/tray src/helper src/settings \
          src/extensions/io.github.aod4kde.notifications/daemon \
          src/extensions/io.github.aod4kde.sensors/daemon

.PHONY: all binaries translations clean compile-commands release $(SUBDIRS)

all: binaries translations

binaries: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

translations:
	bash tools/update-translations.sh

clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf build dist

compile-commands:
	python3 tools/generate-compile-commands.py

release:
	bash tools/package-release.sh

