-- Horizontal Slide Right Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton safe_slide_right
-- Behavior:
--   • Each row rotates right by one character per frame
--   • Characters wrap around from right edge to left
--   • Creates a smooth horizontal scrolling effect
-- Parameters:
--   fps = 20  -- Frame rate for smooth scrolling

local config = {
  fps = 20,
  name = "safe_slide_right",
}

config.update = function(grid)
  for i = 1, #grid do
    local row = grid[i]
    if #row > 0 then
      local last = row[#row]
      for j = #row, 2, -1 do
        row[j] = row[j - 1]
      end
      row[1] = last
    end
  end

  return true
end

local M = {}

function M.register()
  require("cellular-automaton").register_animation(config)
end

return M
