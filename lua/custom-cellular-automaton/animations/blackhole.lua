-- Black-Hole Breakaway Vortex for cellular-automaton.nvim
-- Usage: :CellularAutomaton blackhole_breakaway
-- Behavior:
--   • Text stays in place at first; chars nearer the center detach sooner
--     (stronger "gravity"), spiraling inward and heating up in color as
--     they approach the horizon.
--   • Black hole starts tiny and visibly grows toward a fraction of the
--     screen as it absorbs characters.
--   • Once everything is swallowed, the hole flashes and collapses to a
--     singularity, then detonates in a Big Bang: debris flies outward
--     through expanding shockwaves, then swirls into a rotating spiral
--     galaxy that holds briefly before the animation ends.

local ca = require("cellular-automaton")

-- ================== Tweakables ==================
local FPS            = 30       -- smoothness
-- Detachment timing: mean time-to-detach scales with distance from center
-- (closer chars detach sooner), each with individual jitter.
local DETACH_MEAN        = 6.0      -- seconds (detach-time mean for edge particles)
local DETACH_CENTER_BIAS = 0.35     -- fraction of DETACH_MEAN used for particles at the center
local DETACH_JITTER       = 2.5     -- seconds added/subtracted randomly (scaled by distance)
-- Spiral motion (applies after a particle detaches)
local DECAY_K        = 1.10     -- radial shrink rate per second (higher = faster inward)
local OMEGA_0        = 0.60     -- initial angular speed (radians/sec)
local OMEGA_ACCEL    = 0.50     -- angular acceleration (radians/sec^2)
local SPIRAL_GAIN    = 1.20     -- extra twist near the center (1/r term)
-- Terminal cells are ~2x taller than wide; scale row deltas so orbits and
-- the horizon read as circles instead of vertical ellipses.
local ASPECT         = 0.5
-- Black hole geometry & growth (radius is in column-equivalent units)
local HORIZON_START      = 0.05     -- initial radius — just a speck
local FINAL_RADIUS_FRAC  = 0.32     -- target radius once everything is swallowed, as a
                                     -- fraction of the smaller screen dimension
local BASE_GROWTH_FRAC   = 0.015    -- passive growth per second, as a fraction of target radius
local HOLE_PULSE         = 0.18     -- small sinusoidal "breathing"
-- Finale: brief flash + collapse once the last character is swallowed
local FINALE_DURATION    = 0.9      -- seconds
local FLASH_PEAK_FRAC    = 0.15     -- when (as a fraction of the finale) the flash peaks
local FLASH_BUMP_MULT    = 1.5      -- how much bigger than target radius the flash gets
local FLASH_FADE_EXP     = 1.2      -- shape of the collapse-to-nothing fade
-- Aesthetic: ASCII rings for the hole, hottest (band 1) to coolest (last band)
local HOLE_CHARS     = { "#", "@", "O", "o", "." }
-- Highlight groups, hottest/brightest -> coldest/dimmest
local HEAT_PALETTE   = { "Title", "ErrorMsg", "WarningMsg", "String", "Constant", "Comment" }

-- Big Bang: once the hole collapses, debris blasts outward from the
-- singularity (all distances/velocities are column-equivalent "math" units)
local BIGBANG_DURATION   = 1.6      -- seconds of outward flight before settling
local EXPLODE_SPEED_MIN  = 6.0      -- units/sec
local EXPLODE_SPEED_MAX  = 22.0     -- units/sec
local EXPLODE_DRAG       = 0.965    -- per-frame velocity decay
local BIGBANG_RING_COUNT = 2        -- staggered shockwave rings
local BIGBANG_RING_DELAY = 5        -- frames between successive rings
local BIGBANG_RING_SPEED = 13.0     -- units/sec radial growth
local RING_THICKNESS     = 1.4      -- how thick a shockwave band is
local RING_CHAR          = "*"

