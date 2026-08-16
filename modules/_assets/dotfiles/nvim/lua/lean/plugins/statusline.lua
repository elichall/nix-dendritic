-- lua/lean/plugins/statusline.lua
return {
  {
    "echasnovski/mini.statusline",
    version = false, -- Tracks latest release stream
    event = "VimEnter",
    config = function()
      local statusline = require("mini.statusline")

      statusline.setup({
        -- Integrates mode changes with native editor settings
        set_vim_settings = true,
      })
   end,
  },
}
