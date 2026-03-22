# Chip-8 Emulator

A Chip-8 interpreter implementation written in Zig, utilizing SDL2 for graphics, input, and audio.

## Dependencies

- Zig Compiler
- SDL2 development libraries

## Building

You can build the project using `zig build` directly or via `just` if installed.

### Using Just

Debug build:
```bash
just build
```

Release build:
```bash
just build-release
```

### Using Zig

Debug build:
```bash
zig build
```

Release build (this build will remove all logs about the state of the chip8):
```bash
zig build -Doptimize=ReleaseFast
```

The compiled executable will be placed in `zig-out/bin/chip_8` (or `./bin/chip_8` when using `just`).

## Usage

Run the emulator by providing the path to a ROM file.

### Using Just

```bash
just run <path_to_rom>
```

### Manual Execution

```bash
./bin/chip_8 <path_to_rom> [optional_breakpoint_address]
```

### Arguments

1. **ROM Path**: File path to the Chip-8 ROM.
2. **Breakpoint**: (Optional) Hexadecimal address (without `0x`) to trigger a breakpoint.

### Example

```bash
./bin/chip_8 roms/Games/Pong.ch8
```

## Controls

The original hex keypad is mapped to the left side of the keyboard:

| Chip-8 Key | Keyboard Key |
|------------|--------------|
| 1          | 1            |
| 2          | 2            |
| 3          | 3            |
| C          | 4            |
| 4          | Q            |
| 5          | W            |
| 6          | E            |
| D          | R            |
| 7          | A            |
| 8          | S            |
| 9          | D            |
| E          | F            |
| A          | Z            |
| 0          | X            |
| B          | C            |
| F          | V            |

Use `Ctrl+C` or close the window to exit.

## Quirks

This emulator implements the following behaviors for ambiguous Chip-8 instructions:

- **Shift (`8xy6`, `8xyE`)**: Operates on `Vx` in place (ignores `Vy`).
- **Memory (`Fx55`, `Fx65`)**: The index register `I` is incremented.
- **Logic (`8xy1`, `8xy2`, `8xy3`)**: `VF` is reset to 0.
- **Drawing**: Sprites clip at the screen edges (no wrap-around).
