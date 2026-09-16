-- Bottom-up fire with scheduled ignition and a finite burnout.
-- Usage: :CellularAutomaton inferno (legacy alias: text_inferno)
local U = require("custom-cellular-automaton.util")
local M = {}

function M.register()
	local snapshot, frame, rows, cols
	local fps, burn_duration = 30, 1.8
	local glyphs = { "*", "^", "~", "'", "." }
	local colors = { "CAFireWhite", "CAFireYellow", "CAFireOrange", "CAFireRed", "Comment" }
	require("custom-cellular-automaton.runtime").register({
		name = "inferno",
		fps = fps,
		init = function(grid)
			snapshot, frame = U.snapshot(grid), 0
			rows, cols = U.size(grid)
			for i, color in ipairs({ "#fff4c2", "#ffd75f", "#ff9e40", "#d74b32" }) do
				vim.api.nvim_set_hl(0, colors[i], { default = true, fg = color, ctermfg = ({ 230, 221, 208, 160 })[i] })
			end
		end,
		update = function(grid)
			frame = frame + 1
			local time, pending = frame / fps, false
			for r, row in ipairs(grid) do
				for c, cell in ipairs(row) do
					if cell.char ~= "" then
						local ignition = (rows - r) / math.max(1, rows - 1) * 3
							+ math.abs(c - (cols + 1) / 2) / math.max(1, cols) * 0.6
						local age = time - ignition
						if age < 0 then
							U.plot(grid, c, r, snapshot[r][c].char, snapshot[r][c].hl_group)
							pending = true
						elseif age < burn_duration then
							local heat = math.min(5, 1 + math.floor(age / burn_duration * 5))
							local char = math.random() < age / burn_duration * 0.7 and " " or glyphs[heat]
							U.plot(grid, c, r, char, colors[heat])
							pending = true
						else
							U.plot(grid, c, r, " ", nil)
						end
					end
				end
			end
			return pending
		end,
	})
end

return M
