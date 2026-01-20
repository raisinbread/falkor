-- Rats module: Rat farming and selling functionality

Falkor = Falkor or {}

-- Initialize rat state
function Falkor:initRats()
    self.rats = {
        sellPending = false,  -- Flag for when we're walking to sell rats
        attackCooldown = false,  -- Flag to prevent rapid-fire rat attacks
    }
end

-- Start selling rats (walk to Hakhim)
function Falkor:sellRats()
    Falkor:log("<cyan>Stopping rat detection and walking to Hakhim...")
    send("rats")
    send("walk to Hakhim")
    self.rats.sellPending = true
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
    if Falkor.rats and Falkor.rats.sellPending then
        Falkor:log("<green>Arrived! Selling rats to Hakhim...")
        Falkor:addAction("sell rats to Hakhim")
        Falkor.rats.sellPending = false
    end
]])

-- Create trigger: Auto-attack rats when they appear
Falkor:registerTrigger("triggerRatAppears", "(?:Your eyes are drawn to|With a squeak,) (?:a|an) \\w* ?rat|^An? \\w* ?rat", [[
    -- Only attack if we're not already attacking and cooldown has passed
    if Falkor.player and not Falkor.player.autoAttack and Falkor.rats and not Falkor.rats.attackCooldown then
        Falkor.rats.attackCooldown = true
        Falkor:log("<cyan>Rat detected! Starting auto-attack...")
        Falkor:startAttack("rat")
        -- Clear cooldown after 3 seconds (safety fallback)
        tempTimer(3.0, function()
            if Falkor.rats then
                Falkor.rats.attackCooldown = false
            end
        end)
    end
]], true)

-- Create trigger: Rat slain (clear cooldown immediately so we can attack next rat)
Falkor:registerTrigger("triggerRatSlain", "You have slain", [[
    -- Clear cooldown when rat is killed so we can attack the next one immediately
    if Falkor.rats and Falkor.rats.attackCooldown then
        Falkor.rats.attackCooldown = false
    end
]])
