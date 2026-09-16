-- Warp Drive for cellular-automaton.nvim
-- Usage: :CellularAutomaton warp_drive
-- Code stretches into a cyan/violet hyperspace tunnel, flies past glowing
-- rings and star trails, then reassembles with its original syntax highlights.

local M = {}
local U = require("custom-cellular-automaton.util")

local FPS = 30
local LAUNCH = 1.5
local CRUISE = 4.5
local ARRIVAL = 2.0
local HOLD = 0.5
local TAU = 2 * math.pi

local function smooth(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function plot(grid, x, y, char, hl)
	U.plot(grid, x, y, char, hl)
end

-- Bounded trail work even when perspective projects a star far off-screen.
local function trail(grid, x, y, px, py, hl)
	local dx, dy = x - px, y - py
	local steps = math.min(12, math.ceil(math.max(math.abs(dx), math.abs(dy))))
	local char = math.abs(dx) > math.abs(dy) * 2 and "-"
		or (math.abs(dy) > math.abs(dx) and "|" or (dx * dy > 0 and "\\" or "/"))
	for i = 1, steps do
		local t = i / steps
		plot(grid, px + dx * t, py + dy * t, char, hl)
	end
end

function M.register()
	local state = {}
	local config = { name = "warp_drive", fps = FPS }

	config.init = function(grid)
		local colors = {
			Dim = { fg = "#384478", ctermfg = 60 },
			Violet = { fg = "#b48eff", ctermfg = 141 },
			Cyan = { fg = "#5eeaff", ctermfg = 87 },
			White = { fg = "#e8fbff", ctermfg = 195, bold = true },
		}
		for name, spec in pairs(colors) do
			spec.default = true
			vim.api.nvim_set_hl(0, "CAWarp" .. name, spec)
		end

		state = { frame = 0, rows = #grid, cols = 0, snapshot = {}, text = {}, stars = {} }
		local cells = 0
		for r, row in ipairs(grid) do
			state.cols = math.max(state.cols, #row)
			state.snapshot[r] = {}
			for c, cell in ipairs(row) do
				cells = cells + 1
				state.snapshot[r][c] = { char = cell.char, hl_group = cell.hl_group }
				if cell.char and cell.char ~= " " and cell.char ~= "" then
					state.text[#state.text + 1] = {
						x = c,
						y = r,
						char = cell.char,
						hl = cell.hl_group,
					}
				end
			end
		end
		state.cx, state.cy = (state.cols + 1) / 2, (state.rows + 1) / 2
		-- Correct for terminal cells being roughly twice as tall as they are wide.
		state.radius = math.max(1, math.min(state.cols * 0.45, state.rows * 0.9))
		for _ = 1, math.min(240, math.ceil(cells / 12)) do
			local angle = math.random() * TAU
			local radius = 0.15 + math.random() * 1.2
			state.stars[#state.stars + 1] = {
				x = math.cos(angle) * radius,
				y = math.sin(angle) * radius,
				z = 0.15 + math.random() * 1.5,
				violet = math.random() < 0.3,
			}
		end
	end

	local function restore(grid)
		for r, row in ipairs(grid) do
			for c, cell in ipairs(row) do
				local original = state.snapshot[r][c]
				cell.char, cell.hl_group = original.char, original.hl_group
			end
		end
	end
	config.cleanup = restore

	local function tunnel(grid, time, strength)
		local cx = state.cx + math.sin(time * 0.8) * state.cols * 0.045 * strength
		local cy = state.cy + math.sin(time * 1.1) * state.rows * 0.04 * strength
		local speed = (0.08 + 1.3 * strength) / FPS

		-- Perspective rings form a gently twisting flight corridor.
		for ring = 1, 5 do
			local z = 0.18 + ((ring / 5 - time * 0.45) % 1) * 1.8
			local radius = state.radius * 0.65 / z
			for segment = 1, 72 do
				local angle = segment / 72 * TAU + time * 0.25 + z * 0.4
				local ripple = 1 + 0.045 * math.sin(angle * 6 + time * 2)
				plot(
					grid,
					cx + math.cos(angle) * radius * ripple,
					cy + math.sin(angle) * radius * ripple / 2,
					z < 0.5 and ":" or ".",
					ring % 2 == 0 and "CAWarpViolet" or "CAWarpDim"
				)
			end
		end

		for _, star in ipairs(state.stars) do
			local old_z = star.z
			star.z = star.z - speed
			if star.z < 0.12 then
				star.z = 1.65
				old_z = star.z
			end
			local x = cx + star.x * state.radius / star.z
			local y = cy + star.y * state.radius / star.z / 2
			local px = cx + star.x * state.radius / old_z
			local py = cy + star.y * state.radius / old_z / 2
			local color = star.violet and "CAWarpViolet" or "CAWarpCyan"
			trail(grid, x, y, px, py, star.z > 0.9 and "CAWarpDim" or color)
			plot(grid, x, y, star.z < 0.4 and "+" or ".", star.z < 0.4 and "CAWarpWhite" or color)
		end
	end

	config.update = function(grid)
		if state.rows == 0 or state.cols == 0 then
			return false
		end
		state.frame = state.frame + 1
		local time = state.frame / FPS
		local arrival_start = LAUNCH + CRUISE
		local arrival_end = arrival_start + ARRIVAL

		if time >= arrival_end then
			restore(grid)
			return time < arrival_end + HOLD
		end

		U.clear(grid)

		local launch = smooth(time / LAUNCH)
		local arrival = smooth((time - arrival_start) / ARRIVAL)
		local strength = launch * (1 - arrival)
		tunnel(grid, time, strength)

		if time < LAUNCH then
			local scale = 1 + 18 * launch * launch
			local previous = 1 + 18 * smooth((time - 1 / FPS) / LAUNCH) ^ 2
			for _, p in ipairs(state.text) do
				local dx, dy = p.x - state.cx, p.y - state.cy
				local x, y = state.cx + dx * scale, state.cy + dy * scale
				trail(grid, x, y, state.cx + dx * previous, state.cy + dy * previous, "CAWarpCyan")
				plot(grid, x, y, p.char, launch < 0.15 and p.hl or "CAWarpWhite")
			end
		elseif time >= arrival_start then
			-- The code returns from the vanishing point, with a little barrel roll.
			local angle = (1 - arrival) * 0.7
			local cos, sin = math.cos(angle), math.sin(angle)
			for _, p in ipairs(state.text) do
				local dx, dy = p.x - state.cx, (p.y - state.cy) * 2
				local x = state.cx + (dx * cos - dy * sin) * arrival
				local y = state.cy + (dx * sin + dy * cos) * arrival / 2
				plot(grid, x, y, p.char, arrival < 0.85 and "CAWarpCyan" or p.hl)
			end
			-- Sweep away the tunnel from the center out, locking cells into place.
			local reveal = math.max(0, (arrival - 0.65) / 0.35)
			for r, row in ipairs(grid) do
				for c, cell in ipairs(row) do
					local distance = math.max(
						math.abs(c - state.cx) / math.max(1, state.cols / 2),
						math.abs(r - state.cy) / math.max(1, state.rows / 2)
					)
					if reveal > distance then
						local original = state.snapshot[r][c]
						cell.char, cell.hl_group = original.char, original.hl_group
					end
				end
			end
		end
		return true
	end

	require("custom-cellular-automaton.runtime").register(config)
end

return M
