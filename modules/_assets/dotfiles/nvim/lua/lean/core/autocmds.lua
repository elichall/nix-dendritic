local my_theme_group = vim.api.nvim_create_augroup("LanguageThemes", { clear = true })

-- Target scope isolation for prose-centric filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "tex" },
  callback = function(args)
    -- Spell checking
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { "en_us" }
    
    -- Word processing behavior
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.colorcolumn = ""
    vim.opt_local.list = false
    
    -- (Optional) Hide markdown syntax markers
    -- vim.opt_local.conceallevel = 2

    -- Make j and k move visually instead of by physical line
    vim.keymap.set({"n", "v"}, "j", "gj", { buffer = args.buf })
    vim.keymap.set({"n", "v"}, "k", "gk", { buffer = args.buf })
  end,
  desc = "Local spell check and word-processor settings for structural prose",
})

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  group = my_theme_group,
  callback = function(args)
    vim.schedule(function()
      local buf = args.buf
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local ft = vim.bo[buf].filetype
      local buftype = vim.bo[buf].buftype

      -- Ignore non-normal buffers (like terminals, help, Telescope, NvimTree, Oil)
      if buftype ~= "" then
        return
      end

      if ft == "markdown" or ft == "tex" or ft == "plaintex" then
        vim.cmd("colorscheme melange")
      elseif ft == "cpp" or ft == "c" then
        vim.cmd("colorscheme vague")
      elseif ft == "python" then
        vim.cmd("colorscheme dark2026")
      else
        -- Attempt to load custom default theme, fallback to standard package on failure
        local theme_ok, _ = pcall(vim.cmd, "colorscheme lean_sync")
        if not theme_ok then
          vim.cmd("colorscheme rose-pine")
        end
      end
    end)
  end,
})
