-- Text ignites into warm embers which rise, cool, and leave the viewport.
-- Usage: :CellularAutomaton ember
local U = require("custom-cellular-automaton.util")
local M = {}

function M.register()
	local frame, fuel, particles
	local fps = 30
	require("custom-cellular-automaton.runtime").register({
		name = "ember",
		fps = fps,
		init = function(grid)
			frame, fuel, particles = 0, {}, {}
			for r, row in ipairs(grid) do
				for c, cell in ipairs(row) do
					if cell.char ~= " " and cell.char ~= "" then
						fuel[#fuel + 1] = {
							x = c,
							y = r,
							char = cell.char,
							hl = cell.hl_group,
							ignition = math.random() * 2.5 + (#grid - r) / math.max(1, #grid),
						}
					end
				end
			end
		end,
		update = function(grid)
			frame = frame + 1
			local time = frame / fps
			U.clear(grid)
			local waiting = {}
			for _, p in ipairs(fuel) do
				if time >= p.ignition then
					p.life, p.speed, p.phase = 1 + math.random() * 1.5, 5 + math.random() * 7, math.random() * 6
					particles[#particles + 1] = p
				else
					U.plot(grid, p.x, p.y, p.char, p.hl)
					waiting[#waiting + 1] = p
				end
			end
			fuel = waiting
			local alive = {}
			for _, p in ipairs(particles) do
				p.y = p.y - p.speed / fps
				p.x = p.x + math.sin(time * 3 + p.phase) * 2 / fps
				p.life = p.life - 1 / fps
				if p.life > 0 and p.y >= 0.5 then
					U.plot(grid, p.x, p.y, p.life < 0.5 and "." or "*", p.life < 0.5 and "Comment" or "WarningMsg")
					alive[#alive + 1] = p
				end
			end
			particles = alive
			return #fuel > 0 or #particles > 0
		end,
	})
end

return M
