-- Runewarden module: Battlerage ability management
-- Handles automatic battlerage ability usage based on rage levels

Falkor = Falkor or {}

-- Initialize runewarden state
function Falkor:initRunewarden()
    -- Battlerage abilities configuration
    self.battlerageAbilities = {
        collide = {
            enabled = true,  -- Enabled by default
            rageCost = 14,
            cooldown = 16,
            ready = nil  -- nil = ready, otherwise timestamp when ready
        },
        bulwark = {
            enabled = true,  -- Enabled by default
            rageCost = 28,
            cooldown = 45,
            ready = nil  -- nil = ready, otherwise timestamp when ready
        }
    }
    
    Falkor:log("<green>Runewarden battlerage system initialized.")
    Falkor:log("<cyan>Auto-Collide and Auto-Bulwark enabled by default.")
end

-- Balanceful function for Collide
-- Called when balance is available
function Falkor.autoCollide()
    local ability = Falkor.battlerageAbilities.collide
    
    -- Only use if enabled, we have a target, enough rage, and it's off cooldown
    if ability.enabled and 
       Falkor.player.target and 
       Falkor.player.rage >= ability.rageCost and
       not ability.ready then
        
        send("collide " .. Falkor.player.target)
        
        -- Set cooldown timer
        ability.ready = os.time() + ability.cooldown
        
        -- Schedule cooldown reset
        tempTimer(ability.cooldown, function()
            ability.ready = nil
            Falkor:log("<cyan>Collide ready!")
        end)
        
        return true  -- We sent a command that uses balance
    end
    return false  -- Don't do anything
end

-- Balanceful function for Bulwark
-- Called when balance is available
function Falkor.autoBulwark()
    local ability = Falkor.battlerageAbilities.bulwark
    
    -- Only use if enabled, enough rage, and it's off cooldown
    if ability.enabled and 
       Falkor.player.rage >= ability.rageCost and
       not ability.ready then
        
        send("bulwark")
        
        -- Set cooldown timer
        ability.ready = os.time() + ability.cooldown
        
        -- Schedule cooldown reset
        tempTimer(ability.cooldown, function()
            ability.ready = nil
            Falkor:log("<cyan>Bulwark ready!")
        end)
        
        return true  -- We sent a command that uses balance
    end
    return false  -- Don't do anything
end

-- Note: Rage parsing is now handled in player.lua parsePrompt()
-- This function is kept for backward compatibility but does nothing
function Falkor:parseRage(line)
    -- Rage is now parsed in Falkor.player.rage by parsePrompt()
end

-- Manual collide command
function Falkor:manualCollide(target)
    local ability = self.battlerageAbilities.collide
    
    if not target then
        target = self.player.target
    end
    
    if not target then
        Falkor:log("<yellow>No target specified or detected")
        return
    end
    
    if self.player.rage < ability.rageCost then
        Falkor:log("<yellow>Not enough rage for Collide (need " .. ability.rageCost .. ", have " .. self.player.rage .. ")")
        return
    end
    
    if ability.ready then
        local remaining = ability.ready - os.time()
        Falkor:log("<yellow>Collide on cooldown (" .. remaining .. "s remaining)")
        return
    end
    
    self:queueCommand("collide " .. target)
end

-- Manual bulwark command
function Falkor:manualBulwark()
    local ability = self.battlerageAbilities.bulwark
    
    if self.player.rage < ability.rageCost then
        Falkor:log("<yellow>Not enough rage for Bulwark (need " .. ability.rageCost .. ", have " .. self.player.rage .. ")")
        return
    end
    
    if ability.ready then
        local remaining = ability.ready - os.time()
        Falkor:log("<yellow>Bulwark on cooldown (" .. remaining .. "s remaining)")
        return
    end
    
    self:queueCommand("bulwark")
end

-- Initialize runewarden module
Falkor:initRunewarden()

-- Register battlerage abilities with the balance system
if Falkor.battlerageAbilities.collide.enabled then
    Falkor:addBalanceful("falkor_collide", Falkor.autoCollide)
end
if Falkor.battlerageAbilities.bulwark.enabled then
    Falkor:addBalanceful("falkor_bulwark", Falkor.autoBulwark)
end

-- ============================================
-- RUNEWARDEN ALIASES
-- ============================================

-- Create alias: collide [target] (manual collide)
Falkor:registerAlias("aliasCollide", "^collide( .+)?$", [[
    local target = matches[2]
    if target then
        target = string.gsub(target, "^ ", "")
    end
    Falkor:manualCollide(target)
]])

-- Create alias: bulwark (manual bulwark)
Falkor:registerAlias("aliasBulwark", "^bulwark$", [[
    Falkor:manualBulwark()
]])

-- Create alias: rage (show current rage status)
Falkor:registerAlias("aliasRageStatus", "^rage$", [[
    local collide = Falkor.battlerageAbilities.collide
    local bulwark = Falkor.battlerageAbilities.bulwark
    
    Falkor:log("<cyan>Current Rage: " .. Falkor.player.rage .. "/" .. Falkor.player.maxRage)
    Falkor:log("<cyan>Collide: Cost " .. collide.rageCost .. " rage, CD " .. collide.cooldown .. "s")
    Falkor:log("<cyan>Bulwark: Cost " .. bulwark.rageCost .. " rage, CD " .. bulwark.cooldown .. "s")
    
    if collide.ready then
        local remaining = collide.ready - os.time()
        Falkor:log("<yellow>Collide on cooldown: " .. remaining .. "s remaining")
    else
        Falkor:log("<green>Collide ready!")
    end
    
    if bulwark.ready then
        local remaining = bulwark.ready - os.time()
        Falkor:log("<yellow>Bulwark on cooldown: " .. remaining .. "s remaining")
    else
        Falkor:log("<green>Bulwark ready!")
    end
]])
