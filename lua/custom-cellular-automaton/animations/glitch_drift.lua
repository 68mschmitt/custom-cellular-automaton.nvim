-- Glitch Drift Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton glitch_drift
-- Behavior:
--   • Characters randomly drift left or right
--   • Occasional flickering and character substitution
--   • Random teleportation jumps
--   • Creates a digital glitch/corruption effect
-- Parameters:
--   fps = 50                -- Frame rate
--   max_drift = 2           -- Maximum drift distance per update
--   flicker_chance = 0.1    -- Probability of character flickering
--   teleport_chance = 0.02  -- Probability of random teleportation

local M = {
  fps = 50,
  max_drift = 2,
  flicker_chance = 0.1,
  teleport_chance = 0.02,
  name = "glitch_drift",
}

local frame

local cell_empty = function(grid, x, y)
  return x > 0 and x <= #grid
    and y > 0 and y <= #grid[x]
    and grid[x][y].char == " "
end

M.init = function()
  frame = 0
end

M.update = function(grid)
  frame = frame + 1
  local was_state_updated = false

  for i = 1, #grid do
    for j = 1, #grid[i] do
      grid[i][j].processed = false
    end
  end

  for x = 1, #grid do
    for y = 1, #grid[x] do
      local cell = grid[x][y]

      if cell.processed or cell.char == " " then
        goto continue
      end

      cell.processed = true

      -- Random flicker into glitch characters
      if math.random() < M.flicker_chance then
        local glitch_chars = { "@", "#", "~", "%" }
        cell.char = glitch_chars[math.random(1, #glitch_chars)]
        was_state_updated = true
      end

      -- Random sideways teleport
      if math.random() < M.teleport_chance then
        local dx = math.random(-M.max_drift, M.max_drift)
        local dy = math.random(-1, 1)
        local tx, ty = x + dy, y + dx

        if cell_empty(grid, tx, ty) then
          grid[tx][ty].char = cell.char
          grid[tx][ty].processed = true
          grid[x][y].char = " "
          was_state_updated = true
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

