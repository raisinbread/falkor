-- Balance module: Balance/equilibrium tracking and command queue

Falkor = Falkor or {}

-- Initialize balance tracking
function Falkor:initBalance()
    self.balance = {
        hasBalance = true,
        hasEquilibrium = true,
        actions = {},  -- FIFO queue of all actions
        queueProcessed = false,  -- Whether we've processed the queue for current balance state
    }
    
    Falkor:log("<green>Balance tracking system initialized.")
end

-- Add an action to the queue
-- action: either a command string to send, or a function to call
-- persistent: if true, action stays in queue and runs repeatedly when balance available
-- name: optional name for persistent actions (used for removal)
function Falkor:addAction(action, persistent, name)
    table.insert(self.balance.actions, {
        action = action,
        persistent = persistent or false,
        name = name
    })
    
    -- Try to process the queue - it will check if we have balance and haven't already processed
    self:processQueue()
end

-- Remove an action by name
function Falkor:removeAction(name)
    for i = #self.balance.actions, 1, -1 do
        if self.balance.actions[i].name == name then
            table.remove(self.balance.actions, i)
        end
    end
end

-- Process actions in FIFO order: persistent first, then non-persistent
function Falkor:processQueue()
    -- Only process if we have balance and equilibrium
    if not self.balance.hasBalance or not self.balance.hasEquilibrium then
        self.balance.queueProcessed = false
        return
    end
    
    -- Don't process if we've already processed for this balance state
    if self.balance.queueProcessed then
        return
    end
    
    -- Process actions in FIFO order
    -- Priority: persistent actions first, then non-persistent
    for i, entry in ipairs(self.balance.actions) do
        -- Skip non-persistent actions on first pass
        if entry.persistent then
            local action = entry.action
            local used = false
            
            if type(action) == "string" then
                -- It's a command string
                send(action)
                used = true
            elseif type(action) == "function" then
                -- It's a function - call it and check if it consumed balance
                used = action()
            end
            
            if used then
                self.balance.queueProcessed = true
                return
            end
        end
    end
    
    -- Second pass: process non-persistent actions in FIFO order
    for i, entry in ipairs(self.balance.actions) do
        if not entry.persistent then
            local action = entry.action
            
            if type(action) == "string" then
                -- It's a command string
                send(action)
                self.balance.queueProcessed = true
            elseif type(action) == "function" then
                -- It's a function - call it and check if it consumed balance
                local used = action()
                if used then
                    self.balance.queueProcessed = true
                end
            end
            
            -- Remove non-persistent action after execution
            table.remove(self.balance.actions, i)
            return
        end
    end
end

-- Set balance state (kept for backward compatibility, but not used)
-- Balance state is now managed by the prompt parser in player.lua
function Falkor:setBalance(hasBalance)
    -- No-op: balance state is managed by prompt parser
end

-- Set equilibrium state (kept for backward compatibility, but not used)
-- Equilibrium state is now managed by the prompt parser in player.lua
function Falkor:setEquilibrium(hasEquilibrium)
    -- No-op: equilibrium state is managed by prompt parser
end

-- Initialize balance module
Falkor:initBalance()

-- ============================================
-- BALANCE TRIGGERS
-- ============================================

-- Trigger: Balance regained
-- Note: We don't call setBalance here because the prompt will handle it
-- This trigger is kept for informational purposes only
Falkor:registerTrigger("triggerBalanceGained", "You have recovered balance", [[
    -- Balance state will be updated by the prompt parser
    -- Don't call setBalance here to avoid duplicate command sends
]])

-- Trigger: Balance lost (various messages)
Falkor:registerTrigger("triggerBalanceLost", "You must regain balance first", [[
    Falkor:setBalance(false)
]])

-- Trigger: Equilibrium regained
Falkor:registerTrigger("triggerEquilibriumGained", "You have recovered equilibrium", [[
    Falkor:setEquilibrium(true)
]])

-- Trigger: Equilibrium lost
Falkor:registerTrigger("triggerEquilibriumLost", "You must regain equilibrium first", [[
    Falkor:setEquilibrium(false)
]])

-- Parse prompt for balance/equilibrium state
-- Prompt format: "1539h, 1150m, 5491e, 4600w ex-" or with battlerage "ex 14r-"
-- Balance indicators: 'e' = equilibrium, 'x' = balance
function Falkor:parseBalanceFromPrompt(line)
    -- Look for the balance indicators in the prompt
    -- Format is typically "ex-" or "e-" or "x-" or "--" or "ex 14r-"
    -- Match the letters before the optional rage and final dash
    local balanceStr = string.match(line, "(%a+)%s*%d*r?%-$")
    
    if balanceStr then
        self.balance.hasBalance = string.find(balanceStr, "x") ~= nil
        self.balance.hasEquilibrium = string.find(balanceStr, "e") ~= nil
        
        -- Process queue when we gain balance/eq
        if self.balance.hasBalance or self.balance.hasEquilibrium then
            self:processQueue()
        end
    end
end
