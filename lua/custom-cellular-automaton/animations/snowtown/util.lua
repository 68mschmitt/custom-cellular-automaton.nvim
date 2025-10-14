local U = {}

function U.clamp(v, a, b) return math.max(a, math.min(b, v)) end
function U.is_space(ch) return ch == " " or ch == "" or ch == nil end

function U.grid_size(grid) return #grid, #grid[1] end

function U.snapshot_grid(grid)
  local rows, cols = U.grid_size(grid)
  local snap = {}
  for r = 1, rows do
    snap[r] = {}
    for c = 1, cols do
      snap[r][c] = grid[r][c].char
    end
  end
  return snap
end

function U.clear_grid(grid)
  local rows, cols = U.grid_size(grid)
  for r = 1, rows do
    for c = 1, cols do
      grid[r][c].char = " "
    end
  end
end

-- Draw non-space chars from a stencil (array of strings) at (top,left)
-- Only draws over baseline spaces, so user text is preserved.
function U.blit_stencil_over_spaces(grid, baseline, stencil, top, left)
  local rows, cols = U.grid_size(grid)
  for r = 1, #stencil do
    local line = stencil[r]
    for i = 1, #line do
      local ch = line:sub(i, i)
      if not U.is_space(ch) then
        local rr, cc = top + r - 1, left + i - 1
        if rr >= 1 and rr <= rows and cc >= 1 and cc <= cols then
            -- Only respect baseline text; allow drawing over transient snow
            if U.is_space(baseline[rr][cc]) then
                grid[rr][cc].char = ch
            end
        end
      end
    end
  end
end

function U.randint(a, b)
  return a + math.random(b - a)
end

-- Simple wind oscillation
function U.wind(t, ampl, freq)
  return math.floor(math.sin(t * freq * 2 * math.pi) * ampl)
end

return U
