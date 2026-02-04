-- Main initialization and startup message
-- This file provides utility functions and runs after all modules are loaded

Falkor = Falkor or {}

-- ============================================
-- REGISTRY SYSTEM
-- ============================================

-- Initialize registry for tracking triggers and aliases
function Falkor:initRegistry()
    self.registry = {
        triggers = {},  -- { name -> { id, pattern, code, isRegex, enabled } }
        aliases = {},   -- { name -> { id, pattern, code, enabled } }
    }
end

-- ============================================
-- TRIGGER MANAGEMENT
-- ============================================

-- Register a trigger with automatic cleanup and registry tracking
-- name: unique identifier (e.g., "triggerPrompt")
-- pattern: trigger pattern string
-- code: trigger code string
-- isRegex: true for regex trigger, false for simple trigger (default: false)
function Falkor:registerTrigger(name, pattern, code, isRegex)
    -- Initialize registry if needed
    if not self.registry then
        self:initRegistry()
    end
    
    -- Clean up existing trigger if it exists
    if self.registry.triggers[name] then
        local entry = self.registry.triggers[name]
        if entry.id then
            killTrigger(entry.id)
        end
    end
    
    -- Create new trigger
    local id
    if isRegex then
        id = tempRegexTrigger(pattern, code)
    else
        id = tempTrigger(pattern, code)
    end
    
    -- Store in registry
    self.registry.triggers[name] = {
        id = id,
        pattern = pattern,
        code = code,
        isRegex = isRegex or false,
        enabled = true,
    }
    
    -- Maintain backward compatibility: also store on self for existing code
    self[name] = id
    
    return id
end

-- Note: Mudlet doesn't support enable/disable for triggers
-- The enabled flag is tracked for informational purposes only

-- Remove a trigger completely
function Falkor:unregisterTrigger(name)
    if not self.registry or not self.registry.triggers[name] then
        return false
    end
    
    local entry = self.registry.triggers[name]
    if entry.id then
        killTrigger(entry.id)
    end
    
    self.registry.triggers[name] = nil
    self[name] = nil
    return true
end

-- Get trigger information
function Falkor:getTrigger(name)
    if not self.registry or not self.registry.triggers[name] then
        return nil
    end
    return self.registry.triggers[name]
end

-- List all registered triggers
function Falkor:listTriggers()
    if not self.registry then
        return {}
    end
    
    local list = {}
    for name, entry in pairs(self.registry.triggers) do
        table.insert(list, {
            name = name,
            pattern = entry.pattern,
            isRegex = entry.isRegex,
            enabled = entry.enabled,
        })
    end
    return list
end

-- ============================================
-- ALIAS MANAGEMENT
-- ============================================

-- Register an alias with automatic cleanup and registry tracking
-- name: unique identifier (e.g., "aliasAttack")
-- pattern: alias pattern string
-- code: alias code string
function Falkor:registerAlias(name, pattern, code)
    -- Initialize registry if needed
    if not self.registry then
        self:initRegistry()
    end
    
    -- Clean up existing alias if it exists
    if self.registry.aliases[name] then
        local entry = self.registry.aliases[name]
        if entry.id then
            killAlias(entry.id)
        end
    end
    
    -- Create new alias
    local id = tempAlias(pattern, code)
    
    -- Store in registry
    self.registry.aliases[name] = {
        id = id,
        pattern = pattern,
        code = code,
        enabled = true,
    }
    
    -- Maintain backward compatibility: also store on self for existing code
    self[name] = id
    
    return id
end

-- Note: Mudlet doesn't support enable/disable for aliases
-- The enabled flag is tracked for informational purposes only

-- Remove an alias completely
function Falkor:unregisterAlias(name)
    if not self.registry or not self.registry.aliases[name] then
        return false
    end
    
    local entry = self.registry.aliases[name]
    if entry.id then
        killAlias(entry.id)
    end
    
    self.registry.aliases[name] = nil
    self[name] = nil
    return true
end

-- Get alias information
function Falkor:getAlias(name)
    if not self.registry or not self.registry.aliases[name] then
        return nil
    end
    return self.registry.aliases[name]
end

-- List all registered aliases
function Falkor:listAliases()
    if not self.registry then
        return {}
    end
    
    local list = {}
    for name, entry in pairs(self.registry.aliases) do
        table.insert(list, {
            name = name,
            pattern = entry.pattern,
            enabled = entry.enabled,
        })
    end
    return list
end

-- ============================================
-- REGISTRY UTILITIES
-- ============================================

-- Get registry statistics
function Falkor:getRegistryStats()
    if not self.registry then
        return { triggers = 0, aliases = 0, timers = 0 }
    end
    
    local triggerCount = 0
    local aliasCount = 0
    local timerCount = 0
    
    for _ in pairs(self.registry.triggers) do
        triggerCount = triggerCount + 1
    end
    for _ in pairs(self.registry.aliases) do
        aliasCount = aliasCount + 1
    end
    if self.timers and self.timers.active then
        for _ in pairs(self.timers.active) do
            timerCount = timerCount + 1
        end
    end
    
    return {
        triggers = triggerCount,
        aliases = aliasCount,
        timers = timerCount,
    }
end

