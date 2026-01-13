-- Main initialization and startup message
-- This file runs after all modules are loaded

Falkor = Falkor or {}

Falkor:log("<green>========================================")
Falkor:log("<green>Falkor Combat Script Loaded!")
Falkor:log("<green>========================================")
Falkor:log("<cyan>Commands:")
Falkor:log("<white>  att <target>  - Begin attacking a target")
Falkor:log("<white>  stop          - Stop auto-attacking")
Falkor:log("<white>  butterflies   - Toggle butterfly catching")
Falkor:log("<white>  sellrats      - Walk to Hakhim and sell rats")
Falkor:log("<white>  falkor        - Reinstall Falkor module")
Falkor:log("<green>========================================")

-- ============================================
-- MAIN ALIASES
-- ============================================

-- Clean up existing items if they exist (for reloading)
if Falkor.aliasReinstall then killAlias(Falkor.aliasReinstall) end

-- Create alias: falkor (reinstall Falkor module)
Falkor.aliasReinstall = tempAlias("^falkor$", [[
    -- Uninstall the existing module first
    uninstallModule("Falkor")
    
    -- Small delay to ensure clean uninstall, then reinstall
    tempTimer(0.5, function()
        installModule("__FALKOR_XML_PATH__")
        echo("\nFalkor module reloaded!\n")
    end)
]])
