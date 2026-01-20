-- Butterflies module: Butterfly catching functionality

Falkor = Falkor or {}

-- Initialize butterfly state
function Falkor:initButterflies()
    self.butterflies = {
        enabled = true,  -- Enabled by default (edit to false to disable)
        pendingCatches = 0,  -- Number of butterfly catches queued
        startPending = false,  -- Flag for when we're starting butterfly catching
        startStep = 0,  -- Current step in the startup sequence
        sellPending = false,  -- Flag for when we're selling butterflies
        sellStep = 0,  -- Current step in the sell sequence
    }
end

-- Start butterfly catching setup (walk to Vellis and do the sequence)
function Falkor:startButterflies()
    Falkor:log("<cyan>Starting butterfly setup: walking to Vellis...")
    send("walk to Vellis")
    self.butterflies.startPending = true
    self.butterflies.startStep = 0
end

-- Sell butterflies (walk to Vellis and give net)
function Falkor:sellButterflies()
    Falkor:log("<cyan>Selling butterflies: walking to Vellis...")
    send("walk to Vellis")
    self.butterflies.sellPending = true
    self.butterflies.sellStep = 0
end

-- Initialize butterfly module
Falkor:initButterflies()

-- ============================================
-- BUTTERFLY ALIASES AND TRIGGERS
-- ============================================

-- Create alias: butterflies-start (walk to Vellis and set up butterfly catching)
Falkor:registerAlias("aliasButterfliesStart", "^butterflies-start$", [[
    Falkor:startButterflies()
]])

-- Create alias: sellbutterflies (walk to Vellis and sell butterflies)
Falkor:registerAlias("aliasSellButterflies", "^sellbutterflies$", [[
    Falkor:sellButterflies()
]])

-- Create trigger: Catch butterflies when they appear in the room
-- Only matches room descriptions, not action messages
Falkor:registerTrigger("triggerButterfly", "(?:There (?:is|are) )?(\\d+) .*butterfl(?:y|ies) here|A(?:n)? .*butterfl(?:y|ies) (?:flits about|beats its|is here|flutters here)|You spot (?:a|an) .*butterfl(?:y|ies)", [[
    if Falkor.butterflies and Falkor.butterflies.enabled then
        local count = matches[2] and tonumber(matches[2]) or 1
        local word = count == 1 and "butterfly" or "butterflies"
        Falkor:log("<cyan>Detected " .. count .. " " .. word .. "! Queuing catches...")
        Falkor.butterflies.pendingCatches = Falkor.butterflies.pendingCatches + count
    end
]], true)

-- Create trigger: Retry catching butterfly on failure
Falkor:registerTrigger("triggerButterflyFailed", "flits away and out of reach, eluding your clumsy attempt", [[
    if Falkor.butterflies and Falkor.butterflies.enabled then
        Falkor:log("<yellow>Butterfly escaped! Queuing retry...")
        Falkor.butterflies.pendingCatches = Falkor.butterflies.pendingCatches + 1
    end
]])

