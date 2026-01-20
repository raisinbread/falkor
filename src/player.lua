-- Player module: Core state management and combat
-- Handles bashing, auto-attack, and prompt parsing

Falkor = Falkor or {}

-- Initialize player state
function Falkor:initPlayer()
    -- Consolidated player state object
    self.player = {
        -- Vitals
        health = 0,
        maxHealth = 0,
        mana = 0,
        maxMana = 0,
        endurance = 0,
        maxEndurance = 0,
        willpower = 0,
        maxWillpower = 0,
        rage = 0,
        maxRage = 100,
        
        -- Balance states
        hasBalance = true,
        hasEquilibrium = true,
        
        -- Combat state
        autoAttack = false,
        target = nil,
        
        -- Location
        location = nil,
        area = nil,
    }
    
    -- Configure the game prompt to include the information we need
    -- Format: health, mana, endurance, willpower, balance/eq indicators, rage
    -- *h = health, *m = mana, *e = endurance, *w = willpower
    -- *b = balance/eq indicators, *R = rage
    send("config prompt custom *hh, *mm, *ee, *ww *b*R-")
    
    Falkor:log("<green>Falkor player system initialized.")
    Falkor:log("<yellow>Prompt configured: health, mana, endurance, willpower, balance/eq, rage")
end

-- Balanceful function for auto-attacking
-- This gets called when balance is available
function Falkor.handleAutoAttack()
    -- Only attack if auto-attack is enabled and we have a target
    if Falkor.player.autoAttack and Falkor.player.target then
        send("kill " .. Falkor.player.target)
        return true  -- We sent a command that uses balance
    end
    return false  -- Don't do anything
end

-- Parse the prompt to extract current game state
function Falkor:parsePrompt(line)
    -- Parse vitals from prompt: "3000h, 3000m, 15000e, 15000w ex 14r-"
    local health, mana, endurance, willpower = string.match(line, "^(%d+)h, (%d+)m, (%d+)e, (%d+)w")
    
    if health then
        self.player.health = tonumber(health)
        self.player.mana = tonumber(mana)
        self.player.endurance = tonumber(endurance)
        self.player.willpower = tonumber(willpower)
    end
    
    -- Parse balance/equilibrium state and rage
    -- Format can be: "ex-" or "ex0-" or "ex 14r-" or "ex14r-"
    local balanceStr, rageStr = string.match(line, "(%a+)%s?(%d*)r?%-")
    if balanceStr then
        self.player.hasBalance = string.find(balanceStr, Falkor.PATTERNS.BALANCE_INDICATOR) ~= nil
        self.player.hasEquilibrium = string.find(balanceStr, Falkor.PATTERNS.EQUILIBRIUM_INDICATOR) ~= nil
    end
    
    -- Parse rage (can be "ex0-" or "ex 14r-" or "ex14r-")
    if rageStr and rageStr ~= "" then
        self.player.rage = tonumber(rageStr)
    else
        -- If no rage number shown, it's 0
        self.player.rage = 0
    end
    
    -- Track target via GMCP
    if gmcp and gmcp.Char and gmcp.Char.Combat and gmcp.Char.Combat.Target then
        self.player.target = gmcp.Char.Combat.Target
    end
    
    -- Track location via GMCP
    if gmcp and gmcp.Room and gmcp.Room.Info then
        if gmcp.Room.Info.name then
            self.player.location = gmcp.Room.Info.name
        end
        if gmcp.Room.Info.area then
            self.player.area = gmcp.Room.Info.area
        end
    end
    
    -- Get max values from GMCP if available
    if gmcp and gmcp.Char and gmcp.Char.Vitals then
        if gmcp.Char.Vitals.maxhp then
            self.player.maxHealth = tonumber(gmcp.Char.Vitals.maxhp)
        end
        if gmcp.Char.Vitals.maxmp then
            self.player.maxMana = tonumber(gmcp.Char.Vitals.maxmp)
        end
        if gmcp.Char.Vitals.maxep then
            self.player.maxEndurance = tonumber(gmcp.Char.Vitals.maxep)
        end
        if gmcp.Char.Vitals.maxwp then
            self.player.maxWillpower = tonumber(gmcp.Char.Vitals.maxwp)
        end
    end
