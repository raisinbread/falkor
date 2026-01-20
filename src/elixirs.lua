-- Elixirs module: Automatic health and mana recovery
-- Monitors vitals and drinks elixirs when they drop below configured thresholds
-- Manages elixir balance separately from combat balance

Falkor = Falkor or {}

-- Initialize elixir system
function Falkor:initElixirs()
    self.elixirs = {
        -- Elixir balance tracking
        canDrink = true,       -- Whether we can drink an elixir right now
    }
    
    -- Register trigger for elixir balance
    self:registerTrigger("triggerElixirBalance", "You may drink another health or mana elixir", [[
        Falkor.elixirs.canDrink = true
        Falkor:tryDrinkElixir()
    ]])
    
    Falkor:log("<green>Elixir system initialized.")
end

-- Check if we need to drink health elixir
function Falkor:needsHealthElixir()
    -- Calculate health percentage
    if self.player.maxHealth == 0 then
        return false
    end
    
    local healthPct = (self.player.health / self.player.maxHealth) * 100
    return healthPct < self.config.elixirs.healthThreshold
end

-- Check if we need to drink mana elixir
function Falkor:needsManaElixir()
    -- Calculate mana percentage
    if self.player.maxMana == 0 then
        return false
    end
    
    local manaPct = (self.player.mana / self.player.maxMana) * 100
    return manaPct < self.config.elixirs.manaThreshold
end

-- Try to drink an elixir if we can and need to
function Falkor:tryDrinkElixir()
    -- Can't drink if we're on elixir cooldown
    if not self.elixirs.canDrink then
        return
    end
    
    -- Priority 1: Health (more important to stay alive)
    if self:needsHealthElixir() then
        send("drink health")
        self.elixirs.canDrink = false
        return
    end
    
    -- Priority 2: Mana
    if self:needsManaElixir() then
        send("drink mana")
        self.elixirs.canDrink = false
        return
    end
end

-- Main elixir check function (called on prompt)
function Falkor:checkElixirs()
    -- Only check if elixirs are enabled
    if not self.config.elixirs.enabled then
        return
    end
    
    -- Try to drink if we need to and can
    self:tryDrinkElixir()
end

-- Initialize elixir module
Falkor:initElixirs()
