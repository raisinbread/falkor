# Falkor Combat Script

A Mudlet combat automation script for Achaea, featuring auto-attack, butterfly catching, and rat farming capabilities.

## Prerequisites

Lua is required to build the project. On macOS, install it via Homebrew:

```bash
brew install lua
```

## Project Structure

```
falkor/
├── src/              # Source Lua files (edit these)
│   ├── log.lua       # Logging utilities
│   ├── main.lua      # Core utilities and startup
│   ├── player.lua    # Combat and prompt handling
│   ├── runewarden.lua # Battlerage abilities
│   ├── butterflies.lua # Butterfly catching
│   └── rats.lua      # Rat farming
├── build/            # Build output (generated, don't edit)
├── .vscode/          # VSCode configuration
│   └── tasks.json    # Build task configuration
├── build.lua         # Build script
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

### Combat
- `att <target>` - Begin auto-attacking a target
- `stop` - Stop auto-attacking

### Battlerage (Runewarden)
- `autocollide` - Toggle auto-Collide (14 rage, 16s cooldown)
- `autobulwark` - Toggle auto-Bulwark (28 rage, 45s cooldown)
- `collide [target]` - Manually use Collide
- `bulwark` - Manually use Bulwark
- `rage` - Show current rage and ability status

### Utility
- `butterflies` - Toggle butterfly catching
- `butterflies-start` - Walk to Vellis and set up butterfly catching
- `sellbutterflies` - Walk to Vellis and sell butterflies
- `sellrats` - Walk to Hakhim and sell rats
- `falkor` - Reinstall Falkor module

## Features

### SVOF Integration
Falkor integrates with SVOF (Svo's free system) for intelligent queue management:
- Uses `svo.doadd()` for one-off balance-dependent actions
- Uses `svo.addbalanceful()` for repeating combat actions
- Uses `svo.addbalanceless()` for off-balance abilities
- Automatic balance/equilibrium checking and queuing
- No command stacking or timing issues

### Battlerage System
The Runewarden module provides intelligent battlerage ability management:
- **Auto-Collide**: Automatically uses Collide when you have 14+ rage
- **Auto-Bulwark**: Automatically uses Bulwark when you have 28+ rage
- Tracks cooldowns (16s for Collide, 45s for Bulwark)
- Manual override commands available
- Real-time rage tracking from prompt

### Auto-Attack
- Intelligent target tracking from game prompt
- Automatic attack queueing via SVOF
- Auto-disables on target death or error conditions
- Integrates with battlerage abilities

## Code Organization

The code follows Lua best practices:
- Uses a namespace pattern (`Falkor = Falkor or {}`) to avoid global pollution
- Object-oriented style with `self` for method calls
- Proper initialization and cleanup for reloading
- Modular structure ready for expansion
- Event-driven architecture for SVOF integration

## Development

- Edit files in `src/` directory
- Build the project
- Issue the `falkor` command in Mudlet to re-load the module.