end

-- Handle prompt updates
function Falkor:onPrompt(line)
    -- Parse all player state from prompt
    self:parsePrompt(line)
    
    -- Update balance system state from prompt
    if self.balance then
        self.balance.hasBalance = self.player.hasBalance
        self.balance.hasEquilibrium = self.player.hasEquilibrium
        
        -- Always try to process queue on every prompt
        -- processQueue() will decide if it should act based on balance and whether it's already processed
        self:processQueue()
    end
    
    -- Check elixirs (health/mana recovery) - runs independently of balance queue
    if self.elixirs then
        self:checkElixirs()
    end
    
    -- Catch butterflies if we have pending catches
    if self.butterflies and self.butterflies.pendingCatches and self.butterflies.pendingCatches > 0 then
        self:addAction("catch butterfly")
        self.butterflies.pendingCatches = self.butterflies.pendingCatches - 1
    end
end

-- Start auto-attacking (set target in game, enable auto-attack)
-- targetName: optional target name. If nil, just enables auto-attack without changing target
function Falkor:startAttack(targetName)
    if targetName then
        send("settarget " .. targetName)
        self.player.target = targetName
        Falkor:log("<green>Auto-attack enabled for: " .. targetName)
    else
        Falkor:log("<green>Auto-attack enabled (using current target).")
    end
    self.player.autoAttack = true
    
    -- Add our attack function to the action queue
    self:addAction(Falkor.handleAutoAttack, true, "falkor_autoattack")
end

-- Stop auto-attacking
function Falkor:stopAttack()
    self.player.autoAttack = false
    
    -- Remove our attack function from the action queue
    self:removeAction("falkor_autoattack")
    
    Falkor:log("<red>Auto-attack disabled.")
end

-- Initialize player module
Falkor:initPlayer()

-- ============================================
-- PLAYER ALIASES AND TRIGGERS
-- ============================================

-- Create alias: att [target] (target is optional)
Falkor:registerAlias("aliasAttack", "^att( .+)?$", [[
    local target = matches[2]
    if target then
        -- Remove leading space
        target = string.gsub(target, Falkor.PATTERNS.LEADING_SPACE_SINGLE, "")
    else
        -- No target provided, try to use the current target
        target = Falkor.player.target
        if not target then
            Falkor:log("<yellow>No target specified and no current target found. Use 'att <target>' to set a target.")
            return
        end
    end
    Falkor:startAttack(target)
]])

-- Create alias: stop
Falkor:registerAlias("aliasStop", "^stop$", [[
    Falkor:stopAttack()
]])

-- Create trigger: Prompt line (this fires on EVERY prompt)
-- Match prompt format: "1657h, 1388m, 6035e, 5000w ex-" or with battlerage "ex0-" or "ex 14r-"
-- Regex: numbers followed by h, m, e, w, then balance indicators, optional rage (with or without space), then dash
Falkor:registerTrigger("triggerPrompt", "^\\d+h, \\d+m, \\d+e, \\d+w [a-z]+\\s?\\d*r?-", [[
    Falkor:onPrompt(line)
]], true)

-- Create trigger: Target slain (auto-disables attack)
Falkor:registerTrigger("triggerSlain", "You have slain", [[
    Falkor:stopAttack()
    Falkor:log("<green>Target slain! Auto-attack disabled.")
]])

-- Create trigger: Target not found (auto-disables attack)
Falkor:registerTrigger("triggerMissedTarget", "but see nothing by that name here!", [[
    Falkor:stopAttack()
    Falkor:log("<yellow>Target not found! Auto-attack disabled.")
]])

-- Create trigger: No weapon wielded (auto-disables attack)
Falkor:registerTrigger("triggerNoWeapon", "You haven't got a weapon to do that with.", [[
    Falkor:stopAttack()
    Falkor:log("<red>No weapon wielded! Auto-attack disabled.")
]])

