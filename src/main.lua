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
Falkor:log("<white>  fstophunt           - Stop hunting")
Falkor:log("<white>  combatstart         - Enable combat denizen tracking")
Falkor:log("<white>  combatstop          - Disable combat denizen tracking")
Falkor:log("<white>  fcombat             - Show denizens in current room")
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
Falkor:log("<white>  fconfig             - Show/set configuration")
Falkor:log("<white>  fregistry           - Show registry statistics")
Falkor:log("<white>  ftriggers           - List all registered triggers")
Falkor:log("<white>  faliases            - List all registered aliases")
Falkor:log("<white>  ftimers             - List all active timers")
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

-- Create alias: fregistry (show registry statistics)
Falkor:registerAlias("aliasRegistry", "^fregistry$", [[
    local stats = Falkor:getRegistryStats()
    Falkor:log("<cyan>========================================")
    Falkor:log("<cyan>Falkor Registry Statistics")
    Falkor:log("<cyan>========================================")
    Falkor:log("<white>Triggers:  <yellow>" .. stats.triggers)
    Falkor:log("<white>Aliases:   <yellow>" .. stats.aliases)
    Falkor:log("<white>Timers:    <yellow>" .. stats.timers)
    Falkor:log("<cyan>========================================")
]])

-- Create alias: ftriggers (list all registered triggers)
Falkor:registerAlias("aliasListTriggers", "^ftriggers$", [[
    local triggers = Falkor:listTriggers()
    Falkor:log("<cyan>========================================")
    Falkor:log("<cyan>Registered Triggers (" .. #triggers .. ")")
    Falkor:log("<cyan>========================================")
    
    if #triggers == 0 then
        Falkor:log("<yellow>No triggers registered.")
    else
        -- Sort by name for readability
        table.sort(triggers, function(a, b) return a.name < b.name end)
        
        for _, trigger in ipairs(triggers) do
            local status = trigger.enabled and "<green>ENABLED" or "<red>DISABLED"
            local type = trigger.isRegex and "regex" or "simple"
            local pattern = string.sub(trigger.pattern, 1, 50)
            if string.len(trigger.pattern) > 50 then
                pattern = pattern .. "..."
            end
            Falkor:log("<white>" .. trigger.name .. " <gray>(" .. type .. ")")
            Falkor:log("<gray>  Pattern: " .. pattern)
            Falkor:log("<gray>  Status:  " .. status)
        end
    end
    Falkor:log("<cyan>========================================")
]])

-- Create alias: ftimers (list all active timers)
Falkor:registerAlias("aliasListTimers", "^ftimers$", [[
    local timers = Falkor.timers and Falkor.timers.active or {}
    Falkor:log("<cyan>========================================")
    
    local count = 0
    for _ in pairs(timers) do
        count = count + 1
    end
    
    Falkor:log("<cyan>Active Timers (" .. count .. ")")
    Falkor:log("<cyan>========================================")
    
    if count == 0 then
        Falkor:log("<yellow>No active timers.")
    else
        for name, entry in pairs(timers) do
            Falkor:log("<white>" .. name)
            Falkor:log("<gray>  Delay: <yellow>" .. entry.time .. "s")
            Falkor:log("<gray>  ID: <yellow>" .. (entry.id or "unknown"))
        end
    end
    Falkor:log("<cyan>========================================")
]])

-- Create alias: faliases (list all registered aliases)
Falkor:registerAlias("aliasListAliases", "^faliases$", [[
    local aliases = Falkor:listAliases()
    Falkor:log("<cyan>========================================")
    Falkor:log("<cyan>Registered Aliases (" .. #aliases .. ")")
    Falkor:log("<cyan>========================================")
    
    if #aliases == 0 then
        Falkor:log("<yellow>No aliases registered.")
    else
        -- Sort by name for readability
        table.sort(aliases, function(a, b) return a.name < b.name end)
        
        for _, alias in ipairs(aliases) do
            local status = alias.enabled and "<green>ENABLED" or "<red>DISABLED"
            local pattern = string.sub(alias.pattern, 1, 50)
            if string.len(alias.pattern) > 50 then
                pattern = pattern .. "..."
            end
            Falkor:log("<white>" .. alias.name)
            Falkor:log("<gray>  Pattern: " .. pattern)
            Falkor:log("<gray>  Status:  " .. status)
        end
    end
    Falkor:log("<cyan>========================================")
]])

-- Create alias: fconfig (show or set configuration)
Falkor:registerAlias("aliasConfig", "^fconfig( .+)?$", [[
    local args = matches[2]
    
    if not args or args:match("^%s*$") then
        -- Show all configuration
        local config = Falkor.config
        Falkor:log("<cyan>========================================")
        Falkor:log("<cyan>Falkor Configuration")
        Falkor:log("<cyan>========================================")
        
        -- Butterflies
        Falkor:log("<white>Butterflies:")
        Falkor:log("<gray>  Enabled: " .. (config.butterflies.enabled and "<green>YES" or "<red>NO"))
        
        -- Rats
        Falkor:log("<white>Rats:")
        Falkor:log("<gray>  Attack Cooldown: <yellow>" .. config.rats.attackCooldown .. "s")
        
        -- Timers
        Falkor:log("<white>Timers:")
        Falkor:log("<gray>  Module Reload Delay: <yellow>" .. config.timers.moduleReloadDelay .. "s")
        
        -- Debug
        Falkor:log("<white>Debug:")
        Falkor:log("<gray>  Log Level: <yellow>" .. config.debug.logLevel)
        Falkor:log("<gray>  Show Queue Status: " .. (config.debug.showQueueStatus and "<green>YES" or "<red>NO"))
        
        Falkor:log("<cyan>========================================")
        Falkor:log("<yellow>Use 'fconfig <path> <value>' to change settings")
        Falkor:log("<yellow>Example: fconfig elixirs.healthThreshold 60")
    else
        -- Set configuration value
        args = string.gsub(args, "^%s+", "")  -- Remove leading spaces
        local path, value = string.match(args, "^([^%s]+)%s+(.+)$")
        
        if not path or not value then
            Falkor:log("<red>Error: Invalid format. Use 'fconfig <path> <value>'")
            Falkor:log("<yellow>Example: fconfig elixirs.healthThreshold 60")
            return
        end
        
        -- Try to convert value to number or boolean
        local numValue = tonumber(value)
        local boolValue = nil
        if value == "true" or value == "yes" or value == "1" then
            boolValue = true
        elseif value == "false" or value == "no" or value == "0" then
            boolValue = false
        end
        
        local finalValue = boolValue ~= nil and boolValue or (numValue or value)
        
        if Falkor:setConfig(path, finalValue) then
            Falkor:log("<green>Configuration updated: " .. path .. " = " .. tostring(finalValue))
        else
            Falkor:log("<red>Error: Could not set configuration path: " .. path)
            Falkor:log("<yellow>Valid paths include:")
            Falkor:log("<yellow>  butterflies.enabled")
            Falkor:log("<yellow>  rats.attackCooldown")
            Falkor:log("<yellow>  timers.moduleReloadDelay")
            Falkor:log("<yellow>  debug.logLevel, debug.showQueueStatus")
        end
    end
]])
