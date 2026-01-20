# Server-Side Queueing Refactor

## Overview
Refactored the balance.lua module to use Achaea's built-in server-side queueing system instead of client-side queue management. This simplifies the codebase and leverages the game's native balance/equilibrium tracking.

## Key Changes

### balance.lua
- **Removed**: Client-side queue processing logic (`processQueue()`, `queueProcessed` flag, `actions` array)
- **Added**: Server-side queue integration via `QUEUE ADD` commands
- **Changed**: `addAction()` now sends commands directly to server queue or tracks persistent functions
- **Added**: `processPersistentActions()` for auto-attack and auto-ability functions
- **Added**: `clearQueue()` function to clear server queues
- **Added**: Aliases `fqueue` (view queue) and `fclearqueue` (clear queue)
- **Removed**: Balance/equilibrium triggers and prompt parsing (server handles this now)

### player.lua
- **Changed**: `handleAutoAttack()` now queues commands instead of sending directly
- **Changed**: `onPrompt()` calls `processPersistentActions()` instead of `processQueue()`
- **Updated**: All `addAction()` calls now include queue type parameter (default: "eqbal")

### runewarden.lua
- **Changed**: `handleAutoCollide()` and `handleAutoBulwark()` queue commands instead of sending directly
- **Updated**: Manual ability commands use server queue
- **Maintained**: Cooldown tracking (still client-side as server doesn't track this)

### butterflies.lua
- **Updated**: All `addAction()` calls include queue type parameter

### rats.lua
- **Updated**: All `addAction()` calls include queue type parameter

### config.lua
- **Added**: `queueing.showAlerts` configuration option

## Queue Types Used
- **eqbal**: Requires both balance and equilibrium (default for most actions)
- **free**: Requires balance, equilibrium, not paralyzed, not stunned, not bound
- **bal**: Requires only balance
- **eq**: Requires only equilibrium

## Benefits
1. **Reduced latency**: Server-side queueing executes commands immediately when balance is available
2. **Simpler code**: Removed complex client-side queue management logic
3. **More reliable**: Server has authoritative balance state
4. **Better performance**: No need to track balance state in multiple places

## Persistent Actions
Functions that need to run on every prompt (auto-attack, auto-abilities) are now tracked in `balance.persistentActions` and called via `processPersistentActions()`. These functions send commands directly and use a "queued" flag to prevent over-queueing. The server's automatic queueing handles balance tracking.

### How It Works
1. Persistent function checks conditions and "queued" flag
2. If conditions met and not queued, send command and set queued=true
3. Server automatically queues if off balance
4. When balance is regained, reset queued flag
5. Command executes and cycle repeats

## Configuration
Server-side queueing is automatically enabled on initialization:
- `CONFIG USEQUEUEING ON` - Enables automatic queueing
- `CONFIG SHOWQUEUEALERTS OFF` - Hides queue alert messages (configurable)

## Testing Recommendations
1. Test auto-attack with `att <target>`
2. Test battlerage abilities (Collide, Bulwark) during combat
3. Test butterfly catching
4. Test rat farming
5. Test gold pickup and auto-stand
6. Use `fqueue` to view server queue state
7. Use `fclearqueue` to clear queues if needed
