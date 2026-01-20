-- Balance module: Balance/equilibrium tracking using server-side queueing

Falkor = Falkor or {}

-- Initialize balance tracking
function Falkor:initBalance()
    self.balance = {
        hasBalance = true,
        hasEquilibrium = true,
        persistentActions = {},  -- Persistent actions: { name -> { command, queueType, checkFunc } }
        persistentCallbacks = {},  -- Persistent callbacks: { name -> { func, checkFunc } }
    }
    
    -- Enable server-side queueing
    send("config usequeueing on")
    send("config showqueuealerts off")
    
    Falkor:log("<green>Balance tracking system initialized (using server-side queueing).")
end

-- Add a command to the server-side queue
-- command: command string to send
-- queueType: queue type (default "eqbal" - both balance and equilibrium)
--   Options: "bal", "eq", "eqbal", "free", "freestand", etc.
function Falkor:queueCommand(command, queueType)
    queueType = queueType or "eqbal"
    send(string.format("queue add %s %s", queueType, command))
end

-- Clear the server-side queue
-- queueType: optional queue type to clear (default "all")
function Falkor:clearQueue(queueType)
    queueType = queueType or "all"
    send(string.format("clearqueue %s", queueType))
end

-- Add a persistent action (command that re-queues when balance is regained)
-- command: command string to queue
-- queueType: queue type (default "eqbal")
-- checkFunc: function that returns true to continue, false to expire
-- name: unique name for the action (used for removal)
function Falkor:addPersistentAction(command, queueType, checkFunc, name)
    if not name then
        self:log("<red>Error: Persistent actions must have a name")
        return
    end
    
    if not command then
        self:log("<red>Error: Persistent actions must have a command")
        return
    end
    
    self.balance.persistentActions[name] = {
        command = command,
        queueType = queueType or "eqbal",
        checkFunc = checkFunc
    }
end

-- Remove a persistent action by name
function Falkor:removePersistentAction(name)
    self.balance.persistentActions[name] = nil
end

-- Add a persistent callback (function to call when balance is regained)
-- func: function to execute
-- checkFunc: function that returns true to continue, false to expire
-- name: unique name for the callback (used for removal)
function Falkor:addPersistentCallback(func, checkFunc, name)
    if not name then
        self:log("<red>Error: Persistent callbacks must have a name")
        return
    end
    
    if not func then
        self:log("<red>Error: Persistent callbacks must have a function")
        return
    end
    
    self.balance.persistentCallbacks[name] = {
        func = func,
        checkFunc = checkFunc
    }
end

-- Remove a persistent callback by name
function Falkor:removePersistentCallback(name)
    self.balance.persistentCallbacks[name] = nil
end

-- Called when balance is regained (detected from prompt change)
function Falkor:onBalanceRegained()
    -- Process persistent actions (queued commands)
    local toRemove = {}
    
    for name, action in pairs(self.balance.persistentActions) do
        local shouldContinue = true
        
        -- If there's a check function, call it
        if action.checkFunc and type(action.checkFunc) == "function" then
            shouldContinue = action.checkFunc()
        end
        
        if shouldContinue then
            -- Re-queue the command
            self:queueCommand(action.command, action.queueType)
            if self.config.debug.logLevel >= 2 then
                self:log(string.format("<gray>[DEBUG] Queued: %s", action.command))
            end
        else
            -- Mark for removal
            table.insert(toRemove, name)
            if self.config.debug.logLevel >= 2 then
                self:log(string.format("<gray>[DEBUG] Expired: %s", name))
            end
        end
    end
    
    -- Remove expired actions
    for _, name in ipairs(toRemove) do
        self.balance.persistentActions[name] = nil
    end
    
    -- Process persistent callbacks (direct execution)
    toRemove = {}
    
    for name, callback in pairs(self.balance.persistentCallbacks) do
        local shouldContinue = true
        
        -- If there's a check function, call it
        if callback.checkFunc and type(callback.checkFunc) == "function" then
            shouldContinue = callback.checkFunc()
        end
        
        if shouldContinue then
            -- Execute the callback
            if type(callback.func) == "function" then
                callback.func()
            end
        else
            -- Mark for removal
            table.insert(toRemove, name)
        end
    end
    
    -- Remove expired callbacks
    for _, name in ipairs(toRemove) do
        self.balance.persistentCallbacks[name] = nil
    end
end

-- Called when equilibrium is regained (detected from prompt change)
function Falkor:onEquilibriumRegained()
    -- Currently no specific equilibrium-only actions
    -- Could be extended in the future
end

-- Initialize balance module
Falkor:initBalance()

-- ============================================
-- BALANCE STATE TRACKING
-- ============================================

-- Update balance state from prompt and trigger hooks
-- Prompt format: "1539h, 1150m, 5491e, 4600w ex-" or with battlerage "ex 14r-"
-- Balance indicators: 'e' = equilibrium, 'x' = balance
function Falkor:updateBalanceFromPrompt(line)
    -- Look for the balance indicators in the prompt
    -- Format is typically "ex-" or "e-" or "x-" or "--" or "ex 14r-" or "ex19--"
    -- Match the letters before the optional rage/number and final dash(es)
    local balanceStr = string.match(line, "(%a+)%s*%d*r?%-+$")
    
    if balanceStr then
        local hadBalance = self.balance.hasBalance
        local hadEquilibrium = self.balance.hasEquilibrium
        
        self.balance.hasBalance = string.find(balanceStr, Falkor.PATTERNS.BALANCE_INDICATOR) ~= nil
        self.balance.hasEquilibrium = string.find(balanceStr, Falkor.PATTERNS.EQUILIBRIUM_INDICATOR) ~= nil
        
        -- Trigger hooks when we regain balance/eq (transition from false to true)
        if not hadBalance and self.balance.hasBalance then
            self:onBalanceRegained()
        end
        
        if not hadEquilibrium and self.balance.hasEquilibrium then
            self:onEquilibriumRegained()
        end
    end
end
