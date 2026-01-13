-- Butterflies module: Butterfly catching functionality

Falkor = Falkor or {}

-- Initialize butterfly state
function Falkor:initButterflies()
    self.catchButterflies = false  -- Flag for butterfly catching
    self.pendingButterflyCatches = 0  -- Number of butterfly catches queued
end

-- Toggle butterfly catching
function Falkor:toggleButterflies()
    self.catchButterflies = not self.catchButterflies
    if self.catchButterflies then
        Falkor:log("<green>Butterfly catching enabled.")
    else
        Falkor:log("<red>Butterfly catching disabled.")
    end
end

-- Initialize butterfly module
Falkor:initButterflies()

-- ============================================
-- BUTTERFLY ALIASES AND TRIGGERS
-- ============================================

-- Clean up existing items if they exist (for reloading)
if Falkor.aliasButterfly then killAlias(Falkor.aliasButterfly) end
if Falkor.triggerButterfly then killTrigger(Falkor.triggerButterfly) end
if Falkor.triggerButterflyFailed then killTrigger(Falkor.triggerButterflyFailed) end
if Falkor.triggerButterflyCaught then killTrigger(Falkor.triggerButterflyCaught) end
if Falkor.triggerButterflyNone then killTrigger(Falkor.triggerButterflyNone) end
if Falkor.triggerButterflyNoNet then killTrigger(Falkor.triggerButterflyNoNet) end

-- Create alias: butterflies (toggle butterfly catching)
Falkor.aliasButterfly = tempAlias("^butterflies$", [[
    Falkor:toggleButterflies()
]])

-- Create trigger: Catch butterflies when they appear in the room
-- Only matches room descriptions, not action messages
Falkor.triggerButterfly = tempRegexTrigger("(?:There (?:is|are) )?(\\d+) .*butterfl(?:y|ies) here|A(?:n)? .*butterfl(?:y|ies) (?:flits about|beats its|is here|flutters here)|You spot (?:a|an) .*butterfl(?:y|ies)", [[
    if Falkor.catchButterflies then
        local count = matches[2] and tonumber(matches[2]) or 1
        local word = count == 1 and "butterfly" or "butterflies"
        Falkor:log("<cyan>Detected " .. count .. " " .. word .. "! Queuing catches...")
        Falkor.pendingButterflyCatches = Falkor.pendingButterflyCatches + count
    end
]])

-- Create trigger: Retry catching butterfly on failure
Falkor.triggerButterflyFailed = tempTrigger("flits away and out of reach, eluding your clumsy attempt", [[
    if Falkor.catchButterflies then
        Falkor:log("<yellow>Butterfly escaped! Queuing retry...")
        Falkor.pendingButterflyCatches = Falkor.pendingButterflyCatches + 1
    end
]])

-- Create trigger: Butterfly successfully caught (don't queue more)
Falkor.triggerButterflyCaught = tempTrigger("Success! A", [[
    if Falkor.catchButterflies then
        Falkor:log("<green>Butterfly caught!")
        -- Don't add more to queue, success means we got it
    end
]])

-- Create trigger: No butterflies in room (clear the queue)
Falkor.triggerButterflyNone = tempTrigger("Alas! There are no butterflies to catch here", [[
    if Falkor.catchButterflies and Falkor.pendingButterflyCatches > 0 then
        Falkor:log("<yellow>No butterflies left. Clearing queue.")
        Falkor.pendingButterflyCatches = 0
    end
]])

-- Create trigger: Not wielding a net (abort catching)
Falkor.triggerButterflyNoNet = tempTrigger("You need to be wielding a butterfly net to do that.", [[
    if Falkor.catchButterflies and Falkor.pendingButterflyCatches > 0 then
        Falkor:log("<red>Not wielding a net! Aborting butterfly catching.")
        Falkor.pendingButterflyCatches = 0
    end
]])
