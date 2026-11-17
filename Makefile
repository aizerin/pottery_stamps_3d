OPENSCAD ?= openscad
BUILD_DIR ?= build
FONT_DIR := $(CURDIR)/assets/fonts/Cause
OPENSCAD_WITH_FONTS := OPENSCAD_FONT_PATH="$(FONT_DIR):$$OPENSCAD_FONT_PATH" $(OPENSCAD)

.PHONY: head handle impression alphabet alphabet-uppercase test clean

head:
	mkdir -p "$(BUILD_DIR)"
	$(OPENSCAD_WITH_FONTS) -o "$(BUILD_DIR)/stamp-head.stl" stamp_generator.scad

handle:
	mkdir -p "$(BUILD_DIR)"
	$(OPENSCAD_WITH_FONTS) -o "$(BUILD_DIR)/handle.stl" -D 'part="handle"' stamp_generator.scad

impression:
	mkdir -p "$(BUILD_DIR)"
	$(OPENSCAD_WITH_FONTS) -o "$(BUILD_DIR)/impression.stl" -D 'part="impression"' stamp_generator.scad

alphabet:
	./scripts/generate.py alphabet --google-font Cause --case lowercase --height 10 --scale 0.75 -o "$(BUILD_DIR)/alphabet"

alphabet-uppercase:
	./scripts/generate.py alphabet --google-font Cause --case uppercase --height 10 --scale 0.75 -o "$(BUILD_DIR)/alphabet-uppercase"

test:
	./scripts/smoke-test.sh
	./scripts/test-cli.sh

clean:
	rm -rf "$(BUILD_DIR)"
