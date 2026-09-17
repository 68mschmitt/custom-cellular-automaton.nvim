local M = {}

M.RANDOM = "random"
M.SHOWCASE = "showcase"

-- Friendly labels for every command name this collection (and its
-- dependency's built-ins) can register. Order here is menu order.
M.items = {
	{ label = "Blackhole", value = "blackhole_breakaway" },
	{ label = "Ember Rise", value = "ember" },
	{ label = "Fireworks", value = "fireworks" },
	{ label = "Glitch Drift", value = "glitch_drift" },
	{ label = "Horizontal Slide", value = "safe_slide_right" },
	{ label = "Inferno", value = "inferno" },
	{ label = "Matrix", value = "matrix" },
	{ label = "Plinko", value = "plinko" },
	{ label = "Ripple", value = "ripple" },
	{ label = "Runner", value = "runner" },
	{ label = "Slide Left", value = "slide_left_safe" },
	{ label = "Snowfall", value = "snowfall" },
	{ label = "Snowtown", value = "snowtown" },
	{ label = "Spin Wheel", value = "spin_wheel" },
	{ label = "Star Wars", value = "star_wars" },
	{ label = "Supernova", value = "supernova" },
	{ label = "Updraft", value = "updraft" },
	{ label = "Warp Drive", value = "warp_drive" },
	{ label = "Wisp", value = "wisp" },
	{ label = "Make It Rain", value = "make_it_rain" },
	{ label = "Game of Life", value = "game_of_life" },
	{ label = "Scramble", value = "scramble" },
}

-- Every animation runs in the showcase, in this order.
M.showcase_names = vim.tbl_map(function(item)
	return item.value
end, M.items)

-- How long (seconds) each animation gets before the showcase forces it to
-- stop and move on — long enough to see what it does, short enough that a
-- full tour doesn't drag. Animations that finish on their own (most of
-- them) usually move on well before their time is up; animations that
-- loop forever (matrix, snowfall, ember, ...) rely entirely on this to
-- ever end. A few naturally long, climactic ones (fireworks, blackhole)
-- are deliberately cut short of their real finale for the same reason.
M.showcase_timeouts = {
	blackhole_breakaway = 7,
	ember = 5,
	fireworks = 8,
	glitch_drift = 8,
	safe_slide_right = 4,
	inferno = 5,
	matrix = 5,
	plinko = 8,
	ripple = 5,
	runner = 6,
	slide_left_safe = 4,
	snowfall = 6,
	snowtown = 9,
	spin_wheel = 8,
	star_wars = 6,
	supernova = 11,
	updraft = 5,
	warp_drive = 10,
	wisp = 11,
	make_it_rain = 5,
	game_of_life = 6,
	scramble = 4,
}
M.DEFAULT_SHOWCASE_TIMEOUT = 6

-- Only offer animations that are actually registered right now, so
-- enabled/disabled filters and missing built-ins are respected.
function M.available()
	local ca = require("cellular-automaton")
	local result = {}
	for _, item in ipairs(M.items) do
		if ca.animations[item.value] then
			result[#result + 1] = item
		end
	end
	return result
end

local function available_showcase()
	local ca = require("cellular-automaton")
	local result = {}
	for _, name in ipairs(M.showcase_names) do
		if ca.animations[name] then
			result[#result + 1] = name
		end
	end
	return result
end

function M.pick_random()
	local items = M.available()
	return items[math.random(#items)].value
end

-- Plays `names[index]`, then automatically closes its window and moves on
-- to the next — either once the animation finishes on its own, or once its
-- showcase time budget runs out, whichever comes first. The animation's own
-- window is simply closed early in the latter case: nothing needs restoring
-- first, since every animation reloads the real buffer text fresh on init.
function M.play_sequence(names, index, host_win)
	index = index or 1
	host_win = host_win or vim.api.nvim_get_current_win()
	local name = names[index]
	if not name then
		return
	end
	local ca = require("cellular-automaton")
	local config = ca.animations[name]
	local original_update = config.update
	local advanced = false

	local function advance()
		if advanced then
			return
		end
		advanced = true
		config.update = original_update
		vim.schedule(function()
			require("cellular-automaton.manager").clean()
			vim.defer_fn(function()
				M.play_sequence(names, index + 1, host_win)
			end, 300)
		end)
	end

	config.update = function(grid)
		local continue = original_update(grid)
		if not continue then
			advance()
		end
		return continue
	end
	vim.defer_fn(advance, (M.showcase_timeouts[name] or M.DEFAULT_SHOWCASE_TIMEOUT) * 1000)

	-- Closing the previous animation's floating window doesn't reliably hand
	-- focus back to the original buffer, so land on it explicitly before
	-- starting the next animation (it needs a real filetype for treesitter).
	if vim.api.nvim_win_is_valid(host_win) then
		vim.api.nvim_set_current_win(host_win)
	end
	ca.start_animation(name)
end

-- Resolves a chosen value (a plain animation name, or the random/showcase
-- sentinels) and starts the corresponding animation(s).
function M.run(value)
	if value == M.SHOWCASE then
		M.play_sequence(available_showcase())
		return
	end
	local ca = require("cellular-automaton")
	ca.start_animation(value == M.RANDOM and M.pick_random() or value)
end

function M.select(callback)
	local menu = {
		{ label = "Random", value = M.RANDOM },
		{ label = "Showcase (All)", value = M.SHOWCASE },
	}
	for _, item in ipairs(M.available()) do
		menu[#menu + 1] = item
	end
	vim.ui.select(menu, {
		prompt = "Select a cellular automaton animation:",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice then
			callback(choice.value)
		end
	end)
end

return M
