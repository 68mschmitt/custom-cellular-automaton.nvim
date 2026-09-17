-- Text gathers into a smooth orb with a fading trail, then returns to the buffer.
-- Usage: :CellularAutomaton wisp
local U = require("custom-cellular-automaton.util")
local M = { drift_speed = 120, radius = 5, tail_length = 12 }

function M.register()
	local state
	local fps = 30
	require("custom-cellular-automaton.runtime").register({
		name = "wisp",
		fps = fps,
		init = function(grid)
			local rows, cols = U.size(grid)
			state = {
				frame = 0,
				snapshot = U.snapshot(grid),
				particles = {},
				trail = {},
				x = (cols + 1) / 2,
				y = (rows + 1) / 2,
				vx = 1,
				vy = 0.6,
				rows = rows,
				cols = cols,
				radius = math.max(0, math.min(M.radius, (cols - 1) / 2, rows - 1)),
			}
			for r, row in ipairs(grid) do
				for c, cell in ipairs(row) do
					if cell.char ~= " " and cell.char ~= "" then
						local angle, radius = math.random() * 2 * math.pi, math.sqrt(math.random()) * state.radius
						state.particles[#state.particles + 1] = {
							x = c,
							y = r,
							char = cell.char,
							dx = math.cos(angle) * radius,
							dy = math.sin(angle) * radius / 2,
						}
					end
				end
			end
		end,
		cleanup = function(grid)
			if state and state.snapshot then
				U.restore(grid, state.snapshot)
			end
		end,
		update = function(grid)
			state.frame = state.frame + 1
			local time = state.frame / fps
			if #state.particles == 0 or time >= 10 then
				U.restore(grid, state.snapshot)
				return false
			end
			U.clear(grid)
			if time > 1.5 and time < 8 then
				table.insert(state.trail, 1, { x = state.x, y = state.y })
				if #state.trail > M.tail_length then
					table.remove(state.trail)
				end
				state.x = state.x + state.vx * M.drift_speed / fps
				state.y = state.y + state.vy * M.drift_speed / fps / 2
				local rx, ry = state.radius, state.radius / 2
				if state.x < 1 + rx or state.x > state.cols - rx then
					state.vx = -state.vx
				end
				if state.y < 1 + ry or state.y > state.rows - ry then
					state.vy = -state.vy
				end
				state.x = math.max(1 + rx, math.min(state.cols - rx, state.x))
				state.y = math.max(1 + ry, math.min(state.rows - ry, state.y))
			end
			-- Oldest first, always behind the orb; fading never paints blank pixels.
			if time < 8 then
				for i = #state.trail, 1, -1 do
					local pos = state.trail[i]
					local radius = state.radius * (1 - i / (M.tail_length + 1))
					for angle = 0, 5.9, 0.6 do
						U.plot(
							grid,
							pos.x + math.cos(angle) * radius,
							pos.y + math.sin(angle) * radius / 2,
							i < 4 and "*" or ".",
							i < 4 and "Special" or "Comment"
						)
					end
				end
			end
			local formation = math.min(1, time / 1.5)
			local returning = math.max(0, (time - 8) / 2)
			for i, p in ipairs(state.particles) do
				if formation < 1 or returning > 0 or i <= 160 then
					local x, y = state.x + p.dx, state.y + p.dy
					x, y = p.x + (x - p.x) * formation, p.y + (y - p.y) * formation
					x, y = x + (p.x - x) * returning, y + (p.y - y) * returning
					U.plot(grid, x, y, p.char, "Special")
				end
			end
			return true
		end,
	})
end

return M
