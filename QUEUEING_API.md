# Server-Side Queueing API Reference

## Core Functions

### `Falkor:addAction(action, persistent, name, queueType)`
Add an action to the queue or register a persistent action.

**Parameters:**
- `action` (string|function): Command string or function to execute
- `persistent` (boolean): If true, function is called on every prompt (for auto-attack, etc.)
- `name` (string, optional): Name for persistent actions (used for removal)
- `queueType` (string, optional): Queue type - defaults to "eqbal"

**Examples:**
```lua
-- Queue a simple command
Falkor:addAction("kill rat", false, nil, "eqbal")

-- Register persistent auto-attack function
Falkor:addAction(Falkor.handleAutoAttack, true, "falkor_autoattack")

-- Queue with specific queue type
Falkor:addAction("get gold", false, nil, "free")
```

### `Falkor:removeAction(name)`
Remove a persistent action by name.

**Parameters:**
- `name` (string): Name of the persistent action to remove

**Example:**
```lua
Falkor:removeAction("falkor_autoattack")
```

### `Falkor:processPersistentActions()`
Process all persistent actions (called automatically on every prompt).

### `Falkor:clearQueue(queueType)`
Clear server-side queue.

**Parameters:**
- `queueType` (string, optional): Specific queue to clear, or nil for all queues

**Examples:**
```lua
Falkor:clearQueue("eqbal")  -- Clear eqbal queue
Falkor:clearQueue()         -- Clear all queues
```

## Queue Types

### Simple Queue Types
- `"eqbal"` - Both equilibrium and balance (default)
- `"bal"` - Balance only
- `"eq"` - Equilibrium only
- `"free"` - Eqbal + not paralyzed + not stunned + not bound
- `"freestand"` - Free + standing
- `"full"` - Freestand + class balance
- `"class"` - Class balance
- `"ship"` - Ship command balance
- `"para"` - Not paralyzed
- `"unbound"` - Not bound
- `"stun"` - Not stunned

### Custom Queue Types
You can mix and match conditions using flags:
- `e` = Have equilibrium
- `b` = Have balance
- `c` = Have class balance
- `s` = Have ship balance
- `p` = Have paralysis
- `w` = Are bound
- `u` = Is upright (not prone)
- `t` = Is stunned

Use `!` to invert a condition.

**Examples:**
```lua
-- Execute when have class balance, not paralyzed, not stunned, standing
Falkor:addAction("attack", false, nil, "c!p!tu")

-- Execute when have eq+bal, not bound, not paralyzed, not stunned
Falkor:addAction("combo", false, nil, "eb!w!p!t")
```

## User Commands

### `fqueue`
Display the current server-side queue.

### `fclearqueue [type]`
Clear server queue.
- `fclearqueue` - Clear all queues
- `fclearqueue eqbal` - Clear eqbal queue only

## Configuration

### `config.queueing.showAlerts`
Show/hide server queue alert messages.

**Default:** `false`

**Example:**
```lua
Falkor:setConfig("queueing.showAlerts", true)
```

## Persistent Actions

Persistent actions are functions that run on every prompt to check if they should send a command. They're used for:
- Auto-attack
- Auto-abilities (Collide, Bulwark)
- Any repeating behavior that depends on game state

**Pattern:**
```lua
-- Track if we've queued this action
local queued = false

function Falkor.handleAutoSomething()
    -- Reset queued flag when we regain balance
    if Falkor.player.hasBalance and Falkor.player.hasEquilibrium then
        queued = false
    end
    
    -- Check conditions and queued flag
    if condition_met and not queued then
        -- Send the command directly - server will auto-queue if off balance
        send("command")
        queued = true
    end
end

-- Register as persistent action
Falkor:addAction(Falkor.handleAutoSomething, true, "falkor_something")
```

**Important:** 
- Persistent functions send commands via `send()`, NOT `addAction()`
- They must track a "queued" flag to prevent over-queueing
- Reset the flag when balance is regained
- The server's automatic queueing handles balance tracking