-- Clean up all registered items (useful for module reload)
function Falkor:cleanupRegistry()
    if not self.registry then
        return
    end
    
    -- Clean up all triggers
    for name, entry in pairs(self.registry.triggers) do
        if entry.id then
            killTrigger(entry.id)
        end
        self[name] = nil
    end
    
    -- Clean up all aliases
    for name, entry in pairs(self.registry.aliases) do
        if entry.id then
            killAlias(entry.id)
        end
        self[name] = nil
    end
    
    -- Reset registry
    self.registry = {
        triggers = {},
        aliases = {},
    }
end

-- Comprehensive cleanup function for module uninstall
function Falkor:cleanup()
    -- Get stats before cleanup for reporting
    local stats = self:getRegistryStats()
    
    -- Clean up registry (triggers and aliases)
    self:cleanupRegistry()
    
    -- Clean up timers
    self:cleanupTimers()
    
    -- Clean up combat module (disable tracking and clear state)
    if self.cleanupCombat then
        self:cleanupCombat()
    end
    
    -- Clear any persistent actions and callbacks
    if self.balance then
        self.balance.persistentActions = {}
        self.balance.persistentCallbacks = {}
    end
    
    -- Log cleanup completion with stats
    self:log(string.format(
        "<yellow>Cleanup complete: <white>%d triggers, %d aliases, %d timers removed",
        stats.triggers,
        stats.aliases,
        stats.timers
    ))
end

-- Initialize timer tracking
function Falkor:initTimers()
    self.timers = {
        active = {},  -- { id -> { name, time, func } }
    }
end

-- Register a timer with automatic cleanup tracking
-- name: unique identifier for the timer
-- time: delay in seconds
-- func: function to execute (can be string or function)
-- Returns: timer ID
function Falkor:registerTimer(name, time, func)
    -- Initialize timers if needed
    if not self.timers then
        self:initTimers()
    end
    
    -- Clean up existing timer if it exists
    if self.timers.active[name] then
        local entry = self.timers.active[name]
        if entry.id then
            killTimer(entry.id)
        end
    end
    
    -- Create wrapper function that removes from tracking after execution
    local wrappedFunc
    if type(func) == "function" then
        wrappedFunc = function()
            func()
            -- Remove from tracking after execution
            if Falkor.timers and Falkor.timers.active then
                Falkor.timers.active[name] = nil
            end
        end
    else
        -- If func is a string, we can't wrap it, so just track it
        wrappedFunc = func
    end
    
    -- Create timer
    local id = tempTimer(time, wrappedFunc)
    
    -- Store in tracking
    self.timers.active[name] = {
        id = id,
        time = time,
        func = func,
    }
    
    return id
end

-- Clean up all tracked timers
function Falkor:cleanupTimers()
    if not self.timers then
        return
    end
    
    for name, entry in pairs(self.timers.active) do
        if entry.id then
            killTimer(entry.id)
        end
    end
    
    self.timers.active = {}
end

-- Initialize registry and timer tracking on module load
Falkor:initRegistry()
Falkor:initTimers()

-- Reset reload flag on module load
Falkor.reloadInProgress = false

-- Get registry stats for initialization message
local stats = Falkor:getRegistryStats()

Falkor:log("<green>========================================")
Falkor:log("<green>Falkor Combat Script Loaded!")
Falkor:log("<green>========================================")
Falkor:log(string.format("<gray>Registered %d triggers, %d aliases, %d timers", stats.triggers, stats.aliases, stats.timers))
Falkor:log("<cyan>Combat Commands:")
Falkor:log("<white>  fhunt <name>        - Start hunting denizens (e.g., 'fhunt rat')")
Falkor:log("<cyan>Status Commands:")
Falkor:log("<white>  fplayer             - Show player status (vitals, balance, target)")
Falkor:log("<cyan>Utility Commands:")
Falkor:log("<white>  butterflies-start   - Walk to Vellis and set up butterfly catching")
Falkor:log("<white>  sellbutterflies     - Walk to Vellis and sell butterflies")
Falkor:log("<white>  sellrats            - Walk to Hakhim and sell rats")
Falkor:log("<cyan>Knowledge Base:")
Falkor:log("<white>  fquery <question>   - Query the local knowledge base")
Falkor:log("<cyan>System Commands:")
Falkor:log("<white>  falkor              - Reinstall Falkor module (with automatic cleanup)")
Falkor:log("<green>========================================")

-- ============================================
-- MAIN ALIASES
-- ============================================

-- Create alias: falkor (reinstall Falkor module)
Falkor:registerAlias("aliasReinstall", "^falkor$", [[
    -- Prevent multiple simultaneous reloads
    if Falkor.reloadInProgress then
        return
    end
    
    Falkor.reloadInProgress = true
    
    -- Run comprehensive cleanup before uninstall
    Falkor:cleanup()
    
    -- Uninstall the existing module first
    uninstallModule("Falkor")
    
    -- Small delay to ensure clean uninstall, then reinstall
    -- Note: Using tempTimer directly here since we're about to uninstall
    -- and this timer needs to survive the cleanup
    tempTimer(Falkor.config.timers.moduleReloadDelay, function()
        installModule("__FALKOR_XML_PATH__")
        echo("\nFalkor module reloaded!\n")
        -- Note: reloadInProgress will be reset when the new module loads
    end)
]])

