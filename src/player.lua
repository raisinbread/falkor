-- Player module: Core state management and combat
-- Handles bashing, auto-attack, and prompt parsing

Falkor = Falkor or {}

-- Initialize player state
function Falkor:initPlayer()
    self.autoAttack = false  -- Only flag we need: do we want to auto-attack?
    self.lastTarget = nil    -- Cache for display purposes only
    
    -- Set up the prompt to show what we need
    -- Format: health, mana, endurance balance [target]-
    send("config prompt custom *hh, *mm, *ee *b [*t]-")
    
    Falkor:log("<green>Falkor player system initialized.")
    Falkor:log("<yellow>Prompt configured to show target and balance.")
end

-- Execute bash attack against a target
function Falkor:bash(target)
    send("swing " .. target)
end

-- Parse the prompt to extract current game state
function Falkor:parsePrompt(line)
    -- Example prompt: "777h, 500m, 2335e ex [[pygmy]]--"
    -- Extract balance (x = balance, e = equilibrium)
    local hasBalance = string.find(line, "x")
    
    -- Extract target name from [[target]]
    local target = string.match(line, "%[%[(.-)%]%]")
    if target == "" then target = nil end
    
    return hasBalance, target
end

-- Handle prompt updates
function Falkor:onPrompt(line)
    local hasBalance, target = self:parsePrompt(line)
    
    -- Priority 1: Catch butterflies if we have pending catches and balance
    if self.pendingButterflyCatches and self.pendingButterflyCatches > 0 and hasBalance then
        send("catch butterfly")
        self.pendingButterflyCatches = self.pendingButterflyCatches - 1
        return  -- Don't do anything else this prompt
    end
    
    -- Priority 2: Auto-attack logic: if we want to auto-attack AND we have balance AND we have a target
    if self.autoAttack and hasBalance and target then
        self:bash(target)
    end
    
    -- Update cached target for display
    if target ~= self.lastTarget then
        self.lastTarget = target
        if target then
            Falkor:log("<cyan>Target detected: " .. target)
        else
            Falkor:log("<yellow>Target cleared.")
        end
    end
end

-- Start auto-attacking (set target in game, enable auto-attack)
function Falkor:startAttack(targetName)
    send("settarget " .. targetName)
    self.autoAttack = true
    Falkor:log("<green>Auto-attack enabled for: " .. targetName)
    -- Don't send initial bash - let the prompt handler do it when we have balance
end

-- Stop auto-attacking
function Falkor:stopAttack()
    self.autoAttack = false
    Falkor:log("<red>Auto-attack disabled.")
end

-- Initialize player module
Falkor:initPlayer()

-- ============================================
-- PLAYER ALIASES AND TRIGGERS
-- ============================================

-- Create alias: att <target>
Falkor:registerAlias("aliasAttack", "^att (.+)$", [[
    local target = matches[2]
    Falkor:startAttack(target)
]])

-- Create alias: stop
Falkor:registerAlias("aliasStop", "^stop$", [[
    Falkor:stopAttack()
]])

-- Create trigger: Prompt line (this fires on EVERY prompt)
-- Match the custom prompt format: "777h, 500m, 2335e ex [[pygmy]]--" or "777h, 500m, 2335e ex []--"
Falkor:registerTrigger("triggerPrompt", "^\\d+h, \\d+m, \\d+e .* \\[.*\\]--$", [[
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
    if Falkor.autoAttack then
        Falkor:log("<yellow>Must stand! Standing up...")
        send("stand")
    end
]])
