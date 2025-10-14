-- Wisp Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton wisp
-- Behavior:
--   • Ethereal ball of light drifts across the screen
--   • Characters from text gather to form the wisp
--   • Wisp leaves a fading trail as it moves
--   • Bounces off edges with smooth motion
-- Parameters:
--   fps = 30         -- Frame rate
--   radius = 5       -- Size of the wisp ball
--   drift_speed = 1  -- Movement speed (cells per frame)
--   tail_length = 12 -- Number of fading trail frames

local M = {
  fps = 30,
  radius = 5,
  drift_speed = 1,
  tail_length = 12,              -- number of tail frames
  name = "wisp",
}

local frame = 0
local phase = "formation"
local center = { x = 1, y = 1 }
local ball_chars = {}
local dx, dy = 1, 1
local trail = {}

local function clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

M.init = function(grid)
  frame = 0
  phase = "formation"
  center.x = math.floor(#grid / 2)
  center.y = math.floor(#grid[1] / 2)
  ball_chars = {}
  trail = {}
  dx = 1
  dy = 1

  for i = 1, #grid do
    for j = 1, #grid[i] do
      local char = grid[i][j].char
      if char ~= " " then
        table.insert(ball_chars, { char = char, x = i, y = j })
        grid[i][j].char = " "
      end
    end
  end
end

M.update = function(grid)
  frame = frame + 1
  local height = #grid
  local width = #grid[1]
  local diameter = M.radius * 2 + 1

  -- Clear screen
  for i = 1, height do
    for j = 1, width do
      grid[i][j].char = " "
    end
  end

  if phase == "formation" then
    local all_at_center = true
    for _, c in ipairs(ball_chars) do
      if c.x < center.x then c.x = c.x + 1
      elseif c.x > center.x then c.x = c.x - 1 end

      if c.y < center.y then c.y = c.y + 1
      elseif c.y > center.y then c.y = c.y - 1 end

      if c.x ~= center.x or c.y ~= center.y then
        all_at_center = false
      end
    end

    for _, c in ipairs(ball_chars) do
      if c.x > 0 and c.x <= height and c.y > 0 and c.y <= width then
        grid[c.x][c.y].char = c.char
      end
    end

    if all_at_center then
      phase = "drift"
    end

  elseif phase == "drift" then
    -- Update trail
    table.insert(trail, 1, { x = center.x, y = center.y })
    if #trail > M.tail_length then
      table.remove(trail)
    end

    -- Bounce and move
    if center.x - M.radius <= 1 or center.x + M.radius >= height then dx = -dx end
    if center.y - M.radius <= 1 or center.y + M.radius >= width  then dy = -dy end

    center.x = center.x + dx
    center.y = center.y + dy

    -- Draw orb
    for _, c in ipairs(ball_chars) do
      local angle = math.random() * 2 * math.pi
      local r = math.random(0, M.radius)
      local x = math.floor(center.x + math.cos(angle) * r)
      local y = math.floor(center.y + math.sin(angle) * r)
      if x > 0 and x <= height and y > 0 and y <= width then
        grid[x][y].char = c.char
      end
    end

    -- Draw tail: wide to narrow over time
    local fade_chars = { "*", ".", "-", "·", " " }
    for i, pos in ipairs(trail) do
      local tchar = fade_chars[clamp(i, 1, #fade_chars)]
      local t_ratio = 1 - (i - 1) / M.tail_length
      local taper_radius = math.floor(diameter / 2 * t_ratio)

      for dxt = -taper_radius, taper_radius do
        for dyt = -taper_radius, taper_radius do
          local tx = pos.x + dxt
          local ty = pos.y + dyt
          if tx > 0 and tx <= height and ty > 0 and ty <= width then
            local dist2 = dxt * dxt + dyt * dyt
            if dist2 <= taper_radius * taper_radius then
              grid[tx][ty].char = tchar
            end
          end
        end
      end
    end
  end

  return true
end

function M.register()
  require("cellular-automaton").register_animation(M)
end

return M

