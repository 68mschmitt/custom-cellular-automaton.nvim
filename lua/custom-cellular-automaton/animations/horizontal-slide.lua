-- Usage: :CellularAutomaton safe_slide_right
local M = {}
function M.register()
	require("custom-cellular-automaton.slide").register("safe_slide_right", 1)
end
return M
