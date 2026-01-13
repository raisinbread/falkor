-- Logging module: Centralized console output
-- All output should go through this module

Falkor = Falkor or {}

-- Log a message to the console with the Falkor prefix
-- Preserves color codes from the input string
function Falkor:log(message)
    -- Remove trailing newline if present, we'll add our own
    local msg = message:gsub("\n$", "")
    cecho("[🐉] - " .. msg .. "\n")
end
