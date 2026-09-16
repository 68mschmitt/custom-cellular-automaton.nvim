-- Run from the repository root: nvim --headless -u NONE -l tests/run.lua
vim.opt.runtimepath:append(vim.fn.getcwd())
local ca = { animations = { external = { name = "external" } } }
function ca.register_animation(config)
	-- Match the dependency, which copies configs when adding defaults.
	ca.animations[config.name] = vim.tbl_extend("force", { init = function() end }, config)
end
package.loaded["cellular-automaton"] = ca
local notifications = {}
vim.notify = function(message)
	notifications[#notifications + 1] = message
end
local U = require("custom-cellular-automaton.util")
local plugin = require("custom-cellular-automaton")
local Selection = require("custom-cellular-automaton.selection")
local failures, passed = 0, 0
local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		print("PASS " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n" .. err)
	end
end
local function setup(opts)
	plugin.setup(vim.tbl_extend("force", {
		enabled_animations = {},
		disabled_animations = {},
		fps_overrides = {},
		animation_options = {},
	}, opts or {}))
end
local function grid(rows, cols, kind)
	local result = {}
	local text = kind == "unicode" and "  local λ = '界🙂é' -- text" or "  local x = object.value * 2"
	for r = 1, rows do
		result[r] = {}
		local width = kind == "ragged" and (r == 1 and cols or (r * 13) % (cols + 1)) or cols
		for c = 1, width do
			local char = kind ~= "blank" and r % 3 == 0 and c <= #text and text:sub(c, c) or " "
			result[r][c] = { char = char, hl_group = c % 2 == 0 and "String" or "Comment" }
		end
	end
	return result
end
local function text(row)
	local chars = {}
	for _, cell in ipairs(row) do
		chars[#chars + 1] = cell.char
	end
	return table.concat(chars)
end
local function valid_frame(g, rows, width, label)
	assert(#g == rows, "row count changed")
	for _, row in ipairs(g) do
		for c, cell in ipairs(row) do
			if cell.char == "" then
				assert(c > 1 and U.width(row[c - 1].char) > 1, "orphan wide-glyph continuation at " .. c)
			end
		end
		local line = text(row)
		assert(table.concat(U.chars(line)) == line, "invalid UTF-8")
		assert(
			vim.fn.strdisplaywidth(line) == width,
			string.format(
				"%s: display width changed: expected %d, got %d, cells %d, bytes %d, %q",
				label or "frame",
				width,
				vim.fn.strdisplaywidth(line),
				#row,
				#line,
				line
			)
		)
	end
end
local function run(name, g, limit)
	local config = assert(ca.animations[name], "missing animation: " .. name)
	config.init(g)
	for frame = 1, limit or 1500 do
		if not config.update(g) then
			return frame, g
		end
	end
	error(name .. " did not finish")
end
local function select_lines(labels)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, labels)
	Selection.capture({ range = 2, line1 = 1, line2 = #labels })
end

test("registration filters, aliases, and unrelated animations", function()
	setup()
	assert(ca.animations.inferno and ca.animations.text_inferno)
	assert(ca.animations.matrix and ca.animations.matrix_rain_soft)
	setup({ enabled_animations = { "warp_drive" } })
	assert(vim.tbl_count(ca.animations) == 2 and ca.animations.external)
	setup({ enabled_animations = { "text_inferno" } })
	assert(ca.animations.inferno and not ca.animations.warp_drive)
	setup({ disabled_animations = { "matrix_rain_soft", "inferno" } })
	assert(not ca.animations.matrix and not ca.animations.text_inferno)
	setup()
end)

test("FPS overrides preserve duration and final state", function()
	local times = {}
	for _, fps in ipairs({ 15, 30, 60 }) do
		setup({ enabled_animations = { "warp_drive" }, fps_overrides = { warp_drive = fps } })
		local config = ca.animations.warp_drive
		local g = grid(10, 40, "unicode")
		config.init(g)
		local baseline = vim.deepcopy(g)
		local frames = 0
		repeat
			frames = frames + 1
		until not config.update(g)
		assert(frames < 600 and vim.deep_equal(g, baseline), "restoration failed")
		times[#times + 1] = frames / fps
	end
	assert(math.abs(times[1] - times[3]) < 0.15, "FPS changed simulation duration")
	setup()
end)

test("UTF-8 truncation and renderer byte highlights", function()
	assert(U.truncate(string.rep("a", 17) .. "🙂label", 20) == string.rep("a", 17) .. "..")
	assert(table.concat(U.chars("界🙂é")) == "界🙂é")
	assert(#U.chars("👩‍💻") == 1 and U.width(U.chars("👩‍💻")[1]) == 2)
	assert(#U.chars("🇺🇸") == 1 and U.width(U.chars("🇺🇸")[1]) == 2)
	assert(U.truncate("界界界", 5) == "界..")
	local runtime = require("custom-cellular-automaton.runtime")
	runtime.register({
		name = "unicode_probe",
		fps = 30,
		init = function(g)
			assert(g[1][1].char == "界" and g[1][2].char == "")
			assert(g[1][3].char == "é")
		end,
		update = function(g)
			U.clear(g)
			U.plot(g, 2, 1, "界", "Special")
			U.plot(g, 4, 1, "é", "String")
			return false
		end,
	})
	local g = grid(1, 12, "blank")
	local raw = "界é"
	for i = 1, #raw do
		g[1][i] = { char = raw:sub(i, i), hl_group = "String" }
	end
	local config = ca.animations.unicode_probe
	config.init(g)
	assert(config.update(g), "final frame must be presented before stopping")
	assert(text(g[1]):sub(1, 6) == " 界é")
	for i = 2, 4 do
		assert(g[1][i].hl_group == "Special")
	end
	for i = 5, 6 do
		assert(g[1][i].hl_group == "String")
	end
	assert(not config.update(g))
	setup()
end)

local finite = {
	blackhole_breakaway = true,
	ember = true,
	fireworks = true,
	glitch_drift = true,
	inferno = true,
	plinko = true,
	ripple = true,
	spin_wheel = true,
	star_wars = true,
	supernova = true,
	warp_drive = true,
	wisp = true,
}
local names = {
	"blackhole_breakaway",
	"ember",
	"fireworks",
	"glitch_drift",
	"safe_slide_right",
	"inferno",
	"matrix",
	"plinko",
	"ripple",
	"runner",
	"slide_left_safe",
	"snowfall",
	"snowtown",
	"spin_wheel",
	"star_wars",
	"supernova",
	"updraft",
	"warp_drive",
	"wisp",
}
for _, name in ipairs(names) do
	test(name .. " lifecycle, bounds, Unicode, and restart", function()
		for _, case in ipairs({
			{ 0, 0, "blank" },
			{ 1, 1, "blank" },
			{ 1, 40, "blank" },
			{ 30, 1, "blank" },
			{ 24, 80, "blank" },
			{ 24, 80, "text" },
			{ 24, 80, "unicode" },
			{ 12, 36, "ragged" },
		}) do
			math.randomseed(2026)
			local g = grid(unpack(case))
			local config = ca.animations[name]
			config.init(g)
			local stopped = false
			for frame = 1, finite[name] and 1200 or 240 do
				local running = config.update(g)
				assert(type(running) == "boolean")
				if frame % 30 == 0 then
					valid_frame(g, case[1], case[2], name .. "/" .. case[3] .. "/" .. case[1] .. "x" .. case[2])
				end
				if not running then
					stopped = true
					break
				end
			end
			assert(not finite[name] or stopped, "finite animation never stopped")
			valid_frame(g, case[1], case[2], name .. "/" .. case[3] .. "/final")
		end
		-- Interrupted initialization must not leak the previous grid or phase.
		local config = ca.animations[name]
		config.init(grid(20, 50, "text"))
		config.update(grid(20, 50, "text"))
		local fresh = grid(8, 16, "text")
		config.init(fresh)
		config.update(fresh)
		valid_frame(fresh, 8, 16, name .. "/restart")
	end)
end

test("Inferno burns pending text, including bottom row", function()
	local g = grid(24, 80, "blank")
	g[1][1].char, g[24][80].char = "X", "Y"
	local frames = run("inferno", g)
	assert(frames > 30 and frames < 240)
	for _, row in ipairs(g) do
		assert(not text(row):find("%S"))
	end
end)

test("Glitch does not stop on an idle random frame and restores highlights", function()
	for seed = 1, 10 do
		math.randomseed(seed)
		local g = grid(8, 20, "blank")
		g[4][10] = { char = "X", hl_group = "String" }
		local config = ca.animations.glitch_drift
		config.init(g)
		local baseline = vim.deepcopy(g)
		assert(config.update(g))
		local frames = 1
		while config.update(g) do
			frames = frames + 1
			assert(frames < 300)
		end
		assert(vim.deep_equal(g, baseline))
	end
end)

test("Ripple finishes, restores text, and resets its clock", function()
	local config, results = ca.animations.ripple, {}
	for _ = 1, 2 do
		local g = grid(24, 80, "text")
		config.init(g)
		local baseline = vim.deepcopy(g)
		local frames = 0
		repeat
			frames = frames + 1
			assert(frames < 240)
		until not config.update(g)
		assert(vim.deep_equal(g, baseline))
		results[#results + 1] = frames
	end
	assert(results[1] == results[2])
end)

test("snow effects preserve punctuation and highlights", function()
	for _, name in ipairs({ "snowfall", "snowtown" }) do
		local g = grid(24, 80, "blank")
		for c, char in ipairs({ ".", "*", ".", "*" }) do
			g[10][c + 20] = { char = char, hl_group = "String" }
		end
		local baseline = vim.deepcopy(g)
		ca.animations[name].init(g)
		for _ = 1, 800 do
			ca.animations[name].update(g)
			for c = 21, 24 do
				assert(vim.deep_equal(g[10][c], baseline[10][c]))
			end
		end
	end
end)

test("snow melts once and bottom-row flakes settle", function()
	local Snow = require("custom-cellular-automaton.animations.snowtown.snow")
	local g = grid(4, 8, "blank")
	local snow = Snow.new({ DENSITY = 0, TTL_MIN = 3, TTL_MAX = 3 }):attach(g)
	snow.flakes = { { x = 4, y = 4, speed = 0.5, char = "*" } }
	snow:tick(g, nil, 0)
	assert(snow.ttl[4][4] == 3)
	for _ = 1, 4 do
		U.clear(g)
		snow:tick(g, nil, 0)
	end
	assert(snow.ttl[4][4] == 0 and g[4][4].char == " ")
end)

test("Snowtown floor placement, collision rejection, and floating movement", function()
	local Place = require("custom-cellular-automaton.animations.snowtown.placement")
	local SU = require("custom-cellular-automaton.animations.snowtown.util")
	local items = require("custom-cellular-automaton.animations.snowtown.items").catalog
	assert(#items >= 4 and SU.randint(5, 5) == 5)
	local g = grid(24, 24, "blank")
	local baseline, occupancy = SU.snapshot_grid(g), {}
	assert(Place.place_anchored(g, baseline, items[1], occupancy))
	assert(occupancy[1].top + occupancy[1].h - 1 == 24)
	for _ = 1, 10 do
		Place.place_anchored(g, baseline, items[1], occupancy)
	end
	for i, a in ipairs(occupancy) do
		for j, b in ipairs(occupancy) do
			assert(
				i == j
					or a.left + a.w <= b.left
					or b.left + b.w <= a.left
					or a.top + a.h <= b.top
					or b.top + b.h <= a.top
			)
		end
	end
	g = grid(24, 24, "blank")
	g[24][5] = { char = "界", hl_group = "String" }
	g[24][6] = { char = "", hl_group = "String" }
	baseline, occupancy = SU.snapshot_grid(g), {}
	assert(Place.place_anchored(g, baseline, items[1], occupancy))
	for _, obj in ipairs(occupancy) do
		local item = items[1]
		for r, line in ipairs(item.stencil) do
			for c = 1, #line do
				if not SU.is_space(line:sub(c, c)) then
					assert(SU.is_space(baseline[obj.top + r - 1][obj.left + c - 1]))
				end
			end
		end
	end
	g = grid(24, 80, "blank")
	baseline, occupancy = SU.snapshot_grid(g), {}
	local floating = items[#items]
	assert(Place.place_floating(g, baseline, floating, occupancy))
	local obj = occupancy[1]
	local first = obj.left
	for _ = 1, 30 do
		Place.move_floating(g, baseline, floating, obj, occupancy, 1 / 30)
	end
	assert(obj.left ~= first)
end)

test("selection helper commands capture active visual mode and explicit ranges", function()
	local captured
	vim.api.nvim_create_user_command("CellularAutomaton", function()
		captured = Selection.labels()
	end, { nargs = 1 })
	dofile("plugin/custom-cellular-automaton.lua")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Alpha", "Beta", "Gamma" })
	vim.cmd("normal! ggVj")
	vim.cmd("SpinWheel")
	assert(vim.deep_equal(captured, { "Alpha", "Beta" }))
	vim.cmd("normal! \27")
	vim.cmd("2,3Plinko")
	assert(vim.deep_equal(captured, { "Beta", "Gamma" }))
	vim.cmd("SpinWheel")
	assert(captured[1] == "Option 1", "normal command reused stale marks")
end)

test("selectors retain full Unicode labels, finish, and handle paged candidates", function()
	local labels =
		{ "Very long Unicode label 界🙂alpha", "Beta界", "Gamma🙂", "Delta", "Epsilon", "Zeta", "Eta", "Theta" }
	for _, name in ipairs({ "spin_wheel", "plinko" }) do
		select_lines(labels)
		local before = #notifications
		local _, g = run(name, grid(12, 12, "blank"))
		assert(#notifications == before + 1)
		local match = false
		for _, label in ipairs(labels) do
			if notifications[#notifications]:find(label, 1, true) then
				match = true
			end
		end
		assert(match, "winner lost its full label")
		valid_frame(g, 12, 12)
	end
end)

test("slides preserve cell highlights, obey speed and duration", function()
	setup({
		animation_options = { safe_slide_right = { speed = 30, duration = 0.1 }, slide_left_safe = { speed = 30 } },
	})
	local g = grid(1, 4, "blank")
	g[1][1] = { char = "X", hl_group = "String" }
	ca.animations.safe_slide_right.init(g)
	ca.animations.safe_slide_right.update(g)
	assert(g[1][2].char == "X" and g[1][2].hl_group == "String")
	ca.animations.slide_left_safe.init(g)
	ca.animations.slide_left_safe.update(g)
	assert(g[1][1].char == "X" and g[1][1].hl_group == "String")
	assert(run("safe_slide_right", grid(1, 4, "blank"), 10) <= 5)
	setup()
end)

test("wide glyphs remain atomic through slides and movement", function()
	setup({ enabled_animations = { "safe_slide_right", "updraft" } })
	local g = grid(8, 12, "blank")
	g[3][4] = { char = "界", hl_group = "String" }
	g[3][5] = { char = "", hl_group = "String" }
	local slide = ca.animations.safe_slide_right
	slide.init(g)
	for _ = 1, 24 do
		slide.update(g)
		valid_frame(g, 8, 12, "slide wide glyph")
	end
	assert(text(g[3]):find("界", 1, true), "slide dropped the wide glyph")

	local updraft = ca.animations.updraft
	updraft.init(g)
	for _ = 1, 12 do
		updraft.update(g)
		valid_frame(g, 8, 12, "updraft wide glyph")
	end
	setup()
end)

test("duration cleanup restores temporary animations", function()
	setup({
		enabled_animations = { "wisp", "snowfall", "runner" },
		animation_options = {
			wisp = { duration = 0.1 },
			snowfall = { duration = 0.1 },
			runner = { duration = 0.1 },
		},
	})
	for _, name in ipairs({ "wisp", "snowfall", "runner" }) do
		local g = grid(12, 40, "text")
		local baseline = vim.deepcopy(g)
		local config = ca.animations[name]
		config.init(g)
		for _ = 1, 120 do
			if not config.update(g) then
				break
			end
		end
		assert(vim.deep_equal(g, baseline), name .. " duration did not restore the baseline")
	end
	setup()
end)

test("updraft uses full lift and never jumps through obstacles", function()
	local module = require("custom-cellular-automaton.animations.updraft")
	module.side_noise = false
	local g = grid(8, 10, "blank")
	g[6][5] = { char = "X", hl_group = "String" }
	ca.animations.updraft.init(g)
	ca.animations.updraft.update(g)
	assert(g[4][5].char == "X")
	g = grid(8, 10, "blank")
	g[6][5] = { char = "X", hl_group = "String" }
	g[5][5] = { char = "#", hl_group = "@comment" }
	ca.animations.updraft.init(g)
	ca.animations.updraft.update(g)
	assert(g[6][5].char == "X")
	module.side_noise = true
end)

print(string.format("\n%d passed, %d failed", passed, failures))
if failures > 0 then
	vim.cmd("cquit 1")
end
