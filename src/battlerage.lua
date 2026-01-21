-- Battlerage module: Battlerage ability management
-- Handles battlerage ability cooldown tracking and usage

Falkor = Falkor or {}

-- Initialize battlerage state
function Falkor:initBattlerage()
    self.battlerage = {
        abilities = {
            collide = {
                cost = 14,
                ready = true,
                cooldownPattern = "^(?:Your Collide ability could be used again|You can use Collide again)\\.$",
            },
            bulwark = {
                cost = 28,
                ready = true,
                cooldownPattern = "^(?:Your Bulwark ability could be used again|You can use Bulwark again)\\.$",
            },
            fragment = {
                cost = 17,
                ready = true,
                cooldownPattern = "^(?:Your Fragment ability could be used again|You can use Fragment again)\\.$",
            },
            onslaught = {
                cost = 36,
                ready = true,
                cooldownPattern = "^(?:Your Onslaught ability could be used again|You can use Onslaught again)\\.$",
            },
        }
    }
end

-- Check if we should keep the battlerage callback active
-- Returns true to keep checking, false to stop
function Falkor.checkBattlerageUsage()
    -- Keep callback active as long as hunting is enabled (even without a target)
    return Falkor.combat.hunting.enabled
end

-- Try to use a battlerage ability
function Falkor:useBattlerageAbility(abilityName)
    local ability = self.battlerage.abilities[abilityName]
    if not ability then
        return false
    end
    
    -- Check if ability is ready and we have enough rage
    if ability.ready and self.player.rage >= ability.cost then
        -- Check if we have a target for targeted abilities
        if abilityName == "collide" or abilityName == "fragment" or abilityName == "onslaught" then
            if not self.combat.hunting.target then
                return false
            end
            
            -- Fragment should only be used against shielded targets
            if abilityName == "fragment" and not self.combat.hunting.target.hasShield then
                return false
            end
            
            -- Queue the ability with target (use the key as the command)
            self:queueCommand(abilityName .. " " .. self.combat.hunting.target.id, "bal")
            self:log(string.format("<red>⚔ <yellow>%s <gray>(%d rage)", 
                abilityName:gsub("^%l", string.upper), ability.cost))
        else
            -- Non-targeted ability (bulwark) - use the key as the command
            self:queueCommand(abilityName, "bal")
            self:log(string.format("<red>🛡 <yellow>%s <gray>(%d rage)", 
                abilityName:gsub("^%l", string.upper), ability.cost))
        end
        
        -- Mark as not ready (on cooldown)
        ability.ready = false
        return true
    end
    
    return false
end

-- Check and use battlerage abilities on balance regain
function Falkor.executeBattlerageAbilities()
    -- Only try to use abilities if we have a target
    if not Falkor.combat.hunting.target then
        return
    end
    
    -- Try abilities in priority order (highest cost first for maximum damage)
    -- Onslaught > Bulwark > Fragment > Collide
    
    if Falkor:useBattlerageAbility("onslaught") then
        return
    end
    
    if Falkor:useBattlerageAbility("bulwark") then
        return
    end
    
    if Falkor:useBattlerageAbility("fragment") then
        return
    end
    
    if Falkor:useBattlerageAbility("collide") then
        return
    end
end

-- Handle ability coming off cooldown
function Falkor:handleAbilityCooldownReady(abilityName)
    local ability = self.battlerage.abilities[abilityName]
    if ability then
        ability.ready = true
        self:log(string.format("<purple>⚡ <white>%s <gray>ready (cost: %d rage)", 
            abilityName:gsub("^%l", string.upper), ability.cost))
    end
end

-- Handle list-style cooldown notification
-- Example: "You can use another Battlerage ability again. Available abilities: Collide"
function Falkor:handleBattlerageListReady(availableList)
    -- Parse the comma-separated list of abilities
    for abilityName in string.gmatch(availableList:lower(), "%a+") do
        local ability = self.battlerage.abilities[abilityName]
        if ability and not ability.ready then
            ability.ready = true
            self:log(string.format("<purple>⚡ <white>%s <gray>ready (cost: %d rage)", 
                abilityName:gsub("^%l", string.upper), ability.cost))
        end
    end
end

-- Initialize battlerage module
Falkor:initBattlerage()

-- Register persistent callback to use battlerage abilities
Falkor:addPersistentCallback(
    Falkor.executeBattlerageAbilities,
    Falkor.checkBattlerageUsage,
    "falkor_battlerage"
)

-- ============================================
-- BATTLERAGE TRIGGERS
-- ============================================

-- Trigger for Collide cooldown ready
Falkor:registerTrigger(
    "triggerCollideCooldown",
    Falkor.battlerage.abilities.collide.cooldownPattern,
    [[Falkor:handleAbilityCooldownReady("collide")]],
    "regex"
)

-- Trigger for Bulwark cooldown ready
Falkor:registerTrigger(
    "triggerBulwarkCooldown",
    Falkor.battlerage.abilities.bulwark.cooldownPattern,
    [[Falkor:handleAbilityCooldownReady("bulwark")]],
    "regex"
)

-- Trigger for Fragment cooldown ready
Falkor:registerTrigger(
    "triggerFragmentCooldown",
    Falkor.battlerage.abilities.fragment.cooldownPattern,
    [[Falkor:handleAbilityCooldownReady("fragment")]],
    "regex"
)

-- Trigger for Onslaught cooldown ready
Falkor:registerTrigger(
    "triggerOnslaughtCooldown",
    Falkor.battlerage.abilities.onslaught.cooldownPattern,
    [[Falkor:handleAbilityCooldownReady("onslaught")]],
    "regex"
)

-- Trigger for list-style cooldown notification
-- Example: "You can use another Battlerage ability again. Available abilities: Collide"
Falkor:registerTrigger(
    "triggerBattlerageListReady",
    "^You can use another Battlerage ability again\\. Available abilities: (.+)$",
    [[Falkor:handleBattlerageListReady(matches[2])]],
    "regex"
)
