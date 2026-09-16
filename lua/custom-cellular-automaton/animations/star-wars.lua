-- Perspective crawl of the current buffer. Usage: :CellularAutomaton star_wars
local U = require("custom-cellular-automaton.util")
local M = {}

function M.register()
	local state
	local fps = 30
	require("custom-cellular-automaton.runtime").register({
		name = "star_wars",
		fps = fps,
		init = function(grid)
			local rows, cols = U.size(grid)
			state = { frame = 0, rows = rows, cols = cols, lines = {}, stars = {} }
			for _, row in ipairs(grid) do
				local text = {}
				for _, cell in ipairs(row) do
					text[#text + 1] = cell.char
				end
				local line = table.concat(text):gsub("%s+$", "")
				state.lines[#state.lines + 1] = U.chars(line)
			end
			while #state.lines > 0 and #state.lines[#state.lines] == 0 do
				table.remove(state.lines)
			end
			for _ = 1, math.min(80, math.ceil(rows * cols / 90)) do
				state.stars[#state.stars + 1] = { x = math.random(cols), y = math.random(rows) }
			end
			vim.api.nvim_set_hl(0, "CACrawl", { default = true, fg = "#ffe66d", ctermfg = 221 })
			vim.api.nvim_set_hl(0, "CACrawlDim", { default = true, fg = "#887840", ctermfg = 101 })
		end,
		update = function(grid)
			state.frame = state.frame + 1
			local time = state.frame / fps
			U.clear(grid)
			for _, star in ipairs(state.stars) do
				U.plot(grid, star.x, star.y, ".", "Comment")
			end
			local visible = false
			-- Screen depth is reciprocal: lines slow and narrow toward the horizon.
			for i, chars in ipairs(state.lines) do
				local age = time - (i - 1) * 0.45
				if age < 7 then
					visible = true
				end
				if age >= 0 and age < 7 then
					local depth = 1 + age * 0.65
					local scale = 1 / depth
					local y = 1 + (state.rows - 1) * scale
					local width = 0
					for _, char in ipairs(chars) do
						width = width + U.width(char)
					end
					local x = (state.cols + 1 - width * scale) / 2
					local last = 0
					for _, char in ipairs(chars) do
						local col = math.floor(x + 0.5)
						if col > last and char ~= " " then
							U.plot(grid, col, y, char, age < 4 and "CACrawl" or "CACrawlDim")
							last = col + U.width(char) - 1
						end
						x = x + U.width(char) * scale
					end
				end
			end
			return visible or time < 2
		end,
	})
end

return M
