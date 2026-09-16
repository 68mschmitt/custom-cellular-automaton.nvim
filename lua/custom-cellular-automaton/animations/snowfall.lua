-- Snow with lateral wind and melting accumulation; source text stays intact.
-- Usage: :CellularAutomaton snowfall
local U = require("custom-cellular-automaton.util")
local Snow = require("custom-cellular-automaton.animations.snowtown.snow")
local M = {}

function M.register()
	local frame, snapshot, snow
	require("custom-cellular-automaton.runtime").register({
		name = "snowfall",
		fps = 30,
		init = function(grid)
			frame, snapshot = 0, U.snapshot(grid)
			snow = Snow.new({ TTL_MIN = 120, TTL_MAX = 300 }):attach(grid)
		end,
		cleanup = function(grid)
			if snapshot then
				U.restore(grid, snapshot)
			end
		end,
		update = function(grid)
			frame = frame + 1
			U.restore(grid, snapshot)
			snow:tick(grid, nil, frame / 30)
			return true
		end,
	})
end

return M
