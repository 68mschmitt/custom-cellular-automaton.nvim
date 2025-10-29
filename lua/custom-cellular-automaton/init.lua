local M = {}

M.version = "1.0.0"
M.name = "custom-cellular-automaton.nvim"
M.description = "Collection of 15 custom cellular automaton animations for Neovim"
M.dependencies = { "eandrju/cellular-automaton.nvim" }

M.config = {
  enabled_animations = {},
  disabled_animations = {},
  fps_overrides = {},
}

local animations = {
  "blackhole",
  "ember-rise",
  "fireworks",
  "glitch_drift",
  "horizontal-slide",
  "inferno",
  "matrix",
  "ripple",
  "runner",
  "slide-left",
  "snowfall",
  "snowtown",
  "spin-wheel",
  "star-wars",
  "updraft",
  "wisp",
}

function M.setup(opts)
  opts = opts or {}
  
  if opts.enabled_animations then
    M.config.enabled_animations = opts.enabled_animations
  end
  
  if opts.disabled_animations then
    M.config.disabled_animations = opts.disabled_animations
  end
  
  if opts.fps_overrides then
    M.config.fps_overrides = opts.fps_overrides
  end
  
  M.register_all()
end

function M.register_all()
  for _, name in ipairs(animations) do
    local is_disabled = false
    
    if #M.config.enabled_animations > 0 then
      local found = false
      for _, enabled_name in ipairs(M.config.enabled_animations) do
        if enabled_name == name then
          found = true
          break
        end
      end
      is_disabled = not found
    end
    
    for _, disabled_name in ipairs(M.config.disabled_animations) do
      if disabled_name == name then
        is_disabled = true
        break
      end
    end
    
    if not is_disabled then
      local ok, animation_module = pcall(require, "custom-cellular-automaton.animations." .. name)
      if ok and animation_module.register then
        animation_module.register()
      else
        vim.notify(
          string.format("Failed to load animation: %s", name),
          vim.log.levels.WARN
        )
      end
    end
  end
end

return M
