-- configs/cellular-automaton/runner.lua
-- Animated runner that zips around without overwriting existing text.
-- Usage: :CellularAutomaton runner

local ca = require("custom-cellular-automaton.runtime")

local M = {}

-- ========= Tweakables =========
local FPS = 30
-- Movement noise & bounce
local SPEED = 18.0 -- cells/sec
local NOISE_HZ = 1.2 -- how often the heading wiggles (lower = smoother)
local NOISE_STRENGTH = 1.4 -- radians/sec of angular “push”
local TURN_INERTIA = 0.6 -- seconds; higher = smoother turns
local BOUNCE_JITTER = 0.35 -- radians of random deflection on bounce
local SLIDE_PROB = 0.75 -- chance to slide along a wall instead of full bounce
local FRAME_HZ = 8.0 -- animation frame rate for the runner sprite
-- ==============================

-- Runner sprite (spaces are transparent)
local RUNNER_FRAMES = {
	{ -- frame 1
		" o ",
		"/|>",
		"/ \\",
	},
	{ -- frame 2
		" o ",
		"<|\\",
		"/ \\",
	},
	{ -- frame 3 (mid)
		" o ",
		"/|\\",
		" | ",
	},
}

-- ---------- helpers ----------
local function rnd_unit()
	return (math.random() * 2 - 1)
end
local function atan2(y, x)
	return math.atan2(y, x)
end
local function normalize(vx, vy)
	local m = math.sqrt(vx * vx + vy * vy)
	if m < 1e-9 then
		return 1, 0
	end
	return vx / m, vy / m
end

-- Reflect vector (vx,vy) across a normal (nx,ny), both arbitrary length
local function reflect(vx, vy, nx, ny)
	local nnx, nny = normalize(nx, ny)
	local dot = vx * nnx + vy * nny
	return vx - 2 * dot * nnx, vy - 2 * dot * nny
end

local function is_space(ch)
	-- A continuation cell is part of the user's wide glyph, not open space.
	return ch == " " or ch == nil
end
local function grid_size(grid)
	local cols = 0
	for _, row in ipairs(grid) do
		cols = math.max(cols, #row)
	end
	return #grid, cols
end

local function snapshot_grid(grid)
	local rows, cols = grid_size(grid)
	local snap, highlights = {}, {}
	for r = 1, rows do
		snap[r] = {}
		highlights[r] = {}
		for c = 1, cols do
			local cell = grid[r][c]
			snap[r][c] = cell and cell.char or " "
			highlights[r][c] = cell and cell.hl_group or nil
		end
	end
	return snap, highlights
end

local function dims(stencil)
	local h = #stencil
	local w = 0
	for _, line in ipairs(stencil) do
		if #line > w then
			w = #line
		end
	end
	return w, h
end

local function can_draw_over_baseline(baseline, stencil, top, left)
	local rows, cols = grid_size(baseline)
	for r = 1, #stencil do
		local line = stencil[r]
		for i = 1, #line do
			local ch = line:sub(i, i)
			if not is_space(ch) then
				local rr, cc = top + r - 1, left + i - 1
				if rr < 1 or rr > rows or cc < 1 or cc > cols then
					return false
				end
				if not baseline[rr] or not is_space(baseline[rr][cc]) then
					return false
				end
			end
		end
	end
	return true
end

local function blit_over_baseline(grid, baseline, stencil, top, left)
	local rows, cols = grid_size(grid)
	for r = 1, #stencil do
		local line = stencil[r]
		for i = 1, #line do
			local ch = line:sub(i, i)
			if not is_space(ch) then
				local rr, cc = top + r - 1, left + i - 1
				if rr >= 1 and rr <= rows and cc >= 1 and cc <= cols then
					if is_space(baseline[rr][cc]) then
						grid[rr][cc].char = ch
					end
				end
			end
		end
	end
end

-- ---------- animation state ----------
local state = nil

local function reset_state()
	state = {
		t = 0.0,
		frame_t = 0.0,
		turn_cooldown = 0.0,
		baseline = nil,
		baseline_hl = nil,
		posx = 1.0, -- top-left of sprite (float)
		posy = 1.0,
		vx = 1.0, -- units/sec (columns)
		vy = 0.5, -- units/sec (rows)
		frame = 1,
		theta = 0.0, -- heading angle (radians)
		omega = 0.0, -- angular velocity (rad/s)
		noise_t = 0.0,
		noise_rate = 0.0,
	}
end

local function restore_baseline(grid)
	if not state or not state.baseline then
		return
	end
	for r, row in ipairs(grid) do
		for c, cell in ipairs(row) do
			cell.char = state.baseline[r][c] or " "
			cell.hl_group = state.baseline_hl[r][c]
		end
	end
end

-- try stepping to (nx,ny) with collision to baseline and walls; resolves by bounce/slide
local function resolve_next(baseline, w, h, nx, ny, vx, vy)
	local rows, cols = grid_size(baseline)
	local left = math.floor(nx + 0.5)
	local top = math.floor(ny + 0.5)

	local function fits(t, l)
		return l >= 1
			and t >= 1
			and l + w - 1 <= cols
			and t + h - 1 <= rows
			and can_draw_over_baseline(baseline, RUNNER_FRAMES[state.frame], t, l)
	end

	-- Free move
	if fits(top, left) then
		return nx, ny, vx, vy, false
	end

	-- Try slides (prefer keeping some component)
	if math.random() < SLIDE_PROB then
		local top_v = math.floor(ny + 0.5)
		local left_v = math.floor(state.posx + 0.5)
		if fits(top_v, left_v) then
			-- Treat as a “vertical wall” hit; reflect horizontally w/ jitter
			local rvx, rvy = reflect(vx, vy, 1, 0) -- normal along +x
			local th = atan2(rvy, rvx) + rnd_unit() * BOUNCE_JITTER
			return state.posx, ny, math.cos(th) * SPEED, math.sin(th) * SPEED, true
		end

		local top_h = math.floor(state.posy + 0.5)
		local left_h = math.floor(nx + 0.5)
		if fits(top_h, left_h) then
			-- Treat as a “horizontal wall” hit; reflect vertically w/ jitter
			local rvx, rvy = reflect(vx, vy, 0, 1) -- normal along +y
			local th = atan2(rvy, rvx) + rnd_unit() * BOUNCE_JITTER
			return nx, state.posy, math.cos(th) * SPEED, math.sin(th) * SPEED, true
		end
	end

	-- Full bounce: decide which normal based on which axis moved more
	local nxn, nyn
	if math.abs(vx) > math.abs(vy) then
		nxn, nyn = 1, 0 -- vertical wall normal
	else
		nxn, nyn = 0, 1 -- horizontal wall normal
	end
	local rvx, rvy = reflect(vx, vy, nxn, nyn)
	local th = atan2(rvy, rvx) + rnd_unit() * BOUNCE_JITTER
	-- stay in place to avoid tunneling; return new velocity
	return state.posx, state.posy, math.cos(th) * SPEED, math.sin(th) * SPEED, true
end

local function compose_frame(grid)
	local rows, cols = grid_size(grid)

	-- 1) Restore baseline everywhere (text) and clear everything else.
	for r = 1, rows do
		for c = 1, cols do
			local base = state.baseline[r][c]
			grid[r][c].char = base or " "
			grid[r][c].hl_group = state.baseline_hl[r][c]
		end
	end

	-- 2) Draw the runner on top
	local stencil = RUNNER_FRAMES[state.frame]
	blit_over_baseline(grid, state.baseline, stencil, math.floor(state.posy + 0.5), math.floor(state.posx + 0.5))
