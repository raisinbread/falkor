-- Player module: Core state management and combat
-- Handles bashing, auto-attack, and prompt parsing

Falkor = Falkor or {}

-- Initialize player state
function Falkor:initPlayer()
    self.autoAttack = false  -- Only flag we need: do we want to auto-attack?
    self.lastTarget = nil    -- Cache for display purposes only
    
    -- Note: SVOF manages the prompt, so we don't configure it here
    -- SVOF's prompt includes battlerage tracking automatically
    
    Falkor:log("<green>Falkor player system initialized.")
    Falkor:log("<yellow>Using SVOF queue management and prompt.")
end

-- Balanceful function for auto-attacking
-- This gets called by SVOF when balance is available
function Falkor.autoAttackFunction()
    -- Only attack if auto-attack is enabled and we have a target
    if Falkor.autoAttack and Falkor.lastTarget then
        send("kill " .. Falkor.lastTarget)
        return true  -- We sent a command that uses balance
    end
    return false  -- Don't do anything
end

-- Parse the prompt to extract current game state
function Falkor:parsePrompt(line)
    -- SVOF tracks target via gmcp.Char.Combat.Target
    -- Use SVOF's target tracking
    local target = nil
    if gmcp and gmcp.Char and gmcp.Char.Combat and gmcp.Char.Combat.Target then
        target = gmcp.Char.Combat.Target
    end
    
    return target
end

-- Handle prompt updates
function Falkor:onPrompt(line)
    local target = self:parsePrompt(line)
    
    -- Parse rage from prompt (for runewarden battlerage abilities)
    if self.parseRage then
        self:parseRage(line)
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
    
    -- Priority 1: Catch butterflies if we have pending catches
    -- SVOF will handle balance checking and queuing
    if self.pendingButterflyCatches and self.pendingButterflyCatches > 0 then
        svo.doadd("catch butterfly", false, false)
        self.pendingButterflyCatches = self.pendingButterflyCatches - 1
    end
    
    -- Note: Auto-attack is now handled by the balanceful queue function
    -- No need to do anything here - SVOF will call our function when balance is available
end

-- Start auto-attacking (set target in game, enable auto-attack)
-- targetName: optional target name. If nil, just enables auto-attack without changing target
function Falkor:startAttack(targetName)
    if targetName then
        send("settarget " .. targetName)
        self.lastTarget = targetName
        Falkor:log("<green>Auto-attack enabled for: " .. targetName)
    else
        Falkor:log("<green>Auto-attack enabled (using current target).")
    end
    self.autoAttack = true
    
    -- Add our attack function to SVOF's balanceful queue
    svo.addbalanceful("falkor_autoattack", Falkor.autoAttackFunction)
end

-- Stop auto-attacking
function Falkor:stopAttack()
    self.autoAttack = false
    
    -- Remove our attack function from SVOF's balanceful queue
    svo.removebalanceful("falkor_autoattack")
    
    Falkor:log("<red>Auto-attack disabled.")
end

-- Initialize player module
Falkor:initPlayer()

-- Register event handler for when SVOF's balanceful queue is ready
-- This ensures our functions are re-added if the queue is cleared
function Falkor.onSvoBalancefulReady()
    if Falkor.autoAttack then
        svo.addbalanceful("falkor_autoattack", Falkor.autoAttackFunction)
    end
end

registerAnonymousEventHandler("svo balanceful ready", "Falkor.onSvoBalancefulReady")

-- ============================================
-- PLAYER ALIASES AND TRIGGERS
-- ============================================

-- Create alias: att [target] (target is optional)
Falkor:registerAlias("aliasAttack", "^att( .+)?$", [[
    local target = matches[2]
    if target then
        -- Remove leading space
        target = string.gsub(target, "^ ", "")
    else
        -- No target provided, try to use the last target from prompt
        target = Falkor.lastTarget
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
-- Match SVOF's prompt format: "1539h, 1150m, 5491e, 4600w ex-" or with battlerage "ex 14r-"
-- SVOF manages the prompt format
Falkor:registerTrigger("triggerPrompt", "^\\d+h, \\d+m, \\d+e, \\d+w .+-$", [[
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
        svo.doadd("stand", false, false)
    end
]])
