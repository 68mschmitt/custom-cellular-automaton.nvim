local U = require("custom-cellular-automaton.animations.snowtown.util")

-- Item registry:
-- Each item:
-- {
--   name = "snowman_cozy",
--   class = "anchored" | "floating",
--   stencil = { "line1", "line2", ... },
--   anchor = "bottom_center",  -- anchor point semantics
--   rules = {
--     margin_left = 2, margin_right = 2, margin_top = 1, margin_bottom = 1,
--     min_cols = 20,            -- optional minimum buffer width
--   },
--   max_instances = 2,          -- per scene
-- }

local R = {}

-- === Your chosen snowman (ASCII) ===
local snowman_cozy = {
  "   ___",
  "  |___|",
  "  (o.o)",
  "  ~===~",
  " (  o  )",
  " /(  o )\\",
  "(_______)",
}

R.catalog = {
  {
    name = "snowman_cozy",
    class = "anchored",
    stencil = snowman_cozy,
    anchor = "bottom_center",
    rules = { margin_left = 2, margin_right = 2, margin_bottom = 0, margin_top = 1, min_cols = 24 },
    max_instances = 3,
  },
  -- Add more items over time here without touching other files.
}

-- helpers
local function width_of(stencil)
  local w = 0
  for _, line in ipairs(stencil) do
    if #line > w then w = #line end
  end
  return w
end

local function height_of(stencil) return #stencil end

-- Compute anchor offsets (col-relative)
-- For "bottom_center": reference point is bottom row of stencil, centered.
function R.anchor_offset(stencil, anchor)
  local w = width_of(stencil)
  local h = height_of(stencil)
  if anchor == "bottom_center" then
    return math.floor((w - 1) / 2), h - 1  -- (dx_from_left, dy_from_top) to bottom-center
  end
  -- default
  return 0, h - 1
end

function R.dimensions(stencil) return width_of(stencil), height_of(stencil) end

return R
