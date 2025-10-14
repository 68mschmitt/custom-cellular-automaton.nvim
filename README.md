# custom-cellular-automaton.nvim

A collection of 15 custom cellular automaton animations for Neovim, built on top of [eandrju/cellular-automaton.nvim](https://github.com/Eandrju/cellular-automaton.nvim).

## Features

- 🎨 **15 Unique Animations** - From black holes to snowfall, matrix effects to fireworks
- 🔧 **Easy Configuration** - Enable/disable specific animations with simple setup
- 🚀 **Auto-registration** - All animations load automatically on plugin initialization
- 🎯 **Modular Design** - Each animation is self-contained and follows consistent patterns
- ❄️ **Complex Animations** - Includes advanced multi-file animations like Snowtown

## Requirements

- Neovim >= 0.8.0
- [cellular-automaton.nvim](https://github.com/Eandrju/cellular-automaton.nvim)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'eandrju/cellular-automaton.nvim',
  lazy = false,
}

{
  dir = vim.fn.stdpath("config") .. "/custom-cellular-automaton.nvim",
  dependencies = { 'eandrju/cellular-automaton.nvim' },
  lazy = false,
  config = function()
    require('custom-cellular-automaton').setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'eandrju/cellular-automaton.nvim',
}

use {
  '~/path/to/custom-cellular-automaton.nvim',
  requires = { 'eandrju/cellular-automaton.nvim' },
  config = function()
    require('custom-cellular-automaton').setup()
  end
}
```

## Animations Showcase

### 1. **Blackhole** (`blackhole_breakaway`)
Text characters detach individually and spiral into a growing black hole at the center of the screen.

### 2. **Ember Rise** (`ember`)
Characters flicker and rise upward like glowing embers from a fire.

### 3. **Fireworks** (`fireworks`)
Colorful explosive animations with rockets launching and sparks spreading across the screen.

### 4. **Glitch Drift** (`glitch_drift`)
Characters glitch and drift horizontally with digital distortion effects.

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
Complex winter scene with falling snow, snowmen, and other festive objects that accumulate over time.

### 13. **Star Wars** (`star_wars`)
Text scrolls upward and away like the iconic Star Wars opening crawl.

### 14. **Updraft** (`updraft`)
Characters rise upward in a thermal updraft effect.

### 15. **Wisp** (`wisp`)
Ethereal floating particles drift across the screen with smooth motion.

## Usage

### Running Animations

All animations are registered with cellular-automaton.nvim and can be triggered using:

```vim
:CellularAutomaton <animation_name>
```

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
| `fps_overrides` | `table` | `{}` | Per-animation FPS overrides (future feature) |

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
| Ripple | `ripple` | Circular ripple waves |
| Runner | `runner` | ASCII runner character |
| Slide Left | `slide_left_safe` | Rotate text left |
| Snowfall | `snowfall` | Falling snow |
| Snowtown | `snowtown` | Winter scene with objects |
| Star Wars | `star_wars` | Opening crawl effect |
| Updraft | `updraft` | Rising characters |
| Wisp | `wisp` | Floating particles |

## Architecture

Each animation follows a standardized module pattern:

```lua
local M = {}

function M.register()
  local ca = require("cellular-automaton")
  local config = {
    fps = 30,
    name = "animation_name",
    init = function(grid) 
      -- Initialize animation state
    end,
    update = function(grid)
      -- Update animation frame
      return true  -- return false to stop
    end
  }
  ca.register_animation(config)
end

return M
```

### Directory Structure

```
custom-cellular-automaton.nvim/
├── lua/
│   └── custom-cellular-automaton/
│       ├── init.lua              # Main plugin module
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
