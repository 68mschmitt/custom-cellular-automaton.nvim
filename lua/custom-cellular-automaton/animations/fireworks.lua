-- Fireworks Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton fireworks
-- Behavior:
--   • Rockets launch from bottom and explode into sparks
--   • Sparks spread outward in all directions with gravity
--   • Multiple concurrent explosions create a fireworks show
--   • Optional duration limit (set DURATION_TICKS = nil for infinite)
-- Parameters are configurable at the top of the file (FPS, rocket count, and spark lifetime).

local rng = math.random
local U = require("custom-cellular-automaton.util")

-- optional colors; safe to leave nil if your theme lacks any of these
local PALETTE = {
	"Constant",
	"Type",
	"String",
	"Function",
	"Identifier",
	"DiagnosticOk",
	"DiagnosticWarn",
	"DiagnosticInfo",
	"DiffAdd",
	"DiffText",
}

-- physics/behavior
local MAX_ROCKETS = 3
local ROCKET_SPAWN_PCT = 20
-- speeds are POSITIVE magnitudes; we apply a minus sign when assigning vy
local ROCKET_SPEED_MIN = 1.2
local ROCKET_SPEED_MAX = 1.8
local ROCKET_WIGGLE = 0.25

local BURST_PARTS = 24
local BURST_SPEED_MIN = 0.4
local BURST_SPEED_MAX = 1.3
local GRAVITY = 0.05
local AIR_DRAG = 0.99
local SPARK_LIFE_MIN = 25
local SPARK_LIFE_MAX = 45

local FPS = 30
local DURATION_TICKS = FPS * 12

local function clamp(x, lo, hi)
	return (x < lo) and lo or ((x > hi) and hi or x)
end

local state = { t = 0, rockets = {}, sparks = {}, width = 0, height = 0 }

local function clear_grid(grid)
	U.clear(grid)
end

local function set_cell(grid, x, y, ch, hl)
	U.plot(grid, x, y, ch, hl)
end

local function spawn_rocket()
	local margin = math.min(2, math.floor((state.width - 1) / 2))
	local x = rng(1 + margin, state.width - margin)
	local y = math.max(1, state.height - 1)
	local vx = (rng() * 2 - 1) * 0.2
	-- IMPORTANT: negative vy -> upward motion
	local speed = ROCKET_SPEED_MIN + rng() * (ROCKET_SPEED_MAX - ROCKET_SPEED_MIN)
	local vy = -speed
	local color = rng(1, #PALETTE)
	table.insert(state.rockets, { x = x, y = y, vx = vx, vy = vy, color = color, exploded = false, trail = {} })
end

local function explode(r)
	local color = r.color
	for k = 1, BURST_PARTS do
		local angle = (k / BURST_PARTS) * (2 * math.pi) + (rng() * 0.25)
		local spd = BURST_SPEED_MIN + rng() * (BURST_SPEED_MAX - BURST_SPEED_MIN)
		local life = SPARK_LIFE_MIN + rng(SPARK_LIFE_MAX - SPARK_LIFE_MIN)
		table.insert(state.sparks, {
			x = r.x,
			y = r.y,
			vx = math.cos(angle) * spd,
			vy = math.sin(angle) * spd / 2,
			life = life,
			color = color,
		})
	end
end

local function update_rockets(grid)
	local alive = {}
	for _, r in ipairs(state.rockets) do
		table.insert(r.trail, 1, { x = r.x, y = r.y })
		if #r.trail > 5 then
			table.remove(r.trail)
		end
		for _, point in ipairs(r.trail) do
			set_cell(grid, point.x, point.y, ".", "Comment")
		end
		r.x = r.x + r.vx + ((rng() * 2 - 1) * ROCKET_WIGGLE)
		r.y = r.y + r.vy
		r.x = clamp(r.x, 1, state.width)
		r.y = math.max(1, r.y)
		set_cell(grid, r.x, r.y, "^", PALETTE[r.color])

		local near_top = (r.y <= state.height * 0.25)
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
		s.vy = s.vy * AIR_DRAG + GRAVITY / 2
		s.x = s.x + s.vx
		s.y = s.y + s.vy
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
		state.height, state.width = require("custom-cellular-automaton.util").size(grid)
		state.t = 0
		state.rockets, state.sparks = {}, {}
	end,
	update = function(grid)
		state.t = state.t + 1
		clear_grid(grid)
		local finale = state.t >= DURATION_TICKS - FPS * 2
		local limit = finale and MAX_ROCKETS * 2 or MAX_ROCKETS
		local chance = finale and ROCKET_SPAWN_PCT * 2 or ROCKET_SPAWN_PCT
		if state.t < DURATION_TICKS and #state.rockets < limit and rng(1, 100) <= chance then
			spawn_rocket()
		end
		update_rockets(grid)
		update_sparks(grid)
		if state.t >= DURATION_TICKS and #state.rockets == 0 and #state.sparks == 0 then
			return false
		end
		return true
	end,
}

local M = {}

function M.register()
	require("custom-cellular-automaton.runtime").register(config)
end

return M
