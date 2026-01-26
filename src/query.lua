-- Query module: Interface to Pinecone knowledge base via TypeScript query script
-- Allows querying the knowledge base from within Mudlet

Falkor = Falkor or {}

-- Initialize query state
function Falkor:initQuery()
    self.query = {
        inProgress = false,
        lastQuery = nil,
    }
end

-- Execute query and display results in Mudlet console
function Falkor:executeQuery(queryString)
    if not queryString or queryString:match("^%s*$") then
        self:log("<red>Error: Query string cannot be empty")
        return
    end
    
    if self.query.inProgress then
        self:log("<yellow>A query is already in progress. Please wait...")
        return
    end
    
    self.query.inProgress = true
    self.query.lastQuery = queryString
    
    -- self:log("<cyan>========================================")
    -- self:log("<cyan>Querying Knowledge Base...")
    -- self:log("<cyan>========================================")
    -- self:log("<white>Query: <yellow>" .. queryString)
    -- self:log("<cyan>========================================")
    -- self:log("")
    
    -- Build the command
    local projectPath = Falkor.config.query.projectPath
    local nodePath = Falkor.config.query.nodePath
    local pnpmPath = Falkor.config.query.pnpmPath
    local command = string.format(
        'cd "%s" && PATH="%s:$PATH" "%s" query "%s" 2>&1',
        projectPath,
        nodePath:match("(.*/)[^/]+$"),  -- Extract directory from node path
        pnpmPath,
        queryString:gsub('"', '\\"')  -- Escape quotes in query
    )
    
    -- Execute command and capture output
    local handle = io.popen(command)
    if not handle then
        self:log("<red>Error: Failed to execute query command")
        self.query.inProgress = false
        return
    end
    
    -- Read and display output line by line
    local hasOutput = false
    for line in handle:lines() do
        hasOutput = true
        
        -- Color-code different types of output
        -- if line:match("^Query:") or line:match("^Found %d+ result") then
        --     self:log("<cyan>" .. line)
        -- elseif line:match("^%d+%. Score:") then
        --     self:log("<yellow>" .. line)
        -- elseif line:match("^   Source:") or line:match("^   Chunk:") or line:match("^   Preview:") then
        --     self:log("<gray>" .. line)
        -- elseif line:match("^─+$") or line:match("^═+$") then
        --     self:log("<cyan>" .. line)
        -- elseif line:match("^Generating") or line:match("^Searching") or line:match("embedding") then
        --     self:log("<gray>" .. line)
        if line:match("^Error") or line:match("error") then
            self:log("<red>" .. line)
        else
            -- Regular output (the AI response)
            echo(line .. "\n")
        end
    end
    
    local success = handle:close()
    
    if not hasOutput then
        self:log("<red>No output received from query script")
    end
    
    if not success then
        self:log("")
        self:log("<red>Query command failed. Make sure:")
        self:log("<yellow>  1. You're in the Falkor project directory")
        self:log("<yellow>  2. Dependencies are installed (pnpm install)")
        self:log("<yellow>  3. Ollama is running with llama3.2:3b model")
        self:log("<yellow>  4. Documents have been ingested (pnpm ingest:docs)")
    end
    
    -- self:log("")
    -- self:log("<cyan>========================================")
    
    self.query.inProgress = false
end

-- Initialize query module
Falkor:initQuery()

-- ============================================
-- ALIASES
-- ============================================

-- Create alias: fquery <query>
Falkor:registerAlias("aliasQuery", "^fquery (.+)$", [[
    local queryString = matches[2]
    Falkor:executeQuery(queryString)
]])

-- Create alias: fquery (show help)
Falkor:registerAlias("aliasQueryHelp", "^fquery$", [[
    Falkor:log("<cyan>========================================")
    Falkor:log("<cyan>Falkor Knowledge Base Query")
    Falkor:log("<cyan>========================================")
    Falkor:log("<white>Usage: <yellow>fquery <your question>")
    Falkor:log("")
    Falkor:log("<white>Examples:")
    Falkor:log("<yellow>  fquery What are the tenets of Targossas?")
    Falkor:log("<yellow>  fquery Explain devotion")
    Falkor:log("<yellow>  fquery Who are the Bloodsworn?")
    Falkor:log("")
    Falkor:log("<gray>Note: This queries the local knowledge base")
    Falkor:log("<gray>using documents ingested with 'pnpm ingest:docs'")
    Falkor:log("<cyan>========================================")
]])
