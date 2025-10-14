-- Snowfall for cellular-automaton.nvim
-- Requires: https://github.com/Eandrju/cellular-automaton.nvim
-- Usage: :CellularAutomaton snowfall

local ca = require("cellular-automaton")

-- Tweakables
local FPS        = 30         -- lower = calmer
local DENSITY    = 0.005       -- spawn chance per column per frame
local WIND_AMPL  = 1          -- pixels of sideways drift
local WIND_FREQ  = 0.08       -- how fast wind oscillates
local FLAKES     = { "*", "·", "•", "." }  -- choose thin glyphs for subtle effect

-- Helpers
local function is_empty(cell)
  -- Treat true space as empty. Everything else is an obstacle or snow.
  return cell and (cell.char == " " or cell.char == "")
end

local function random_flake()
  return FLAKES[math.random(#FLAKES)]
end

-- We keep a frame counter to drive wind and gentle variation
local t = 0

local config = {
  fps  = FPS,
  name = "snowfall",
}

-- Optional: seed RNG once per animation start
config.init = function(_grid)
  math.randomseed(os.time())
end

-- Move a single flake at (r, c) if possible; returns whether it moved.
local function step_flake(grid, r, c, wind)
  local rows, cols = #grid, #grid[1]
  local below_r = r + 1

  -- Down
  if below_r <= rows and is_empty(grid[below_r][c]) then
    grid[below_r][c].char, grid[r][c].char = grid[r][c].char, " "
    return true
  end

  -- Down + wind-biased diagonal (left or right)
  local dir = wind >= 0 and 1 or -1
  for _, dc in ipairs({ dir, -dir }) do
    local nc = c + dc
    if below_r <= rows and nc >= 1 and nc <= cols and is_empty(grid[below_r][nc]) then
      grid[below_r][nc].char, grid[r][c].char = grid[r][c].char, " "
      return true
    end
  end

  -- Can't move: it "accumulates" where it is.
  return false
end

config.update = function(grid)
  t = t + 1
  local rows, cols = #grid, #grid[1]

  -- Spawn new flakes at the top row with small random probability per column
  -- Only spawn over empty cells to avoid overwriting visible text.
  for c = 1, cols do
    if is_empty(grid[1][c]) and math.random() < DENSITY then
      grid[1][c].char = random_flake()
    end
  end

  -- Compute wind for this frame (oscillates left/right)
  local wind = math.floor(math.sin(t * WIND_FREQ) * WIND_AMPL)

  -- Update from bottom to top so each flake moves at most once per frame
  for r = rows - 1, 1, -1 do
    for c = 1, cols do
      local cell = grid[r][c]
      if cell and (cell.char == "*" or cell.char == "·" or cell.char == "•" or cell.char == ".") then
        step_flake(grid, r, c, wind)
      end
    end
  end

  return true  -- keep animating
end

local M = {}

function M.register()
  ca.register_animation(config)
end

return M
