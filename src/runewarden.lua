-- Runewarden module: Battlerage ability management
-- Handles automatic battlerage ability usage based on rage levels

Falkor = Falkor or {}

-- Constants for this module
local COMMAND_COLLIDE = "collide"
local COMMAND_BULWARK = "bulwark"

-- Initialize runewarden state
function Falkor:initRunewarden()
    -- Battlerage abilities state (configuration is in config.lua)
    self.battlerageAbilities = {
        collide = {
            ready = nil  -- nil = ready, otherwise timestamp when ready
        },
        bulwark = {
            ready = nil  -- nil = ready, otherwise timestamp when ready
        }
    }
    
    Falkor:log("<green>Runewarden battlerage system initialized.")
    local collideEnabled = self.config.battlerage.collide.enabled and "enabled" or "disabled"
    local bulwarkEnabled = self.config.battlerage.bulwark.enabled and "enabled" or "disabled"
    Falkor:log("<cyan>Auto-Collide: " .. collideEnabled .. ", Auto-Bulwark: " .. bulwarkEnabled)
end

-- Balanceful function for Collide
-- Called when balance is available
function Falkor.handleAutoCollide()
    local ability = Falkor.battlerageAbilities.collide
    local config = Falkor.config.battlerage.collide
    
    -- Only use if enabled, in combat, we have a target, enough rage, and it's off cooldown
    if config.enabled and 
       Falkor.player.autoAttack and
       Falkor.player.target and 
       Falkor.player.rage >= config.rageCost and
       not ability.ready then
        
        send(COMMAND_COLLIDE .. " " .. Falkor.player.target)
        
        -- Set cooldown timer
        ability.ready = os.time() + config.cooldown
        
        -- Schedule cooldown reset
        tempTimer(config.cooldown, function()
            ability.ready = nil
        end)
        
        return false  -- Battlerage abilities don't consume balance, allow other actions
    end
    return false  -- Don't do anything
end

-- Balanceful function for Bulwark
-- Called when balance is available
function Falkor.handleAutoBulwark()
    local ability = Falkor.battlerageAbilities.bulwark
    local config = Falkor.config.battlerage.bulwark
    
    -- Only use if enabled, in combat, we have a target, enough rage, and it's off cooldown
    if config.enabled and 
       Falkor.player.autoAttack and
       Falkor.player.target and 
       Falkor.player.rage >= config.rageCost and
       not ability.ready then
        
        send(COMMAND_BULWARK)
        
        -- Set cooldown timer
        ability.ready = os.time() + config.cooldown
        
        -- Schedule cooldown reset
        tempTimer(config.cooldown, function()
            ability.ready = nil
        end)
        
        return false  -- Battlerage abilities don't consume balance, allow other actions
    end
    return false  -- Don't do anything
end

-- Note: Rage parsing is now handled in player.lua parsePrompt()
-- This function is removed as it's no longer needed

-- Manual collide command
function Falkor:manualCollide(target)
    local ability = self.battlerageAbilities.collide
    local config = self.config.battlerage.collide
    
    if not target then
        target = self.player.target
    end
    
    if not target then
        Falkor:log("<yellow>No target specified or detected")
        return
    end
    
    if self.player.rage < config.rageCost then
        Falkor:log("<yellow>Not enough rage for Collide (need " .. config.rageCost .. ", have " .. self.player.rage .. ")")
        return
    end
    
    if ability.ready then
        local remaining = ability.ready - os.time()
        Falkor:log("<yellow>Collide on cooldown (" .. remaining .. "s remaining)")
        return
    end
    
    self:addAction(COMMAND_COLLIDE .. " " .. target)
end

-- Manual bulwark command
function Falkor:manualBulwark()
    local ability = self.battlerageAbilities.bulwark
    local config = self.config.battlerage.bulwark
    
    if self.player.rage < config.rageCost then
        Falkor:log("<yellow>Not enough rage for Bulwark (need " .. config.rageCost .. ", have " .. self.player.rage .. ")")
        return
    end
    
    if ability.ready then
        local remaining = ability.ready - os.time()
        Falkor:log("<yellow>Bulwark on cooldown (" .. remaining .. "s remaining)")
        return
    end
    
    self:addAction(COMMAND_BULWARK)
end

-- Initialize runewarden module
Falkor:initRunewarden()

-- Register battlerage abilities with the balance system
if Falkor.config.battlerage.collide.enabled then
    Falkor:addAction(Falkor.handleAutoCollide, true, "falkor_collide")
end
if Falkor.config.battlerage.bulwark.enabled then
    Falkor:addAction(Falkor.handleAutoBulwark, true, "falkor_bulwark")
end

-- ============================================
-- RUNEWARDEN ALIASES
-- ============================================

-- Create alias: collide [target] (manual collide)
Falkor:registerAlias("aliasCollide", "^collide( .+)?$", [[
    local target = matches[2]
    if target then
        target = string.gsub(target, Falkor.PATTERNS.LEADING_SPACE_SINGLE, "")
    end
    Falkor:manualCollide(target)
]])

-- Create alias: bulwark (manual bulwark)
Falkor:registerAlias("aliasBulwark", "^bulwark$", [[
    Falkor:manualBulwark()
]])

-- Create alias: rage (show current rage status)
Falkor:registerAlias("aliasRageStatus", "^rage$", [[
    local collideAbility = Falkor.battlerageAbilities.collide
    local bulwarkAbility = Falkor.battlerageAbilities.bulwark
    local collideConfig = Falkor.config.battlerage.collide
    local bulwarkConfig = Falkor.config.battlerage.bulwark
    
    Falkor:log("<cyan>Current Rage: " .. Falkor.player.rage .. "/" .. Falkor.player.maxRage)
    Falkor:log("<cyan>Collide: Cost " .. collideConfig.rageCost .. " rage, CD " .. collideConfig.cooldown .. "s")
    Falkor:log("<cyan>Bulwark: Cost " .. bulwarkConfig.rageCost .. " rage, CD " .. bulwarkConfig.cooldown .. "s")
    
    if collideAbility.ready then
        local remaining = collideAbility.ready - os.time()
        Falkor:log("<yellow>Collide on cooldown: " .. remaining .. "s remaining")
    else
        Falkor:log("<green>Collide ready!")
    end
    
    if bulwarkAbility.ready then
        local remaining = bulwarkAbility.ready - os.time()
        Falkor:log("<yellow>Bulwark on cooldown: " .. remaining .. "s remaining")
    else
        Falkor:log("<green>Bulwark ready!")
    end
]])