-- Galaxy: debris swirls into a rotating spiral once the blast settles
local GALAXY_ARMS          = 2      -- spiral arm count
local GALAXY_RADIUS_FRAC   = 0.85   -- galaxy radius, as a fraction of the largest circle that fits
local GALAXY_MIN_RADIUS    = 1.5    -- bulge radius, never smaller than this
local GALAXY_TWIST         = 5.5    -- radians the arms wind from core to edge
local GALAXY_CORE_SCATTER  = 1.6    -- extra angular scatter near the core (fat bulge)
local GALAXY_ARM_SCATTER   = 0.22   -- angular scatter along the arms (keeps them tight)
local GALAXY_FORM_DURATION = 2.2    -- seconds to swirl from debris into formation
local GALAXY_OMEGA         = 0.12   -- slow rotation once formed (radians/sec)
local GALAXY_HOLD_DURATION = 4.0    -- seconds to hold the finished, rotating galaxy
-- Star glyphs, brightest core -> dimmest rim (parallel to HEAT_PALETTE)
local GALAXY_CHARS = { "@", "#", "*", "+", ".", "." }

-- Ignore-list (set to nil to suck everything, including spaces)
-- Example to ignore blank space & tabs:
-- local IGNORE = { [" "]=true, ["\t"]=true }
local IGNORE = nil

-- Collision rule when multiple particles land on same cell:
-- "near-center" keeps the one that is currently closer to the center
local COLLISION = "near-center"
-- =================================================

