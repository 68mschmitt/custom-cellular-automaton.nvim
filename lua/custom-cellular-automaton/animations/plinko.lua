-- Plinko Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton plinko
-- Behavior:
--   • Creates a full-screen Plinko/Galton board
--   • Balls drop from the top and bounce off pegs randomly
--   • Visually selected lines become bucket labels at the bottom
--   • Balls accumulate in buckets with a natural distribution
--   • Winner is the bucket with the most balls
--
-- Select text in visual mode before running to populate bucket labels

local rng = math.random

-- ===== Configuration =====
local FPS = 30
local MAX_LABEL_LENGTH = 20
local BALLS_PER_LABEL = 5
local SPAWN_INTERVAL_MIN = 8
local SPAWN_INTERVAL_MAX = 12
local PEG_HORIZ_SPACING = 4
local PEG_VERT_SPACING = 2

-- Characters for drawing
local BALL_CHAR = "O"
local PEG_CHAR = "."
local WALL_CHAR = "|"

-- Colors for buckets (cycle through these)
local COLORS = {
  "String", "Function", "Type", "Constant", "Identifier",
  "DiagnosticOk", "DiagnosticInfo", "DiagnosticHint",
}

-- ===== State =====
local state = {
  labels = {},
  width = 0,
  height = 0,
  balls = {},
  bucket_counts = {},
  peg_field_start = 0,
  peg_field_end = 0,
  bucket_start = 0,
  bucket_width = 0,
  num_labels = 0,
  total_balls = 0,
  balls_spawned = 0,
  balls_settled = 0,
  spawn_timer = 0,
  next_spawn_interval = 0,
  frame = 0,
  finished = false,
  winner_label = nil,
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
        local trimmed = line:match("^%s*(.-)%s*$") -- trim whitespace
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

-- Check whether a row is a peg row in the field
local function is_peg_row(row)
  if row < state.peg_field_start or row > state.peg_field_end then
    return false
  end
  return (row - state.peg_field_start) % PEG_VERT_SPACING == 0
end

-- Determine which bucket a given x position falls into
local function get_bucket_for_x(x)
  local idx = math.floor((x - 1) / state.bucket_width) + 1
  return math.max(1, math.min(idx, state.num_labels))
end

-- Get the center x column of a bucket
local function get_bucket_center_x(bucket_idx)
  local left = (bucket_idx - 1) * state.bucket_width + 1
  return left + math.floor(state.bucket_width / 2)
end

-- Get the highlight group for a bucket (cycles through COLORS)
local function get_bucket_color(bucket_idx)
  return COLORS[((bucket_idx - 1) % #COLORS) + 1]
end

-- ===== Ball Management =====

-- Spawn a new ball at a random x position along the top
local function spawn_ball()
  local min_x = math.floor(state.width * 0.15) + 1
  local max_x = math.floor(state.width * 0.85)
  if min_x > max_x then
    min_x = 1
    max_x = state.width
  end
  local x = rng(min_x, max_x)

  table.insert(state.balls, {
    x = x,
    y = 1,
    phase = "falling", -- "falling" | "settling" | "settled"
    bucket_idx = nil,
    target_y = nil,
  })
  state.balls_spawned = state.balls_spawned + 1
  state.next_spawn_interval = rng(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
  state.spawn_timer = 0
end

-- Advance all balls by one frame
local function update_balls()
  for _, ball in ipairs(state.balls) do
    if ball.phase == "falling" then
      -- Move down one row per frame
      ball.y = ball.y + 1

      -- Deflect at peg rows (50/50 left or right by one column)
      if is_peg_row(ball.y) then
        if rng(1, 2) == 1 then
          ball.x = ball.x - 1
        else
          ball.x = ball.x + 1
        end
        -- Keep within screen bounds
        ball.x = math.max(1, math.min(ball.x, state.width))
      end

      -- Transition to settling when reaching bucket zone
      if ball.y >= state.bucket_start then
        ball.phase = "settling"
        ball.bucket_idx = get_bucket_for_x(ball.x)
        -- Reserve a stack slot immediately to prevent overlaps
        state.bucket_counts[ball.bucket_idx] = state.bucket_counts[ball.bucket_idx] + 1
        ball.x = get_bucket_center_x(ball.bucket_idx)
        local stack_pos = state.bucket_counts[ball.bucket_idx] - 1
        ball.target_y = state.height - 1 - stack_pos
        -- Clamp so balls don't overflow above the bucket zone
        if ball.target_y < state.bucket_start then
          ball.target_y = state.bucket_start
        end
        -- If already at or past the target, settle immediately
        if ball.y >= ball.target_y then
          ball.y = ball.target_y
          ball.phase = "settled"
          state.balls_settled = state.balls_settled + 1
        end
      end

    elseif ball.phase == "settling" then
      -- Continue falling toward the stack position inside the bucket
      ball.y = ball.y + 1
      if ball.y >= ball.target_y then
        ball.y = ball.target_y
        ball.phase = "settled"
        state.balls_settled = state.balls_settled + 1
      end
    end
    -- "settled" balls don't move
  end
end

-- ===== Drawing =====

-- Draw the staggered peg field
local function draw_pegs(grid)
  local row_idx = 0
  for row = state.peg_field_start, state.peg_field_end, PEG_VERT_SPACING do
    local offset = (row_idx % 2 == 0) and 0 or math.floor(PEG_HORIZ_SPACING / 2)
    for col = 2 + offset, state.width - 1, PEG_HORIZ_SPACING do
      set_cell(grid, col, row, PEG_CHAR, "Normal")
    end
    row_idx = row_idx + 1
  end
end

-- Draw bucket walls and labels along the bottom
local function draw_buckets(grid)
  for i = 1, state.num_labels do
    local color = get_bucket_color(i)
    local left = (i - 1) * state.bucket_width + 1

    -- Draw left wall
    for row = state.bucket_start, state.height do
      set_cell(grid, left, row, WALL_CHAR, color)
    end

    -- Draw right wall on the last bucket
    if i == state.num_labels then
      local right = math.min(i * state.bucket_width + 1, state.width)
      for row = state.bucket_start, state.height do
        set_cell(grid, right, row, WALL_CHAR, color)
      end
    end

    -- Draw label centered at the very bottom row
    local label = state.labels[i]
    local max_display = state.bucket_width - 2
    if max_display < 1 then
      max_display = 1
    end
    if #label > max_display then
      if max_display > 2 then
        label = label:sub(1, max_display - 2) .. ".."
      else
        label = label:sub(1, max_display)
      end
    end
    local label_x = left + 1 + math.floor((state.bucket_width - 2 - #label) / 2)
    draw_text(grid, label_x, state.height, label, color)
  end
end

-- Draw all balls (in-flight and settled)
local function draw_balls(grid)
  for _, ball in ipairs(state.balls) do
    if ball.phase == "falling" then
      set_cell(grid, ball.x, ball.y, BALL_CHAR, "WarningMsg")
    elseif ball.phase == "settling" then
      set_cell(grid, ball.x, ball.y, BALL_CHAR, get_bucket_color(ball.bucket_idx))
    elseif ball.phase == "settled" then
      set_cell(grid, ball.x, ball.y, BALL_CHAR, get_bucket_color(ball.bucket_idx))
    end
  end
end

-- Show the winner banner once all balls have settled
local function draw_result(grid)
  -- Determine winner once and cache it
  if not state.winner_label then
    local max_count = 0
    local winners = {}
    for i = 1, state.num_labels do
      if state.bucket_counts[i] > max_count then
        max_count = state.bucket_counts[i]
        winners = { i }
      elseif state.bucket_counts[i] == max_count then
        table.insert(winners, i)
      end
    end
    -- Break ties randomly
    local winner_idx = winners[rng(1, #winners)]
    state.winner_label = state.labels[winner_idx]
  end

  local banner = ">>> WINNER: " .. state.winner_label .. " <<<"
  local banner_x = math.floor(state.width / 2 - #banner / 2)
  local banner_y = 2

  draw_text(grid, banner_x, banner_y, banner, "ErrorMsg")
end

-- ===== Animation Configuration =====

local config = {
  name = "plinko",
  fps = FPS,

  init = function(grid)
    state.width = #(grid[1] or {})
    state.height = #grid

    -- Get labels from visual selection (already limited to MAX_LABEL_LENGTH)
    state.labels = get_visual_selection()
    state.num_labels = #state.labels

    -- Layout: drop zone rows 1-2, pegs 3..~80%, buckets ~80%..bottom
    state.peg_field_start = 3
    state.peg_field_end = math.floor(state.height * 0.80)
    state.bucket_start = state.peg_field_end + 1
    state.bucket_width = math.floor(state.width / state.num_labels)
    -- Ensure at least 3-wide buckets (wall + 1 char + wall)
    if state.bucket_width < 3 then
      state.bucket_width = 3
    end

    -- Reset ball state
    state.balls = {}
    state.bucket_counts = {}
    for i = 1, state.num_labels do
      state.bucket_counts[i] = 0
    end

    state.total_balls = state.num_labels * BALLS_PER_LABEL
    state.balls_spawned = 0
    state.balls_settled = 0
    state.spawn_timer = 0
    state.next_spawn_interval = rng(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
    state.frame = 0
    state.finished = false
    state.winner_label = nil

    -- Spawn the first ball immediately
    spawn_ball()
  end,

  update = function(grid)
    clear_grid(grid)
    state.frame = state.frame + 1

    -- Stagger ball spawns over time
    if state.balls_spawned < state.total_balls then
      state.spawn_timer = state.spawn_timer + 1
      if state.spawn_timer >= state.next_spawn_interval then
        spawn_ball()
      end
    end

    -- Advance physics
    update_balls()

    -- Render layers: pegs first, then buckets, then balls on top
    draw_pegs(grid)
    draw_buckets(grid)
    draw_balls(grid)

    -- Check end condition: all balls settled
    if state.balls_settled >= state.total_balls and not state.finished then
      state.finished = true
    end

    if state.finished then
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
