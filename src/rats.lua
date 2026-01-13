-- Rats module: Rat farming and selling functionality

Falkor = Falkor or {}

-- Initialize rat state
function Falkor:initRats()
    self.sellRatsPending = false  -- Flag for when we're walking to sell rats
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

-- Clean up existing items if they exist (for reloading)
if Falkor.aliasSellRats then killAlias(Falkor.aliasSellRats) end
if Falkor.triggerArrived then killTrigger(Falkor.triggerArrived) end
if Falkor.triggerRatAppears then killTrigger(Falkor.triggerRatAppears) end

-- Create alias: sellrats (walk to Hakhim and sell rats)
Falkor.aliasSellRats = tempAlias("^sellrats$", [[
    Falkor:sellRats()
]])

-- Create trigger: Arrived at destination (sell rats if pending)
Falkor.triggerArrived = tempTrigger("You have arrived at your destination!", [[
    if Falkor.sellRatsPending then
        Falkor:log("<green>Arrived! Selling rats to Hakhim...")
        send("sell rats to Hakhim")
        Falkor.sellRatsPending = false
    end
]])

-- Create trigger: Auto-attack rats when they appear
Falkor.triggerRatAppears = tempRegexTrigger("(?:Your eyes are drawn to|With a squeak,) (?:a|an) \\w* ?rat|^A \\w* ?rat", [[
    Falkor:log("<cyan>Rat detected! Starting auto-attack...")
    Falkor:startAttack("rat")
]])
