-- Black-Hole Breakaway Vortex for cellular-automaton.nvim
-- Usage: :CellularAutomaton blackhole_breakaway
-- Behavior:
--   • Text stays in place at first; chars detach over time (individually).
--   • Detached chars spiral inward, speeding up.
--   • Black hole starts tiny and grows whenever it absorbs characters.
--   • Stops when all characters are gone.

local ca = require("cellular-automaton")

-- ================== Tweakables ==================
local FPS            = 30       -- smoothness
-- Detachment timing: each particle has its own detach_at = EXP(mean) + jitter
local DETACH_MEAN    = 6.0      -- seconds (average time until a char detaches)
local DETACH_JITTER  = 2.5      -- seconds added/subtracted randomly
-- Spiral motion (applies after a particle detaches)
local DECAY_K        = 1.10     -- radial shrink rate per second (higher = faster inward)
local OMEGA_0        = 0.60     -- initial angular speed (radians/sec)
local OMEGA_ACCEL    = 0.50     -- angular acceleration (radians/sec^2)
local SPIRAL_GAIN    = 1.20     -- extra twist near the center (1/r term)
-- Black hole geometry & growth
local HORIZON_START  = 0.0001      -- initial radius (cells) — just a speck
local BASE_GROWTH    = 0.0002     -- passive radius growth per second
local GROW_PER_ABS   = 0.0004    -- extra radius gained per character swallowed
local HOLE_PULSE     = 0.18     -- small sinusoidal "breathing"
-- Aesthetic: ASCII rings for the hole
local HOLE_CHARS     = { "#", "@", "O", "o", "." }

-- Ignore-list (set to nil to suck everything, including spaces)
-- Example to ignore blank space & tabs:
-- local IGNORE = { [" "]=true, ["\t"]=true }
local IGNORE = nil

-- Collision rule when multiple particles land on same cell:
-- "near-center" keeps the one that is currently closer to the center
local COLLISION = "near-center"
-- =================================================

local function clamp(v,a,b) return math.max(a, math.min(b, v)) end
local function get_center(rows, cols) return math.floor((rows+1)/2), math.floor((cols+1)/2) end
local function dist(dx, dy) return math.sqrt(dx*dx + dy*dy) end
local function rot(dx, dy, theta)
  local ct, st = math.cos(theta), math.sin(theta)
  return dx*ct - dy*st, dx*st + dy*ct
end

-- Exponential sample with mean m (simple inversion, uniform in (0,1))
local function exp_sample(mean)
  local u = math.random()
  if u <= 1e-9 then u = 1e-9 end
  return -mean * math.log(u)
end

local function snapshot_particles(grid)
  local rows, cols = #grid, #grid[1]
  local parts = {}
  for r = 1, rows do
    for c = 1, cols do
      local ch = grid[r][c].char
      local ignore = IGNORE and IGNORE[ch]
      if not ignore and ch and ch ~= "" then
        -- keep spaces too unless explicitly ignored
        table.insert(parts, {
          r0 = r, c0 = c, ch = ch,
          state = "stuck",   -- "stuck" → "free" → "done"
          detach_at = 0.0,   -- filled in during init
          t0 = 0.0,          -- time when it detached
        })
      end
    end
  end
  return parts
end

local function clear_grid(grid)
  local rows, cols = #grid, #grid[1]
  for r = 1, rows do
    for c = 1, cols do
      grid[r][c].char = " "
    end
  end
end

local function draw_baseline_intact(grid, parts)
  -- Draw only the characters that are still "stuck" in their original spots.
  for _, p in ipairs(parts) do
    if p.state == "stuck" then
      grid[p.r0][p.c0].char = p.ch
    end
  end
end

local function draw_hole(grid, cr, cc, radius)
  local rows, cols = #grid, #grid[1]
  local bands = #HOLE_CHARS
  local rceil = math.ceil(radius) + bands + 1
  local rmin, rmax = clamp(cr - rceil, 1, rows), clamp(cr + rceil, 1, rows)
  local cmin, cmax = clamp(cc - rceil, 1, cols), clamp(cc + rceil, 1, cols)

  for r = rmin, rmax do
    for c = cmin, cmax do
      local d = dist(r - cr, c - cc)
      if d <= radius + bands - 1 then
        local band = math.floor(clamp((d - radius) + 1, 1, bands))
        if d <= radius then band = 1 end
        grid[r][c].char = HOLE_CHARS[band]
      end
    end
  end
