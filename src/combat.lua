--[[
    Combat Module
    Tracks denizens in the room using GMCP Char.Items events
    Maintains a list of all denizens with their ID, name, and description
]]

Falkor = Falkor or {}

-- Initialize combat state
function Falkor:initCombat()
    -- Clean up existing handlers if reinitializing
    if self.combat and self.combat.handlers then
        for name, handlerId in pairs(self.combat.handlers) do
            if handlerId then
                killAnonymousEventHandler(handlerId)
            end
        end
    end
    
    self.combat = {
        -- Denizens currently in the room
        -- Structure: { [id] = { id = "...", name = "...", attrib = "...", icon = "..." } }
        denizens = {},
        
        -- Tracking enabled/disabled
        enabled = true,
        
        -- Hunting state
        hunting = {
            enabled = false,
            searchString = nil,  -- What we're hunting (e.g., "rat")
            target = nil,  -- Current target: { id, name, attrib, icon }
            lastTarget = nil,  -- Last target we had: { id, name, attrib, icon }
            awaitingKillConfirm = false,  -- Waiting to confirm if target was killed or fled
        },
        
        -- Event handler IDs for cleanup
        handlers = {},
    }
    
    -- Register GMCP event handlers (always registered, but only process if enabled)
    self.combat.handlers.list = registerAnonymousEventHandler(
        "gmcp.Char.Items.List", 
        "Falkor:handleItemsList"
    )
    
    self.combat.handlers.add = registerAnonymousEventHandler(
        "gmcp.Char.Items.Add", 
        "Falkor:handleItemsAdd"
    )
    
    self.combat.handlers.remove = registerAnonymousEventHandler(
        "gmcp.Char.Items.Remove", 
        "Falkor:handleItemsRemove"
    )
end

-- Clean up combat module resources
function Falkor:cleanupCombat()
    if not self.combat then
        return
    end
    
    -- Clean up event handlers
    if self.combat.handlers then
        for name, handlerId in pairs(self.combat.handlers) do
            if handlerId then
                killAnonymousEventHandler(handlerId)
            end
        end
        self.combat.handlers = {}
    end
    
    -- Clear hunting state
    if self.combat.hunting then
        self:clearHuntTarget()
        self.combat.hunting = {
            enabled = false,
            searchString = nil,
            target = nil,
            lastTarget = nil,
            awaitingKillConfirm = false,
        }
    end
    
    -- Clear denizens
    self.combat.denizens = {}
end

