local ca       = require("cellular-automaton")
local U        = require("custom-cellular-automaton.animations.snowtown.util")
local Items    = require("custom-cellular-automaton.animations.snowtown.items")
local Place    = require("custom-cellular-automaton.animations.snowtown.placement")
local SnowMod  = require("custom-cellular-automaton.animations.snowtown.snow")
local Spawner  = require("custom-cellular-automaton.animations.snowtown.spawner")

local A = {}

-- === Tunables ===
local FPS              = 30
local SPAWN_INTERVAL   = 7.0     -- seconds between attempts to add a new object
local SNOW_CONFIG      = {
    DENSITY = 0.005,
    WIND_AMPL = 1,
    WIND_FREQ = 0.08,
    TTL_MIN = 8,
    TTL_MAX = 18,
}

-- Animation state
local state = nil

local function reset_state()
    state = {
        t_frames = 0,
        baseline = nil,       -- snapshot of user buffer
        occupancy = {},       -- placed items (rects)
        snow      = SnowMod.new(SNOW_CONFIG),
        spawner   = Spawner.new({ interval = SPAWN_INTERVAL }),
        counts    = {},       -- by name
    }
end

-- Compose the frame: baseline -> objects (anchored then floating) -> snow
local function compose_frame(grid)
    -- DO NOT clear the grid. Start by re-asserting only baseline *non-spaces*.
    local rows, cols = U.grid_size(grid)

    -- 1) Repaint baseline text on top of whatever is there (so it stays intact)
    for r = 1, rows do
        for c = 1, cols do
            local ch = state.baseline[r][c]
            if not U.is_space(ch) then
                grid[r][c].char = ch
            end
        end
    end

    -- 2) Redraw placed objects (they should overwrite snow if present)
    for _, obj in ipairs(state.occupancy) do
        local item
        for _, it in ipairs(Items.catalog) do
            if it.name == obj.name then item = it; break end
        end
        if item then
            -- (see patch to blit below)
            U.blit_stencil_over_spaces(grid, state.baseline, item.stencil, obj.top, obj.left)
        end
    end

    -- 3) Let snow move/settle/fade *without* being wiped first
    state.snow:tick(grid, state.baseline, state.t_frames / FPS)

end

-- Placement callback for the spawner
local function try_place_item(grid, item)
    if item.class == "anchored" then
        return Place.place_anchored(grid, state.baseline, item, state.occupancy)
    else
        return Place.place_floating(grid, state.baseline, item, state.occupancy)
    end
end

A.register = function()
    local cfg = {
        fps  = FPS,
        name = "snowtown",
        init = function(grid)
            math.randomseed(os.time())
            reset_state()
            state.baseline = U.snapshot_grid(grid)

            -- ensure snow object is properly attached to this grid
            state.snow = SnowMod.new(SNOW_CONFIG)
            state.snow:attach(grid)
            assert(type(state.snow.tick) == "function", "[snowtown] snow.tick missing")
            assert(state.snow.ttl ~= nil, "[snowtown] snow.ttl not allocated")

        end,

        update = function(grid)
            state.t_frames = state.t_frames + 1

            -- Spawn logic (one attempt every SPAWN_INTERVAL seconds)
            state.spawner:tick(state.t_frames / FPS, function(item)
                return try_place_item(grid, item)
            end)

            -- Fresh compose
            compose_frame(grid)

            -- Keep running
            return true
        end,
    }

    ca.register_animation(cfg)
end

return A
