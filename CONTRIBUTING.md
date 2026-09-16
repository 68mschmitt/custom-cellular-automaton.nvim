# Contributing to custom-cellular-automaton.nvim

Thank you for your interest in contributing! This guide will help you add new custom animations to the plugin.

## Table of Contents

- [Animation Architecture](#animation-architecture)
- [Creating a New Animation](#creating-a-new-animation)
- [Animation Module Pattern](#animation-module-pattern)
- [Testing Your Animation](#testing-your-animation)
- [Submitting Your Contribution](#submitting-your-contribution)

## Animation Architecture

Each animation in this plugin follows a standardized module pattern that:
1. Exports a `register()` function
2. Configures FPS, name, and animation behavior
3. Registers with `cellular-automaton.nvim`

### Directory Structure

```
lua/custom-cellular-automaton/animations/
├── your-animation.lua          # Simple single-file animation
└── complex-animation/          # Multi-file animation (if needed)
    ├── init.lua
    ├── animation.lua
    └── helpers.lua
```

## Creating a New Animation

### Step 1: Create Your Animation File

Create a new file in `lua/custom-cellular-automaton/animations/` with a descriptive name:

```bash
touch lua/custom-cellular-automaton/animations/my-animation.lua
```

### Step 2: Follow the Module Pattern

Here's the basic template for a new animation:

```lua
-- My Animation for cellular-automaton.nvim
-- Usage: :CellularAutomaton my_animation
-- Behavior:
--   • Brief description of what your animation does
--   • Key visual effects
--   • Any special features
-- Parameters:
--   fps = 30  -- Frame rate (adjust for smoothness vs performance)

local M = {}

function M.register()
  local runtime = require("custom-cellular-automaton.runtime")
  
  local config = {
    fps = 30,
    name = "my_animation",  -- Command name users will invoke
    
    init = function(grid)
      -- Initialize your animation state here
      -- grid is a 2D array of cells: grid[row][col].char
      -- Save initial state if needed
      -- Use math.random() without reseeding Neovim's shared generator.
    end,
    
    update = function(grid)
      -- Update the animation frame
      -- Modify grid[row][col].char to change displayed characters
      
      -- Return true to continue animation
      -- Return false to stop animation
      return true
    end
  }
  
  runtime.register(config)
end

return M
```

## Animation Module Pattern

### Grid Structure

The `grid` parameter is a 2D array where:
- `grid[row][col].char` = character to display (string)
- `grid[row][col].hl_group` = optional highlight group (string)
- Rows and columns are 1-indexed display cells (Lua convention)
- Wide glyphs have an empty-string continuation cell. Keep glyph strings intact.
- The shared runtime pads uneven rows and handles empty grids before invoking animations.
- Use `custom-cellular-automaton.util` for bounds-safe drawing, snapshots, and Unicode-aware text.
- The runtime converts display cells to byte cells for the dependency renderer and preserves fixed-step timing under FPS overrides.

### Common Helper Functions

Here are some useful patterns:

```lua
-- Get grid dimensions
local rows, cols = require("custom-cellular-automaton.util").size(grid)

-- Check if a cell is empty
local function is_empty(grid, r, c)
  return grid[r] and grid[r][c] and grid[r][c].char == " "
end

-- Use util.plot for drawing so wide glyphs are replaced atomically.
local U = require("custom-cellular-automaton.util")
U.plot(grid, c, r, char, hl_group)

-- Clamp value to range
local function clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

-- Snapshot grid for baseline reference
local function snapshot_grid(grid)
  local snap = {}
  for r = 1, #grid do
    snap[r] = {}
    for c = 1, #grid[r] do
      snap[r][c] = grid[r][c].char
    end
  end
  return snap
end
```

### Animation State

Store persistent state outside the config table:

```lua
local state = {
  frame = 0,
  particles = {},
  baseline = nil
}

-- Reset in init
config.init = function(grid)
  state.frame = 0
  state.particles = {}
  state.baseline = snapshot_grid(grid)
end
```

### Performance Tips

1. **FPS**: Higher FPS = smoother but more CPU intensive
   - Simple effects: 20-30 FPS
   - Complex calculations: 15-20 FPS
   - High-speed motion: 40-60 FPS

2. **Early Returns**: Stop updating when animation is complete
   ```lua
   if all_particles_gone then
     return false  -- Stop animation
   end
   ```

3. **Dirty Checking**: Only update cells that changed
   ```lua
   if state.changed_cells[key] then
     grid[r][c].char = new_char
   end
   ```

## Testing Your Animation

### 1. Add to Plugin Registration

Edit `lua/custom-cellular-automaton/init.lua` and add your animation name to the `animations` table:

```lua
local animations = {
  -- ... existing animations ...
  "my-animation",
}
```

### 2. Test Locally

Reload your Neovim config and test:

```vim
:CellularAutomaton my_animation
```

### 3. Test Edge Cases

Run the regression suite from the repository root:

```sh
nvim --headless -u NONE -l tests/run.lua
luacheck lua plugin --no-color
```

- Empty buffers
- Very small buffers (< 10 lines)
- Very large buffers (> 1000 lines)
- Buffers with special characters
- Different terminal sizes

## Complex Multi-File Animations

For animations requiring multiple files (like `snowtown`):

### Directory Structure
```
lua/custom-cellular-automaton/animations/my-complex-animation/
├── init.lua          # Entry point with register()
├── animation.lua     # Main animation logic
├── helpers.lua       # Utility functions
└── particles.lua     # Particle system
```

### init.lua Pattern
```lua
local M = {}

function M.register()
  require("custom-cellular-automaton.animations.my-complex-animation.animation").register()
end

return M
```

### Module Paths
Use full module paths for internal requires:
```lua
local helpers = require("custom-cellular-automaton.animations.my-complex-animation.helpers")
```

## Submitting Your Contribution

### Before Submitting

- [ ] Add documentation header to your animation file
- [ ] Test animation in various buffer sizes
- [ ] Run `nvim --headless -u NONE -l tests/run.lua`
- [ ] Run `luacheck lua plugin --no-color`
- [ ] Verify no syntax errors with `:checkhealth`
- [ ] Add animation name to `init.lua` registration list
- [ ] Update README.md animation showcase (if applicable)

### Pull Request Guidelines

1. **Title**: Clear description of the animation
   - Good: "Add spiral vortex animation"
   - Bad: "New animation"

2. **Description**: Include:
   - What the animation does
   - Visual effect description
   - Any special requirements
   - Screenshot/GIF if possible

3. **Code Quality**:
   - Follow existing code style
   - Include inline comments for complex logic
   - Use meaningful variable names
   - Keep functions focused and small

### Example Animations to Study

- **Simple**: `slide-left.lua` - Basic row rotation
- **Medium**: `ember-rise.lua` - Particle movement with spawning
- **Complex**: `blackhole.lua` - Physics simulation with state tracking
- **Advanced**: `snowtown/` - Multi-file with multiple systems

## Questions?

Feel free to:
- Open an issue for questions
- Look at existing animations for examples
- Check the [cellular-automaton.nvim](https://github.com/Eandrju/cellular-automaton.nvim) docs for API details

Happy animating! 🎨
