-- Main initialization and startup message
-- This file provides utility functions and runs after all modules are loaded

Falkor = Falkor or {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Register a trigger with automatic cleanup
-- name: unique identifier (e.g., "triggerPrompt")
-- pattern: trigger pattern string
-- code: trigger code string
-- isRegex: true for regex trigger, false for simple trigger (default: false)
function Falkor:registerTrigger(name, pattern, code, isRegex)
    -- Clean up existing trigger if it exists
    if self[name] then
        killTrigger(self[name])
        self[name] = nil
    end
    
    -- Create new trigger
    if isRegex then
        self[name] = tempRegexTrigger(pattern, code)
    else
        self[name] = tempTrigger(pattern, code)
    end
end

-- Register an alias with automatic cleanup
-- name: unique identifier (e.g., "aliasAttack")
-- pattern: alias pattern string
-- code: alias code string
function Falkor:registerAlias(name, pattern, code)
    -- Clean up existing alias if it exists
    if self[name] then
        killAlias(self[name])
        self[name] = nil
    end
    
    -- Create new alias
    self[name] = tempAlias(pattern, code)
end

Falkor:log("<green>========================================")
Falkor:log("<green>Falkor Combat Script Loaded!")
Falkor:log("<green>========================================")
Falkor:log("<cyan>Combat Commands:")
Falkor:log("<white>  att <target>        - Begin attacking a target")
Falkor:log("<white>  stop                - Stop auto-attacking")
Falkor:log("<cyan>Battlerage Commands:")
Falkor:log("<white>  autocollide         - Toggle auto-Collide (14 rage, 16s CD)")
Falkor:log("<white>  autobulwark         - Toggle auto-Bulwark (28 rage, 45s CD)")
Falkor:log("<white>  collide [target]    - Manual Collide")
Falkor:log("<white>  bulwark             - Manual Bulwark")
Falkor:log("<white>  rage                - Show rage status")
Falkor:log("<cyan>Utility Commands:")
Falkor:log("<white>  butterflies         - Toggle butterfly catching")
Falkor:log("<white>  butterflies-start   - Walk to Vellis and set up butterfly catching")
Falkor:log("<white>  sellbutterflies     - Walk to Vellis and sell butterflies")
Falkor:log("<white>  sellrats            - Walk to Hakhim and sell rats")
Falkor:log("<white>  falkor              - Reinstall Falkor module")
Falkor:log("<green>========================================")

-- ============================================
-- MAIN ALIASES
-- ============================================

-- Create alias: falkor (reinstall Falkor module)
Falkor:registerAlias("aliasReinstall", "^falkor$", [[
    -- Uninstall the existing module first
    uninstallModule("Falkor")
    
    -- Small delay to ensure clean uninstall, then reinstall
    tempTimer(0.5, function()
        installModule("__FALKOR_XML_PATH__")
        echo("\nFalkor module reloaded!\n")
    end)
]])
