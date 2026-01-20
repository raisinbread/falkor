#!/usr/bin/env lua
-- Build script for Falkor Mudlet package
-- Generates an XML package from .lua source files in src/

local PACKAGE_NAME = "Falkor"
local SRC_DIR = "src"
local BUILD_DIR = "build"
local OUTPUT_FILE = BUILD_DIR .. "/" .. PACKAGE_NAME .. ".xml"

-- Load order for scripts (dependencies first)
local LOAD_ORDER = {
    "log.lua",
    "constants.lua",  -- Constants must load first
    "config.lua",  -- Configuration must load second
    "main.lua",  -- Load early to provide utility functions
    "balance.lua",  -- Balance tracking must load before modules that use it
    "player.lua",
    "elixirs.lua",  -- Elixir system depends on player module
    "combat.lua",  -- Combat tracking system
    "runewarden.lua",
    "butterflies.lua",
}

-- Escape XML special characters (only &, <, > need escaping in element content)
local function escapeXml(str)
    return str
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end

-- Read file contents
local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

-- Check Lua file for syntax errors
local function checkSyntax(path)
    -- Use luac -p for syntax-only checking (doesn't execute code)
    local handle = io.popen("luac -p \"" .. path .. "\" 2>&1")
    if not handle then
        return false, "Could not run syntax check"
    end
    
    local output = handle:read("*a")
    local success = handle:close()
    
    if not success or output ~= "" then
        return false, output
    end
    
    return true, nil
end

-- Write file contents
local function writeFile(path, content)
    local file = io.open(path, "w")
    if not file then
        error("Could not open file for writing: " .. path)
    end
    file:write(content)
    file:close()
end

-- Check if directory exists
local function dirExists(path)
    local ok, err, code = os.rename(path, path)
    if not ok then
        if code == 13 then return true end -- Permission denied but exists
    end
    return ok
end

-- Create directory (works on Unix/macOS)
local function mkdir(path)
    os.execute("mkdir -p " .. path)
end

-- List .lua files in directory
local function listLuaFiles(dir)
    local files = {}
    local handle = io.popen('ls "' .. dir .. '"/*.lua 2>/dev/null')
    if handle then
        for file in handle:lines() do
            local name = file:match("([^/]+)$")
            if name then
                files[name] = true
            end
        end
        handle:close()
    end
    return files
end

-- Get absolute path of current directory
local function getAbsolutePath()
    local handle = io.popen("pwd")
    if handle then
        local path = handle:read("*a"):gsub("%s+", "") -- Remove all whitespace including newlines
        handle:close()
        if path and path ~= "" then
            return path
        end
    end
    -- Fallback: try environment variable (Unix/macOS)
    return os.getenv("PWD") or "."
end

-- Generate XML for a single script
local function generateScript(name, content)
    return string.format([[			<Script isActive="yes" isFolder="no">
				<name>%s</name>
				<packageName></packageName>
				<script>%s</script>
				<eventHandlerList />
			</Script>]], name, escapeXml(content))
end

-- Main build function
local function build()
    -- Ensure build directory exists
    if not dirExists(BUILD_DIR) then
        mkdir(BUILD_DIR)
    end

    -- Get absolute path to the XML output file
    local projectRoot = getAbsolutePath()
    local xmlPath = projectRoot .. "/" .. OUTPUT_FILE

    -- Collect scripts in order
    local scripts = {}
    local processed = {}

    -- First, process files in explicit load order
    for _, filename in ipairs(LOAD_ORDER) do
        local path = SRC_DIR .. "/" .. filename
        
        -- Check syntax first
        local syntaxOk, syntaxError = checkSyntax(path)
        if not syntaxOk then
            print("  ERROR in " .. filename .. ":")
            print("    " .. syntaxError)
            error("Syntax error in " .. filename .. ", aborting build")
        end
        
        local content = readFile(path)
        if content then
            -- Replace placeholder with actual XML path (only for main.lua)
            if filename == "main.lua" then
                content = content:gsub("__FALKOR_XML_PATH__", xmlPath)
            end
            table.insert(scripts, generateScript(filename, content))
            processed[filename] = true
            print("  Added: " .. filename)
        end
    end

    -- Then, add any remaining .lua files not in load order
    local allFiles = listLuaFiles(SRC_DIR)
    local extras = {}
    for filename in pairs(allFiles) do
        if not processed[filename] then
            table.insert(extras, filename)
        end
    end
    table.sort(extras)

    for _, filename in ipairs(extras) do
        local path = SRC_DIR .. "/" .. filename
        
        -- Check syntax first
        local syntaxOk, syntaxError = checkSyntax(path)
        if not syntaxOk then
            print("  ERROR in " .. filename .. ":")
            print("    " .. syntaxError)
            error("Syntax error in " .. filename .. ", aborting build")
        end
        
        local content = readFile(path)
        if content then
            -- Replace placeholder with actual XML path (only for main.lua)
            if filename == "main.lua" then
                content = content:gsub("__FALKOR_XML_PATH__", xmlPath)
            end
            table.insert(scripts, generateScript(filename, content))
            print("  Added: " .. filename .. " (extra)")
        end
    end

    -- Generate the full XML package
    local xml = string.format([[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MudletPackage>
<MudletPackage version="1.001">
	<ScriptPackage>
		<ScriptGroup isActive="yes" isFolder="yes">
			<name>%s</name>
			<packageName></packageName>
			<script></script>
			<eventHandlerList />
%s
		</ScriptGroup>
	</ScriptPackage>
</MudletPackage>
]], PACKAGE_NAME, table.concat(scripts, "\n"))

    -- Write output file
    writeFile(OUTPUT_FILE, xml)

    print("")
    print("Build complete!")
    print("  Output: " .. OUTPUT_FILE)
    print("  Scripts: " .. #scripts)
end

-- Run the build
print("Building " .. PACKAGE_NAME .. " package...")
print("")
build()
