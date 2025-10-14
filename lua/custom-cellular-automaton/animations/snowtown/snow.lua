local U = require("custom-cellular-automaton.animations.snowtown.util")

local Snow = {}

-- Config (tune from animation)
Snow.DENSITY   = 0.005
Snow.WIND_AMPL = 1
Snow.WIND_FREQ = 0.08
Snow.TTL_MIN   = 8      -- frames
Snow.TTL_MAX   = 18
Snow.FLAKES    = { "*", "·", ".", "•" }

local function rnd_flake(self)
    local t = self.FLAKES
    return t[math.random(#t)]
end

-- Allocate TTL field parallel to grid; 0 means no settled snow
function Snow.alloc_ttl(grid)
    local rows, cols = U.grid_size(grid)
    local ttl = {}
    for r=1, rows do
        ttl[r] = {}
        for c=1, cols do
            ttl[r][c] = 0
        end
    end
    return ttl
end

local function is_snow_char(ch)
    return ch == "*" or ch == "·" or ch == "." or ch == "•"
end

local function spawn_top(self, grid, baseline)
    local rows, cols = U.grid_size(grid)
    for c=1, cols do
        if U.is_space(baseline[1][c]) and U.is_space(grid[1][c].char) and math.random() < self.DENSITY then
            grid[1][c].char = rnd_flake(self)
        end
    end
end

local function cell_empty(grid, r, c)
    return r>=1 and c>=1 and r<=#grid and c<=#grid[1] and U.is_space(grid[r][c].char)
end

local function step_fall(grid, r, c, wind)
    local rows, cols = U.grid_size(grid)
    local below = r + 1
    if below <= rows and U.is_space(grid[below][c].char) then
        grid[below][c].char, grid[r][c].char = grid[r][c].char, " "
        return true
    end
    local dir = wind >= 0 and 1 or -1
    for _, dc in ipairs({ dir, -dir }) do
        local nc = c + dc
        if below <= rows and nc >= 1 and nc <= cols and U.is_space(grid[below][nc].char) then
            grid[below][nc].char, grid[r][c].char = grid[r][c].char, " "
            return true
        end
    end
    return false
end

-- Convert resting flakes into TTL "settled snow"
local function settle_or_move(self, grid, wind, ttl)
  local rows, cols = U.grid_size(grid)
  for r = rows - 1, 1, -1 do
    for c = 1, cols do
      local ch = grid[r][c].char
      if ch == "*" or ch == "·" or ch == "." or ch == "•" then
        local moved = step_fall(grid, r, c, wind)
        if not moved then
          -- settle: give it a lifespan AND clear the falling glyph
          ttl[r][c] = math.random(self.TTL_MIN, self.TTL_MAX)
          grid[r][c].char = " "   -- <<< prevents TTL from being re-assigned next frame
        end
      end
    end
  end
end

-- Age TTL pixels and draw them (short-lived accumulation)
local function age_and_draw_ttl(grid, baseline, ttl)
  local rows, cols = #grid, #grid[1]
  for r = 1, rows do
    for c = 1, cols do
      local life = ttl[r][c]
      if life > 0 then
        life = life - 1
        ttl[r][c] = life

        local cur = grid[r][c].char
        local base_is_space = (baseline[r][c] == " " or baseline[r][c] == "")

        if life <= 0 then
          -- melt: only clear if what's visible is a snow glyph
          if cur == "*" or cur == "·" or cur == "." or cur == "•" then
            grid[r][c].char = " "
          end
        else
          -- show a light dot only on “empty baseline” and currently empty
          if base_is_space and (cur == " " or cur == "") then
            grid[r][c].char = "."
          end
        end
      end
    end
  end
end

function Snow.tick(self, grid, baseline, t)
    local wind = U.wind(t, self.WIND_AMPL, self.WIND_FREQ)
    spawn_top(self, grid, baseline)
    settle_or_move(self, grid, wind, self.ttl)
    age_and_draw_ttl(grid, baseline, self.ttl)
end

function Snow.new(config)
    local o = setmetatable({}, { __index = Snow })
    if config then
        for k, v in pairs(config) do o[k] = v end
    end
    o.ttl = nil
    return o
end

-- at bottom of snow.lua (before 'return Snow')
function Snow.attach(self, grid)
    -- allocate per-grid TTL store here
    self.ttl = self.ttl or Snow.alloc_ttl(grid)
    return self
end

return Snow
