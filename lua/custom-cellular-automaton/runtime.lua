local U = require("custom-cellular-automaton.util")
local M = { options = {}, owned = {} }

M.names = {
	blackhole = { "blackhole_breakaway" },
	["ember-rise"] = { "ember" },
	["horizontal-slide"] = { "safe_slide_right" },
	inferno = { "inferno", "text_inferno" },
	matrix = { "matrix", "matrix_rain_soft" },
	["slide-left"] = { "slide_left_safe" },
	["spin-wheel"] = { "spin_wheel" },
	["star-wars"] = { "star_wars" },
}

-- The dependency uses byte cells and byte highlight offsets. Animations work
-- with display cells; only this boundary expands complete glyphs back to bytes.
local function decode(grid)
	local rows, width = #grid, 0
	local encoded = {}
	for r, source_row in ipairs(grid) do
		local bytes, highlights = {}, {}
		for _, cell in ipairs(source_row) do
			local char = cell.char or " "
			for i = 1, #char do
				bytes[#bytes + 1] = char:sub(i, i)
				highlights[#bytes] = cell.hl_group
			end
		end
		local text = table.concat(bytes)
		encoded[r] = { text = text, highlights = highlights }
		width = math.max(width, vim.fn.strdisplaywidth(text))
	end
	local result = {}
	for r = 1, rows do
		local text, highlights = encoded[r].text, encoded[r].highlights
		local row, col, byte = {}, 1, 1
		for _, char in ipairs(U.chars(text)) do
			local size = char == "\t" and (vim.bo.tabstop - (col - 1) % vim.bo.tabstop) or math.max(1, U.width(char))
			if col + size - 1 > width then
				break
			end
			row[col] = { char = char == "\t" and " " or char, hl_group = highlights[byte] }
			for offset = 1, size - 1 do
				row[col + offset] = { char = "", hl_group = highlights[byte] }
			end
			col, byte = col + size, byte + #char
		end
		for c = col, width do
			row[c] = { char = " " }
		end
		result[r] = row
	end
	return result, rows > 0 and width > 0
end

local function encode(logical, output)
	for r, row in ipairs(logical) do
		local bytes, c, count = output[r] or {}, 1, 0
		while c <= #row do
			local cell = row[c]
			if cell.char == "" then
				if c == 1 or U.width(row[c - 1].char) <= 1 then
					count = count + 1
					bytes[count] = bytes[count] or {}
					bytes[count].char, bytes[count].hl_group = " ", cell.hl_group
				end
				c = c + 1
			else
				local char = cell.char
				local width = math.max(1, U.width(char))
				if c + width - 1 > #row then
					char, width = " ", 1
				end
				for i = 1, #char do
					count = count + 1
					bytes[count] = bytes[count] or {}
					bytes[count].char, bytes[count].hl_group = char:sub(i, i), cell.hl_group
				end
				c = c + width
			end
		end
		for i = #bytes, count + 1, -1 do
			bytes[i] = nil
		end
		output[r] = bytes
	end
end

function M.unregister_all()
	local ca = require("cellular-automaton")
	for name, config in pairs(M.owned) do
		if ca.animations[name] == config then
			ca.animations[name] = nil
		end
	end
	M.owned = {}
end

function M.register(config)
	local ca = require("cellular-automaton")
	local keys = M.names[M.current_module] or { config.name }
	local fps = M.options.fps_overrides or {}
	local override = fps[M.current_module] or fps[config.name]
	for _, key in ipairs(keys) do
		override = override or fps[key]
	end
	local target_fps = override or config.fps
	local settings = M.options.animation_options or {}
	local duration = (settings[M.current_module] or settings[config.name] or {}).duration
	assert(duration == nil or (type(duration) == "number" and duration > 0), "Duration must be positive")
	assert(
		type(target_fps) == "number" and target_fps >= 1 and target_fps <= 120,
		"Animation FPS must be between 1 and 120"
	)
	local logical, valid, finished, accumulator, elapsed
	local wrapped = {
		name = config.name,
		fps = target_fps,
		init = function(grid)
			logical, valid = decode(grid)
			finished, accumulator, elapsed = false, 0, 0
			if valid and config.init then
				config.init(logical)
			end
			encode(logical, grid)
		end,
		update = function(grid)
			if not valid or finished then
				return false
			end
			elapsed = elapsed + 1 / target_fps
			if duration and elapsed > duration then
				if config.cleanup then
					config.cleanup(logical)
				end
				finished = true
				encode(logical, grid)
				return true
			end
			-- Fixed simulation steps preserve physics and duration under FPS overrides.
			accumulator = accumulator + config.fps / target_fps
			while accumulator >= 1 - 1e-9 do
				accumulator = accumulator - 1
				if not config.update(logical) then
					finished = true
					break
				end
			end
			encode(logical, grid)
			-- The manager renders BEFORE update: allow the final state to be rendered.
			return true
		end,
	}
	for _, key in ipairs(keys) do
		local alias = vim.tbl_extend("force", wrapped, { name = key })
		ca.register_animation(alias)
		M.owned[key] = ca.animations[key]
	end
end

return M
