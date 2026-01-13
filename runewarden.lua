-- Runewarden Combat Script for Mudlet/Achaea
-- Namespace for all Runewarden functions and properties

Runewarden = Runewarden or {}

-- Initialize the system
function Runewarden:init()
    self.autoAttack = false  -- Only flag we need: do we want to auto-attack?
    self.lastTarget = nil    -- Cache for display purposes only
    self.catchButterflies = false  -- Flag for butterfly catching
    self.pendingButterflyCatches = 0  -- Number of butterfly catches queued
    
    -- Set up the prompt to show what we need
    -- Format: health, mana, endurance balance [target]-
    send("config prompt custom *hh, *mm, *ee *b [*t]-")
    
    cecho("<green>Runewarden system initialized.\n")
    cecho("<yellow>Prompt configured to show target and balance.\n")
end

-- Parse the prompt to extract current game state
function Runewarden:parsePrompt(line)
    -- Example prompt: "777h, 500m, 2335e ex [[pygmy]]--"
    -- Extract balance (x = balance, e = equilibrium)
    local hasBalance = string.find(line, "x")
    
    -- Extract target name from [[target]]
    local target = string.match(line, "%[%[(.-)%]%]")
    if target == "" then target = nil end
    
    return hasBalance, target
end

-- Handle prompt updates
function Runewarden:onPrompt(line)
    local hasBalance, target = self:parsePrompt(line)
    
    -- Priority 1: Catch butterflies if we have pending catches and balance
    if self.pendingButterflyCatches > 0 and hasBalance then
        send("catch butterfly")
        self.pendingButterflyCatches = self.pendingButterflyCatches - 1
        return  -- Don't do anything else this prompt
    end
    
    -- Priority 2: Auto-attack logic: if we want to auto-attack AND we have balance AND we have a target
    if self.autoAttack and hasBalance and target then
        send("swing " .. target)
    end
    
    -- Update cached target for display
    if target ~= self.lastTarget then
        self.lastTarget = target
        if target then
            cecho("<cyan>Target detected: " .. target .. "\n")
        else
            cecho("<yellow>Target cleared.\n")
        end
    end
end

-- Start auto-attacking (set target in game, enable auto-attack)
function Runewarden:startAttack(targetName)
    send("settarget " .. targetName)
    self.autoAttack = true
    cecho("<green>Auto-attack enabled for: " .. targetName .. "\n")
    -- Initial swing
    send("swing " .. targetName)
end

-- Stop auto-attacking
function Runewarden:stopAttack()
    self.autoAttack = false
    cecho("<red>Auto-attack disabled.\n")
end

-- Toggle butterfly catching
function Runewarden:toggleButterflies()
    self.catchButterflies = not self.catchButterflies
    if self.catchButterflies then
        cecho("<green>Butterfly catching enabled.\n")
    else
        cecho("<red>Butterfly catching disabled.\n")
    end
end

-- Initialize on load
Runewarden:init()

-- ============================================
-- PROGRAMMATIC SETUP OF ALIASES AND TRIGGERS
-- ============================================

-- Clean up existing items if they exist (for reloading)
if Runewarden.aliasAttack then killAlias(Runewarden.aliasAttack) end
if Runewarden.aliasStop then killAlias(Runewarden.aliasStop) end
if Runewarden.aliasButterfly then killAlias(Runewarden.aliasButterfly) end
if Runewarden.triggerPrompt then killTrigger(Runewarden.triggerPrompt) end
if Runewarden.triggerSlain then killTrigger(Runewarden.triggerSlain) end
if Runewarden.triggerMissedTarget then killTrigger(Runewarden.triggerMissedTarget) end
if Runewarden.triggerButterfly then killTrigger(Runewarden.triggerButterfly) end
if Runewarden.triggerButterflyFailed then killTrigger(Runewarden.triggerButterflyFailed) end
if Runewarden.triggerButterflyCaught then killTrigger(Runewarden.triggerButterflyCaught) end
if Runewarden.triggerButterflyNone then killTrigger(Runewarden.triggerButterflyNone) end

-- Create alias: att <target>
Runewarden.aliasAttack = tempAlias("^att (.+)$", [[
    local target = matches[2]
    Runewarden:startAttack(target)
]])

-- Create alias: stop
Runewarden.aliasStop = tempAlias("^stop$", [[
    Runewarden:stopAttack()
]])

-- Create alias: butterflies (toggle butterfly catching)
Runewarden.aliasButterfly = tempAlias("^butterflies$", [[
    Runewarden:toggleButterflies()
]])

-- Create trigger: Prompt line (this fires on EVERY prompt)
-- Match the custom prompt format: "777h, 500m, 2335e ex [[pygmy]]--" or "777h, 500m, 2335e ex []--"
Runewarden.triggerPrompt = tempRegexTrigger("^\\d+h, \\d+m, \\d+e .* \\[.*\\]--$", [[
    Runewarden:onPrompt(line)
]])

-- Create trigger: Target slain (auto-disables attack)
Runewarden.triggerSlain = tempTrigger("You have slain", [[
    Runewarden:stopAttack()
    cecho("<green>Target slain! Auto-attack disabled.\n")
]])

-- Create trigger: Target not found (auto-disables attack)
Runewarden.triggerMissedTarget = tempTrigger("but see nothing by that name here!", [[
    Runewarden:stopAttack()
    cecho("<yellow>Target not found! Auto-attack disabled.\n")
]])

-- Create trigger: Catch butterflies when they appear in the room
-- Only matches room descriptions, not action messages
Runewarden.triggerButterfly = tempRegexTrigger("(?:There (?:is|are) )?(\\d+) .*butterfl(?:y|ies) here|A(?:n)? .*butterfl(?:y|ies) (?:flits about|beats its|is here)", [[
    if Runewarden.catchButterflies then
        local count = matches[2] and tonumber(matches[2]) or 1
        local word = count == 1 and "butterfly" or "butterflies"
        cecho("<cyan>Detected " .. count .. " " .. word .. "! Queuing catches...\n")
        Runewarden.pendingButterflyCatches = Runewarden.pendingButterflyCatches + count
    end
]])

-- Create trigger: Retry catching butterfly on failure
Runewarden.triggerButterflyFailed = tempTrigger("flits away and out of reach, eluding your clumsy attempt", [[
    if Runewarden.catchButterflies then
        cecho("<yellow>Butterfly escaped! Queuing retry...\n")
        Runewarden.pendingButterflyCatches = Runewarden.pendingButterflyCatches + 1
    end
]])

-- Create trigger: Butterfly successfully caught (don't queue more)
Runewarden.triggerButterflyCaught = tempTrigger("Success! A", [[
    if Runewarden.catchButterflies then
        cecho("<green>Butterfly caught!\n")
        -- Don't add more to queue, success means we got it
    end
]])

-- Create trigger: No butterflies in room (clear the queue)
Runewarden.triggerButterflyNone = tempTrigger("Alas! There are no butterflies to catch here", [[
    if Runewarden.catchButterflies and Runewarden.pendingButterflyCatches > 0 then
        cecho("<yellow>No butterflies left. Clearing queue.\n")
        Runewarden.pendingButterflyCatches = 0
    end
]])

cecho("<green>========================================\n")
cecho("<green>Runewarden Combat Script Loaded!\n")
cecho("<green>========================================\n")
cecho("<cyan>Commands:\n")
cecho("<white>  att <target>  - Begin attacking a target\n")
cecho("<white>  stop          - Stop auto-attacking\n")
cecho("<white>  butterflies   - Toggle butterfly catching\n")
cecho("<green>========================================\n")