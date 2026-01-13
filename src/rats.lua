-- Rats module: Rat farming and selling functionality

Falkor = Falkor or {}

-- Initialize rat state
function Falkor:initRats()
    self.sellRatsPending = false  -- Flag for when we're walking to sell rats
    self.ratAttackCooldown = false  -- Flag to prevent rapid-fire rat attacks
end

-- Start selling rats (walk to Hakhim)
function Falkor:sellRats()
    Falkor:log("<cyan>Stopping rat detection and walking to Hakhim...")
    send("rats")
    send("walk to Hakhim")
    self.sellRatsPending = true
end

-- Initialize rat module
Falkor:initRats()

-- ============================================
-- RAT ALIASES AND TRIGGERS
-- ============================================

-- Create alias: sellrats (walk to Hakhim and sell rats)
Falkor:registerAlias("aliasSellRats", "^sellrats$", [[
    Falkor:sellRats()
]])

-- Create trigger: Arrived at destination (sell rats if pending)
Falkor:registerTrigger("triggerArrived", "You have arrived at your destination!", [[
    if Falkor.sellRatsPending then
        Falkor:log("<green>Arrived! Selling rats to Hakhim...")
        send("sell rats to Hakhim")
        Falkor.sellRatsPending = false
    end
]])

-- Create trigger: Auto-attack rats when they appear
Falkor:registerTrigger("triggerRatAppears", "(?:Your eyes are drawn to|With a squeak,) (?:a|an) \\w* ?rat|^A \\w* ?rat", [[
    -- Only attack if we're not already attacking and cooldown has passed
    if not Falkor.autoAttack and not Falkor.ratAttackCooldown then
        Falkor.ratAttackCooldown = true
        Falkor:log("<cyan>Rat detected! Starting auto-attack...")
        Falkor:startAttack("rat")
        -- Clear cooldown after 3 seconds (safety fallback)
        tempTimer(3.0, function()
            Falkor.ratAttackCooldown = false
        end)
    end
]], true)

-- Create trigger: Rat slain (clear cooldown immediately so we can attack next rat)
Falkor:registerTrigger("triggerRatSlain", "You have slain", [[
    -- Clear cooldown when rat is killed so we can attack the next one immediately
    if Falkor.ratAttackCooldown then
        Falkor.ratAttackCooldown = false
    end
]])
