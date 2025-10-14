-- Inferno Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton text_inferno
-- Behavior:
--   • Fire rises from bottom to top, consuming text row by row
--   • Each row flickers through flame characters (*, ~, ., `, space)
--   • Rows burn out after a duration, leaving empty space
--   • Creates an intense rising flame effect
-- Parameters:
--   fps = 30            -- Frame rate
--   burn_duration = 10  -- Seconds each row burns before fading

local M = {
  fps = 30,
  burn_duration = 10, -- seconds
  name = "text_inferno",
}

local frame = 0
local ignition_frame = {} -- ignition_frame[row] = frame when it starts burning
local flicker_chars = { "*", "~", ".", "`", " " }
local total_rows = 0

M.init = function(grid)
  frame = 0
  ignition_frame = {}
  total_rows = #grid
  local middle = math.floor(total_rows / 2)
  local rows = {}

  -- Collect burn order (center outward)
  for i = 0, total_rows do
    if grid[middle - i] then table.insert(rows, middle - i) end
    if i ~= 0 and grid[middle + i] then table.insert(rows, middle + i) end
  end

  local interval = math.floor((M.fps * M.burn_duration) / #rows)

  for i, row in ipairs(rows) do
    ignition_frame[row] = (i - 1) * interval
  end
end

M.update = function(grid)
  frame = frame + 1
  local changed = false

  local width = #grid[1]
  local center_col = math.floor(width / 2)

  for row = 1, #grid do
    local start_frame = ignition_frame[row]
    if not start_frame or frame < start_frame then goto continue end

    local burn_progress = frame - start_frame
    local spread = math.floor(burn_progress / 2)

    for dx = -spread, spread do
      local col = center_col + dx
      if col >= 1 and col <= width then
        local cell = grid[row][col]
        if cell.char ~= " " then
          local phase = math.random()
          if phase < 0.4 then
            cell.char = flicker_chars[math.random(1, 3)]
          elseif phase < 0.9 then
            cell.char = flicker_chars[4]
          else
            cell.char = " "
          end
          changed = true
        end
      end
    end

    ::continue::
  end

  return changed
end

function M.register()
  require("cellular-automaton").register_animation(M)
end

return M

