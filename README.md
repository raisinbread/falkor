# Falkor Combat Script

A Mudlet combat automation script for Achaea, featuring auto-attack, butterfly catching, and rat farming capabilities.

## Project Structure

```
achaea/
├── src/              # Source Lua files (edit these)
│   ├── player.lua
│   ├── butterflies.lua
│   ├── rats.lua
│   └── main.lua
├── build/            # Build output (generated, don't edit)
│   └── achaea.lua
├── .vscode/          # VSCode configuration
│   └── tasks.json    # Build task configuration
├── build.sh          # Build script
└── README.md         # This file
```

## Building

To build the project, you can use either method:

### Command Line
```bash
./build.sh
```

### VSCode
Press `Cmd+Shift+B` (or `Ctrl+Shift+B` on Windows/Linux) to run the "🐉 Build Falkor" task.

This will:
1. Recursively find all `.lua` files in the `src/` directory
2. Concatenate them in alphabetical order
3. Output a single `achaea.lua` file to `build/`

The build file (`achaea.lua`) can then be imported into Mudlet.

## Usage in Mudlet

1. Build the project using `./build.sh`
2. Open Mudlet
3. Import the file: `build/achaea.lua`
   - You can drag and drop it into Mudlet, or
   - Use Mudlet's Script Editor to load it

## Commands

- `att <target>` - Begin auto-attacking a target
- `stop` - Stop auto-attacking
- `butterflies` - Toggle butterfly catching
- `sellrats` - Walk to Hakhim and sell rats

## Code Organization

The code follows Lua best practices:
- Uses a namespace pattern (`Falkor = Falkor or {}`) to avoid global pollution
- Object-oriented style with `self` for method calls
- Proper initialization and cleanup for reloading
- Modular structure ready for expansion

## Development

- Edit files in `src/` directory
- Run `./build.sh` to rebuild
- The build script preserves source file comments showing which file each section came from
- Files are concatenated in alphabetical order for deterministic builds
