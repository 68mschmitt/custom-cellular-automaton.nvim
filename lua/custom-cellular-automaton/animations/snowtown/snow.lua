-- Falling particles and settled snow are separate from text and object glyphs.
local U = require("custom-cellular-automaton.util")
local Snow = {}
Snow.__index = Snow

function Snow.new(config)
	local self = setmetatable(
		{ DENSITY = 0.005, WIND_AMPL = 1, WIND_FREQ = 0.08, TTL_MIN = 30, TTL_MAX = 90, flakes = {}, ttl = {} },
		Snow
	)
	for key, value in pairs(config or {}) do
		self[key] = value
	end
	return self
end

function Snow:attach(grid)
	self.flakes, self.ttl = {}, {}
	for r, row in ipairs(grid) do
		self.ttl[r] = {}
		for c = 1, #row do
			self.ttl[r][c] = 0
		end
	end
	return self
end

function Snow:tick(grid, _, time)
	local rows, cols = U.size(grid)
	local function empty(r, c)
		local cell = grid[r] and grid[r][c]
		-- A continuation cell belongs to a wide text glyph and is not free space.
		return cell and cell.char == " " and self.ttl[r][c] == 0
	end
	-- Age exactly once, independently of which glyph was rendered last frame.
	for r, row in ipairs(self.ttl) do
		for c, life in ipairs(row) do
			row[c] = math.max(0, life - 1)
			if grid[r][c].char ~= " " and grid[r][c].char ~= "" then
				row[c] = 0
			end
		end
	end
	for c = 1, cols do
		if #self.flakes < 240 and empty(1, c) and math.random() < self.DENSITY then
			self.flakes[#self.flakes + 1] =
				{ x = c, y = 1, speed = 0.2 + math.random() * 0.25, char = math.random() < 0.2 and "*" or "." }
		end
	end
	local wind = math.sin(time * self.WIND_FREQ * 2 * math.pi) * self.WIND_AMPL
	local alive = {}
	for _, flake in ipairs(self.flakes) do
		local r, c = math.floor(flake.y + 0.5), math.floor(flake.x + 0.5)
		local nx = math.max(1, math.min(cols, flake.x + wind * 0.16))
		local nc = math.floor(nx + 0.5)
		if empty(r, nc) then
			flake.x, c = nx, nc
		end
		if r < rows and empty(r + 1, c) then
			flake.y = flake.y + flake.speed
			alive[#alive + 1] = flake
		else
			local dir = wind >= 0 and 1 or -1
			if r < rows and empty(r + 1, c + dir) then
				flake.x, flake.y = c + dir, r + 1
				alive[#alive + 1] = flake
			elseif empty(r, c) then
				self.ttl[r][c] = math.random(self.TTL_MIN, self.TTL_MAX)
			end
		end
	end
	self.flakes = alive
	for r, row in ipairs(self.ttl) do
		for c, life in ipairs(row) do
			if life > 0 then
				U.plot(grid, c, r, ".", "Comment")
			end
		end
	end
	for _, flake in ipairs(alive) do
		local r, c = math.floor(flake.y + 0.5), math.floor(flake.x + 0.5)
		if empty(r, c) then
			U.plot(grid, c, r, flake.char, "Special")
		end
	end
end

return Snow
