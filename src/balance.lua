-- Balance module: Balance/equilibrium tracking and command queue

Falkor = Falkor or {}

-- Initialize balance tracking
function Falkor:initBalance()
    self.balance = {
        hasBalance = true,
        hasEquilibrium = true,
        commandQueue = {},  -- Queue of commands waiting for balance
        balancefulFunctions = {},  -- Functions to call when balance is available
    }
    
    Falkor:log("<green>Balance tracking system initialized.")
end

-- Add a command to the queue (replacement for svo.doadd)
-- command: the command string to send
-- priority: optional priority (higher = sooner, default 5)
function Falkor:queueCommand(command, priority)
    priority = priority or 5
    
    table.insert(self.balance.commandQueue, {
        command = command,
        priority = priority
    })
    
    -- Sort queue by priority (higher first)
    table.sort(self.balance.commandQueue, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Try to process the queue immediately
    self:processQueue()
end

-- Add a balanceful function (replacement for svo.addbalanceful)
-- name: unique identifier for the function
-- func: function to call when balance is available (should return true if it used balance)
function Falkor:addBalanceful(name, func)
    self.balance.balancefulFunctions[name] = func
end

-- Remove a balanceful function (replacement for svo.removebalanceful)
-- name: unique identifier for the function
function Falkor:removeBalanceful(name)
    self.balance.balancefulFunctions[name] = nil
end

-- Process the command queue and balanceful functions
function Falkor:processQueue()
    -- Only process if we have balance and equilibrium
    if not self.balance.hasBalance or not self.balance.hasEquilibrium then
        return
    end
    
    -- First, try to execute queued commands
    if #self.balance.commandQueue > 0 then
        local cmd = table.remove(self.balance.commandQueue, 1)
        send(cmd.command)
        self.balance.hasBalance = false
        self.balance.hasEquilibrium = false
        return
    end
    
    -- If no queued commands, try balanceful functions in priority order
    -- Priority order: battlerage abilities first, then auto-attack
    local functionOrder = {
        "falkor_collide",
        "falkor_bulwark", 
        "falkor_autoattack"
    }
    
    local balanceConsumed = false
    for _, name in ipairs(functionOrder) do
        local func = self.balance.balancefulFunctions[name]
        if func then
            local used = func()
            if used then
                -- This function consumed balance (e.g., auto-attack)
                balanceConsumed = true
                break
            end
            -- If battlerage ability fired (returns false but sent a command),
            -- continue to next function (auto-attack)
        end
    end
    
    -- Mark balance as used to prevent duplicate processQueue calls
    if balanceConsumed then
        self.balance.hasBalance = false
        self.balance.hasEquilibrium = false
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
