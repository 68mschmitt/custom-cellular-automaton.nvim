if vim.g.loaded_custom_cellular_automaton then
  return
end
vim.g.loaded_custom_cellular_automaton = 1

require("custom-cellular-automaton").setup()
