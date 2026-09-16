-- Drifting scanlines, temporary corruption and teleport bursts, then recovery.
-- Usage: :CellularAutomaton glitch_drift
local U = require("custom-cellular-automaton.util")
local M = {}

function M.register()
	local frame, snapshot, particles, cols
	local fps, duration = 30, 7
	local glyphs = { "@", "#", "~", "%" }
	require("custom-cellular-automaton.runtime").register({
		name = "glitch_drift",
		fps = fps,
		init = function(grid)
			frame, snapshot, particles = 0, U.snapshot(grid), {}
			local _
			_, cols = U.size(grid)
			for r, row in ipairs(grid) do
				for c, cell in ipairs(row) do
					if cell.char ~= " " and cell.char ~= "" then
						particles[#particles + 1] = { x = c, y = r, char = cell.char, hl = cell.hl_group, drift = 0 }
					end
				end
			end
		end,
		cleanup = function(grid)
			if snapshot then
				U.restore(grid, snapshot)
			end
		end,
		update = function(grid)
			frame = frame + 1
			local time = frame / fps
			if #particles == 0 or time >= duration then
				U.restore(grid, snapshot)
				return false
			end
			U.clear(grid)
			local envelope = math.min(1, time, (duration - time) / 1.5)
			for _, p in ipairs(particles) do
				p.drift = p.drift + (p.y % 2 == 0 and 1 or -1) * 4 / fps
				if math.random() < 0.025 then
					p.drift = p.drift + math.random(-6, 6)
				end
				local offset = (p.drift + math.sin(time * 3 + p.y) * 2) * envelope
				local x = 1 + ((math.floor(p.x + offset + 0.5) - 1) % cols)
				local glitch = math.random() < 0.12 * envelope
				U.plot(grid, x, p.y, glitch and glyphs[math.random(#glyphs)] or p.char, glitch and "Special" or p.hl)
			end
			return true
		end,
	})
end

return M
