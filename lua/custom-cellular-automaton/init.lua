local M = {}

M.version = "1.0.0"
M.name = "custom-cellular-automaton.nvim"
M.description = "Collection of 19 custom cellular automaton animations for Neovim"
M.dependencies = { "eandrju/cellular-automaton.nvim" }

M.config = {
	enabled_animations = {},
	disabled_animations = {},
	fps_overrides = {},
	animation_options = {},
}

local animations = {
	"blackhole",
	"ember-rise",
	"fireworks",
	"glitch_drift",
	"horizontal-slide",
	"inferno",
	"matrix",
	"plinko",
	"ripple",
	"runner",
	"slide-left",
	"snowfall",
	"snowtown",
	"spin-wheel",
	"star-wars",
	"supernova",
	"updraft",
	"warp_drive",
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
	if opts.animation_options then
		M.config.animation_options = opts.animation_options
	end

	M.register_all()
end

function M.register_all()
	local runtime = require("custom-cellular-automaton.runtime")
	runtime.unregister_all()
	runtime.options = M.config
	for _, name in ipairs(animations) do
		local names = vim.list_extend({ name }, runtime.names[name] or {})
		local is_disabled = false

		if #M.config.enabled_animations > 0 then
			local found = false
			for _, enabled_name in ipairs(M.config.enabled_animations) do
				if vim.tbl_contains(names, enabled_name) then
					found = true
					break
				end
			end
			is_disabled = not found
		end

		for _, disabled_name in ipairs(M.config.disabled_animations) do
			if vim.tbl_contains(names, disabled_name) then
				is_disabled = true
				break
			end
		end

		if not is_disabled then
			local ok, animation_module = pcall(require, "custom-cellular-automaton.animations." .. name)
			if ok and animation_module.register then
				runtime.current_module = name
				animation_module.register()
			else
				vim.notify(string.format("Failed to load animation: %s", name), vim.log.levels.WARN)
			end
		end
	end
	runtime.current_module = nil
end

return M
