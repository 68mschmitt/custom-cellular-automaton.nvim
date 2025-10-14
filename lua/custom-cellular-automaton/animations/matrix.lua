local cfg = { fps = 24, name = "matrix_rain_soft" }

-- Tunables (tweak to taste)
local SPAWN_PROB_PER_COL = 0.025  -- lower = fewer streams
local MIN_LEN_FACTOR     = 0.06   -- trail length as fraction of screen height
local MAX_LEN_FACTOR     = 0.25
local MIN_SPEED          = 0.35   -- cells per frame
local MAX_SPEED          = 0.75
local COL_COOLDOWN_FR    = 20     -- frames to wait before reusing a column
local CHAR_POOL          = { "0", "1", "┊", "┆" } -- small, readable set

local drops, col_cooldown

local function rand_char()
    return CHAR_POOL[math.random(#CHAR_POOL)]
end

cfg.init = function(grid)
    local w = #grid[1]
    drops = {}
    col_cooldown = {}
    for j = 1, w do col_cooldown[j] = 0 end
    -- optional: start almost empty
end

cfg.update = function(grid)
    local h, w = #grid, #grid[1]

    -- Fade/clear the frame instead of shifting the whole buffer
    for i = 1, h do
        for j = 1, w do
            grid[i][j].char = " "
        end
    end

    -- Decrement column cooldowns
    for j = 1, w do
        if col_cooldown[j] > 0 then col_cooldown[j] = col_cooldown[j] - 1 end
    end

    -- Maybe spawn new drops
    for j = 1, w do
        if col_cooldown[j] == 0 and math.random() < SPAWN_PROB_PER_COL then
            local len = math.random(math.max(2, math.floor(h * MIN_LEN_FACTOR)),
            math.max(3, math.floor(h * MAX_LEN_FACTOR)))
            local speed = MIN_SPEED + math.random() * (MAX_SPEED - MIN_SPEED)
            table.insert(drops, {
                col = j,
                head = 1,     -- fractional row position
                speed = speed,
                len = len,
            })
            col_cooldown[j] = COL_COOLDOWN_FR
        end
    end

    -- Advance and draw drops
    local alive = {}
    for _, d in ipairs(drops) do
        d.head = d.head + d.speed

        -- draw from head down to head-len
        local head_row = math.floor(d.head)
        local tail_row = head_row - d.len

        -- draw sparse trail: only every other cell in tail to reduce density
        for r = head_row, math.max(1, tail_row), -1 do
            if r >= 1 and r <= h then
                if r == head_row then
                    -- brighter head glyph (just a fresh char)
                    grid[r][d.col].char = rand_char()
                else
                    -- thin the tail a bit
                    if ((head_row - r) % 2 == 0) then
                        grid[r][d.col].char = rand_char()
                    end
                end
            end
        end

        -- keep if tail still on screen
        if tail_row <= h then
            table.insert(alive, d)
        end
    end
    drops = alive

    return true
end

local M = {}

function M.register()
    require("cellular-automaton").register_animation(cfg)
end

return M
