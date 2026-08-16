require('lazy').load({plugins={'nvim-treesitter'}})
local ts = require('nvim-treesitter')
ts.install({'c', 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline', 'cpp', 'python', 'cmake', 'bash'})

-- Wait for installation to finish
local timer = vim.loop.new_timer()
timer:start(500, 500, vim.schedule_wrap(function()
  -- If there are no active downloads/compilations, we could exit.
  -- But an easier way is just to wait 10 seconds and exit.
end))

vim.defer_fn(function() vim.cmd('qa') end, 15000)
