-- Ripple effect for cellular-automaton.nvim
-- Usage: :CellularAutomaton ripple
-- Origin: cursor position (configurable below)

local ca = require("cellular-automaton")

-- ===== Tweakables =====
local FPS        = 30         -- smoothness
local WAVELENGTH = 6.0        -- distance between rings (cells)
local SPEED      = 0.055       -- ring expansion speed (cycles/frame)
local THICKNESS  = 0.28       -- how "thick" the ring band is (0-1)
local DECAY      = 0.015      -- amplitude decay per cell of radius
local LOOP       = false      -- if false, stops after traveling off-screen
local ORIGIN     = "cursor"   -- "cursor" | "center"

-- characters used to draw the ring (weak → strong)
local RING_CHARS = { "·", "-", "~", "≈" }

-- ======================

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function get_origin(rows, cols)
  if ORIGIN == "cursor" then
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))  -- 1-based (row, col)
    return clamp(r, 1, rows), clamp(c, 1, cols)
  else
    return math.floor(rows / 2), math.floor(cols / 2)
  end
end

local function snapshot_grid(grid)
  local rows, cols = #grid, #grid[1]
  local snap = {}
  for r = 1, rows do
    local row = {}
    for c = 1, cols do
      row[c] = grid[r][c].char
    end
    snap[r] = row
  end
  return snap
end

local function restore_from_snapshot(grid, snap)
  local rows, cols = #grid, #grid[1]
  for r = 1, rows do
    for c = 1, cols do
      grid[r][c].char = snap[r][c]
    end
  end
end

local t = 0
local origin_r, origin_c = 1, 1
local baseline = nil
local max_radius = 0

local cfg = {
  fps  = FPS,
  name = "ripple",
  init = function(grid)
    math.randomseed(os.time())
    local rows, cols = #grid, #grid[1]
    origin_r, origin_c = get_origin(rows, cols)
    baseline = snapshot_grid(grid)
    -- longest distance needed to cover the screen
    max_radius = math.sqrt(rows * rows + cols * cols) + 4
  end,
}

cfg.update = function(grid)
  t = t + 1
  local rows, cols = #grid, #grid[1]

  -- Redraw original content each frame so we overlay rings cleanly
  restore_from_snapshot(grid, baseline)

  -- current wave phase travels outward with time
  -- phase = distance / wavelength - speed * time
  -- ring occurs when sin(2π*phase) ≈ 0 (we use abs(sin) < THICKNESS band)
  local two_pi = 2 * math.pi
  local active = false

  for r = 1, rows do
    for c = 1, cols do
      local dr = r - origin_r
      local dc = c - origin_c
      local dist = math.sqrt(dr * dr + dc * dc)

      -- amplitude decays with distance so far rings are subtler
      local amp = math.max(0, 1.0 - dist * DECAY)

      -- compute wave value at this point in time
      local phase = (dist / WAVELENGTH) - (SPEED * t / FPS)
      local s = math.sin(two_pi * phase)

      -- draw a band where |sin| is small (near wave crest)
      if amp > 0 and math.abs(s) < THICKNESS then
        -- pick a glyph intensity from closeness to crest + amplitude
        local closeness = 1.0 - (math.abs(s) / THICKNESS)  -- 0..1 (1 at center)
        local strength = clamp(amp * closeness, 0, 1)
        local idx = 1 + math.floor(strength * (#RING_CHARS - 1) + 0.5)
        idx = clamp(idx, 1, #RING_CHARS)

        -- avoid overwriting whitespace-only lines too aggressively:
        -- overlay only if baseline wasn't space OR if strength is decent
        if baseline[r][c] ~= " " or strength > 0.25 then
          grid[r][c].char = RING_CHARS[idx]
          active = true
        end
      end
    end
  end

  -- Stop after ring traveled off screen, unless LOOPing
  if not LOOP then
    local current_radius = (SPEED * t / FPS) * (WAVELENGTH * 2.0 * math.pi) / two_pi
    if current_radius > max_radius and not active then
      return false
    end
  end

  return true
end

local M = {}

function M.register()
  ca.register_animation(cfg)
end

return M
