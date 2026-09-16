-- Updraft Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton updraft
-- Behavior:
--   • Characters rise upward in a thermal updraft
--   • Optional side-to-side noise adds drift effect
--   • Characters move through empty space only
--   • Creates a hot air/wind rising effect
-- Parameters:
--   fps = 50         -- High frame rate for smooth motion
--   side_noise = true -- Enable horizontal drift while rising
--   lift_rate = 2    -- Number of cells to rise per frame

local U = require("custom-cellular-automaton.util")
local M = {
	fps = 50,
	side_noise = true,
	lift_rate = 2,
	name = "updraft",
}

local frame, snapshot

local cell_empty = function(grid, x, y)
	if x > 0 and x <= #grid and y > 0 and y <= #grid[x] and grid[x][y].char == " " then
		return true
	end
	return false
end

local swap_cells = function(grid, x1, y1, x2, y2)
	grid[x1][y1], grid[x2][y2] = grid[x2][y2], grid[x1][y1]
end

M.init = function(grid)
	frame = 1
	snapshot = U.snapshot(grid)
end

M.cleanup = function(grid)
	if snapshot then
		U.restore(grid, snapshot)
	end
end

M.update = function(grid)
	frame = frame + 1

	for i = 1, #grid do
		for j = 1, #grid[i] do
			grid[i][j].processed = false
		end
	end

	local was_state_updated = false

	for x0 = 2, #grid do -- scan from top down
		for i = 1, #grid[x0] do
			local y0 = ((frame + x0) % 2 == 0) and i or (#grid[x0] + 1 - i)
			local cell = grid[x0][y0]

			if
				cell.char == " "
				or cell.char == ""
				or U.width(cell.char) > 1
				or string.find(cell.hl_group or "", "comment")
				or cell.processed
			then
				goto continue
			end

			cell.processed = true

			-- horizontal flutter (wind)
			if M.side_noise then
				local random = math.random()
				if random < 0.03 and cell_empty(grid, x0, y0 + 1) then
					swap_cells(grid, x0, y0, x0, y0 + 1)
					was_state_updated = true
					goto continue
				elseif random < 0.06 and cell_empty(grid, x0, y0 - 1) then
					swap_cells(grid, x0, y0, x0, y0 - 1)
					was_state_updated = true
					goto continue
				end
			end

			-- lift the character upward if possible
			local current_x = x0
			for _ = 1, M.lift_rate do
				local x_target = current_x - 1
				if x_target < 1 then
					break
				end

				if cell_empty(grid, x_target, y0) then
					swap_cells(grid, current_x, y0, x_target, y0)
					current_x = x_target
					was_state_updated = true
				else
					break
				end
			end

			::continue::
		end
	end

	return was_state_updated
end

function M.register()
	require("custom-cellular-automaton.runtime").register(M)
end

return M
