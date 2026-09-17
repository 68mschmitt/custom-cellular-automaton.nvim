-- Supernova Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton supernova
-- Behavior:
--   • Every character on screen is pulled inward toward a single point,
--     heating up (dim -> white-hot) as it collapses -- a dying star.
--   • Once fully collapsed, the core briefly flashes...
--   • ...then detonates: characters fling outward as cooling debris while
--     one or more expanding shockwave rings sweep across the buffer.
--   • Debris cools and burns away (char -> "*" -> "+" -> "." -> gone), and
--     the surviving cinders drift in place as dim stardust.
--   • Gravity then takes hold: exactly that scattered stardust is pulled
--     back across the screen to where it started, reigniting into the
--     original characters as each one arrives home -- a stellar rebirth.

local rng = math.random
local U = require("custom-cellular-automaton.util")

-- ===== Tweakables =====
local FPS = 36

local IMPLODE_DURATION = 2.0 -- seconds for a particle to fully collapse
local IMPLODE_STAGGER_MAX = 0.5 -- extra random seconds added per particle
local CORE_HOLD = 0.3 -- seconds the bright core lingers before detonating

local EXPLODE_SPEED_MIN = 0.5 -- cells/frame
local EXPLODE_SPEED_MAX = 2.0 -- cells/frame
local EXPLODE_DRAG = 0.985 -- per-frame velocity decay
local PARTICLE_LIFE_MIN = 45 -- frames
local PARTICLE_LIFE_MAX = 95 -- frames

local RING_COUNT = 2 -- number of staggered shockwave rings
local RING_DELAY_FRAMES = 6 -- frames between successive rings
local RING_SPEED = 1.4 -- cells/frame radial growth
local RING_THICKNESS = 1.4 -- how thick the ring band is

local AFTERGLOW_DURATION = 1.2 -- seconds the settled cinders twinkle before gravity pulls them home

local GENESIS_STAGGER_MAX = 0.7 -- extra random seconds before a cinder begins its return
local GENESIS_DURATION = 1.5 -- seconds for a cinder to travel home once it starts moving
local GENESIS_HOLD = 0.5 -- seconds the fully-reformed text lingers before the animation ends

local CENTER_JITTER_FRAC = 0.12 -- how far the epicenter can drift from dead-center

-- Highlight groups ordered hottest/brightest -> coldest/dimmest
local HEAT_PALETTE = { "Title", "ErrorMsg", "WarningMsg", "String", "Constant", "Identifier", "Comment" }
local RING_CHARS = { "@", "#", "*", "o", "." }

-- ===== Helpers =====

local function clamp(v, a, b)
	return math.max(a, math.min(b, v))
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
local function dist(dx, dy)
	return math.sqrt(dx * dx + dy * dy)
end
local ASPECT = 0.5

