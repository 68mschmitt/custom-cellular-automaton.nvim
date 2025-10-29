-- Spin Wheel Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton spin_wheel
-- Behavior:
--   • Creates an animated carnival-style spin wheel
--   • Pie slices are labeled with visually selected lines
--   • Fixed arrow pointer shows the winning selection
--   • Smooth spinning with natural deceleration
--   • Wheel size scales with number of selections
-- 
-- Select text in visual mode before running to populate wheel labels

local rng = math.random

-- ===== Configuration =====
local FPS = 50
local INITIAL_SPEED = 0.10        -- radians per frame (faster initial spin)
local MIN_SPINS = 2                -- minimum full rotations before stopping
local DECEL_RATE = 0.992           -- deceleration factor per frame (closer to 1 = slower decel)
local MIN_SPEED = 0.001            -- when to stop spinning
local MAX_LABEL_LENGTH = 20        -- maximum characters per label
local MIN_RADIUS = 10              -- minimum wheel radius
local LABEL_PADDING = 4            -- extra space around labels in radius calculation

-- Characters for drawing
local SPOKE_CHAR = "|"           -- Simple line for spokes
local OUTER_CHAR = "o"           -- Simple circle for outer rim
local ARROW_CHAR = "<"           -- Simple arrow
local CENTER_CHAR = "+"          -- Simple center point

-- Colors for pie slices (cycle through these)
local COLORS = {
  "String", "Function", "Type", "Constant", "Identifier",
  "DiagnosticOk", "DiagnosticInfo", "DiagnosticHint",
}

-- ===== State =====
local state = {
  angle = 0,                    -- current rotation angle
  angular_velocity = 0,         -- current rotation speed
  labels = {},                  -- text labels for pie slices
  width = 0,
  height = 0,
  center_x = 0,
  center_y = 0,
  radius = 0,
  target_rotations = 0,
  total_rotations = 0,
}

-- ===== Helper Functions =====

local function get_visual_selection()
  local visual_lines = {}
  local start_line, end_line
  
  -- First, try to get from the stored global (set by :SpinWheel command)
  if vim.g.spin_wheel_selection then
    start_line = vim.g.spin_wheel_selection.start_line
    end_line = vim.g.spin_wheel_selection.end_line
    -- Clear it after use
    vim.g.spin_wheel_selection = nil
  else
    -- Fall back to visual marks
    local mark_start = vim.fn.getpos("'<")
    local mark_end = vim.fn.getpos("'>")
    start_line = mark_start[2]
    end_line = mark_end[2]
  end
  
  -- Get lines if we have valid range
  if start_line and end_line and start_line > 0 and end_line > 0 and start_line <= end_line then
    -- Get the buffer number (0 = current buffer)
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Get lines from buffer
    local success, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, start_line - 1, end_line, false)
    
    if success and lines then
      for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")  -- trim whitespace
        if trimmed and #trimmed > 0 then
          -- Enforce max label length
          if #trimmed > MAX_LABEL_LENGTH then
            trimmed = trimmed:sub(1, MAX_LABEL_LENGTH - 2) .. ".."
          end
          table.insert(visual_lines, trimmed)
        end
      end
    end
  end
  
  -- Fallback if no valid selection
  if #visual_lines == 0 then
    visual_lines = { "Option 1", "Option 2", "Option 3", "Option 4", "Option 5" }
  end
  
  return visual_lines
end

-- Calculate the longest label length
local function get_max_label_length(labels)
  local max_len = 0
  for _, label in ipairs(labels) do
    if #label > max_len then
      max_len = #label
    end
  end
  return max_len
end

local function set_cell(grid, x, y, ch, hl)
  local iy = math.floor(y + 0.5)
  local ix = math.floor(x + 0.5)
  if iy >= 1 and iy <= state.height and ix >= 1 and ix <= state.width then
    local cell = grid[iy][ix]
    cell.char = ch
    if hl then cell.hl_group = hl end
  end
end

local function clear_grid(grid)
  for i = 1, #grid do
    for j = 1, #(grid[i]) do
      grid[i][j].char = " "
    end
  end
end

-- Draw a line from (x1,y1) to (x2,y2)
local function draw_line(grid, x1, y1, x2, y2, ch, hl)
  local dx = x2 - x1
  local dy = y2 - y1
  local steps = math.max(math.abs(dx), math.abs(dy))
  
  if steps == 0 then
    set_cell(grid, x1, y1, ch, hl)
    return
  end
  
  for i = 0, steps do
    local t = i / steps
    local x = x1 + dx * t
    local y = y1 + dy * t
    set_cell(grid, x, y, ch, hl)
  end
end

-- Draw text at position
local function draw_text(grid, x, y, text, hl)
  for i = 1, #text do
    local ix = math.floor(x + i - 1 + 0.5)
    local iy = math.floor(y + 0.5)
    if iy >= 1 and iy <= state.height and ix >= 1 and ix <= state.width then
      local cell = grid[iy][ix]
      cell.char = text:sub(i, i)
      if hl then cell.hl_group = hl end
    end
  end
end

