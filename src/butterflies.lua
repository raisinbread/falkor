-- Butterflies module: Butterfly catching functionality

Falkor = Falkor or {}

-- Initialize butterfly state
function Falkor:initButterflies()
    self.catchButterflies = false  -- Flag for butterfly catching
    self.pendingButterflyCatches = 0  -- Number of butterfly catches queued
    self.butterfliesStartPending = false  -- Flag for when we're starting butterfly catching
    self.butterfliesStartStep = 0  -- Current step in the startup sequence
    self.sellButterfliesPending = false  -- Flag for when we're selling butterflies
    self.sellButterfliesStep = 0  -- Current step in the sell sequence
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

-- Start butterfly catching setup (walk to Vellis and do the sequence)
function Falkor:startButterflies()
    Falkor:log("<cyan>Starting butterfly setup: walking to Vellis...")
    send("walk to Vellis")
    self.butterfliesStartPending = true
    self.butterfliesStartStep = 0
end

-- Sell butterflies (walk to Vellis and give net)
function Falkor:sellButterflies()
    Falkor:log("<cyan>Selling butterflies: walking to Vellis...")
    send("walk to Vellis")
    self.sellButterfliesPending = true
    self.sellButterfliesStep = 0
end

-- Initialize butterfly module
Falkor:initButterflies()

-- ============================================
-- BUTTERFLY ALIASES AND TRIGGERS
-- ============================================

-- Create alias: butterflies (toggle butterfly catching)
Falkor:registerAlias("aliasButterfly", "^butterflies$", [[
    Falkor:toggleButterflies()
]])

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
    if Falkor.catchButterflies then
        local count = matches[2] and tonumber(matches[2]) or 1
        local word = count == 1 and "butterfly" or "butterflies"
        Falkor:log("<cyan>Detected " .. count .. " " .. word .. "! Queuing catches...")
        Falkor.pendingButterflyCatches = Falkor.pendingButterflyCatches + count
    end
]], true)

-- Create trigger: Retry catching butterfly on failure
Falkor:registerTrigger("triggerButterflyFailed", "flits away and out of reach, eluding your clumsy attempt", [[
    if Falkor.catchButterflies then
        Falkor:log("<yellow>Butterfly escaped! Queuing retry...")
        Falkor.pendingButterflyCatches = Falkor.pendingButterflyCatches + 1
    end
]])

-- Create trigger: Butterfly successfully caught (don't queue more)
Falkor:registerTrigger("triggerButterflyCaught", "Success! A", [[
    if Falkor.catchButterflies then
        Falkor:log("<green>Butterfly caught!")
        -- Don't add more to queue, success means we got it
    end
]])

-- Create trigger: No butterflies in room (clear the queue)
Falkor:registerTrigger("triggerButterflyNone", "Alas! There are no butterflies to catch here", [[
    if Falkor.catchButterflies and Falkor.pendingButterflyCatches > 0 then
        Falkor:log("<yellow>No butterflies left. Clearing queue.")
        Falkor.pendingButterflyCatches = 0
    end
]])

-- Create trigger: Not wielding a net (abort catching)
Falkor:registerTrigger("triggerButterflyNoNet", "You need to be wielding a butterfly net to do that.", [[
    if Falkor.catchButterflies and Falkor.pendingButterflyCatches > 0 then
        Falkor:log("<red>Not wielding a net! Aborting butterfly catching.")
        Falkor.pendingButterflyCatches = 0
    end
]])

-- Create trigger: Arrived at Vellis (wait for Vellis to appear)
Falkor:registerTrigger("triggerButterfliesArrived", "You have arrived at your destination!", [[
    if Falkor.butterfliesStartPending or Falkor.sellButterfliesPending then
        Falkor:log("<yellow>Arrived at destination. Waiting for Vellis...")
        -- Don't do anything yet, wait for Vellis to appear
    end
]])

-- Create trigger: Vellis appears in room description
Falkor:registerTrigger("triggerVellisPresent", "Vellis, the butterfly collector", [[
    if Falkor.butterfliesStartPending and Falkor.butterfliesStartStep == 0 then
        -- Starting sequence: wait for Vellis, then agree
        Falkor.butterfliesStartStep = 1
        Falkor:log("<green>Vellis detected! Starting setup sequence...")
        Falkor:queueCommand("agree")
    elseif Falkor.sellButterfliesPending and Falkor.sellButterfliesStep == 0 then
        -- Selling sequence: wait for Vellis, then agree
        Falkor.sellButterfliesStep = 1
        Falkor:log("<green>Vellis detected! Starting sell sequence...")
        Falkor:queueCommand("agree")
    end
]])

-- Handle sequence steps after commands (for starting)
function Falkor:handleButterfliesStep()
    if not self.butterfliesStartPending then return end
    
    if self.butterfliesStartStep == 1 then
        -- Just agreed, now greet
        self.butterfliesStartStep = 2
        Falkor:log("<cyan>Greeting Vellis...")
        self:queueCommand("greet Vellis")
    elseif self.butterfliesStartStep == 2 then
        -- Just greeted, now agree again
        self.butterfliesStartStep = 3
        Falkor:log("<cyan>Agreeing again...")
        self:queueCommand("agree")
    elseif self.butterfliesStartStep == 3 then
        -- Just agreed again, now wield net
        self.butterfliesStartStep = 4
        Falkor:log("<cyan>Wielding net...")
        self:queueCommand("wield net")
    elseif self.butterfliesStartStep == 4 then
        -- Just wielded net, enable butterfly catching
        self.butterfliesStartStep = 0
        self.butterfliesStartPending = false
        self.catchButterflies = true
        Falkor:log("<green>Butterfly catching enabled!")
    end
end

-- Handle sequence steps after commands (for selling)
function Falkor:handleSellButterfliesStep()
    if not self.sellButterfliesPending then return end
    
    if self.sellButterfliesStep == 1 then
        -- Just agreed, now give net
        self.sellButterfliesStep = 2
        Falkor:log("<cyan>Giving net to Vellis...")
        self:queueCommand("give net to Vellis")
    elseif self.sellButterfliesStep == 2 then
        -- Just gave net, turn off butterfly catching
        self.sellButterfliesStep = 0
        self.sellButterfliesPending = false
        self.catchButterflies = false
        Falkor:log("<green>Butterflies sold! Butterfly catching disabled.")
    end
end

-- Trigger for "agree" command completion (for starting sequence)
Falkor:registerTrigger("triggerButterfliesAgree", "You agree", [[
    if Falkor.butterfliesStartPending then
        Falkor:handleButterfliesStep()
    end
]])

-- Trigger for "greet" command completion
Falkor:registerTrigger("triggerButterfliesGreet", "You greet", [[
    if Falkor.butterfliesStartPending then
        Falkor:handleButterfliesStep()
    end
]])

-- Trigger for "wield" command completion
Falkor:registerTrigger("triggerButterfliesWield", "You are now wielding", [[
    if Falkor.butterfliesStartPending then
        Falkor:handleButterfliesStep()
    end
]])

-- Trigger for "agree" command completion (for selling sequence)
Falkor:registerTrigger("triggerSellButterfliesAgree", "You agree", [[
    if Falkor.sellButterfliesPending then
        Falkor:handleSellButterfliesStep()
    end
]])

-- Trigger for "give" command completion
Falkor:registerTrigger("triggerSellButterfliesGive", "You give", [[
    if Falkor.sellButterfliesPending then
        Falkor:handleSellButterfliesStep()
    end
]])
