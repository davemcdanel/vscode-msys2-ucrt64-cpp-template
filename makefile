# Project Makefile
# Author: David Lee McDanel
# Date: 2025-03-02
# License: Public Domain (Unlicense) - see LICENSE.md
# Description: A custom Makefile for building, documenting, and installing the Hello World! - For C++ project.

# Project configuration
PROJECT_NAME = "vscode-msys2-ucrt64-cpp-template"
TARGET = $(notdir $(shell pwd))
TARGET_EXE = $(TARGET).exe
BUILD_ROOT = $(shell pwd)
BUILD_ID = $(shell date +%Y%m%d-%H:%M:%S)
COMMIT_MSG ?= "Automatic commit of successful build."
PLATFORM ?= "console"
RELEASE_REMOTE ?= origin

# Directory structure
SOURCE_DIR = Source_Files
HEADER_DIR = Header_Files
OBJECT_DIR = obj
BINARY_DIR = bin
DOCUMENT_DIR = docs

# File collections
SOURCE_FILES := $(wildcard $(SOURCE_DIR)/*.cpp)
OBJECT_FILES := $(patsubst $(SOURCE_DIR)/%.cpp,$(OBJECT_DIR)/%.o,$(SOURCE_FILES))
DEPENDENCY_FILES := $(OBJECT_FILES:.o=.d)

# Include dependencies
-include $(DEPENDENCY_FILES)

# Version extraction
VERSION = $(shell grep 'define VERSION_STRING' $(HEADER_DIR)/version.h | sed 's/.*VERSION_STRING "\(.*\)"/\1/')
export VERSION_STRING=$(VERSION)

# Platform-specific settings
ifeq ($(OS),Windows_NT)
	INSTALL_PATH = $(shell cygpath -u "$$USERPROFILE/AppData/Local/$(TARGET)")
	CONFIG_PATH = $(INSTALL_PATH)/.config
else
	INSTALL_PATH = $(HOME)/bin
	CONFIG_PATH = $(HOME)
endif

# Toolchain configuration
REMOVE = rm -f
CREATE_DIR = mkdir -p
COPY = install
FIND_UTIL = /usr/bin/find

CXX ?= /ucrt64/bin/g++
CXXFLAGS = -std=c++17 -I$(HEADER_DIR) -Wall -DBUILD_SYSTEM_OKAY -MMD -MP
LINKER ?= /ucrt64/bin/g++

ifeq ($(PLATFORM),console)
# Windows console application
	LDFLAGS = -Wall -lm -lpthread
else ifeq ($(PLATFORM),raspberry)
# Raspberry Pi with pigpio
	LDFLAGS = -Wall -I. -lm -lpthread -lpigpio -lrt # raspberry pi
else ifeq ($(PLATFORM),WinGUI)
# Windows GUI Application
	LDFLAGS = -Wall -I. -lm -lpthread -Wl,-subsystem,windows
else 
# Default Windows console application
	LDFLAGS = -Wall -lm -lpthread
endif

# Build type toggle - override with: make BUILD_MODE=release all
BUILD_MODE ?= debug

ifeq ($(BUILD_MODE),release)
	CXXFLAGS += -O2
else
	CXXFLAGS += -g -O0
endif

# Phony list
.PHONY: all update-version release-patch release-minor release-major clean verify-tools docs-clean docs-init docs commit push pull release run install uninstall test

# Primary build target
all: verify-tools update-version $(BINARY_DIR)/$(TARGET_EXE)
	@echo "Built $(TARGET_EXE) in $(BUILD_MODE) mode."

# Linking rule
$(BINARY_DIR)/$(TARGET_EXE): $(OBJECT_FILES)
	@$(CREATE_DIR) $(BINARY_DIR)
	@$(LINKER) $(OBJECT_FILES) $(LDFLAGS) -o $@
	@echo "Linked $(TARGET_EXE) successfully!"

# Compilation rule
$(OBJECT_DIR)/%.o: $(SOURCE_DIR)/%.cpp
	@$(CREATE_DIR) $(OBJECT_DIR)
	@$(CXX) $(CXXFLAGS) -c $< -o $@
	@echo "Compiled $< into $@"

# Version management
update-version:
	@GIT_DESC=$$(git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --long 2>/dev/null); \
	if [ -n "$$GIT_DESC" ]; then \
		TAG=$$(echo "$$GIT_DESC" | sed 's/-[0-9]*-g[0-9a-f]*$$//'); \
		COUNT=$$(echo "$$GIT_DESC" | sed 's/^.*-\([0-9]*\)-g[0-9a-f]*$$/\1/'); \
		HASH=$$(git rev-parse --short HEAD); \
		BASE=$$(echo "$$TAG" | sed 's/^v//'); \
	else \
		BASE="0.0.0"; \
		COUNT=$$(git rev-list --count HEAD 2>/dev/null || echo "0"); \
		HASH=$$(git rev-parse --short HEAD 2>/dev/null || echo "nogit"); \
	fi; \
	DIRTY=$$(git status --porcelain --untracked-files=normal | \
		sed '/^[^ ]* Doxyfile$$/d; /^[^ ]* Header_Files\/version\.h$$/d' | grep -q . && echo "-dirty" || true); \
	if [ "$$COUNT" = "0" ] && [ -z "$$DIRTY" ]; then \
		NEW_VER="$$BASE+g$$HASH"; \
	else \
		NEW_VER="$$BASE-dev.$$COUNT+g$$HASH$$DIRTY"; \
	fi; \
	$(CREATE_DIR) $(HEADER_DIR); \
	printf '/** @file version.h\n * @brief Git-generated version file. Do not edit manually.\n */\n#ifndef VERSION_H\n#define VERSION_H\n#define VERSION_STRING "%s"\n#define BUILD_ID "%s"\n#endif\n' "$$NEW_VER" "$(BUILD_ID)" > $(HEADER_DIR)/version.h; \
	echo "Updated $(HEADER_DIR)/version.h to version $$NEW_VER and build ID $(BUILD_ID)";

release-patch:
	@LATEST=$$(git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	MAJOR=$$(echo "$$LATEST" | sed 's/^v//' | cut -d. -f1); \
	MINOR=$$(echo "$$LATEST" | sed 's/^v//' | cut -d. -f2); \
	PATCH=$$(echo "$$LATEST" | sed 's/^v//' | cut -d. -f3); \
	PATCH=$$((PATCH + 1)); \
	TAG="v$$MAJOR.$$MINOR.$$PATCH"; \
	git tag -a "$$TAG" -m "Release $$TAG" && \
	git push $(RELEASE_REMOTE) "$$TAG" || exit 1; \
	echo "Created and pushed $$TAG"

release-minor:
	@LATEST=$$(git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	MAJOR=$$(echo "$$LATEST" | sed 's/^v//' | cut -d. -f1); \
	MINOR=$$(echo "$$LATEST" | sed 's/^v//' | cut -d. -f2); \
	MINOR=$$((MINOR + 1)); \
	TAG="v$$MAJOR.$$MINOR.0"; \
	git tag -a "$$TAG" -m "Release $$TAG" && \
	git push $(RELEASE_REMOTE) "$$TAG" || exit 1; \
	echo "Created and pushed $$TAG"

release-major:
	@LATEST=$$(git describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	MAJOR=$$(echo "$$LATEST" | sed 's/^v//' | cut -d. -f1); \
	MAJOR=$$((MAJOR + 1)); \
	TAG="v$$MAJOR.0.0"; \
	git tag -a "$$TAG" -m "Release $$TAG" && \
	git push $(RELEASE_REMOTE) "$$TAG" || exit 1; \
	echo "Created and pushed $$TAG"

$(HEADER_DIR)/version.h:
	@$(CREATE_DIR) $(HEADER_DIR)
	@echo "/** @file version.h" > $@
	@echo " * @brief Auto-generated version file. Do not edit manually." >> $@
	@echo " * @copyright Copyright (c) 2025 David Lee McDanel" >> $@
	@echo " * @n @n This is free and unencumbered software released into the public domain under the Unlicense (see LICENSE.md)." >> $@
	@echo " */" >> $@
	@echo "#ifndef VERSION_H" >> $@
	@echo "#define VERSION_H" >> $@
	@echo "#define VERSION_STRING \"0.0.0\"" >> $@
	@echo "#define BUILD_ID \"$(BUILD_ID)\"" >> $@
	@echo "#endif" >> $@
	@echo "Initialized $(HEADER_DIR)/version.h to version 0.0.0 and build ID $(BUILD_ID)"

# Cleanup target
clean:
	@$(REMOVE) $(OBJECT_FILES) $(DEPENDENCY_FILES)
	@echo "Cleared object and dependency files."
	@$(REMOVE) $(BINARY_DIR)/$(TARGET_EXE)
	@echo "Removed executable."

# Tool verification
verify-tools:
	@/ucrt64/bin/g++ --version >/dev/null 2>&1 || { echo "Error: /ucrt64/bin/g++ not found"; exit 1; }
	@doxygen --version >/dev/null 2>&1 || { echo "Warning: Doxygen not found in PATH; 'docs' target will fail"; }

# Doxyfile creation
Doxyfile:
	@echo "Generating minimal Doxyfile..."
	@doxygen -s -g Doxyfile
	@echo "Minimal Doxyfile created."
	@sed -i '/^EXTRACT_ALL[ \t]*=/c\EXTRACT_ALL = YES' Doxyfile || echo "EXTRACT_ALL = YES" >> Doxyfile
	@sed -i '/^SOURCE_BROWSER[ \t]*=/c\SOURCE_BROWSER = YES' Doxyfile || echo "SOURCE_BROWSER = YES" >> Doxyfile
	@sed -i '/^GENERATE_TREEVIEW[ \t]*=/c\GENERATE_TREEVIEW = YES' Doxyfile || echo "GENERATE_TREEVIEW = YES" >> Doxyfile
	@sed -i '/^GENERATE_LATEX[ \t]*=/c\GENERATE_LATEX = NO' Doxyfile || echo "GENERATE_LATEX = NO" >> Doxyfile
	@echo "Basic HTML output with tree view.  Setting can be overridden in Doxyfile."

# Documentation cleanup
docs-clean:
	@test -d $(DOCUMENT_DIR) && cd $(DOCUMENT_DIR) && $(FIND_UTIL) . -type f -not -name "PlaceHolder.txt" -exec $(REMOVE) {} \;
	@test -d $(DOCUMENT_DIR) && cd $(DOCUMENT_DIR) && $(FIND_UTIL) . -type d -not -path . -exec rmdir {} \; 2>/dev/null || true
	@echo "Cleaned documentation, kept PlaceHolder.txt."

# Documentation initialization
docs-init:
	@test -d $(DOCUMENT_DIR) || $(CREATE_DIR) $(DOCUMENT_DIR)
	@test -f $(DOCUMENT_DIR)/PlaceHolder.txt || echo "Placeholder for documentation directory" > $(DOCUMENT_DIR)/PlaceHolder.txt
	@echo "$(DOCUMENT_DIR)/PlaceHolder.txt initialized."

# Documentation generation
docs: docs-clean docs-init update-version Doxyfile
	@sed -i '/^INPUT[ \t]*=/c\INPUT = . $(shell cygpath -w $(SOURCE_DIR)) $(shell cygpath -w $(HEADER_DIR))' Doxyfile || echo "INPUT = . $(shell cygpath -w $(SOURCE_DIR)) $(shell cygpath -w $(HEADER_DIR))" >> Doxyfile
	@sed -i '/^OUTPUT_DIRECTORY[ \t]*=/c\OUTPUT_DIRECTORY = $(shell cygpath -w $(DOCUMENT_DIR))' Doxyfile || echo "OUTPUT_DIRECTORY = $(shell cygpath -w $(DOCUMENT_DIR))" >> Doxyfile
	@sed -i '/^PROJECT_NUMBER[ \t]*=/c\PROJECT_NUMBER = \"$(VERSION)\"' Doxyfile || echo "PROJECT_NUMBER = \"$(VERSION)\"" >> Doxyfile
	@sed -i '/^PROJECT_NAME[ \t]*=/c\PROJECT_NAME = $(PROJECT_NAME)' Doxyfile || echo "PROJECT_NAME = $(PROJECT_NAME)" >> Doxyfile
	@doxygen Doxyfile
	@echo "Generated documentation in $(DOCUMENT_DIR)/"

# Git operations
commit:
	@cd $(BUILD_ROOT) && \
	pwd && \
	git add -A . && \
	git commit -m "$(COMMIT_MSG) Build:$(BUILD_ID)"

push:
	@git push $(RELEASE_REMOTE) main

pull:
	@git pull $(RELEASE_REMOTE) main

release: all test commit push
	@echo "Released tested build with Git sync."

# Config file generation
$(BUILD_ROOT)/.$(TARGET)/$(TARGET).conf:
	@$(CREATE_DIR) $(BUILD_ROOT)/.$(TARGET)
	@echo "# Default configuration for $(TARGET)" > $@
	@echo "Generated default config at $@"

# Run target
run: $(BUILD_ROOT)/.$(TARGET)/$(TARGET).conf $(BINARY_DIR)/$(TARGET_EXE)
	@"$(BINARY_DIR)/$(TARGET_EXE)"

# Installation
install: $(BUILD_ROOT)/.$(TARGET)/$(TARGET).conf $(BINARY_DIR)/$(TARGET_EXE)
	@if [ "$(INSTALL_PATH)" = "$(HOME)/bin" ] && [ ! -w "$(INSTALL_PATH)" ]; then \
		test "$$(id -u)" -ne 0 && { echo "Error: $(INSTALL_PATH) requires sudo privileges; run 'sudo make install'"; exit 1; }; \
	fi
	@test -d "$(INSTALL_PATH)" || $(CREATE_DIR) "$(INSTALL_PATH)" || { echo "Error: Failed to create install directory $(INSTALL_PATH)"; exit 1; }
	@$(COPY) $(BINARY_DIR)/$(TARGET_EXE) "$(INSTALL_PATH)/" || { echo "Error: Failed to install $(TARGET_EXE) to $(INSTALL_PATH)"; exit 1; }
	@$(CREATE_DIR) "$(CONFIG_PATH)" || { echo "Error: Failed to create $(CONFIG_PATH)"; exit 1; }
	@if [ -f "$(CONFIG_PATH)/$(TARGET).conf" ]; then \
		$(COPY) "$(CONFIG_PATH)/$(TARGET).conf" "$(CONFIG_PATH)/$(TARGET).conf.bak.$(BUILD_ID)"; \
		echo "Backed up config to $(CONFIG_PATH)/$(TARGET).conf.bak.$(BUILD_ID)"; \
	fi
	@$(COPY) $(BUILD_ROOT)/.$(TARGET)/$(TARGET).conf "$(CONFIG_PATH)/$(TARGET).conf" || \
		{ echo "Warning: No config file found to install"; }
	@echo "Installed $(TARGET_EXE) to $(INSTALL_PATH)"
	@echo "Config placed at $(CONFIG_PATH)/$(TARGET).conf"

# Uninstall
uninstall:
	@$(REMOVE) "$(INSTALL_PATH)/$(TARGET_EXE)"
	@$(REMOVE) "$(CONFIG_PATH)/$(TARGET).conf"
	@if [ -d "$(CONFIG_PATH)" ] && [ -z "$$(ls -A "$(CONFIG_PATH)")" ]; then \
		rmdir "$(CONFIG_PATH)"; \
		echo "Removed empty $(CONFIG_PATH)"; \
	fi
	@echo "Uninstalled $(TARGET_EXE) from $(INSTALL_PATH)"
	@echo "Removed config from $(CONFIG_PATH)"

# Test with inputs 5 + 10
test: $(BINARY_DIR)/$(TARGET_EXE)
	@echo "Testing basic addition..."
	@"$(BINARY_DIR)/$(TARGET_EXE)" 5 10
	@echo "Basic addition test passed."
	@echo "Testing input handling..."
	@echo -e "5\n10\n\n\n" | "$(BINARY_DIR)/$(TARGET_EXE)" > /dev/null && echo "Input handling test passed."
