return {
  {
    "lervag/vimtex",
    lazy = false, -- VimTeX recommends not lazy-loading as it manages its own lazy-loading internally
    keys = {
      {
        "<leader>P",
        ft = "tex",
        "<cmd>VimtexCompile<cr>",
        desc = "Compile and Preview LaTeX",
      },
    },
    init = function()
      -- Use xdg-open to open the PDF in the system's default viewer (which is often the browser on Linux)
      vim.g.vimtex_view_general_viewer = "xdg-open"
      
      -- Optional: If you explicitly want to force a specific browser, you can comment the above line and uncomment one of these:
      -- vim.g.vimtex_view_general_viewer = "google-chrome"
      -- vim.g.vimtex_view_general_viewer = "firefox"

      -- Do not open viewer automatically during compilation if you want to control it manually, 
      -- but usually people want it to pop up.
      vim.g.vimtex_view_automatic = 1
    end,
  },
}