local function get_max_cols(grid)
	local m = 0
	for r = 1, #grid do
		m = math.max(m, #grid[r])
	end
	return m
end

local function get_center(rows, cols)
	return math.floor((rows + 1) / 2), math.floor((cols + 1) / 2)
end

-- coldness: 0 = hottest/brightest, 1 = coldest/dimmest
local function palette_index(coldness)
	coldness = clamp(coldness, 0, 1)
	local n = #HEAT_PALETTE
	return clamp(math.floor(coldness * (n - 1) + 0.5) + 1, 1, n)
end

local function set_cell(grid, x, y, ch, hl)
	U.plot(grid, x, y, ch, hl)
end

local function clear_grid(grid)
	U.clear(grid)
end

-- Captures each character's original position and highlight so it can find
-- its way home again after being scattered as debris.
local function snapshot_particles(grid)
	local parts = {}
	for r = 1, #grid do
		for c = 1, #grid[r] do
			local cell = grid[r][c]
			local ch = cell.char
			if ch and ch ~= "" and ch ~= " " then
				table.insert(parts, { r0 = r, c0 = c, ch = ch, hl0 = cell.hl_group })
			end
		end
	end
	return parts
end

-- Draw one thin expanding ring band around (cr, cc) at the given radius.
local function draw_ring(grid, cr, cc, radius, rows, max_cols)
	if radius < 0.5 then
		return
	end
	local rceil = math.ceil(radius) + 2
	local rmin, rmax = clamp(math.floor(cr - rceil * ASPECT), 1, rows), clamp(math.ceil(cr + rceil * ASPECT), 1, rows)
	local cmin, cmax = clamp(cc - rceil, 1, max_cols), clamp(cc + rceil, 1, max_cols)

	local max_r = dist(rows / ASPECT, max_cols)
	local frac = clamp(radius / max_r, 0, 1)
	local idx = palette_index(frac)
	local color = HEAT_PALETTE[idx]
	local ch = RING_CHARS[math.min(idx, #RING_CHARS)]

	for r = rmin, rmax do
		for c = cmin, cmax do
			if c <= #grid[r] then
				local d = dist((r - cr) / ASPECT, c - cc)
				if math.abs(d - radius) <= RING_THICKNESS then
					U.plot(grid, c, r, ch, color)
				end
			end
		end
	end
end

-- ===== State =====
local state = {
	particles = {},
	rows = 0,
	max_cols = 0,
	center_r = 1,
	center_c = 1,
	phase = "implode",
	t = 0,
	core_t = 0,
	frame_since_explode = 0,
	rings = {},
	afterglow_t = 0,
	genesis_t = 0,
	hold_t = 0,
	original_snapshot = {},
}

-- ===== Animation Configuration =====

local config = {
	name = "supernova",
	fps = FPS,

	init = function(grid)
		state.rows = #grid
		state.max_cols = get_max_cols(grid)
		state.original_snapshot = U.snapshot(grid)

		local base_r, base_c = get_center(state.rows, state.max_cols)
		local jr = math.floor((rng() * 2 - 1) * state.rows * CENTER_JITTER_FRAC)
		local jc = math.floor((rng() * 2 - 1) * state.max_cols * CENTER_JITTER_FRAC)
		state.center_r = clamp(base_r + jr, 1, math.max(1, state.rows))
		state.center_c = clamp(base_c + jc, 1, math.max(1, state.max_cols))

		state.particles = snapshot_particles(grid)
		for _, p in ipairs(state.particles) do
			p.delay = rng() * IMPLODE_STAGGER_MAX
			p.x, p.y = p.c0, p.r0
			p.alive = true
		end

		state.phase = "implode"
		state.t = 0
		state.core_t = 0
		state.frame_since_explode = 0
		state.rings = {}
		state.afterglow_t = 0
		state.genesis_t = 0
		state.hold_t = 0
	end,

	update = function(grid)
		state.t = state.t + 1 / FPS
		clear_grid(grid)

		if state.phase == "implode" then
			local all_done = true

			for _, p in ipairs(state.particles) do
				local local_t = math.max(0, state.t - p.delay)
				local frac = clamp(local_t / IMPLODE_DURATION, 0, 1)
				if frac < 1 then
					all_done = false
				end
				local ease = frac * frac * frac
				p.x = lerp(p.c0, state.center_c, ease)
				p.y = lerp(p.r0, state.center_r, ease)
				p.heat = ease
			end

			for _, p in ipairs(state.particles) do
				local idx = palette_index(1 - p.heat)
				set_cell(grid, p.x, p.y, p.ch, HEAT_PALETTE[idx])
			end

			if all_done then
				state.phase = "core"
				state.core_t = 0
			end
		elseif state.phase == "core" then
			state.core_t = state.core_t + 1 / FPS

			set_cell(grid, state.center_c, state.center_r, "@", "Title")
			for dy = -1, 1 do
				for dx = -1, 1 do
					if not (dx == 0 and dy == 0) then
						set_cell(grid, state.center_c + dx, state.center_r + dy, "*", "Title")
					end
				end
			end

			if state.core_t >= CORE_HOLD then
				state.phase = "explode"
				state.frame_since_explode = 0

				for _, p in ipairs(state.particles) do
					local angle = rng() * 2 * math.pi
					local speed = EXPLODE_SPEED_MIN + rng() * (EXPLODE_SPEED_MAX - EXPLODE_SPEED_MIN)
					p.vx = math.cos(angle) * speed
					p.vy = math.sin(angle) * speed * ASPECT
					p.life = rng(PARTICLE_LIFE_MIN, PARTICLE_LIFE_MAX)
					p.life_max = p.life
					p.x, p.y = state.center_c, state.center_r
					p.alive = true
				end

				state.rings = {}
				for i = 1, RING_COUNT do
					table.insert(state.rings, { radius = 0, start_frame = (i - 1) * RING_DELAY_FRAMES, active = false })
				end
			end
		elseif state.phase == "explode" then
			state.frame_since_explode = state.frame_since_explode + 1
			local any_alive = false

			for _, p in ipairs(state.particles) do
				if p.alive then
					p.vx = p.vx * EXPLODE_DRAG
					p.vy = p.vy * EXPLODE_DRAG
					p.x = p.x + p.vx
					p.y = p.y + p.vy
					p.life = p.life - 1

					if p.life <= 0 or p.x < -2 or p.x > state.max_cols + 2 or p.y < -2 or p.y > state.rows + 2 then
						p.alive = false
					else
						any_alive = true
						local frac = p.life / p.life_max
						local idx = palette_index(1 - frac)
						local ch = p.ch
						if frac < 0.15 then
							ch = "."
						elseif frac < 0.45 then
							ch = (rng() < 0.5) and "*" or "+"
						end
						set_cell(grid, p.x, p.y, ch, HEAT_PALETTE[idx])
					end
				end
			end

			local any_ring_active = false
			local max_r = dist(
				math.max(state.center_r - 1, state.rows - state.center_r) / ASPECT,
				math.max(state.center_c - 1, state.max_cols - state.center_c)
			)
			for _, ring in ipairs(state.rings) do
				if state.frame_since_explode >= ring.start_frame then
					ring.active = true
				end
				if ring.active then
					ring.radius = ring.radius + RING_SPEED
					if ring.radius <= max_r then
						any_ring_active = true
						draw_ring(grid, state.center_r, state.center_c, ring.radius, state.rows, state.max_cols)
					end
				end
			end

			if not any_alive and not any_ring_active then
				state.phase = "afterglow"
				state.afterglow_t = 0
				for _, p in ipairs(state.particles) do
					p.twinkle_phase = rng() * 2 * math.pi
					p.twinkle_speed = 0.05 + rng() * 0.1
				end
			end
		elseif state.phase == "afterglow" then
			state.afterglow_t = state.afterglow_t + 1 / FPS

			-- The exact cinders each character became keep glowing faintly
			-- right where they came to rest.
			for _, p in ipairs(state.particles) do
				p.twinkle_phase = p.twinkle_phase + p.twinkle_speed
				local bright = (math.sin(p.twinkle_phase) + 1) / 2
				if bright > 0.5 then
					local idx = palette_index(1 - bright)
					set_cell(grid, p.x, p.y, ".", HEAT_PALETTE[idx])
				end
			end

			if state.afterglow_t >= AFTERGLOW_DURATION then
				state.phase = "genesis"
				state.genesis_t = 0
				for _, p in ipairs(state.particles) do
					p.genesis_delay = rng() * GENESIS_STAGGER_MAX
					p.gx0, p.gy0 = p.x, p.y
					p.frac = 0
				end
			end
		elseif state.phase == "genesis" then
			state.genesis_t = state.genesis_t + 1 / FPS
			local all_done = true

			for _, p in ipairs(state.particles) do
				local local_t = math.max(0, state.genesis_t - p.genesis_delay)
				local frac = clamp(local_t / GENESIS_DURATION, 0, 1)
				p.frac = frac
				if frac < 1 then
					all_done = false
				end
				-- Gravity pulls hard at first, then eases the cinder gently home.
				local ease = 1 - (1 - frac) ^ 3
				p.x = lerp(p.gx0, p.c0, ease)
				p.y = lerp(p.gy0, p.r0, ease)
			end

			for _, p in ipairs(state.particles) do
				if p.frac >= 1 then
					set_cell(grid, p.c0, p.r0, p.ch, p.hl0)
				else
					-- Reignites from a dim cinder to a hot flare right as it arrives.
					local idx = palette_index(1 - p.frac)
					set_cell(grid, p.x, p.y, p.ch, HEAT_PALETTE[idx])
				end
			end

			if all_done then
				U.restore(grid, state.original_snapshot)
				state.phase = "genesis_hold"
				state.hold_t = 0
			end
		elseif state.phase == "genesis_hold" then
			state.hold_t = state.hold_t + 1 / FPS
			U.restore(grid, state.original_snapshot)
			if state.hold_t >= GENESIS_HOLD then
				return false
			end
		end

		return true
	end,
}

-- ===== Module Export =====

local M = {}

function M.register()
	require("custom-cellular-automaton.runtime").register(config)
end

return M
