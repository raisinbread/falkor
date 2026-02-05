-- Prayer module: Interface to LLM for composing prayers in Breviary style
-- Allows generating prayers from within Mudlet using the Breviary as reference

Falkor = Falkor or {}

-- Initialize prayer state
function Falkor:initPray()
    self.pray = {
        inProgress = false,
        lastPrompt = nil,
    }
end

-- Execute prayer composition and display results in Mudlet console
function Falkor:composePrayer(promptString)
    if not promptString or promptString:match("^%s*$") then
        self:log("<red>Error: Prayer prompt cannot be empty")
        return
    end
    
    if self.pray.inProgress then
        self:log("<yellow>A prayer is already being composed. Please wait...")
        return
    end
    
    self.pray.inProgress = true
    self.pray.lastPrompt = promptString
    
    -- Build the command
    local projectPath = Falkor.config.paths.projectPath
    local nodePath = Falkor.config.paths.nodePath
    local pnpmPath = Falkor.config.paths.pnpmPath
    local command = string.format(
        'cd "%s" && PATH="%s:$PATH" "%s" pray "%s" 2>&1',
        projectPath,
        nodePath:match("(.*/)[^/]+$"),  -- Extract directory from node path
        pnpmPath,
        promptString:gsub('"', '\\"')  -- Escape quotes in prompt
    )
    
    -- Execute command and capture output
    local handle = io.popen(command)
    if not handle then
        self:log("<red>Error: Failed to execute prayer command")
        self.pray.inProgress = false
        return
    end
    
    -- Read and display output line by line
    local hasOutput = false
    for line in handle:lines() do
        hasOutput = true
        
        if line:match("^Error") or line:match("error") then
            self:log("<red>" .. line)
        else
            -- Regular output (the composed prayer)
            echo(line .. "\n")
        end
    end
    
    local success = handle:close()
    
    if not hasOutput then
        self:log("<red>No output received from prayer script")
    end
    
    if not success then
        self:log("")
        self:log("<red>Prayer command failed. Make sure:")
        self:log("<yellow>  1. You're in the Falkor project directory")
        self:log("<yellow>  2. Dependencies are installed (pnpm install)")
        self:log("<yellow>  3. Ollama is running with qwen2.5:7b model")
        self:log("<yellow>  4. The Breviary document exists at docs/breviary_of_targossas.txt")
    end
    
    self.pray.inProgress = false
end

-- Initialize prayer module
Falkor:initPray()

-- ============================================
-- ALIASES
-- ============================================

-- Create alias: fpray <prompt>
Falkor:registerAlias("aliasPray", "^fpray (.+)$", [[
    local promptString = matches[2]
    Falkor:composePrayer(promptString)
]])

-- Create alias: fpray (show help)
Falkor:registerAlias("aliasPrayHelp", "^fpray$", [[
    Falkor:log("<cyan>========================================")
    Falkor:log("<cyan>Falkor Prayer Composer")
    Falkor:log("<cyan>========================================")
    Falkor:log("<white>Usage: <yellow>fpray <your prayer prompt>")
    Falkor:log("")
    Falkor:log("<white>Examples:")
    Falkor:log("<yellow>  fpray Compose a prayer for victory in battle")
    Falkor:log("<yellow>  fpray Write a prayer of thanks for the Bloodsworn")
    Falkor:log("<yellow>  fpray Create a prayer for strength and courage")
    Falkor:log("")
    Falkor:log("<gray>Note: This uses the Breviary of Targossas as a")
    Falkor:log("<gray>style reference to compose prayers with an LLM")
    Falkor:log("<cyan>========================================")
]])
