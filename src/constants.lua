-- Constants module: Shared constants used across multiple files
-- Only constants used in 2+ files should be here
-- Single-use constants should be defined inline in their respective files

Falkor = Falkor or {}

-- Balance indicator characters (used in player.lua and balance.lua)
Falkor.PATTERNS = {
    BALANCE_INDICATOR = "x",
    EQUILIBRIUM_INDICATOR = "e",
    LEADING_SPACE_SINGLE = "^ ",  -- Used in player.lua and runewarden.lua
}
