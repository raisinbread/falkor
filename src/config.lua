-- Configuration module: Centralized application configuration
-- All configurable values should be defined here

Falkor = Falkor or {}

-- Initialize configuration
function Falkor:initConfig()
    self.config = {
        -- Elixir system configuration
        elixirs = {
            enabled = true,
            healthThreshold = 50,  -- Percentage below which to drink health elixir
            manaThreshold = 50,    -- Percentage below which to drink mana elixir
        },
        
        -- Battlerage abilities configuration
        battlerage = {
            collide = {
                enabled = true,   -- Auto-use Collide when conditions are met
                rageCost = 14,   -- Rage required to use Collide
                cooldown = 16,   -- Cooldown in seconds
            },
            bulwark = {
                enabled = true,   -- Auto-use Bulwark when conditions are met
                rageCost = 28,   -- Rage required to use Bulwark
                cooldown = 45,   -- Cooldown in seconds
            },
        },
        
        -- Butterfly catching configuration
        butterflies = {
            enabled = true,  -- Auto-catch butterflies when detected
        },
        
        -- Rat farming configuration
        rats = {
            attackCooldown = 3.0,  -- Cooldown in seconds before attacking next rat
        },
        
        -- System timers
        timers = {
            moduleReloadDelay = 0.5,  -- Delay in seconds before reinstalling module
        },
        
        -- Debug and logging configuration
        debug = {
            logLevel = "info",  -- "debug", "info", "warn", "error"
            showQueueStatus = false,  -- Show queue status in fplayer command
        },
    }
    
    Falkor:log("<green>Configuration system initialized.")
end

-- Get a configuration value by path (e.g., "elixirs.healthThreshold")
-- Returns nil if path doesn't exist
function Falkor:getConfig(path)
    if not self.config then
        return nil
    end
    
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, part)
    end
    
    local value = self.config
    for _, part in ipairs(parts) do
        if type(value) == "table" and value[part] ~= nil then
            value = value[part]
        else
            return nil
        end
    end
    
    return value
end

-- Set a configuration value by path (e.g., "elixirs.healthThreshold", 60)
-- Returns true if successful, false if path doesn't exist
function Falkor:setConfig(path, value)
    if not self.config then
        return false
    end
    
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return false
    end
    
    -- Navigate to the parent of the target
    local target = self.config
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(target) == "table" and target[part] ~= nil then
            target = target[part]
        else
            return false
        end
    end
    
    -- Set the value
    local key = parts[#parts]
    if type(target) == "table" then
        target[key] = value
        return true
    end
    
    return false
end

-- Initialize configuration on module load
Falkor:initConfig()
