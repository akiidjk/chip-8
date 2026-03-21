#!/usr/bin/env just --justfile
# === COMMON VARIABLES ===

RESET := "\\033[0m"
GREEN := "\\033[32m"
CYAN := "\\033[36m"

# Zig build specifics

ZIG := "zig"
EXEC_NAME := "chip_8"
BIN_DIR := "./bin"

# CROSS PLATFORM HELPERS

PATHSEP := if os() == "windows" { "\\" } else { "/" }
MKDIR_CMD := if os() == "windows" { "mkdir" } else { "mkdir -p" }
ECHO_CMD := if os() == "windows" { "echo" } else { "echo -e" }

# Display help information
help:
    @just --list

# === BUILD TARGETS ===

# Default: build debug
[group('build')]
build: zig-build
    @{{ ECHO_CMD }} "{{ GREEN }}[+] Build complete (debug)!{{ RESET }}"

[group('build')]
zig-build:
    @echo -e "{{ CYAN }}[*] Building (debug) with {{ ZIG }}...{{ RESET }}"
    @{{ MKDIR_CMD }} {{ BIN_DIR }}
    @{{ ZIG }} build
    @cp zig-out/bin/{{ EXEC_NAME }} {{ BIN_DIR }}{{ PATHSEP }}{{ EXEC_NAME }} || true
    @{{ ECHO_CMD }} "{{ GREEN }}[+] Zig debug build finished. Binary (if produced) copied to {{ BIN_DIR }}{{ PATHSEP }}{{ EXEC_NAME }}{{ RESET }}"

# Build release (optimized)
[group('build')]
zig-build-release:
    @echo -e "{{ CYAN }}[*] Building (release) with {{ ZIG }}...{{ RESET }}"
    @{{ MKDIR_CMD }} {{ BIN_DIR }}
    @{{ ZIG }} build -Doptimize=ReleaseFast
    @cp zig-out/bin/{{ EXEC_NAME }} {{ BIN_DIR }}{{ PATHSEP }}{{ EXEC_NAME }} || true
    @{{ ECHO_CMD }} "{{ GREEN }}[+] Zig release build finished. Binary (if produced) copied to {{ BIN_DIR }}{{ PATHSEP }}{{ EXEC_NAME }}{{ RESET }}"

# Run the built executable (debug)
[group('dev')]
run ROM: zig-build
    @echo -e "{{ CYAN }}[*] Running {{ EXEC_NAME }}...{{ RESET }}"
    @zig-out/bin/{{ EXEC_NAME }} {{ ROM }}

# Run the release binary if you prefer
[group('dev')]
run-release ROM: zig-build-release
    @echo -e "{{ CYAN }}[*] Running {{ EXEC_NAME }} (release)...{{ RESET }}"
    @{{ BIN_DIR }}{{ PATHSEP }}{{ EXEC_NAME }} {{ ROM }}

# === TESTS & LINT ===

[group('test')]
test:
    @echo -e "{{ CYAN }}[*] Running Zig tests...{{ RESET }}"
    @{{ ZIG }} test

[group('tools')]
fmt:
    @echo -e "{{ CYAN }}[*] Formatting project with {{ ZIG }} fmt...{{ RESET }}"
    @{{ ZIG }} fmt src/*.zig

[group('tools')]
lint:
    @echo -e "{{ CYAN }}[*] Lint check (fmt --check)...{{ RESET }}"
    @{{ ZIG }} fmt --check src/*.zig

# === CLEAN & INSTALL ===

[group('dev')]
clean:
    @echo -e "{{ CYAN }}[*] Cleaning zig cache, output and bin...{{ RESET }}"
    @rm -rf zig-cache zig-out {{ BIN_DIR }}
    @{{ ECHO_CMD }} "{{ GREEN }}[+] Clean complete!{{ RESET }}"

[group('dev')]
install: zig-build-release
    @echo -e "{{ CYAN }}[*] Installing binary to /usr/local/bin...{{ RESET }}"
    @sudo cp {{ BIN_DIR }}{{ PATHSEP }}{{ EXEC_NAME }} /usr/local/bin/{{ EXEC_NAME }}
    @{{ ECHO_CMD }} "{{ GREEN }}[+] Install complete!{{ RESET }}"
