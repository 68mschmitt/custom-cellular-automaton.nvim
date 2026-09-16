-- Green digital rain with stable trails and white-hot heads.
-- Usage: :CellularAutomaton matrix (legacy alias: matrix_rain_soft)
local U = require("custom-cellular-automaton.util")
local M = {}

function M.register()
	local drops, cooldown, rows, cols
	local pool = { "0", "1", ":", "+", "|" }
	local function glyph()
		return pool[math.random(#pool)]
	end
	require("custom-cellular-automaton.runtime").register({
		name = "matrix",
		fps = 24,
		init = function(grid)
			rows, cols = U.size(grid)
			drops, cooldown = {}, {}
			for c = 1, cols do
				cooldown[c] = 0
			end
			for name, spec in pairs({
				Head = { "#e0ffe0", 194 },
				Bright = { "#63ff87", 83 },
				Green = { "#22b855", 35 },
				Dim = { "#175a32", 22 },
			}) do
				vim.api.nvim_set_hl(0, "CAMatrix" .. name, { default = true, fg = spec[1], ctermfg = spec[2] })
			end
		end,
		update = function(grid)
			U.clear(grid)
			for c = 1, cols do
				cooldown[c] = math.max(0, cooldown[c] - 1)
				if cooldown[c] == 0 and math.random() < 0.035 then
					local length = math.random(math.max(2, math.floor(rows * 0.1)), math.max(3, math.floor(rows * 0.4)))
					drops[#drops + 1] = {
						col = c,
						head = 0,
						speed = 0.25 + math.random() * 0.45,
						length = length,
						chars = {},
					}
					cooldown[c] = math.ceil((rows + length) / drops[#drops].speed)
				end
			end
			local alive = {}
			for _, drop in ipairs(drops) do
				drop.head = drop.head + drop.speed
				local head = math.floor(drop.head)
				for r = math.max(1, head - drop.length), math.min(rows, head) do
					if not drop.chars[r] or math.random() < 0.015 then
						drop.chars[r] = glyph()
					end
					local age = (head - r) / drop.length
					local color = r == head and "Head" or (age < 0.25 and "Bright" or (age < 0.7 and "Green" or "Dim"))
					U.plot(grid, drop.col, r, drop.chars[r], "CAMatrix" .. color)
				end
				if head - drop.length <= rows then
					alive[#alive + 1] = drop
				end
			end
			drops = alive
			return true
		end,
	})
end

return M
