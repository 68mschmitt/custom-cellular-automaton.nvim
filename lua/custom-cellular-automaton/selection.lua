local M = {}
local pending

local function lines(first, last)
	if first <= 0 or last <= 0 then
		return {}
	end
	first, last = math.min(first, last), math.max(first, last)
	return vim.api.nvim_buf_get_lines(0, first - 1, last, false)
end

function M.capture(opts)
	local mode = vim.fn.mode():sub(1, 1)
	if opts.range > 0 then
		pending = lines(opts.line1, opts.line2)
	elseif mode == "v" or mode == "V" or mode == "\22" then
		pending = lines(vim.fn.getpos("v")[2], vim.api.nvim_win_get_cursor(0)[1])
	else
		pending = {}
	end
end

function M.labels()
	local source = pending
	pending = nil
	if not source then
		source = lines(vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2])
	end
	local labels = {}
	for _, line in ipairs(source) do
		local text = vim.trim(line)
		if text ~= "" then
			labels[#labels + 1] = text
		end
	end
	if #labels == 0 then
		return { "Option 1", "Option 2", "Option 3", "Option 4", "Option 5" }
	end
	return labels
end

return M
