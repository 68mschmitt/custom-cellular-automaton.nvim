# custom-cellular-automaton.nvim

A collection of 19 custom cellular automaton animations for Neovim, built on top of [eandrju/cellular-automaton.nvim](https://github.com/Eandrju/cellular-automaton.nvim).

## Features

- 🎨 **19 Unique Animations** - From black holes to snowfall, matrix effects to fireworks
- 🔧 **Easy Configuration** - Enable/disable specific animations with simple setup
- 🚀 **Auto-registration** - All animations load automatically on plugin initialization
- 🎯 **Modular Design** - Each animation is self-contained and follows consistent patterns
- ❄️ **Complex Animations** - Includes advanced multi-file animations like Snowtown

## Requirements

- Neovim >= 0.9.0
- [cellular-automaton.nvim](https://github.com/Eandrju/cellular-automaton.nvim)

> **Note:** This plugin currently uses a forked version of `cellular-automaton.nvim` as a dependency to address an issue. A [pull request](https://github.com/Eandrju/cellular-automaton.nvim/pull/38) has been submitted to fix this in the upstream repository, but it has not yet been merged.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  '68mschmitt/custom-cellular-automaton.nvim',
  dependencies = { '68mschmitt/cellular-automaton.nvim' },
  lazy = false,
  config = function()
    require('custom-cellular-automaton').setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  '68mschmitt/custom-cellular-automaton.nvim',
  requires = { '68mschmitt/cellular-automaton.nvim' },
  config = function()
    require('custom-cellular-automaton').setup()
  end
}
```

## Animations Showcase

### 1. **Blackhole** (`blackhole_breakaway`)
Text characters detach individually and spiral into a growing black hole. A Big Bang finale forms a rotating galaxy fitted to the viewport, which keeps slowly turning forever -- close the window to end it.

### 2. **Ember Rise** (`ember`)
Characters flicker and rise upward like glowing embers from a fire.

### 3. **Fireworks** (`fireworks`)
Colorful rockets leave trails and burst into falling sparks. A twelve-second show builds to a finale, then lets the last sparks fade.

### 4. **Glitch Drift** (`glitch_drift`)
Characters drift in opposing scanlines, temporarily glitch and teleport, then recover their original text and highlights.

### 5. **Horizontal Slide** (`safe_slide_right`)
All text rows rotate horizontally to the right in a smooth loop.

### 6. **Inferno** (`inferno`)
Intense rising flames consume the text from bottom to top.

### 7. **Matrix** (`matrix`)
Classic Matrix-style digital rain effect with cascading green characters.

### 8. **Ripple** (`ripple`)
Expanding circular ripples emanate from the center, distorting text.

### 9. **Runner** (`runner`)
An animated ASCII runner character navigates around your text without overwriting it.

### 10. **Slide Left** (`slide_left_safe`)
All text rows rotate horizontally to the left in a smooth loop.

### 11. **Snowfall** (`snowfall`)
Gentle snowflakes fall down the screen with wind drift effects.

### 12. **Snowtown** (`snowtown`)
Winter scene with melting snow, snowmen, pine trees, cabins, and a moving sleigh. Text and object glyphs stay intact beneath the snowfall.

### 13. **Star Wars** (`star_wars`)
Text scrolls upward and away like the iconic Star Wars opening crawl.

### 14. **Updraft** (`updraft`)
Characters rise upward in a thermal updraft effect.

### 15. **Wisp** (`wisp`)
Text gathers into a softly drifting orb with a fading trail, then returns to its original positions and highlights.

### 16. **Spin Wheel** (`spin_wheel`)
An animated selection wheel with a fixed pointer and smooth deceleration. The wheel fits the viewport and switches to a compact selector in small splits. Full Unicode labels are retained; the winner is shown on screen and in a notification. Select lines before running to populate the wheel.

### 17. **Plinko** (`plinko`)
A Plinko board where balls collide with visible pegs and accumulate in labeled buckets with numeric totals. Large selections use automatically cycling pages, keeping every candidate reachable. The final view shows the winner's page, and a notification includes the full label.

### 18. **Supernova** (`supernova`)
Every character collapses inward toward a single point, heating from dim to white-hot as it implodes. The core flashes, then detonates outward as cooling debris while expanding shockwave rings sweep the screen, settling into cinders that glow faintly in place. Gravity then pulls that exact stardust back home, each cinder reigniting into its original character as it arrives -- a stellar rebirth that restores the text exactly.

### 19. **Warp Drive** (`warp_drive`)
Your code stretches into luminous streaks as you accelerate through a cyan-and-violet hyperspace tunnel. Glowing rings and perspective star trails rush past a drifting vanishing point, then the text barrel-rolls back into place with its original syntax highlighting. The journey runs for about nine seconds, even on a blank buffer.

```vim
:CellularAutomaton warp_drive
```

Use `"warp_drive"` in `enabled_animations` or `disabled_animations` to control registration.

## Usage

### Running Animations

All animations are registered with cellular-automaton.nvim and can be triggered using:

```vim
:CellularAutomaton <animation_name>
```

### Spin Wheel and Plinko Selections

Use the range-aware helper commands after selecting lines:

```vim
:'<,'>SpinWheel
:'<,'>Plinko
```

The visual-mode keybindings below capture the active selection directly. Invoking a helper in normal mode without a range uses default options.

The standard commands also work and use the last completed visual selection when available:
```vim
:CellularAutomaton spin_wheel
:CellularAutomaton plinko
```

`CellularAutomaton` itself does not accept a range. Both selectors stop updating after showing the result for three seconds. Press `q`, `<Esc>`, or `<CR>` to close the animation window.

### Example Keybindings

```lua
vim.keymap.set("n", "<leader>fw", function() 
  vim.cmd([[CellularAutomaton fireworks]]) 
end, { desc = "Fireworks animation" })

vim.keymap.set("n", "<leader>bh", function() 
  vim.cmd([[CellularAutomaton blackhole_breakaway]]) 
end, { desc = "Black hole animation" })

vim.keymap.set("n", "<leader>st", function() 
  vim.cmd([[CellularAutomaton snowtown]]) 
end, { desc = "Snowtown animation" })

-- Spin wheel with visual selection
vim.keymap.set("v", "<leader>sw", "<Cmd>SpinWheel<CR>", { desc = "Spin wheel selector" })
vim.keymap.set("v", "<leader>pl", "<Cmd>Plinko<CR>", { desc = "Plinko selector" })
```

## Configuration

### Basic Setup

```lua
require('custom-cellular-automaton').setup()
```

### Enable Only Specific Animations

```lua
require('custom-cellular-automaton').setup({
  enabled_animations = {
    "fireworks",
    "blackhole",
    "snowtown",
    "matrix"
  }
})
```

### Disable Specific Animations

```lua
require('custom-cellular-automaton').setup({
  disabled_animations = {
    "glitch_drift",
    "updraft"
  }
})
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled_animations` | `table` | `{}` | List of animation names to enable (if set, only these will load) |
| `disabled_animations` | `table` | `{}` | List of animation names to disable |
| `fps_overrides` | `table` | `{}` | Render FPS per animation, from 1–120; fixed simulation steps preserve speed and duration |
| `animation_options` | `table` | `{}` | Per-animation options: `duration` limits runtime in seconds; slides also accept `speed` in cells/second |

Filters and FPS overrides accept module names (such as `"spin-wheel"`) or command names (`"spin_wheel"`). Calling `setup()` again updates registration, including removing disabled animations. Options omitted from a later setup call retain their previous values; use `{}` to reset a list or options table.

```lua
require('custom-cellular-automaton').setup({
  fps_overrides = { warp_drive = 60, matrix = 20 },
  animation_options = {
    matrix = { duration = 20 },
    safe_slide_right = { speed = 12, duration = 10 },
    slide_left_safe = { speed = 12, duration = 10 },
  },
})
```

Animation options use canonical command names. `text_inferno` and `matrix_rain_soft` remain available as legacy command aliases for `inferno` and `matrix`.

## Animation Names Reference

| Animation | Command Name | Description |
|-----------|-------------|-------------|
| Blackhole | `blackhole_breakaway` | Spiral vortex effect |
| Ember Rise | `ember` | Rising embers |
| Fireworks | `fireworks` | Explosive fireworks |
| Glitch Drift | `glitch_drift` | Digital glitch effect |
| Horizontal Slide | `safe_slide_right` | Rotate text right |
| Inferno | `inferno` | Rising flames |
| Matrix | `matrix` | Matrix digital rain |
| Plinko | `plinko` | Paged peg-board selector |
| Ripple | `ripple` | Circular ripple waves |
| Runner | `runner` | ASCII runner character |
| Slide Left | `slide_left_safe` | Rotate text left |
| Snowfall | `snowfall` | Falling snow |
| Snowtown | `snowtown` | Winter scene with objects |
| Spin Wheel | `spin_wheel` | Carnival wheel selector |
| Star Wars | `star_wars` | Opening crawl effect |
| Supernova | `supernova` | Collapse, detonation, and gravitational rebirth |
| Updraft | `updraft` | Rising characters |
| Warp Drive | `warp_drive` | Neon hyperspace tunnel and code reassembly |
| Wisp | `wisp` | Floating particles |

## Architecture

Each animation follows a standardized module pattern:

```lua
local M = {}

function M.register()
  local runtime = require("custom-cellular-automaton.runtime")
  local config = {
    fps = 30,
    name = "animation_name",
    init = function(grid) 
      -- Initialize animation state
    end,
    update = function(grid)
      -- Update animation frame
      return true  -- return false to stop
    end,
    cleanup = function(grid)
      -- Optional: restore temporary state when duration is reached
    end
  }
  runtime.register(config)
end

return M
```

The runtime normalizes grids, keeps complete UTF-8 glyphs together, translates display cells to the dependency's byte-oriented renderer, applies FPS overrides, and ensures the final frame is rendered before updates stop. Animation state must be reset in `init`; bounded effects return `false` only when their lifecycle is complete.

## Development Checks

From the repository root:

```sh
nvim --headless -u NONE -l tests/run.lua
```

The regression suite covers all animations, empty/tiny/uneven/Unicode grids, restarts, finite lifecycles, selection capture, registration filters, FPS overrides, snow lifetimes, and text/highlight preservation.

### Directory Structure

```
custom-cellular-automaton.nvim/
├── lua/
│   └── custom-cellular-automaton/
│       ├── init.lua              # Main plugin module
│       ├── runtime.lua           # Grid, Unicode, timing, and registration bridge
│       ├── selection.lua         # Range-aware selector input
│       ├── slide.lua             # Shared slide implementation
│       ├── util.lua              # Shared display-cell helpers
│       └── animations/           # Individual animations
│           ├── blackhole.lua
│           ├── ember-rise.lua
│           ├── fireworks.lua
│           ├── ...
│           └── snowtown/         # Multi-file animation
│               ├── init.lua
│               ├── animation.lua
│               ├── items.lua
│               ├── placement.lua
│               ├── snow.lua
│               ├── spawner.lua
│               └── util.lua
├── tests/
│   └── run.lua                         # Headless regression suite
└── plugin/
    └── custom-cellular-automaton.lua  # Auto-load bootstrap
```

## Credits

Built with ❤️ on top of [cellular-automaton.nvim](https://github.com/Eandrju/cellular-automaton.nvim) by Eandrju.

Individual animation credits:
- All custom animations designed and implemented for this collection
- Snowtown animation features dynamic object placement and particle effects
- Runner animation includes collision detection and smooth movement

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding new animations or improving existing ones.