end

function M.register()
	local cfg = {
		fps = FPS,
		name = "runner",

		init = function(grid)
			reset_state()
			state.baseline, state.baseline_hl = snapshot_grid(grid)

			-- place runner at a random valid spot that doesn't cover text
			local w, h = dims(RUNNER_FRAMES[state.frame])
			local rows, cols = grid_size(grid)
			state.placed = false
			for _ = 1, 400 do
				local left = math.random(math.max(1, cols - w + 1))
				local top = math.random(math.max(1, rows - h + 1))
				if can_draw_over_baseline(state.baseline, RUNNER_FRAMES[state.frame], top, left) then
					state.posx, state.posy = left, top
					state.placed = true
					break
				end
			end

			if not state.placed then
				for top = 1, rows - h + 1 do
					for left = 1, cols - w + 1 do
						if can_draw_over_baseline(state.baseline, RUNNER_FRAMES[state.frame], top, left) then
							state.posx, state.posy, state.placed = left, top, true
							break
						end
					end
					if state.placed then
						break
					end
				end
			end

			-- random initial direction
			local ang = math.random() * 2 * math.pi
			state.theta = ang
			state.omega = 0.0
			state.vx = math.cos(state.theta) * SPEED
			state.vy = math.sin(state.theta) * SPEED
		end,
		cleanup = restore_baseline,

		update = function(grid)
			if not state.placed then
				return false
			end
			local dt = 1.0 / FPS
			state.t = state.t + dt
			state.frame_t = state.frame_t + dt
			state.turn_cooldown = state.turn_cooldown - dt

			-- Animate frames
			if state.frame_t >= 1.0 / FRAME_HZ then
				state.frame_t = state.frame_t - 1.0 / FRAME_HZ
				state.frame = state.frame + 1
				if state.frame > #RUNNER_FRAMES then
					state.frame = 1
				end
			end

			-- Smooth heading noise (replaces old jitter)
			do
				-- pick a slowly-changing target angular rate
				state.noise_t = state.noise_t - dt
				if state.noise_t <= 0 then
					state.noise_rate = NOISE_STRENGTH * rnd_unit()
					state.noise_t = 1 / NOISE_HZ
				end
				local target_rate = state.noise_rate
				-- ease angular velocity toward target (turn smoothing)
				state.omega = state.omega + (target_rate - state.omega) * (dt / TURN_INERTIA)
				-- advance heading
				state.theta = state.theta + state.omega * dt
				-- rebuild velocity from heading at constant speed
				state.vx = math.cos(state.theta) * SPEED
				state.vy = math.sin(state.theta) * SPEED
			end

			-- Proposed next position
			local nx = state.posx + state.vx * dt
			local ny = state.posy + state.vy * dt

			local w, h = dims(RUNNER_FRAMES[state.frame])
			local left, top, nvx, nvy = resolve_next(state.baseline, w, h, nx, ny, state.vx, state.vy)
			state.posx, state.posy = left, top
			state.vx, state.vy = nvx, nvy
			state.theta = atan2(state.vy, state.vx) -- <-- keep noise aligned after bounce

			compose_frame(grid)
			return true
		end,
	}

	ca.register(cfg)
end

return M
