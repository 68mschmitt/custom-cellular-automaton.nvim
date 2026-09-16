local U = require("custom-cellular-automaton.animations.snowtown.util")
local Items = require("custom-cellular-automaton.animations.snowtown.items")

local P = {}

local function overlaps(occupancy, top, left, w, h, except)
	for _, obj in ipairs(occupancy) do
		if
			obj ~= except
			and left < obj.left + obj.w
			and left + w > obj.left
			and top < obj.top + obj.h
			and top + h > obj.top
		then
			return true
		end
	end
	return false
end

-- Check if stencil can be placed at (top,left) respecting baseline (no overwrite of baseline text)
local function can_place_over_spaces(grid, baseline, stencil, top, left)
	local rows, cols = U.grid_size(grid)
	for r = 1, #stencil do
		local line = stencil[r]
		for i = 1, #line do
			local ch = line:sub(i, i)
			if not U.is_space(ch) then
				local rr, cc = top + r - 1, left + i - 1
				if rr < 1 or rr > rows or cc < 1 or cc > cols or not grid[rr] or not grid[rr][cc] then
					return false
				end
				if not U.is_space(baseline[rr][cc]) then
					return false
				end
			end
		end
	end
	return true
end

-- For anchored items: require support under the anchor cell
local function has_support(baseline, occupancy, rr, cc, rows)
	if rr == rows then
		return true
	end -- bottom of buffer
	-- support if baseline at (rr+1,cc) is non-space OR an anchored object already drew there
	local below_base = baseline[rr + 1][cc]
	if not U.is_space(below_base) then
		return true
	end
	for _, obj in ipairs(occupancy) do
		if obj.class == "anchored" and rr + 1 == obj.top and cc >= obj.left and cc < obj.left + obj.w then
			return true
		end
	end
	return false
end

-- Try place an anchored item by scanning potential x positions near ground
function P.place_anchored(grid, baseline, item, occupancy)
	local rows, cols = U.grid_size(grid)
	if item.rules.min_cols and cols < item.rules.min_cols then
		return false
	end

	local w, h = Items.dimensions(item.stencil)
	local dx_anchor, dy_anchor = Items.anchor_offset(item.stencil, item.anchor)

	local left_margin = item.rules.margin_left or 0
	local right_margin = item.rules.margin_right or 0
	local top_margin = item.rules.margin_top or 0

	local min_top = 1 + top_margin
	local max_top = rows - h + 1 - (item.rules.margin_bottom or 0)
	local min_left = 1 + left_margin
	local max_left = cols - w - right_margin + 1
	if max_top < min_top or max_left < min_left then
		return false
	end

	-- Scan from the floor upward so objects can rest on the floor or on one another.
	for top = max_top, min_top, -1 do
		local start = U.randint(min_left, max_left)
		for offset = 0, max_left - min_left do
			local left = min_left + ((start - min_left + offset) % (max_left - min_left + 1))
			local anchor_r = top + dy_anchor
			local anchor_c = left + dx_anchor
			if
				has_support(baseline, occupancy, anchor_r, anchor_c, rows)
				and not overlaps(occupancy, top, left, w, h)
				and can_place_over_spaces(grid, baseline, item.stencil, top, left)
			then
				table.insert(occupancy, { top = top, left = left, w = w, h = h, name = item.name, class = "anchored" })
				U.blit_stencil_over_spaces(grid, baseline, item.stencil, top, left)
				return true
			end
		end
	end
	return false
end

-- Floating placement respects text and other objects; snow is transient.
function P.place_floating(grid, baseline, item, occupancy)
	local rows, cols = U.grid_size(grid)
	local w, h = Items.dimensions(item.stencil)
	local left_margin = (item.rules.margin_left or 0)
	local right_margin = (item.rules.margin_right or 0)
	local top_margin = (item.rules.margin_top or 1)
	local bottom_margin = (item.rules.margin_bottom or 1)

	local min_left = 1 + left_margin
	local max_left = cols - w - right_margin + 1
	local min_top = 1 + top_margin
	local max_top = rows - h - bottom_margin + 1
	if max_left < min_left or max_top < min_top then
		return false
	end

	local tries = 20
	for _ = 1, tries do
		local left = U.randint(min_left, max_left)
		local top = U.randint(min_top, max_top)
		if
			not overlaps(occupancy, top, left, w, h)
			and can_place_over_spaces(grid, baseline, item.stencil, top, left)
		then
			table.insert(
				occupancy,
				{ top = top, left = left, x = left, direction = 1, w = w, h = h, name = item.name, class = "floating" }
			)
			U.blit_stencil_over_spaces(grid, baseline, item.stencil, top, left)
			return true
		end
	end
	return false
end

function P.move_floating(grid, baseline, item, obj, occupancy, dt)
	local _, cols = U.grid_size(grid)
	local x = obj.x + obj.direction * 3 * dt
	local left = math.floor(x + 0.5)
	local min_left = 1 + (item.rules.margin_left or 0)
	local max_left = cols - obj.w - (item.rules.margin_right or 0) + 1
	if
		left < min_left
		or left > max_left
		or overlaps(occupancy, obj.top, left, obj.w, obj.h, obj)
		or not can_place_over_spaces(grid, baseline, item.stencil, obj.top, left)
	then
		obj.direction = -obj.direction
	else
		obj.x, obj.left = x, left
	end
end

return P
