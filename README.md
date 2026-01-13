# Falkor Combat Script

A Mudlet combat automation script for Achaea, featuring auto-attack, butterfly catching, and rat farming capabilities.

## Prerequisites

Lua is required to build the project. On macOS, install it via Homebrew:

```bash
brew install lua
```

## Project Structure

```
achaea/
├── src/              # Source Lua files (edit these)
│   ├── player.lua
│   ├── butterflies.lua
│   ├── rats.lua
│   └── main.lua
├── build/            # Build output (generated, don't edit)
├── .vscode/          # VSCode configuration
│   └── tasks.json    # Build task configuration
├── build.lua          # Build script
└── README.md         # This file
```

## Building

To build the project, you can use either method:

### Command Line
```lua
lua build.lua
```

### VSCode
Press `Cmd+Shift+B` (or `Ctrl+Shift+B` on Windows/Linux) to run the "🐉 Build Falkor" task.

Building creates a new Mudlet XML package file.

## Usage in Mudlet

1. Build the project.
2. Open Mudlet
3. Open the Module Manager () (Toolbox > Module Manager)
4. Press the Install button, navigating to the XML file to complete the installation.

## Commands

- `att <target>` - Begin auto-attacking a target
- `stop` - Stop auto-attacking
- `butterflies` - Toggle butterfly catching
- `sellrats` - Walk to Hakhim and sell rats
- `falkor` - Reinstall Falkor module

## Code Organization

The code follows Lua best practices:
- Uses a namespace pattern (`Falkor = Falkor or {}`) to avoid global pollution
- Object-oriented style with `self` for method calls
- Proper initialization and cleanup for reloading
- Modular structure ready for expansion

## Development

- Edit files in `src/` directory
- Build the project
- Issue the `falkor` command in Mudlet to re-load the module.
