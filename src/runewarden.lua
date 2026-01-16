-- Runewarden module: Battlerage ability management
-- Handles automatic battlerage ability usage based on rage levels

Falkor = Falkor or {}

-- Initialize runewarden state
function Falkor:initRunewarden()
    self.currentRage = 0     -- Track current rage level
    self.maxRage = 100       -- Maximum rage (standard)
    
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
-- Called by SVOF when balance is available
function Falkor.autoCollide()
    local ability = Falkor.battlerageAbilities.collide
    
    -- Only use if enabled, we have a target, enough rage, and it's off cooldown
    if ability.enabled and 
       Falkor.lastTarget and 
       Falkor.currentRage >= ability.rageCost and
       not ability.ready then
        
        send("collide " .. Falkor.lastTarget)
        
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
-- Called by SVOF when balance is available
function Falkor.autoBulwark()
    local ability = Falkor.battlerageAbilities.bulwark
    
    -- Only use if enabled, enough rage, and it's off cooldown
    if ability.enabled and 
       Falkor.currentRage >= ability.rageCost and
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

-- Parse rage from GMCP (SVOF tracks this)
function Falkor:parseRage(line)
    -- SVOF tracks battlerage via gmcp.Char.Vitals
    if gmcp and gmcp.Char and gmcp.Char.Vitals and gmcp.Char.Vitals.rage then
        local newRage = tonumber(gmcp.Char.Vitals.rage)
        if newRage and newRage ~= self.currentRage then
            self.currentRage = newRage
            -- Uncomment for debugging:
            -- Falkor:log("<yellow>Rage updated: " .. self.currentRage)
        end
    end
end

-- Enable auto-collide
function Falkor:enableCollide()
    local ability = self.battlerageAbilities.collide
    ability.enabled = true
    svo.addbalanceful("falkor_collide", Falkor.autoCollide)
    Falkor:log("<green>Auto-Collide enabled (requires " .. ability.rageCost .. " rage, " .. ability.cooldown .. "s cooldown)")
end

-- Disable auto-collide
function Falkor:disableCollide()
    self.battlerageAbilities.collide.enabled = false
    svo.removebalanceful("falkor_collide")
    Falkor:log("<red>Auto-Collide disabled")
end

-- Toggle auto-collide
function Falkor:toggleCollide()
    if self.battlerageAbilities.collide.enabled then
        self:disableCollide()
    else
        self:enableCollide()
    end
end

-- Enable auto-bulwark
function Falkor:enableBulwark()
    local ability = self.battlerageAbilities.bulwark
    ability.enabled = true
    svo.addbalanceful("falkor_bulwark", Falkor.autoBulwark)
    Falkor:log("<green>Auto-Bulwark enabled (requires " .. ability.rageCost .. " rage, " .. ability.cooldown .. "s cooldown)")
end

-- Disable auto-bulwark
function Falkor:disableBulwark()
    self.battlerageAbilities.bulwark.enabled = false
    svo.removebalanceful("falkor_bulwark")
    Falkor:log("<red>Auto-Bulwark disabled")
end

-- Toggle auto-bulwark
function Falkor:toggleBulwark()
    if self.battlerageAbilities.bulwark.enabled then
        self:disableBulwark()
    else
        self:enableBulwark()
    end
end

-- Manual collide command
function Falkor:manualCollide(target)
    local ability = self.battlerageAbilities.collide
    
    if not target then
        target = self.lastTarget
    end
    
    if not target then
        Falkor:log("<yellow>No target specified or detected")
        return
    end
    
    if self.currentRage < ability.rageCost then
        Falkor:log("<yellow>Not enough rage for Collide (need " .. ability.rageCost .. ", have " .. self.currentRage .. ")")
        return
    end
    
    if ability.ready then
        local remaining = ability.ready - os.time()
        Falkor:log("<yellow>Collide on cooldown (" .. remaining .. "s remaining)")
        return
    end
    
    svo.doadd("collide " .. target, false, false)
end

-- Manual bulwark command
function Falkor:manualBulwark()
    local ability = self.battlerageAbilities.bulwark
    
    if self.currentRage < ability.rageCost then
        Falkor:log("<yellow>Not enough rage for Bulwark (need " .. ability.rageCost .. ", have " .. self.currentRage .. ")")
        return
    end
    
    if ability.ready then
        local remaining = ability.ready - os.time()
        Falkor:log("<yellow>Bulwark on cooldown (" .. remaining .. "s remaining)")
        return
    end
    
    svo.doadd("bulwark", false, false)
end

-- Initialize runewarden module
Falkor:initRunewarden()

-- Register battlerage abilities with SVOF (since Falkor loads after SVOF)
if Falkor.battlerageAbilities.collide.enabled then
    svo.addbalanceful("falkor_collide", Falkor.autoCollide)
end
if Falkor.battlerageAbilities.bulwark.enabled then
    svo.addbalanceful("falkor_bulwark", Falkor.autoBulwark)
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

-- Create alias: autocollide (toggle auto-collide)
Falkor:registerAlias("aliasAutoCollide", "^autocollide$", [[
    Falkor:toggleCollide()
]])

-- Create alias: autobulwark (toggle auto-bulwark)
Falkor:registerAlias("aliasAutoBulwark", "^autobulwark$", [[
    Falkor:toggleBulwark()
]])

-- Create alias: rage (show current rage status)
Falkor:registerAlias("aliasRageStatus", "^rage$", [[
    local collide = Falkor.battlerageAbilities.collide
    local bulwark = Falkor.battlerageAbilities.bulwark
    
    Falkor:log("<cyan>Current Rage: " .. Falkor.currentRage .. "/" .. Falkor.maxRage)
    Falkor:log("<cyan>Auto-Collide: " .. (collide.enabled and "ON" or "OFF") .. 
               " (Cost: " .. collide.rageCost .. " rage, CD: " .. collide.cooldown .. "s)")
    Falkor:log("<cyan>Auto-Bulwark: " .. (bulwark.enabled and "ON" or "OFF") .. 
               " (Cost: " .. bulwark.rageCost .. " rage, CD: " .. bulwark.cooldown .. "s)")
    
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
