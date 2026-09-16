-- Usage: :CellularAutomaton slide_left_safe
local M = {}
function M.register()
	require("custom-cellular-automaton.slide").register("slide_left_safe", -1)
end
return M
