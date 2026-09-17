if vim.g.loaded_custom_cellular_automaton then
	return
end
vim.g.loaded_custom_cellular_automaton = 1

require("custom-cellular-automaton").setup()

vim.api.nvim_create_user_command("CellularAutomaton", function(opts)
	local menu = require("custom-cellular-automaton.menu")
	if opts.fargs[1] then
		menu.run(opts.fargs[1])
		return
	end
	menu.select(menu.run)
end, {
	nargs = "?",
	complete = function(_, line)
		local menu = require("custom-cellular-automaton.menu")
		local animation_list =
			vim.list_extend({ menu.RANDOM, menu.SHOWCASE }, vim.tbl_keys(require("cellular-automaton").animations))
		local l = vim.split(line, "%s+", {})
		if #l == 2 then
			return vim.tbl_filter(function(val)
				return vim.startswith(val, l[2])
			end, animation_list)
		end
	end,
})

for command, animation in pairs({ SpinWheel = "spin_wheel", Plinko = "plinko" }) do
	vim.api.nvim_create_user_command(command, function(opts)
		require("custom-cellular-automaton.selection").capture(opts)
		vim.cmd("CellularAutomaton " .. animation)
	end, { range = true })
end
