FILTER   := redmine_textile.lua
SRC_DIR  := src
BUILD_DIR := build
SOURCES  := $(wildcard $(SRC_DIR)/*.redmine.md)
TARGETS  := $(patsubst $(SRC_DIR)/%.redmine.md,$(BUILD_DIR)/%.redmine.textile,$(SOURCES))

.PHONY: all clean list

all: $(TARGETS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.redmine.textile: $(SRC_DIR)/%.redmine.md $(FILTER) | $(BUILD_DIR)
	pandoc --lua-filter=$(FILTER) -f markdown -t textile '$<' -o '$@'

clean:
	rm -rf $(BUILD_DIR)

list:
	@echo "Sources: $(SOURCES)"
	@echo "Targets: $(TARGETS)"