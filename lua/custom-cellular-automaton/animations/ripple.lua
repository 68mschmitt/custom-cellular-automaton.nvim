-- Three finite, aspect-correct ripples from the cursor. Usage: :CellularAutomaton ripple
local U = require("custom-cellular-automaton.util")
local M = {}

function M.register()
	local snapshot, frame, cx, cy, radius
	local fps, speed = 30, 22 -- column-equivalent cells per second
	require("custom-cellular-automaton.runtime").register({
		name = "ripple",
		fps = fps,
		init = function(grid)
			local rows, cols = U.size(grid)
			snapshot, frame = U.snapshot(grid), 0
			local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
			cx = math.max(1, math.min(cols, vim.fn.wincol() - (info and info.textoff or 0)))
			cy = math.max(1, math.min(rows, vim.fn.winline()))
			radius = math.sqrt(math.max(cx - 1, cols - cx) ^ 2 + (2 * math.max(cy - 1, rows - cy)) ^ 2)
		end,
		cleanup = function(grid)
			if snapshot then
				U.restore(grid, snapshot)
			end
		end,
		update = function(grid)
			frame = frame + 1
			local time = frame / fps
			U.restore(grid, snapshot)
			if time > radius / speed + 1.1 then
				return false
			end
			for r, row in ipairs(grid) do
				for c, cell in ipairs(row) do
					if cell.char ~= "" then
						local distance = math.sqrt((c - cx) ^ 2 + ((r - cy) * 2) ^ 2)
						for wave = 0, 2 do
							local front = (time - wave * 0.4) * speed
							local offset = math.abs(distance - front)
							if front >= 0 and offset < 1.2 then
								U.plot(grid, c, r, offset < 0.5 and "~" or ".", wave == 0 and "Special" or "Comment")
							end
						end
					end
				end
			end
			return true
		end,
	})
end

return M
