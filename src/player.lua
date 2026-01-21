-- Player module: Core state management
-- Handles vitals tracking and prompt parsing

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
        
        -- Location
        location = nil,
        area = nil,
        
        -- Gold pickup cooldown
        goldReady = true,
        goldCooldown = 4.0,
    }
    
    -- Configure the game prompt to include the information we need
    -- Format: health, mana, endurance, willpower, balance/eq indicators, rage
    -- *h = health, *m = mana, *e = endurance, *w = willpower
    -- *b = balance/eq indicators, *R = rage
    send("config prompt custom *hh, *mm, *ee, *ww *b*R-", false)
    
    -- Configure battlerage messages to show ability cooldowns (not gain messages)
    send("config ragemsg abcooldowns", false)
    
    -- Enable server-side curing
    send("curing on", false)
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
    
    -- Update balance system state from prompt and trigger hooks
    if self.balance then
        self:updateBalanceFromPrompt(line)
    end
    
    -- Check elixirs (health/mana recovery) - runs independently of balance
    if self.elixirs then
        self:checkElixirs()
    end
    
    -- Catch butterflies if we have pending catches
    if self.butterflies and self.butterflies.pendingCatches and self.butterflies.pendingCatches > 0 then
        self:queueCommand("catch butterfly")
        self.butterflies.pendingCatches = self.butterflies.pendingCatches - 1
    end
end

-- Queue get gold command with cooldown check
function Falkor:queueGetGold()
    if self.player.goldReady then
        self:queueCommand("get gold")
        self.player.goldReady = false
        tempTimer(self.player.goldCooldown, function()
            Falkor.player.goldReady = true
        end)
    end
end

-- Initialize player module
Falkor:initPlayer()

-- ============================================
-- RAT SELLING
-- ============================================

-- Start selling rats (walk to Hakhim)
function Falkor:sellRats()
    self.player.sellRatsPending = true
    Falkor:log("<cyan>Walking to Hakhim to sell rats...")
    send("rats")
    send("walk to Hakhim")
end

-- ============================================
-- PLAYER ALIASES AND TRIGGERS
-- ============================================

-- Create trigger: Prompt line (this fires on EVERY prompt)
-- Match prompt format: "1657h, 1388m, 6035e, 5000w ex-" or with battlerage "ex0-" or "ex 14r-"
-- Regex: numbers followed by h, m, e, w, then balance indicators, optional rage (with or without space), then dash
Falkor:registerTrigger("triggerPrompt", "^\\d+h, \\d+m, \\d+e, \\d+w [a-z]+\\s?\\d*r?-", [[
    Falkor:onPrompt(line)
]], true)

-- Create trigger: Must stand first (auto-stand)
Falkor:registerTrigger("triggerMustStand", "You must be standing first.", [[
    Falkor:log("<yellow>Must stand! Standing up...")
    Falkor:queueCommand("stand")
]])

-- Create trigger: Gold from corpse (auto-pickup)
Falkor:registerTrigger("triggerGoldFromCorpse", "sovereigns spills", [[
    Falkor:queueGetGold()
]])

-- Create trigger: Arrived at destination (sell rats if pending)
Falkor:registerTrigger("triggerArrived", "You have arrived at your destination!", [[
    if Falkor.player.sellRatsPending then
        Falkor:log("<green>Arrived! Selling rats to Hakhim...")
        Falkor:queueCommand("sell rats to Hakhim")
        Falkor.player.sellRatsPending = false
    end
]])

-- Create alias: sellrats (walk to Hakhim and sell rats)
Falkor:registerAlias("aliasSellRats", "^sellrats$", [[
    Falkor:sellRats()
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
    
    -- Combat system status
    Falkor:log("")
    local huntingStr = (Falkor.combat.hunting.enabled and "<green>ENABLED" or "<red>DISABLED")
    Falkor:log("<white>Hunting:      " .. huntingStr)
    if Falkor.combat.hunting.target then
        Falkor:log("<white>Target:       <yellow>" .. Falkor.combat.hunting.target.name .. " <gray>(ID: " .. Falkor.combat.hunting.target.id .. ")")
    else
        Falkor:log("<white>Target:       <gray>none")
    end
    if Falkor.combat.hunting.searchString then
        Falkor:log("<white>Hunt Search:  <cyan>" .. Falkor.combat.hunting.searchString)
    end
    
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
