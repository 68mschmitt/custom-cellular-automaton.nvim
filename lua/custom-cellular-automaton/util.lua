local M = {}
local ZERO_WIDTH_JOINER = string.char(226, 128, 141)

local function is_regional_indicator(char)
	local codepoint = vim.fn.char2nr(char)
	return codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF
end

function M.size(grid)
	local width = 0
	for _, row in ipairs(grid) do
		width = math.max(width, #row)
	end
	return #grid, width
end

function M.width(char)
	if char == "" then
		return 0
	end
	if #char == 1 and char:byte() < 128 then
		return 1
	end
	return vim.fn.strdisplaywidth(char)
end

-- Decode complete UTF-8 graphemes; tolerate a viewport clipped mid-character.
function M.chars(text)
	local codepoints, i = {}, 1
	while i <= #text do
		local b = text:byte(i)
		local n = b < 128 and 1
			or (b >= 194 and b <= 223 and 2 or (b >= 224 and b <= 239 and 3 or (b >= 240 and b <= 244 and 4 or 0)))
		local valid = n > 0 and i + n - 1 <= #text
		for j = i + 1, i + n - 1 do
			local byte = text:byte(j) or 0
			valid = valid and byte >= 128 and byte <= 191
		end
		local second = text:byte(i + 1) or 0
		valid = valid
			and not (
				b == 224 and second < 160
				or b == 237 and second >= 160
				or b == 240 and second < 144
				or b == 244 and second >= 144
			)
		codepoints[#codepoints + 1] = valid and text:sub(i, i + n - 1) or "?"
		i = i + (valid and n or 1)
	end

	local chars, joining, regional = {}, false, false
	for _, char in ipairs(codepoints) do
		local combining = #char > 1 and vim.fn.strchars("a" .. char, true) == 1
		if char == ZERO_WIDTH_JOINER then -- zero-width joiner
			if #chars == 0 then
				chars[1] = " "
			end
			chars[#chars] = chars[#chars] .. char
			joining = true
			regional = false
		elseif joining then
			chars[#chars] = chars[#chars] .. char
			joining = false
			regional = false
		elseif combining then
			if #chars == 0 then
				chars[1] = " " .. char
			else
				chars[#chars] = chars[#chars] .. char
			end
			regional = false
		elseif is_regional_indicator(char) and regional then
			chars[#chars] = chars[#chars] .. char
			regional = false
		elseif is_regional_indicator(char) then
			chars[#chars + 1] = char
			regional = true
		else
			chars[#chars + 1] = char
			regional = false
		end
	end
	return chars
end

function M.truncate(text, width)
	if width <= 0 then
		return ""
	end
	if vim.fn.strdisplaywidth(text) <= width then
		return text
	end
	local suffix = width > 2 and ".." or ""
	local out, used = {}, 0
	for _, char in ipairs(M.chars(text)) do
		local size = M.width(char)
		if used + size > width - #suffix then
			break
		end
		out[#out + 1], used = char, used + size
	end
	return table.concat(out) .. suffix
end

function M.plot(grid, x, y, char, hl)
	local row_index, col = math.floor(y + 0.5), math.floor(x + 0.5)
	local row = grid[row_index]
	if char ~= "" and row and row[col] then
		local width = M.width(char)
		if width > 1 and not row[col + width - 1] then
			return
		end
		local function clear_glyph(at)
			local start = at
			if row[at].char == "" then
				for candidate = at - 1, 1, -1 do
					local candidate_char = row[candidate].char
					if candidate_char ~= "" then
						if candidate + math.max(1, M.width(candidate_char)) - 1 >= at then
							start = candidate
						end
						break
					end
				end
			end
			local span = math.max(1, M.width(row[start].char))
			for offset = 0, span - 1 do
				local cell = row[start + offset]
				if cell then
					cell.char, cell.hl_group = " ", nil
				end
			end
		end

		-- Clear complete glyphs before writing so effects cannot orphan a continuation.
		for offset = 0, width - 1 do
			clear_glyph(col + offset)
		end
		row[col].char, row[col].hl_group = char, hl
		for offset = 1, width - 1 do
			if row[col + offset] then
				row[col + offset].char = ""
				row[col + offset].hl_group = hl
			end
		end
	end
end

function M.text(grid, x, y, text, hl)
	for _, char in ipairs(M.chars(text)) do
		M.plot(grid, x, y, char, hl)
		x = x + M.width(char)
	end
end

function M.clear(grid)
	for _, row in ipairs(grid) do
		for _, cell in ipairs(row) do
			cell.char, cell.hl_group = " ", nil
		end
	end
end

function M.snapshot(grid)
	return vim.deepcopy(grid)
end

function M.restore(grid, snapshot)
	for r, row in ipairs(grid) do
		for c, cell in ipairs(row) do
			local original = snapshot[r] and snapshot[r][c]
			cell.char = original and original.char or " "
			cell.hl_group = original and original.hl_group or nil
		end
	end
end

return M