-- Draw the wheel with pie slices
local function draw_wheel(grid)
  local num_slices = #state.labels
  local slice_angle = (2 * math.pi) / num_slices
  
  -- Draw outer circle only
  local circle_steps = math.floor(2 * math.pi * state.radius)
  for i = 0, circle_steps do
    local a = (i / circle_steps) * 2 * math.pi
    local x = state.center_x + state.radius * math.cos(a)
    local y = state.center_y + state.radius * math.sin(a)
    set_cell(grid, x, y, OUTER_CHAR, nil)
  end
  
  -- Draw simple spokes for each slice
  for slice = 1, num_slices do
    local color = COLORS[((slice - 1) % #COLORS) + 1]
    local start_angle = state.angle + (slice - 1) * slice_angle
    
    -- Draw single radial spoke (simplified)
    local x_end = state.radius * math.cos(start_angle)
    local y_end = state.radius * math.sin(start_angle)
    draw_line(grid, state.center_x, state.center_y,
              state.center_x + x_end, state.center_y + y_end,
              SPOKE_CHAR, nil)
    
    -- Draw label at middle of slice
    local mid_angle = start_angle + slice_angle / 2
    local label_dist = state.radius * 0.65
    local label_x = state.center_x + label_dist * math.cos(mid_angle)
    local label_y = state.center_y + label_dist * math.sin(mid_angle)
    
    -- Get label (already truncated to MAX_LABEL_LENGTH)
    local label = state.labels[slice]
    
    -- Center the label at the position
    label_x = label_x - #label / 2
    draw_text(grid, label_x, label_y, label, color)  -- Only labels have color
  end
  
  -- Draw center point (no color)
  set_cell(grid, state.center_x, state.center_y, CENTER_CHAR, nil)
end

-- Draw the fixed arrow pointer
local function draw_arrow(grid)
  -- Arrow points to the right (3 o'clock position)
  local arrow_x = state.center_x + state.radius + 2
  local arrow_y = state.center_y
  
  -- Simple arrow: -->
  set_cell(grid, arrow_x, arrow_y, ARROW_CHAR, nil)
  set_cell(grid, arrow_x + 1, arrow_y, "-", nil)
  set_cell(grid, arrow_x + 2, arrow_y, "-", nil)
end

-- Determine which slice the arrow is pointing to
local function get_winning_slice()
  -- Arrow points to angle 0 (3 o'clock)
  -- Normalize angle to [0, 2*pi]
  local normalized_angle = state.angle % (2 * math.pi)
  if normalized_angle < 0 then
    normalized_angle = normalized_angle + 2 * math.pi
  end
  
  -- The slice at angle 0 relative to current rotation
  -- We need to account for rotation direction
  local slice_angle = (2 * math.pi) / #state.labels
  local slice_idx = math.floor((2 * math.pi - normalized_angle) / slice_angle) % #state.labels + 1
  
  return slice_idx
end

-- Show the result when wheel stops
local function draw_result(grid)
  local winner_idx = get_winning_slice()
  local winner = state.labels[winner_idx]
  
  -- Draw simple result banner at top
  local banner = ">>> WINNER: " .. winner .. " <<<"
  local banner_x = math.floor(state.width / 2 - #banner / 2)
  local banner_y = 2
  
  -- Just draw the text, no background
  draw_text(grid, banner_x, banner_y, banner, "ErrorMsg")
end

-- ===== Animation Configuration =====

local config = {
  name = "spin_wheel",
  fps = FPS,
  
  init = function(grid)
    state.width = #(grid[1] or {})
    state.height = #grid
    state.center_x = math.floor(state.width / 2)
    state.center_y = math.floor(state.height / 2)
    
    -- Get labels from visual selection (already limited to MAX_LABEL_LENGTH)
    state.labels = get_visual_selection()
    
    -- Calculate radius based on longest label
    -- The label sits at ~65% of radius, so we need radius * 0.65 >= label_length / 2
    -- Therefore: radius >= (label_length / 2) / 0.65
    local max_label_len = get_max_label_length(state.labels)
    local radius_for_label = math.ceil((max_label_len / 2) / 0.65) + LABEL_PADDING
    
    -- Ensure minimum radius and fit within screen
    state.radius = math.max(radius_for_label, MIN_RADIUS)
    state.radius = math.min(state.radius, math.floor(math.min(state.width, state.height) / 2) - 5)
    
    -- Set initial rotation parameters
    state.angle = rng() * 2 * math.pi  -- random starting angle
    state.angular_velocity = INITIAL_SPEED
    state.target_rotations = MIN_SPINS + rng() * 3  -- random extra spins
    state.total_rotations = 0
  end,
  
  update = function(grid)
    clear_grid(grid)
    
    -- Update rotation
    if state.angular_velocity > MIN_SPEED then
      state.angle = state.angle + state.angular_velocity
      state.total_rotations = state.total_rotations + state.angular_velocity / (2 * math.pi)
      
      -- Apply deceleration after minimum rotations
      if state.total_rotations >= state.target_rotations then
        state.angular_velocity = state.angular_velocity * DECEL_RATE
      end
    else
      -- Stopped - show result for a few frames
      state.angular_velocity = 0
    end
    
    -- Draw components
    draw_wheel(grid)
    draw_arrow(grid)
    
    -- Show result when stopped
    if state.angular_velocity == 0 then
      draw_result(grid)
    end
    
    return true
  end,
}

-- ===== Module Export =====

local M = {}

function M.register()
  require("cellular-automaton").register_animation(config)
end

return M
