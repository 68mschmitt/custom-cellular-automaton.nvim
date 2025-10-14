local U = require("custom-cellular-automaton.animations.snowtown.util")
local Items = require("custom-cellular-automaton.animations.snowtown.items")

local P = {}

-- Check if stencil can be placed at (top,left) respecting baseline (no overwrite of baseline text)
local function can_place_over_spaces(grid, baseline, stencil, top, left)
  local rows, cols = U.grid_size(grid)
  for r = 1, #stencil do
    local line = stencil[r]
    for i = 1, #line do
      local ch = line:sub(i, i)
      if not U.is_space(ch) then
        local rr, cc = top + r - 1, left + i - 1
        if rr < 1 or rr > rows or cc < 1 or cc > cols then return false end
        if not U.is_space(baseline[rr][cc]) then return false end
      end
    end
  end
  return true
end

-- For anchored items: require support under the anchor cell
local function has_support(baseline, grid, rr, cc, rows)
  if rr == rows then return true end -- bottom of buffer
  -- support if baseline at (rr+1,cc) is non-space OR an anchored object already drew there
  local below_base = baseline[rr + 1][cc]
  if not U.is_space(below_base) then return true end
  local below_cur = grid[rr + 1][cc].char
  return not U.is_space(below_cur)
end

-- Try place an anchored item by scanning potential x positions near ground
function P.place_anchored(grid, baseline, item, occupancy)
  local rows, cols = U.grid_size(grid)
  if item.rules.min_cols and cols < item.rules.min_cols then return false end

  local w, h = Items.dimensions(item.stencil)
  local dx_anchor, dy_anchor = Items.anchor_offset(item.stencil, item.anchor)

  local left_margin  = item.rules.margin_left or 0
  local right_margin = item.rules.margin_right or 0
  local top_margin   = item.rules.margin_top or 0

  local top = rows - h - (item.rules.margin_bottom or 0)
  top = math.max(1 + top_margin, top)

  -- Try a handful of random x slots to reduce scan cost
  local tries = math.max(10, math.floor(cols / math.max(1, w)))
  for _ = 1, tries do
    local left = U.randint(1 + left_margin, math.max(1 + left_margin, cols - w - right_margin + 1))
    local anchor_r = top + dy_anchor
    local anchor_c = left + dx_anchor

    if anchor_r >= 1 and anchor_r <= rows and anchor_c >= 1 and anchor_c <= cols then
      if has_support(baseline, grid, anchor_r, anchor_c, rows) then
        if can_place_over_spaces(grid, baseline, item.stencil, top, left) then
          -- mark occupancy (rough)
          table.insert(occupancy, { top = top, left = left, w = w, h = h, name = item.name, class = "anchored" })
          -- draw immediately
          U.blit_stencil_over_spaces(grid, baseline, item.stencil, top, left)
          return true
        end
      end
    end
  end
  return false
end

-- Floating placement (no movement yet): place where baseline and current are empty
function P.place_floating(grid, baseline, item, occupancy)
  local rows, cols = U.grid_size(grid)
  local w, h = Items.dimensions(item.stencil)
  local left_margin  = (item.rules.margin_left or 0)
  local right_margin = (item.rules.margin_right or 0)
  local top_margin   = (item.rules.margin_top or 1)
  local bottom_margin= (item.rules.margin_bottom or 1)

  local min_left = 1 + left_margin
  local max_left = math.max(min_left, cols - w - right_margin + 1)
  local min_top  = 1 + top_margin
  local max_top  = math.max(min_top, rows - h - bottom_margin + 1)

  local tries = 20
  for _=1, tries do
    local left = U.randint(min_left, max_left)
    local top  = U.randint(min_top,  max_top)
    if can_place_over_spaces(grid, baseline, item.stencil, top, left) then
      table.insert(occupancy, { top = top, left = left, w = w, h = h, name = item.name, class = "floating" })
      U.blit_stencil_over_spaces(grid, baseline, item.stencil, top, left)
      return true
    end
  end
  return false
end

return P