local function clamp(v,a,b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function get_center(rows, cols) return math.floor((rows+1)/2), math.floor((cols+1)/2) end
local function dist(dx, dy) return math.sqrt(dx*dx + dy*dy) end
local function rot(dx, dy, theta)
  local ct, st = math.cos(theta), math.sin(theta)
  return dx*ct - dy*st, dx*st + dy*ct
end

local function get_max_cols(grid)
  local m = 0
  for r = 1, #grid do
    m = math.max(m, #grid[r])
  end
  return m
end

-- coldness: 0 = hottest/brightest, 1 = coldest/dimmest
local function palette_index(coldness)
  coldness = clamp(coldness, 0, 1)
  local n = #HEAT_PALETTE
  return clamp(math.floor(coldness * (n - 1) + 0.5) + 1, 1, n)
end

-- Exponential sample with mean m (simple inversion, uniform in (0,1))
local function exp_sample(mean)
  local u = math.random()
  if u <= 1e-9 then u = 1e-9 end
  return -mean * math.log(u)
end

local function snapshot_particles(grid)
  local rows = #grid
  local parts = {}
  for r = 1, rows do
    for c = 1, #grid[r] do  -- Use actual row length
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
  local rows = #grid
  for r = 1, rows do
    for c = 1, #grid[r] do  -- Use actual row length
      grid[r][c].char = " "
    end
  end
end

local function draw_baseline_intact(grid, parts)
  -- Draw only the characters that are still "stuck" in their original spots.
  for _, p in ipairs(parts) do
    if p.state == "stuck" then
      -- Check bounds before accessing
      if p.r0 <= #grid and p.c0 <= #grid[p.r0] then
        grid[p.r0][p.c0].char = p.ch
      end
    end
  end
end

-- radius is in column-equivalent ("math") units; ASPECT corrects the row
-- axis so the drawn rings look circular rather than egg-shaped.
local function draw_hole(grid, cr, cc, radius, rows, max_cols)
  local bands = #HOLE_CHARS
  local rceil_col = math.ceil(radius) + bands + 1
  local rceil_row = math.ceil(radius * ASPECT) + bands + 1
  local rmin, rmax = clamp(cr - rceil_row, 1, rows), clamp(cr + rceil_row, 1, rows)
  local cmin, cmax = clamp(cc - rceil_col, 1, max_cols), clamp(cc + rceil_col, 1, max_cols)

  for r = rmin, rmax do
    for c = cmin, cmax do
      -- Check if this cell exists in the current row
      if c <= #grid[r] then
        local dx = c - cc
        local dy = (r - cr) / ASPECT
        local d = dist(dx, dy)
        if d <= radius + bands - 1 then
          local band = math.floor(clamp((d - radius) + 1, 1, bands))
          if d <= radius then band = 1 end
          local coldness = (band - 1) / (bands - 1)
          grid[r][c].char = HOLE_CHARS[band]
          grid[r][c].hl_group = HEAT_PALETTE[palette_index(coldness)]
        end
      end
    end
  end
end

-- Places a single glyph given a position in column-equivalent ("math")
-- units relative to (cr, cc); ASPECT corrects the row axis on the way back
-- to screen coordinates.
local function set_star(grid, rows, max_cols, cr, cc, x_math, y_math, ch, hl)
  local rr = math.floor(cr + y_math * ASPECT + 0.5)
  local col = math.floor(cc + x_math + 0.5)
  if rr >= 1 and rr <= rows and col >= 1 and col <= max_cols and col <= #grid[rr] then
    grid[rr][col].char = ch
    grid[rr][col].hl_group = hl
  end
end

-- One thin expanding shockwave band, in column-equivalent ("math") units.
local function draw_ring(grid, rows, max_cols, cr, cc, radius, color, ch)
  if radius < 0.5 then return end
  local rceil_col = math.ceil(radius) + 2
  local rceil_row = math.ceil(radius * ASPECT) + 2
  local rmin, rmax = clamp(cr - rceil_row, 1, rows), clamp(cr + rceil_row, 1, rows)
  local cmin, cmax = clamp(cc - rceil_col, 1, max_cols), clamp(cc + rceil_col, 1, max_cols)

  for r = rmin, rmax do
    for c = cmin, cmax do
      if c <= #grid[r] then
        local dx = c - cc
        local dy = (r - cr) / ASPECT
        local d = dist(dx, dy)
        if math.abs(d - radius) <= RING_THICKNESS then
          grid[r][c].char = ch
          grid[r][c].hl_group = color
        end
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
local phase = "vortex"     -- "vortex" -> "finale" -> "bigbang" -> "galaxy_form" -> "galaxy_hold"
local finale_t = 0.0
local target_radius = 1.0  -- radius the hole grows toward once everything is swallowed
local base_growth = 0.0    -- passive radius growth per second
local growth_per_abs = 0.0 -- extra radius gained per character swallowed
local heat_ref = 1.0       -- reference distance used to color free particles

-- Big Bang / galaxy state (all positions in column-equivalent "math" units)
local stars = nil          -- debris that becomes the galaxy
local bigbang_t = 0.0
local bigbang_frame = 0
local bigbang_rings = nil
local bigbang_extent = 1.0 -- reference distance used to color shockwaves/debris
local galaxy_form_t = 0.0
local galaxy_hold_t = 0.0
local rotation_theta = 0.0
local galaxy_radius = 1.0

local function start_bigbang(rows, max_cols)
  phase = "bigbang"
  bigbang_t = 0.0
  bigbang_frame = 0
  bigbang_extent = dist(max_cols / 2, (rows / ASPECT) / 2)
  galaxy_radius = math.max(GALAXY_MIN_RADIUS + 2, bigbang_extent * GALAXY_RADIUS_FRAC)

  stars = {}
  for _ = 1, total do
    local angle = math.random() * 2 * math.pi
    local speed = EXPLODE_SPEED_MIN + math.random() * (EXPLODE_SPEED_MAX - EXPLODE_SPEED_MIN)

    local u = math.random() ^ 1.6 -- skew toward the core: denser bulge, sparser rim
    local arm = math.random(1, GALAXY_ARMS)
    local scatter = GALAXY_ARM_SCATTER + GALAXY_CORE_SCATTER * (1 - u) ^ 2

    table.insert(stars, {
      x = 0.0, y = 0.0,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      coldness = u,
      radius = GALAXY_MIN_RADIUS + u * (galaxy_radius - GALAXY_MIN_RADIUS),
      base_angle = (arm - 1) * (2 * math.pi / GALAXY_ARMS) + GALAXY_TWIST * u
        + (math.random() * 2 - 1) * scatter,
      twinkle_phase = math.random() * 2 * math.pi,
      twinkle_speed = 0.5 + math.random() * 1.5,
    })
  end

  bigbang_rings = {}
  for i = 1, BIGBANG_RING_COUNT do
    table.insert(bigbang_rings, { radius = 0.0, start_frame = (i - 1) * BIGBANG_RING_DELAY, active = false })
  end
end

local cfg = {
  fps  = FPS,
  name = "blackhole_breakaway",
  init = function(grid)
    math.randomseed(os.time())
    local rows = #grid
    local max_cols = get_max_cols(grid)
    center_r, center_c = get_center(rows, max_cols)
    parts = snapshot_particles(grid)
    total = #parts
    swallowed = 0
    t_global = 0.0
    phase = "vortex"
    finale_t = 0.0
    stars = nil
    bigbang_rings = nil
    galaxy_form_t = 0.0
    galaxy_hold_t = 0.0
    rotation_theta = 0.0

    target_radius = math.max(3, math.min(rows, max_cols) * FINAL_RADIUS_FRAC)
    growth_per_abs = (target_radius - HORIZON_START) / math.max(1, total)
    base_growth = target_radius * BASE_GROWTH_FRAC
    heat_ref = dist(max_cols, rows / ASPECT) / 2

    -- Assign individualized detachment times: particles closer to the
    -- center feel stronger "gravity" and detach sooner on average.
    local max_r0 = 0
    for _, p in ipairs(parts) do
      local x0 = p.c0 - center_c
      local y0 = (p.r0 - center_r) / ASPECT
      p._r0_math = dist(x0, y0)
      max_r0 = math.max(max_r0, p._r0_math)
    end
    for _, p in ipairs(parts) do
      local norm = max_r0 > 1e-9 and (p._r0_math / max_r0) or 0
      local mean = DETACH_MEAN * (DETACH_CENTER_BIAS + (1 - DETACH_CENTER_BIAS) * norm)
      local jitter = (math.random() * 2 - 1) * DETACH_JITTER * (0.5 + 0.5 * norm)
      p.detach_at = math.max(0.1, exp_sample(mean) + jitter)
      p._r0_math = nil
    end
  end,
}

cfg.update = function(grid)
  local rows = #grid
  local max_cols = get_max_cols(grid)
  clear_grid(grid)

  if phase == "finale" then
    finale_t = finale_t + 1.0 / FPS
    local frac = clamp(finale_t / FINALE_DURATION, 0, 1)
    local x = frac / FLASH_PEAK_FRAC
    local flash = x * math.exp(1 - x)
    local fade = (1 - frac) ^ FLASH_FADE_EXP
    local radius = target_radius * (1 + FLASH_BUMP_MULT * flash) * fade
    if radius > 0.05 then
      draw_hole(grid, center_r, center_c, radius, rows, max_cols)
    end
    if frac >= 1 then
      start_bigbang(rows, max_cols)
    end
    return true
  end

  if phase == "bigbang" then
    bigbang_t = bigbang_t + 1.0 / FPS
    bigbang_frame = bigbang_frame + 1

    for _, s in ipairs(stars) do
      s.vx = s.vx * EXPLODE_DRAG
      s.vy = s.vy * EXPLODE_DRAG
      s.x = s.x + s.vx / FPS
      s.y = s.y + s.vy / FPS

      local speed_frac = clamp(dist(s.vx, s.vy) / EXPLODE_SPEED_MAX, 0, 1)
      local idx = palette_index(1 - speed_frac)
      set_star(grid, rows, max_cols, center_r, center_c, s.x, s.y, GALAXY_CHARS[idx], HEAT_PALETTE[idx])
    end

    for _, ring in ipairs(bigbang_rings) do
      if bigbang_frame >= ring.start_frame then
        ring.active = true
      end
      if ring.active then
        ring.radius = ring.radius + BIGBANG_RING_SPEED / FPS
        if ring.radius <= bigbang_extent + RING_THICKNESS then
          local frac = clamp(ring.radius / bigbang_extent, 0, 1)
          local color = HEAT_PALETTE[palette_index(frac)]
          draw_ring(grid, rows, max_cols, center_r, center_c, ring.radius, color, RING_CHAR)
        end
      end
    end

    if bigbang_t >= BIGBANG_DURATION then
      phase = "galaxy_form"
      galaxy_form_t = 0.0
      for _, s in ipairs(stars) do
        s.form_start_x = s.x
        s.form_start_y = s.y
      end
    end
    return true
  end

  if phase == "galaxy_form" or phase == "galaxy_hold" then
    rotation_theta = rotation_theta + GALAXY_OMEGA / FPS

    local ease = 1.0
    if phase == "galaxy_form" then
      galaxy_form_t = galaxy_form_t + 1.0 / FPS
      local frac = clamp(galaxy_form_t / GALAXY_FORM_DURATION, 0, 1)
      ease = frac * frac * (3 - 2 * frac) -- smoothstep
    end

    for _, s in ipairs(stars) do
      local angle = s.base_angle + rotation_theta
      local tx = s.radius * math.cos(angle)
      local ty = s.radius * math.sin(angle)

      local x, y = tx, ty
      if phase == "galaxy_form" then
        x = lerp(s.form_start_x, tx, ease)
        y = lerp(s.form_start_y, ty, ease)
      end

      local twinkle = phase == "galaxy_hold"
        and (math.sin(galaxy_hold_t * s.twinkle_speed + s.twinkle_phase) - 0.5) * 0.4
        or 0
      local idx = palette_index(clamp(s.coldness - twinkle, 0, 1))
      set_star(grid, rows, max_cols, center_r, center_c, x, y, GALAXY_CHARS[idx], HEAT_PALETTE[idx])
    end

    if phase == "galaxy_form" and galaxy_form_t >= GALAXY_FORM_DURATION then
      phase = "galaxy_hold"
      galaxy_hold_t = 0.0
    elseif phase == "galaxy_hold" then
      galaxy_hold_t = galaxy_hold_t + 1.0 / FPS
      if galaxy_hold_t >= GALAXY_HOLD_DURATION then
        return false
      end
    end
    return true
  end

  t_global = t_global + 1.0 / FPS

  -- Current hole radius:
  -- small speck + passive growth toward target + growth proportional to
  -- swallowed chars + a small breathing pulse.
  local horizon = HORIZON_START
                 + base_growth * t_global
                 + growth_per_abs * swallowed
                 + HOLE_PULSE * math.sin(t_global * 2 * math.pi * 0.65)
  horizon = clamp(horizon, 0.05, target_radius * 1.15)

  -- Angular speed ramps over time
  local omega = OMEGA_0 + OMEGA_ACCEL * t_global

  -- Place all FREE particles into a map to handle collisions
  local placed = {}

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
      -- original offset from center, in column-equivalent ("math") units
      local x0 = p.c0 - center_c
      local y0 = (p.r0 - center_r) / ASPECT
      local r0 = dist(x0, y0)

      if r0 < 1e-9 then
        -- If it somehow starts at center, it's immediately swallowed
        p.state = "done"
        swallowed = swallowed + 1
      else
        -- Spiral: rotate and shrink toward center (all in math space)
        local spiral_term = SPIRAL_GAIN / (r0 + 1.0) * (1.0 + 0.6 * tau)
        local theta = (omega * tau) + spiral_term
        local sx, sy = rot(x0, y0, theta)

        -- Exponential radial decay inward
        local shrink = math.exp(-DECAY_K * tau)
        sx, sy = sx * shrink, sy * shrink
        local d_math = dist(sx, sy)

        -- If it crosses the horizon: swallowed
        if d_math <= horizon then
          p.state = "done"
          swallowed = swallowed + 1
        else
          -- Convert back to screen coordinates
          local rr = clamp(center_r + math.floor(0.5 + sy * ASPECT), 1, rows)
          local cc = clamp(center_c + math.floor(0.5 + sx), 1, max_cols)
          local key = rr * (max_cols + 1) + cc  -- simple unique key

          -- Closer to the horizon = hotter/brighter
          local coldness = clamp(d_math / heat_ref, 0, 1)
          local color = HEAT_PALETTE[palette_index(coldness)]

          -- Keep nearer-to-center char on collisions
          local slot = placed[key]
          if not slot or (COLLISION == "near-center" and d_math < slot.d) then
            placed[key] = { d = d_math, ch = p.ch, color = color }
          end
        end
      end
    end
  end

  -- Draw the placed FREE particles (they override stuck text at their landing spots)
  for key, val in pairs(placed) do
    local cc = key % (max_cols + 1)
    local rr = (key - cc) / (max_cols + 1)
    rr = clamp(rr, 1, rows)
    cc = clamp(cc, 1, max_cols)
    -- Check bounds before writing
    if rr <= #grid and cc <= #grid[rr] then
      grid[rr][cc].char = val.ch
      grid[rr][cc].hl_group = val.color
    end
  end

  -- Finally draw the black hole so its rings are visible on top
  draw_hole(grid, center_r, center_c, horizon, rows, max_cols)

  -- Once everyone is gone, flash and collapse before stopping
  if swallowed >= total then
    phase = "finale"
    finale_t = 0.0
  end
  return true
end

local M = {}

function M.register()
  ca.register_animation(cfg)
end

return M
