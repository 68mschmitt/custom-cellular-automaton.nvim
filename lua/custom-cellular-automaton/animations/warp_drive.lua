-- Warp Drive for cellular-automaton.nvim
-- Usage: :CellularAutomaton warp_drive
-- Code stretches into a cyan/violet hyperspace tunnel, flies past glowing
-- rings and star trails, then reassembles with its original syntax highlights.

local M = {}
local U = require("custom-cellular-automaton.util")
local Warp = require("custom-cellular-automaton.warp")

local FPS = 30
local LAUNCH = 1.5
local CRUISE = 4.5
local ARRIVAL = 2.0
local HOLD = 0.5

function M.register()
	local state = {}
	local config = { name = "warp_drive", fps = FPS }

	config.init = function(grid)
		Warp.setup_colors()

		state = { frame = 0, rows = #grid, cols = 0, snapshot = {}, text = {} }
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
		state.tunnel = Warp.new_state(state.rows, state.cols, cells)
		state.cx, state.cy = state.tunnel.cx, state.tunnel.cy
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

		local launch = Warp.smooth(time / LAUNCH)
		local arrival = Warp.smooth((time - arrival_start) / ARRIVAL)
		local strength = launch * (1 - arrival)
		Warp.tunnel(grid, state.tunnel, time, strength, FPS)

		if time < LAUNCH then
			local scale = 1 + 18 * launch * launch
			local previous = 1 + 18 * Warp.smooth((time - 1 / FPS) / LAUNCH) ^ 2
			for _, p in ipairs(state.text) do
				local dx, dy = p.x - state.cx, p.y - state.cy
				local x, y = state.cx + dx * scale, state.cy + dy * scale
				Warp.trail(grid, x, y, state.cx + dx * previous, state.cy + dy * previous, "CAWarpCyan")
				U.plot(grid, x, y, p.char, launch < 0.15 and p.hl or "CAWarpWhite")
			end
		elseif time >= arrival_start then
			-- The code returns from the vanishing point, with a little barrel roll.
			local angle = (1 - arrival) * 0.7
			local cos, sin = math.cos(angle), math.sin(angle)
			for _, p in ipairs(state.text) do
				local dx, dy = p.x - state.cx, (p.y - state.cy) * 2
				local x = state.cx + (dx * cos - dy * sin) * arrival
				local y = state.cy + (dx * sin + dy * cos) * arrival / 2
				U.plot(grid, x, y, p.char, arrival < 0.85 and "CAWarpCyan" or p.hl)
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
