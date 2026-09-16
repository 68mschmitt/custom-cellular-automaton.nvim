-- Both directions share cell-preserving rotation and configurable speed.
local U = require("custom-cellular-automaton.util")
local M = {}

local function units(row)
	local result, col = {}, 1
	while col <= #row do
		local cell = row[col]
		if cell.char == "" then
			-- Tolerate malformed input without creating another continuation.
			result[#result + 1] = { char = " ", hl_group = cell.hl_group, width = 1 }
			col = col + 1
		else
			local width = math.max(1, U.width(cell.char))
			if col + width - 1 > #row then
				result[#result + 1] = { char = " ", hl_group = cell.hl_group, width = 1 }
				col = col + 1
			else
				result[#result + 1] = { char = cell.char, hl_group = cell.hl_group, width = width }
				col = col + width
			end
		end
	end
	return result
end

function M.register(name, direction)
	local runtime = require("custom-cellular-automaton.runtime")
	local options = (runtime.options.animation_options or {})[name] or {}
	local speed = options.speed or 20
	assert(type(speed) == "number" and speed > 0 and speed <= 120, "Slide speed must be in (0, 120]")
	local offset
	runtime.register({
		name = name,
		fps = 30,
		init = function()
			offset = 0
		end,
		update = function(grid)
			offset = offset + speed / 30
			local steps = math.floor(offset + 1e-9)
			offset = offset - steps
			for _, row in ipairs(grid) do
				if #row > 0 and steps > 0 then
					local old = units(row)
					local count = #old
					local rotated = {}
					local unit_index = 1
					while unit_index <= count do
						local unit = old[1 + ((unit_index - 1 - direction * steps) % count)]
						rotated[#rotated + 1] = unit
						unit_index = unit_index + 1
					end
					local col = 1
					for _, unit in ipairs(rotated) do
						row[col] = { char = unit.char, hl_group = unit.hl_group }
						for part = 1, unit.width - 1 do
							row[col + part] = { char = "", hl_group = unit.hl_group }
						end
						col = col + unit.width
					end
				end
			end
			return true
		end,
	})
end

return M