-- Check if an item is a denizen (has 'm' attribute for mobile)
function Falkor:checkIsDenizen(item)
    if not item.attrib or not item.attrib:find("m") then
        return false
    end
    
    -- Filter out corpses (they have 'm' attribute but aren't alive)
    if item.name and item.name:lower():find("corpse") then
        return false
    end
    
    return true
end

-- Check if a denizen matches our hunting search string
function Falkor:checkMatchesHuntTarget(denizen)
    if not self.combat.hunting.searchString then
        return false
    end
    
    local searchLower = string.lower(self.combat.hunting.searchString)
    local nameLower = string.lower(denizen.name)
    
    -- Check if the search string appears in the denizen name
    return string.find(nameLower, searchLower, 1, true) ~= nil
end

-- Check function for hunting attack persistence
-- Returns true to keep attacking, false to stop
function Falkor.checkHuntAttack()
    -- Keep attacking if hunting is enabled and we have a target
    return Falkor.combat.hunting.enabled and Falkor.combat.hunting.target ~= nil
end

-- Find and set a new hunting target from available denizens
-- silent: if true, don't log the acquisition message
function Falkor:findHuntTarget(silent)
    if not self.combat.hunting.enabled or not self.combat.hunting.searchString then
        return false
    end
    
    -- Look through denizens for a match
    for _, denizen in pairs(self.combat.denizens) do
        if self:checkMatchesHuntTarget(denizen) then
            -- Set as target
            self.combat.hunting.target = {
                id = denizen.id,
                name = denizen.name,
                attrib = denizen.attrib,
                icon = denizen.icon,
                hasShield = false,  -- Track if target has a shield
            }
            
            -- Update last target
            self.combat.hunting.lastTarget = self.combat.hunting.target
            
            -- Add persistent attack action
            local attackCommand = "slaughter " .. denizen.id
            self:addPersistentAction(attackCommand, "bal", Falkor.checkHuntAttack, "falkor_hunt_attack")
            
            -- Queue the initial attack immediately
            self:queueCommand(attackCommand, "bal")
            
            if not silent then
                self:log(string.format(
                    "<green>🎯 Target acquired: <yellow>%s <gray>(ID: %s)",
                    denizen.name,
                    denizen.id
                ))
            end
            
            return true
        end
    end
    
    return false
end

-- Clear current hunting target
function Falkor:clearHuntTarget()
    -- Save current target as last target before clearing
    if self.combat.hunting.target then
        self.combat.hunting.lastTarget = self.combat.hunting.target
    end
    
    self.combat.hunting.target = nil
    self.combat.hunting.awaitingKillConfirm = false
    
    -- Remove persistent attack action (will auto-expire on next balance check anyway)
    self:removePersistentAction("falkor_hunt_attack")
end

-- Handle gmcp.Char.Items.List event
-- This fires when entering a new room or when the full item list updates
function Falkor:handleItemsList(event, ...)
    -- Only process if tracking is enabled
    if not self.combat.enabled then
        return
    end
    
    -- Validate GMCP data exists
    if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.List then
        return
    end
    
    local itemData = gmcp.Char.Items.List
    
    -- Clear current denizens list
    self.combat.denizens = {}
    
    -- Process items and extract denizens
    if itemData.items then
        for _, item in ipairs(itemData.items) do
            if self:checkIsDenizen(item) then
                -- Store denizen by ID
                self.combat.denizens[item.id] = {
                    id = item.id,
                    name = item.name,
                    attrib = item.attrib,
                    icon = item.icon or "none"
                }
            end
        end
    end
    
    -- If hunting and no target, try to find one
    if self.combat.hunting.enabled and not self.combat.hunting.target then
        self:findHuntTarget()
    end
end

-- Handle gmcp.Char.Items.Add event
-- This fires when an item (including denizen) is added to the room
function Falkor:handleItemsAdd(event, ...)
    -- Only process if tracking is enabled
    if not self.combat.enabled then
        return
    end
    
    -- Validate GMCP data exists
    if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Add then
        return
    end
    
    local data = gmcp.Char.Items.Add
    
    -- Check if the added item is a denizen or gold
    if data.item then
        local item = data.item
        
        if self:checkIsDenizen(item) then
            -- Add denizen to tracking
            self.combat.denizens[item.id] = {
                id = item.id,
                name = item.name,
                attrib = item.attrib,
                icon = item.icon or "none"
            }
            
            -- If hunting and no target, try to find one
            if self.combat.hunting.enabled and not self.combat.hunting.target then
                self:findHuntTarget()
            end
        end
    end
end

-- Handle gmcp.Char.Items.Remove event
-- This fires when an item (including denizen) is removed from the room
function Falkor:handleItemsRemove(event, ...)
    -- Only process if tracking is enabled
    if not self.combat.enabled then
        return
    end
    
    -- Validate GMCP data exists
    if not gmcp or not gmcp.Char or not gmcp.Char.Items or not gmcp.Char.Items.Remove then
        return
    end
    
    local data = gmcp.Char.Items.Remove
    
    -- Check if the removed item is a denizen we're tracking
    if data.item and data.item.id and self.combat.denizens[data.item.id] then
        local removedDenizen = self.combat.denizens[data.item.id]
        local wasTarget = false
        
        -- Check if this was our hunting target
        if self.combat.hunting.enabled and self.combat.hunting.target and 
           self.combat.hunting.target.id == data.item.id then
            wasTarget = true
            
            -- Log target lost
            self:log(string.format(
                "<yellow>❌ Target lost: <white>%s <gray>(ID: %s)",
                removedDenizen.name,
                removedDenizen.id
            ))
            
            -- Unset the target immediately
            self:clearHuntTarget()
        end
        
        -- Remove denizen from tracking
        self.combat.denizens[data.item.id] = nil
        
        -- If we lost our target, try to find a new one
        if wasTarget and self.combat.hunting.enabled then
            self:findHuntTarget()
        end
    end
end

-- Log all denizens currently in the room
function Falkor:logDenizens(eventType)
    -- Count denizens
    local count = 0
    for _ in pairs(self.combat.denizens) do
        count = count + 1
    end
    
    -- Log header
    self:log(string.format("<cyan>=== Combat Status [%s] ===", eventType))
    
    -- Show current target
    if self.combat.hunting.enabled and self.combat.hunting.target then
        self:log(string.format(
            "<green>Current Target: <yellow>%s <gray>(ID: %s)",
            self.combat.hunting.target.name,
            self.combat.hunting.target.id
        ))
    elseif self.combat.hunting.enabled then
        self:log("<yellow>Current Target: <white>None")
    end
    
    -- Show denizens in room
    if count == 0 then
        self:log("<yellow>Denizens in room: <white>None")
    else
        self:log(string.format("<green>Denizens in room: <white>%d", count))
        
        -- Convert to array for sorting
        local denizenArray = {}
        for _, denizen in pairs(self.combat.denizens) do
            table.insert(denizenArray, denizen)
        end
        
        -- Sort by name for consistent display
        table.sort(denizenArray, function(a, b)
            return a.name < b.name
        end)
        
        -- Log each denizen
        for i, denizen in ipairs(denizenArray) do
            self:log(string.format(
                "<white>  [%d] <yellow>%s <gray>(ID: %s)",
                i,
                denizen.name,
                denizen.id
            ))
        end
    end
    
    self:log("<cyan>===================================")
end

-- Enable combat tracking
function Falkor:startCombatTracking()
    self.combat.enabled = true
    self:log("<green>Combat tracking ENABLED")
    self:log("<white>Denizens will be logged on room entry and when they enter/leave")
end

-- Disable combat tracking
function Falkor:stopCombatTracking()
    self.combat.enabled = false
    self:log("<yellow>Combat tracking DISABLED")
end

-- Start hunting a specific denizen type
function Falkor:startHunting(searchString)
    if not searchString or searchString == "" then
        self:log("<red>Error: Must provide a search string (e.g., 'fhunt rat')")
        return
    end
    
    -- Trim whitespace
    searchString = searchString:match("^%s*(.-)%s*$")
    
    -- Don't restart if already hunting the same thing
    if self.combat.hunting.enabled and self.combat.hunting.searchString == searchString then
        -- Silently ignore duplicate calls
        return
    end
    
    self.combat.hunting.enabled = true
    self.combat.hunting.searchString = searchString
    self.combat.hunting.target = nil
    self.combat.hunting.awaitingKillConfirm = false
    
    self:log(string.format("<green>🎯 Hunting started: <yellow>%s", searchString))
    
    -- Try to find a target immediately
    if not self:findHuntTarget() then
        self:log("<yellow>No matching denizens in room. Will auto-target when one appears.")
    end
end

-- Stop hunting
function Falkor:stopHunting()
    self.combat.hunting.enabled = false
    self.combat.hunting.searchString = nil
    self:clearHuntTarget()
    
    -- Remove persistent attack action
    self:removePersistentAction("falkor_hunt_attack")
    
    self:log("<yellow>🛑 Hunting stopped")
end

-- Handle kill confirmation
function Falkor:handleKillConfirm()
    if not self.combat.hunting.awaitingKillConfirm then
        return
    end
    
    self:log("<green>✅ Kill confirmed!")
    
    -- Clear the target
    self:clearHuntTarget()
    
    -- Try to find next target
    if self.combat.hunting.enabled then
        if not self:findHuntTarget() then
            self:log("<yellow>No more targets matching '<white>" .. self.combat.hunting.searchString .. "<yellow>' in room")
        end
    end
end

-- Handle shield detection
function Falkor:handleShieldDetected()
    if self.combat.hunting.target then
        self.combat.hunting.target.hasShield = true
    end
end

-- Initialize combat module
Falkor:initCombat()

-- ============================================
-- COMBAT TRIGGERS
-- ============================================

-- Trigger for kill confirmation
Falkor:registerTrigger("triggerHuntKillConfirm", "You have slain", [[
    Falkor:handleKillConfirm()
]])

-- Trigger for shield detection
Falkor:registerTrigger("triggerShieldDetected", "is protected by a shield", [[
    Falkor:handleShieldDetected()
]])

-- ============================================
-- COMBAT ALIASES
-- ============================================

-- Create alias: fhunt (start hunting a denizen type)
Falkor:registerAlias("aliasHunt", "^fhunt (.+)$", [[
    local searchString = matches[2]
    Falkor:startHunting(searchString)
]])
