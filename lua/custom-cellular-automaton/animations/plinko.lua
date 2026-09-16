-- Peg collisions, paged buckets and visible totals. Usage: :'<,'>Plinko
local U = require("custom-cellular-automaton.util")
local Selection = require("custom-cellular-automaton.selection")
local M = {}
local COLORS = { "String", "Function", "Type", "Constant", "Identifier", "Special" }

function M.register()
	local state
	local fps = 30
	local function peg_at(row, x)
		if row < 3 or row >= state.bucket_top or (row - 3) % 2 ~= 0 then
			return nil
		end
		local offset = ((row - 3) / 2) % 2 * 2 + 2
		local peg = offset + math.floor((x - offset) / 4 + 0.5) * 4
		if peg >= 2 and peg < state.world_width and math.abs(x - peg) <= 0.8 then
			return peg
		end
	end
	require("custom-cellular-automaton.runtime").register({
		name = "plinko",
		fps = fps,
		init = function(grid)
			local rows, cols = U.size(grid)
			local labels = Selection.labels()
			local per_page = math.max(1, math.min(#labels, math.floor(cols / 10)))
			local bucket_width = math.max(1, math.floor(cols / per_page))
			state = {
				frame = 0,
				labels = labels,
				rows = rows,
				cols = cols,
				balls = {},
				counts = {},
				per_page = per_page,
				pages = math.ceil(#labels / per_page),
				bucket_width = bucket_width,
				world_width = bucket_width * #labels,
				bucket_top = math.max(2, rows - math.max(3, math.floor(rows * 0.22))),
				spawned = 0,
				settled = 0,
				total = #labels * 5,
				finished_at = nil,
			}
			for i = 1, #labels do
				state.counts[i] = 0
			end
			state.interval = math.max(1, math.floor(12 * fps / state.total))
		end,
		update = function(grid)
			state.frame = state.frame + 1
			if state.spawned < state.total and #state.balls < 40 and (state.frame - 1) % state.interval == 0 then
				state.spawned = state.spawned + 1
				-- Every bucket is reachable, including those on later pages.
				state.balls[#state.balls + 1] = {
					x = 1 + math.random() * math.max(0, state.world_width - 1),
					y = 1,
					vx = (math.random() - 0.5) * 0.3,
					vy = 0.3,
				}
			end
			local alive = {}
			for _, ball in ipairs(state.balls) do
				local old_row = math.floor(ball.y)
				ball.vy = math.min(0.75, ball.vy + 0.025)
				ball.y = ball.y + ball.vy
				ball.x = ball.x + ball.vx
				if ball.x < 1 or ball.x > state.world_width then
					ball.vx = -ball.vx
				end
				ball.x = math.max(1, math.min(state.world_width, ball.x))
				local row = math.floor(ball.y)
				local peg = row > old_row and peg_at(row, ball.x)
				if peg then
					local direction = math.random(2) == 1 and -1 or 1
					ball.vx, ball.vy = direction * 0.65, 0.25
					ball.x = math.max(1, math.min(state.world_width, peg + direction))
				end
				ball.vx = ball.vx * 0.97
				if ball.y >= state.bucket_top then
					local bucket = math.min(#state.labels, math.floor((ball.x - 1) / state.bucket_width) + 1)
					state.counts[bucket] = state.counts[bucket] + 1
					state.settled = state.settled + 1
				else
					alive[#alive + 1] = ball
				end
			end
			state.balls = alive
			if state.settled == state.total and not state.finished_at then
				local best, winners = -1, {}
				for i, count in ipairs(state.counts) do
					if count > best then
						best, winners = count, { i }
					elseif count == best then
						winners[#winners + 1] = i
					end
				end
				state.winner = winners[math.random(#winners)]
				state.finished_at = state.frame
				vim.notify("Plinko winner: " .. state.labels[state.winner] .. " (" .. best .. " balls)")
			end
			local page = state.winner and math.floor((state.winner - 1) / state.per_page)
				or math.floor(state.frame / (fps * 3)) % state.pages
			local offset = page * state.per_page * state.bucket_width
			U.clear(grid)
			for row = 3, state.bucket_top - 1, 2 do
				local first = 2 + ((row - 3) / 2) % 2 * 2
				local start = first + math.max(0, math.ceil((offset + 1 - first) / 4)) * 4
				for x = start, math.min(state.world_width - 1, offset + state.cols), 4 do
					U.plot(grid, x - offset, row, ".", "Comment")
				end
			end
			for i = page * state.per_page + 1, math.min(#state.labels, (page + 1) * state.per_page) do
				local left = (i - 1) * state.bucket_width + 1 - offset
				local width = state.bucket_width
				local color = COLORS[(i - 1) % #COLORS + 1]
				for r = state.bucket_top, state.rows - 2 do
					U.plot(grid, left, r, "|", color)
					local level = state.rows - 2 - r
					for x = 1, math.max(1, width - 2) do
						if level * math.max(1, width - 2) + x <= state.counts[i] then
							U.plot(grid, left + x, r, "o", color)
						end
					end
				end
				U.text(grid, left, state.rows - 1, U.truncate("[" .. state.counts[i] .. "]", width), color)
				U.text(grid, left, state.rows, U.truncate(state.labels[i], width), color)
			end
			for _, ball in ipairs(state.balls) do
				U.plot(grid, ball.x - offset, ball.y, "O", "WarningMsg")
			end
			local banner = state.winner and ("WINNER: " .. state.labels[state.winner])
				or string.format("Plinko %d/%d  page %d/%d", state.settled, state.total, page + 1, state.pages)
			U.text(grid, 1, 1, U.truncate(banner, state.cols), "Title")
			return not state.finished_at or state.frame - state.finished_at < fps * 3
		end,
	})
end

return M
