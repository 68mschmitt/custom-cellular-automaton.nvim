-- Responsive selection wheel. Usage: :'<,'>SpinWheel or :CellularAutomaton spin_wheel
local U = require("custom-cellular-automaton.util")
local Selection = require("custom-cellular-automaton.selection")
local M = {}
local TAU = 2 * math.pi
local COLORS = { "String", "Function", "Type", "Constant", "Identifier", "Special" }

function M.register()
	local state
	local fps, spin_time, hold = 30, 8, 3
	require("custom-cellular-automaton.runtime").register({
		name = "spin_wheel",
		fps = fps,
		init = function(grid)
			local rows, cols = U.size(grid)
			local labels = Selection.labels()
			local winner = math.random(#labels)
			local start = math.random() * TAU
			local finish = TAU - (winner - 0.5) / #labels * TAU
			state = {
				frame = 0,
				labels = labels,
				winner = winner,
				rows = rows,
				cols = cols,
				cx = (cols + 1) / 2,
				cy = (rows + 3) / 2,
				radius = math.max(0, math.min((cols - 8) / 2, rows - 6)),
				start = start,
				travel = TAU * 3 + (finish - start) % TAU,
				announced = false,
			}
		end,
		update = function(grid)
			state.frame = state.frame + 1
			local time = state.frame / fps
			local progress = math.min(1, time / spin_time)
			local angle = state.start + state.travel * (1 - (1 - progress) ^ 3)
			local current = math.floor((-angle % TAU) / TAU * #state.labels) + 1
			U.clear(grid)
			if state.radius >= 3 then
				local steps = math.max(12, math.ceil(TAU * state.radius * 1.5))
				for i = 1, steps do
					local a = i / steps * TAU
					U.plot(
						grid,
						state.cx + state.radius * math.cos(a),
						state.cy + state.radius / 2 * math.sin(a),
						"o",
						"Special"
					)
				end
				local occupied = {}
				for i, label in ipairs(state.labels) do
					local a = angle + (i - 1) / #state.labels * TAU
					-- Dense wheels use rim ticks; excessive spokes would obscure labels.
					local begin = #state.labels <= 16 and 1 or math.max(1, state.radius - 1)
					for r = begin, state.radius do
						U.plot(grid, state.cx + r * math.cos(a), state.cy + r / 2 * math.sin(a), ".", "Comment")
					end
					a = a + math.pi / #state.labels
					local text =
						U.truncate(i .. ":" .. label, math.max(1, math.min(20, math.floor(state.radius * 0.85))))
					local width = vim.fn.strdisplaywidth(text)
					local x = math.floor(state.cx + state.radius * 0.6 * math.cos(a) - width / 2 + 0.5)
					local y = math.floor(state.cy + state.radius * 0.32 * math.sin(a) + 0.5)
					local fits = x >= 1 and x + width - 1 <= state.cols
					for c = x - 1, x + width do
						if occupied[y .. ":" .. c] then
							fits = false
						end
					end
					if fits then
						U.text(grid, x, y, text, COLORS[(i - 1) % #COLORS + 1])
						for c = x - 1, x + width do
							occupied[y .. ":" .. c] = true
						end
					end
				end
				U.plot(grid, state.cx, state.cy, "+", "Special")
				U.text(grid, state.cx + state.radius + 1, state.cy, "<--", "WarningMsg")
			else
				U.text(
					grid,
					1,
					math.max(1, math.ceil(state.rows / 2)),
					U.truncate("> " .. state.labels[current], state.cols),
					"Special"
				)
			end
			local stopped = progress == 1
			local label = state.labels[stopped and state.winner or current]
			U.text(grid, 1, 1, U.truncate((stopped and "WINNER: " or "Spinning: ") .. label, state.cols), "Title")
			if stopped and not state.announced then
				state.announced = true
				vim.notify("Spin Wheel winner: " .. label)
			end
			return time < spin_time + hold
		end,
	})
end

return M