-- Create trigger: Butterfly successfully caught (don't queue more)
Falkor:registerTrigger("triggerButterflyCaught", "Success! A", [[
    if Falkor.butterflies and Falkor.butterflies.enabled then
        Falkor:log("<green>Butterfly caught!")
        -- Don't add more to queue, success means we got it
    end
]])

-- Create trigger: No butterflies in room (clear the queue)
Falkor:registerTrigger("triggerButterflyNone", "Alas! There are no butterflies to catch here", [[
    if Falkor.butterflies and Falkor.butterflies.enabled and Falkor.butterflies.pendingCatches > 0 then
        Falkor:log("<yellow>No butterflies left. Clearing queue.")
        Falkor.butterflies.pendingCatches = 0
    end
]])

-- Create trigger: Not wielding a net (abort catching)
Falkor:registerTrigger("triggerButterflyNoNet", "You need to be wielding a butterfly net to do that.", [[
    if Falkor.butterflies and Falkor.butterflies.enabled and Falkor.butterflies.pendingCatches > 0 then
        Falkor:log("<red>Not wielding a net! Aborting butterfly catching.")
        Falkor.butterflies.pendingCatches = 0
    end
]])

-- Create trigger: Arrived at Vellis (wait for Vellis to appear)
Falkor:registerTrigger("triggerButterfliesArrived", "You have arrived at your destination!", [[
    if (Falkor.butterflies and Falkor.butterflies.startPending) or (Falkor.butterflies and Falkor.butterflies.sellPending) then
        Falkor:log("<yellow>Arrived at destination. Waiting for Vellis...")
        -- Don't do anything yet, wait for Vellis to appear
    end
]])

-- Create trigger: Vellis appears in room description
Falkor:registerTrigger("triggerVellisPresent", "Vellis, the butterfly collector", [[
    if Falkor.butterflies and Falkor.butterflies.startPending and Falkor.butterflies.startStep == 0 then
        -- Starting sequence: wait for Vellis, then agree
        Falkor.butterflies.startStep = 1
        Falkor:log("<green>Vellis detected! Starting setup sequence...")
        Falkor:addAction("agree")
    elseif Falkor.butterflies and Falkor.butterflies.sellPending and Falkor.butterflies.sellStep == 0 then
        -- Selling sequence: wait for Vellis, then agree
        Falkor.butterflies.sellStep = 1
        Falkor:log("<green>Vellis detected! Starting sell sequence...")
        Falkor:addAction("agree")
    end
]])

-- Handle sequence steps after commands (for starting)
function Falkor:handleButterfliesStep()
    if not self.butterflies or not self.butterflies.startPending then return end
    
    if self.butterflies.startStep == 1 then
        -- Just agreed, now greet
        self.butterflies.startStep = 2
        Falkor:log("<cyan>Greeting Vellis...")
        self:addAction("greet Vellis")
    elseif self.butterflies.startStep == 2 then
        -- Just greeted, now agree again
        self.butterflies.startStep = 3
        Falkor:log("<cyan>Agreeing again...")
        self:addAction("agree")
    elseif self.butterflies.startStep == 3 then
        -- Just agreed again, now wield net
        self.butterflies.startStep = 4
        Falkor:log("<cyan>Wielding net...")
        self:addAction("wield net")
    elseif self.butterflies.startStep == 4 then
        -- Just wielded net, enable butterfly catching
        self.butterflies.startStep = 0
        self.butterflies.startPending = false
        self.butterflies.enabled = true
        Falkor:log("<green>Butterfly catching enabled!")
    end
end

-- Handle sequence steps after commands (for selling)
function Falkor:handleSellButterfliesStep()
    if not self.butterflies or not self.butterflies.sellPending then return end
    
    if self.butterflies.sellStep == 1 then
        -- Just agreed, now give net
        self.butterflies.sellStep = 2
        Falkor:log("<cyan>Giving net to Vellis...")
        self:addAction("give net to Vellis")
    elseif self.butterflies.sellStep == 2 then
        -- Just gave net, turn off butterfly catching
        self.butterflies.sellStep = 0
        self.butterflies.sellPending = false
        self.butterflies.enabled = false
        Falkor:log("<green>Butterflies sold! Butterfly catching disabled.")
    end
end

-- Trigger for "agree" command completion (for starting sequence)
Falkor:registerTrigger("triggerButterfliesAgree", "You agree", [[
    if Falkor.butterflies and Falkor.butterflies.startPending then
        Falkor:handleButterfliesStep()
    end
]])

-- Trigger for "greet" command completion
Falkor:registerTrigger("triggerButterfliesGreet", "You greet", [[
    if Falkor.butterflies and Falkor.butterflies.startPending then
        Falkor:handleButterfliesStep()
    end
]])

-- Trigger for "wield" command completion
Falkor:registerTrigger("triggerButterfliesWield", "You are now wielding", [[
    if Falkor.butterflies and Falkor.butterflies.startPending then
        Falkor:handleButterfliesStep()
    end
]])

-- Trigger for "agree" command completion (for selling sequence)
Falkor:registerTrigger("triggerSellButterfliesAgree", "You agree", [[
    if Falkor.butterflies and Falkor.butterflies.sellPending then
        Falkor:handleSellButterfliesStep()
    end
]])

-- Trigger for "give" command completion
Falkor:registerTrigger("triggerSellButterfliesGive", "You give", [[
    if Falkor.butterflies and Falkor.butterflies.sellPending then
        Falkor:handleSellButterfliesStep()
    end
]])