end

-- Animation state
local t_global = 0.0      -- seconds
local center_r, center_c = 1, 1
local parts = nil
local total = 0
local swallowed = 0

local cfg = {
  fps  = FPS,
  name = "blackhole_breakaway",
  init = function(grid)
    math.randomseed(os.time())
    local rows, cols = #grid, #grid[1]
    center_r, center_c = get_center(rows, cols)
    parts = snapshot_particles(grid)
    total = #parts
    swallowed = 0
    t_global = 0.0

    -- assign individualized detachment times
    for _, p in ipairs(parts) do
      local base = exp_sample(DETACH_MEAN)   -- average DETACH_MEAN seconds
      local jitter = (math.random() * 2 - 1) * DETACH_JITTER
      p.detach_at = math.max(0.1, base + jitter)
    end
  end,
}

cfg.update = function(grid)
  t_global = t_global + 1.0 / FPS
  local rows, cols = #grid, #grid[1]

  -- Start with a clean slate; we'll draw intact text, free particles, then hole.
  clear_grid(grid)

  -- Current hole radius:
  -- small speck + tiny passive growth + growth proportional to swallowed chars + pulse
  local horizon = HORIZON_START
                 + BASE_GROWTH * t_global
                 + GROW_PER_ABS * swallowed
                 + HOLE_PULSE * math.sin(t_global * 2 * math.pi * 0.65)

  -- Angular speed ramps over time
  local omega = OMEGA_0 + OMEGA_ACCEL * t_global

  -- Place all FREE particles into a map to handle collisions
  local placed = {}
  local remaining_free = 0

  -- First pass: draw still-stuck baseline chars
  draw_baseline_intact(grid, parts)

  -- Second pass: update & place the FREE particles
  for _, p in ipairs(parts) do
    if p.state == "stuck" then
      if t_global >= p.detach_at then
        -- it breaks away now
        p.state = "free"
        p.t0 = t_global
      end
    end

    if p.state == "free" then
      local tau = t_global - p.t0 -- time since this particle detached
      -- original offset from center (continuous x,y with x~col, y~row)
      local y0 = p.r0 - center_r
      local x0 = p.c0 - center_c
      local r0 = dist(x0, y0)

      if r0 < 1e-9 then
        -- If it somehow starts at center, it's immediately swallowed
        p.state = "done"
        swallowed = swallowed + 1
      else
        -- Spiral: rotate and shrink toward center
        local spiral_term = SPIRAL_GAIN / (r0 + 1.0) * (1.0 + 0.6 * tau)
        local theta = (omega * tau) + spiral_term
        local sx, sy = rot(x0, y0, theta)

        -- Exponential radial decay inward
        local shrink = math.exp(-DECAY_K * tau)
        sx, sy = sx * shrink, sy * shrink

        local rr = center_r + math.floor(0.5 + sy)
        local cc = center_c + math.floor(0.5 + sx)

        -- If it crosses the horizon: swallowed
        if dist(rr - center_r, cc - center_c) <= horizon then
          p.state = "done"
          swallowed = swallowed + 1
        else
          -- Clamp to screen
          rr = clamp(rr, 1, rows)
          cc = clamp(cc, 1, cols)
          local key = rr * (cols + 1) + cc  -- simple unique key
          local dcur = dist(rr - center_r, cc - center_c)

          -- Keep nearer-to-center char on collisions
          local slot = placed[key]
          if not slot or (COLLISION == "near-center" and dcur < slot.d) then
            placed[key] = { d = dcur, ch = p.ch }
          end

          remaining_free = remaining_free + 1
        end
      end
    end
  end

  -- Draw the placed FREE particles (they override stuck text at their landing spots)
  for key, val in pairs(placed) do
    local cc = key % (cols + 1)
    local rr = (key - cc) / (cols + 1)
    rr = clamp(rr, 1, rows)
    cc = clamp(cc, 1, cols)
    grid[rr][cc].char = val.ch
  end

  -- Finally draw the black hole so its rings are visible on top
  draw_hole(grid, center_r, center_c, horizon)

  -- Stop when everyone is gone
  if swallowed >= total then
    return false
  end
  return true
end

local M = {}

function M.register()
  ca.register_animation(cfg)
end

return M