-- Create trigger: Must stand first (auto-stand)
Falkor:registerTrigger("triggerMustStand", "You must be standing first.", [[
    Falkor:log("<yellow>Must stand! Standing up...")
    Falkor:addAction("stand")
]])

-- Create trigger: Gold from corpse (auto-pickup)
Falkor:registerTrigger("triggerGoldFromCorpse", "sovereigns spills from the corpse", [[
    Falkor:addAction("get gold")
]])

-- Create trigger: Gold in room (auto-pickup)
Falkor:registerTrigger("triggerGoldInRoom", "a small pile of golden sovereigns", [[
    Falkor:addAction("get gold")
]])

-- Create alias: fplayer (display player status)
Falkor:registerAlias("aliasFplayer", "^fplayer$", [[
    Falkor:log("<cyan>========================================")
    Falkor:log("<cyan>Falkor Player Status")
    Falkor:log("<cyan>========================================")
    
    -- Vitals
    local hp_pct = Falkor.player.maxHealth > 0 and math.floor((Falkor.player.health / Falkor.player.maxHealth) * 100) or 0
    local mp_pct = Falkor.player.maxMana > 0 and math.floor((Falkor.player.mana / Falkor.player.maxMana) * 100) or 0
    local ep_pct = Falkor.player.maxEndurance > 0 and math.floor((Falkor.player.endurance / Falkor.player.maxEndurance) * 100) or 0
    local wp_pct = Falkor.player.maxWillpower > 0 and math.floor((Falkor.player.willpower / Falkor.player.maxWillpower) * 100) or 0
    
    Falkor:log("<white>Health:     <green>" .. Falkor.player.health .. "<white>/<green>" .. Falkor.player.maxHealth .. " <white>(" .. hp_pct .. "%)")
    Falkor:log("<white>Mana:       <cyan>" .. Falkor.player.mana .. "<white>/<cyan>" .. Falkor.player.maxMana .. " <white>(" .. mp_pct .. "%)")
    Falkor:log("<white>Endurance:  <yellow>" .. Falkor.player.endurance .. "<white>/<yellow>" .. Falkor.player.maxEndurance .. " <white>(" .. ep_pct .. "%)")
    Falkor:log("<white>Willpower:  <magenta>" .. Falkor.player.willpower .. "<white>/<magenta>" .. Falkor.player.maxWillpower .. " <white>(" .. wp_pct .. "%)")
    Falkor:log("<white>Rage:       <red>" .. Falkor.player.rage .. "<white>/<red>" .. Falkor.player.maxRage)
    
    -- Balance states
    Falkor:log("")
    local balStr = (Falkor.player.hasBalance and "<green>YES" or "<red>NO")
    local eqStr = (Falkor.player.hasEquilibrium and "<green>YES" or "<red>NO")
    Falkor:log("<white>Balance:      " .. balStr)
    Falkor:log("<white>Equilibrium:  " .. eqStr)
    
    -- Combat state
    Falkor:log("")
    local attackStr = (Falkor.player.autoAttack and "<green>ENABLED" or "<red>DISABLED")
    Falkor:log("<white>Auto-attack:  " .. attackStr)
    Falkor:log("<white>Target:       <cyan>" .. (Falkor.player.target or "<gray>none"))
    
    -- Location
    if Falkor.player.location or Falkor.player.area then
        Falkor:log("")
        if Falkor.player.location then
            Falkor:log("<white>Location:     <yellow>" .. Falkor.player.location)
        end
        if Falkor.player.area then
            Falkor:log("<white>Area:         <yellow>" .. Falkor.player.area)
        end
    end
    
    -- Command queue
    if Falkor.balance and Falkor.balance.commandQueue then
        local queueSize = #Falkor.balance.commandQueue
        if queueSize > 0 then
            Falkor:log("")
            Falkor:log("<white>Command Queue: <yellow>" .. queueSize .. " <white>pending")
        end
    end
    
    Falkor:log("<cyan>========================================")
]])
