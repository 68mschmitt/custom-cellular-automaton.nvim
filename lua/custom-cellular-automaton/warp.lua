-- Shared hyperspace-tunnel effect used by the warp_drive animation and by
-- any other animation that wants to fly text back into place through it.
local U = require("custom-cellular-automaton.util")
local M = {}

local TAU = 2 * math.pi

function M.smooth(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

function M.setup_colors()
	local colors = {
		Dim = { fg = "#384478", ctermfg = 60 },
		Violet = { fg = "#b48eff", ctermfg = 141 },
		Cyan = { fg = "#5eeaff", ctermfg = 87 },
		White = { fg = "#e8fbff", ctermfg = 195, bold = true },
	}
	for name, spec in pairs(colors) do
		spec.default = true
		vim.api.nvim_set_hl(0, "CAWarp" .. name, spec)
	end
end

-- Bounded trail work even when perspective projects a star far off-screen.
function M.trail(grid, x, y, px, py, hl)
	local dx, dy = x - px, y - py
	local steps = math.min(12, math.ceil(math.max(math.abs(dx), math.abs(dy))))
	local char = math.abs(dx) > math.abs(dy) * 2 and "-"
		or (math.abs(dy) > math.abs(dx) and "|" or (dx * dy > 0 and "\\" or "/"))
	for i = 1, steps do
		local t = i / steps
		U.plot(grid, px + dx * t, py + dy * t, char, hl)
	end
end

-- A tunnel anchored on a grid of the given size, with `cell_count` driving
-- how many star trails to seed (denser buffers get more stars).
function M.new_state(rows, cols, cell_count)
	local state = { rows = rows, cols = cols, stars = {} }
	state.cx, state.cy = (cols + 1) / 2, (rows + 1) / 2
	-- Correct for terminal cells being roughly twice as tall as they are wide.
	state.radius = math.max(1, math.min(cols * 0.45, rows * 0.9))
	for _ = 1, math.min(240, math.ceil(cell_count / 12)) do
		local angle = math.random() * TAU
		local radius = 0.15 + math.random() * 1.2
		state.stars[#state.stars + 1] = {
			x = math.cos(angle) * radius,
			y = math.sin(angle) * radius,
			z = 0.15 + math.random() * 1.5,
			violet = math.random() < 0.3,
		}
	end
	return state
end

-- Draws one frame of the flight corridor: twisting perspective rings plus
-- streaking star trails. `strength` (0..1) fades the corridor in and out.
function M.tunnel(grid, state, time, strength, fps)
	local cx = state.cx + math.sin(time * 0.8) * state.cols * 0.045 * strength
	local cy = state.cy + math.sin(time * 1.1) * state.rows * 0.04 * strength
	local speed = (0.08 + 1.3 * strength) / fps

	for ring = 1, 5 do
		local z = 0.18 + ((ring / 5 - time * 0.45) % 1) * 1.8
		local radius = state.radius * 0.65 / z
		for segment = 1, 72 do
			local angle = segment / 72 * TAU + time * 0.25 + z * 0.4
			local ripple = 1 + 0.045 * math.sin(angle * 6 + time * 2)
			U.plot(
				grid,
				cx + math.cos(angle) * radius * ripple,
				cy + math.sin(angle) * radius * ripple / 2,
				z < 0.5 and ":" or ".",
				ring % 2 == 0 and "CAWarpViolet" or "CAWarpDim"
			)
		end
	end

	for _, star in ipairs(state.stars) do
		local old_z = star.z
		star.z = star.z - speed
		if star.z < 0.12 then
			star.z = 1.65
			old_z = star.z
		end
		local x = cx + star.x * state.radius / star.z
		local y = cy + star.y * state.radius / star.z / 2
		local px = cx + star.x * state.radius / old_z
		local py = cy + star.y * state.radius / old_z / 2
		local color = star.violet and "CAWarpViolet" or "CAWarpCyan"
		M.trail(grid, x, y, px, py, star.z > 0.9 and "CAWarpDim" or color)
		U.plot(grid, x, y, star.z < 0.4 and "+" or ".", star.z < 0.4 and "CAWarpWhite" or color)
	end
end

return M
