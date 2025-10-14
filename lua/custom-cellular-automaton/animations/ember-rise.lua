-- Ember Rise Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton ember
-- Behavior:
--   • Characters flicker and transform into embers (* or .)
--   • Embers rise upward through empty space
--   • New embers randomly ignite from static characters
--   • Creates a rising fire/ember effect from text
-- Parameters:
--   fps = 40               -- Frame rate
--   ignition_chance = 0.01 -- Probability of new ember spawning per character
--   flicker_chance = 0.15  -- Probability of ember flickering each frame
--   rise_rate = 1          -- Number of cells embers rise per frame

local M = {
  fps = 40,
  ignition_chance = 0.01,
  flicker_chance = 0.15,
  rise_rate = 1,
  name = "ember",
}

local frame

local cell_empty = function(grid, x, y)
  return x > 0 and x <= #grid
    and y > 0 and y <= #grid[x]
    and grid[x][y].char == " "
end

local swap_cells = function(grid, x1, y1, x2, y2)
  grid[x1][y1], grid[x2][y2] = grid[x2][y2], grid[x1][y1]
end

M.init = function()
  frame = 0
end

M.update = function(grid)
  frame = frame + 1
  local was_state_updated = false

  -- Reset process flags
  for i = 1, #grid do
    for j = 1, #grid[i] do
      grid[i][j].processed = false
    end
  end

  for x = #grid - 1, 1, -1 do
    for y = 1, #grid[x] do
      local cell = grid[x][y]

      if cell.processed or string.find(cell.hl_group or "", "comment") then
        goto continue
      end

      cell.processed = true

      -- Chance to flicker
      if math.random() < M.flicker_chance and cell.char ~= " " then
        cell.char = (math.random() < 0.5) and "*" or "."
        was_state_updated = true
      end

      -- Chance to ignite new embers from static chars
      if cell.char ~= " " and math.random() < M.ignition_chance then
        -- duplicate this cell upwards
        if cell_empty(grid, x - 1, y) then
          grid[x - 1][y].char = cell.char
          grid[x - 1][y].processed = true
          was_state_updated = true
        end
      end

      -- Try to rise upward if empty space
      for step = 1, M.rise_rate do
        if cell_empty(grid, x - step, y) then
          swap_cells(grid, x, y, x - step, y)
          was_state_updated = true
          break
        end
      end

      ::continue::
    end
  end

  return was_state_updated
end

function M.register()
  require("cellular-automaton").register_animation(M)
end

return M

