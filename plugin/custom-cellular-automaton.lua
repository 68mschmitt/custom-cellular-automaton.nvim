if vim.g.loaded_custom_cellular_automaton then
  return
end
vim.g.loaded_custom_cellular_automaton = 1

require("custom-cellular-automaton").setup()

-- Create a helper command for SpinWheel that explicitly captures selection
vim.api.nvim_create_user_command('SpinWheel', function(opts)
  -- Store the visual selection range before running the animation
  if opts.range > 0 then
    -- Visual selection was used
    local start_line = opts.line1
    local end_line = opts.line2
    
    -- Store in global variable for the animation to access
    vim.g.spin_wheel_selection = {
      start_line = start_line,
      end_line = end_line,
    }
  else
    vim.g.spin_wheel_selection = nil
  end
  
  -- Run the animation
  vim.cmd('CellularAutomaton spin_wheel')
end, { range = true })
