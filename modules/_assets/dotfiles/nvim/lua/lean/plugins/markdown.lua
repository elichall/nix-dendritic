return {
  {
    "kcayme/md-view.nvim",
    cmd = { "MdView", "MdViewStop", "MdViewToggle", "MdViewList" },
    ft = "markdown",
    keys = {
      {
        "<leader>P",
        ft = "markdown",
        "<cmd>MdViewToggle<cr>",
        desc = "Toggle Markdown Preview",
      },
    },
    config = function()
      require("md-view").setup({
        auto_close = false,
        theme = { mode = "auto" },
      })
    end,
  },
}
