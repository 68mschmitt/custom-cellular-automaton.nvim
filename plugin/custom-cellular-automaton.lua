if vim.g.loaded_custom_cellular_automaton then
	return
end
vim.g.loaded_custom_cellular_automaton = 1

require("custom-cellular-automaton").setup()

for command, animation in pairs({ SpinWheel = "spin_wheel", Plinko = "plinko" }) do
	vim.api.nvim_create_user_command(command, function(opts)
		require("custom-cellular-automaton.selection").capture(opts)
		vim.cmd("CellularAutomaton " .. animation)
	end, { range = true })
end
