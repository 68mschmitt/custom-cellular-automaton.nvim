-- Fireworks Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton fireworks
-- Behavior:
--   • Rockets launch from bottom and explode into sparks
--   • Sparks spread outward in all directions with gravity
--   • Multiple concurrent explosions create a fireworks show
--   • Optional duration limit (set DURATION_TICKS = nil for infinite)
-- Parameters configurable at top of file (FPS, NUM_ROCKETS, SPARK_TTL, etc.)

local rng = math.random

-- optional colors; safe to leave nil if your theme lacks any of these
local PALETTE = {
  "Constant", "Type", "String", "Function", "Identifier",
  "DiagnosticOk", "DiagnosticWarn", "DiagnosticInfo", "DiffAdd", "DiffText",
}

-- physics/behavior
local MAX_ROCKETS      = 3
local ROCKET_SPAWN_PCT = 20
-- speeds are POSITIVE magnitudes; we apply a minus sign when assigning vy
local ROCKET_SPEED_MIN = 1.2
local ROCKET_SPEED_MAX = 1.8
local ROCKET_WIGGLE    = 0.25

local BURST_PARTS      = 24
local BURST_SPEED_MIN  = 0.4
local BURST_SPEED_MAX  = 1.3
local GRAVITY          = 0.05
local AIR_DRAG         = 0.99
local SPARK_LIFE_MIN   = 25
local SPARK_LIFE_MAX   = 45

local FPS              = 55
local DURATION_TICKS   = 10000

local function clamp(x, lo, hi) return (x < lo) and lo or ((x > hi) and hi or x) end

local state = { t = 0, rockets = {}, sparks = {}, width = 0, height = 0 }

local function clear_grid(grid)
  for i = 1, #grid do
    for j = 1, #(grid[i]) do
      grid[i][j].char = " "
      -- leave hl_group alone; it’s optional
    end
  end
end

local function set_cell(grid, x, y, ch, hl)
  local iy = math.floor(y + 0.5)
  local ix = math.floor(x + 0.5)
  if iy >= 1 and iy <= state.height and ix >= 1 and ix <= state.width then
    local cell = grid[iy][ix]
    cell.char = ch
    if hl then cell.hl_group = hl end
  end
end

local function spawn_rocket()
  local x  = rng(3, state.width - 2)
  local y  = state.height - 1
  local vx = (rng() * 2 - 1) * 0.2
  -- IMPORTANT: negative vy -> upward motion
  local speed = ROCKET_SPEED_MIN + rng() * (ROCKET_SPEED_MAX - ROCKET_SPEED_MIN)
  local vy = -speed
  local color = rng(1, #PALETTE)
  table.insert(state.rockets, { x = x, y = y, vx = vx, vy = vy, color = color, exploded = false })
end

local function explode(r)
  local color = r.color
  for k = 1, BURST_PARTS do
    local angle = (k / BURST_PARTS) * (2 * math.pi) + (rng() * 0.25)
    local spd   = BURST_SPEED_MIN + rng() * (BURST_SPEED_MAX - BURST_SPEED_MIN)
    local life  = SPARK_LIFE_MIN + rng(SPARK_LIFE_MAX - SPARK_LIFE_MIN)
    table.insert(state.sparks, {
      x = r.x, y = r.y,
      vx = math.cos(angle) * spd,
      vy = math.sin(angle) * spd,
      life = life,
      color = color,
    })
  end
end

local function update_rockets(grid)
  local alive = {}
  for _, r in ipairs(state.rockets) do
    r.x = r.x + r.vx + ((rng() * 2 - 1) * ROCKET_WIGGLE)
    r.y = r.y + r.vy
    r.x = clamp(r.x, 2, state.width - 1)
    set_cell(grid, r.x, r.y, ".", PALETTE[r.color])

    local near_top    = (r.y <= state.height * 0.25)
    local high_enough = (r.y <= state.height * 0.55)
    local random_boom = high_enough and (rng(1, 100) <= 7)

    if (near_top or random_boom) and not r.exploded then
      r.exploded = true
      explode(r)
    end

    if not r.exploded and r.y > 1 then
      table.insert(alive, r)
    end
  end
  state.rockets = alive
end

local function update_sparks(grid)
  local alive = {}
  for _, s in ipairs(state.sparks) do
    s.vx = s.vx * AIR_DRAG
    s.vy = s.vy * AIR_DRAG + GRAVITY
    s.x  = s.x + s.vx
    s.y  = s.y + s.vy
    s.life = s.life - 1
    local ch = (s.life > 20) and "*" or ((s.life > 8) and "+" or ".")
    set_cell(grid, s.x, s.y, ch, PALETTE[s.color])
    if s.life > 0 and s.y < state.height + 1 then
      table.insert(alive, s)
    end
  end
  state.sparks = alive
end

local config = {
  name = "fireworks",
  fps = FPS,
  init = function(grid)
    state.width  = #(grid[1] or {})
    state.height = #grid
    state.t = 0
    state.rockets, state.sparks = {}, {}
  end,
  update = function(grid)
    state.t = state.t + 1
    clear_grid(grid)
    if #state.rockets < MAX_ROCKETS and rng(1, 100) <= ROCKET_SPAWN_PCT then
      spawn_rocket()
    end
    update_rockets(grid)
    update_sparks(grid)
    if DURATION_TICKS and state.t >= DURATION_TICKS then return false end
    return true
  end,
}

local M = {}

function M.register()
  require("cellular-automaton").register_animation(config)
end

return M
