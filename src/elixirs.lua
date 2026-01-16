-- Elixirs module: Automatic health and mana recovery
-- Monitors vitals and drinks elixirs when they drop below configured thresholds

Falkor = Falkor or {}

-- Initialize elixir system
function Falkor:initElixirs()
    self.elixirs = {
        -- Configuration (edit these values to customize)
        healthThreshold = 50,  -- Percentage below which to drink health
        manaThreshold = 50,    -- Percentage below which to drink mana
    }
    
    Falkor:log("<green>Elixir system initialized.")
end

-- Check if we need to drink health elixir
function Falkor:checkHealthElixir()
    -- Calculate health percentage
    if self.player.maxHealth == 0 then
        return false
    end
    
    local healthPct = (self.player.health / self.player.maxHealth) * 100
    
    -- Check if we need to drink
    if healthPct < self.elixirs.healthThreshold then
        self:queueCommand("drink health", 8)  -- High priority (higher than normal combat)
        return true
    end
    
    return false
end

-- Check if we need to drink mana elixir
function Falkor:checkManaElixir()
    -- Calculate mana percentage
    if self.player.maxMana == 0 then
        return false
    end
    
    local manaPct = (self.player.mana / self.player.maxMana) * 100
    
    -- Check if we need to drink
    if manaPct < self.elixirs.manaThreshold then
        self:queueCommand("drink mana", 7)  -- High priority but slightly lower than health
        return true
    end
    
    return false
end

-- Main elixir check function (called on prompt)
function Falkor:checkElixirs()
    -- Check both health and mana
    -- They'll be queued with appropriate priorities
    self:checkHealthElixir()
    self:checkManaElixir()
end

-- Initialize elixir module
Falkor:initElixirs()
