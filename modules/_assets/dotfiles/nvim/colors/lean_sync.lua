-- Clear existing configurations safely
vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "lean_sync"

-- Load the static palette safely
local ok, c = pcall(require, "lean.core.palette")
if not ok then
  return -- Terminates execution if structural layout file is missing
end

-- Unified high-level utility function
local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- ==============================================================================
-- NATIVE VIM CORE INTERFACES
-- ==============================================================================
hi("Normal", { fg = c.white, bg = "none" })    -- Keeps background fully transparent for multiplexer integration
hi("NormalFloat", { fg = c.white, bg = c.bg }) -- Floating windows handle explicit canvas bounds
hi("Comment", { fg = c.gray, italic = true })
hi("Constant", { fg = c.magenta })
hi("String", { fg = c.green })
hi("Character", { fg = c.green })
hi("Number", { fg = c.magenta })
hi("Boolean", { fg = c.magenta })
hi("Float", { fg = c.magenta })
hi("Identifier", { fg = c.white })
hi("Function", { fg = c.yellow })
hi("Statement", { fg = c.blue })
hi("Conditional", { fg = c.blue })
hi("Repeat", { fg = c.blue })
hi("Label", { fg = c.blue })
hi("Operator", { fg = c.cyan })
hi("Keyword", { fg = c.blue })
hi("Exception", { fg = c.red })
hi("PreProc", { fg = c.magenta })
hi("Type", { fg = c.cyan })
hi("Special", { fg = c.yellow })
hi("Delimiter", { fg = c.white })
hi("Underlined", { underline = true })
hi("Bold", { bold = true })
hi("Italic", { italic = true })
hi("Error", { fg = c.red, bold = true })
hi("Todo", { fg = c.yellow, bold = true })
-- ==============================================================================
-- BLINK.CMP FLOATING INTERFACE OVERRIDES
-- ==============================================================================
hi("BlinkCmpMenu", { fg = c.white, bg = c.black })
hi("BlinkCmpMenuBorder", { fg = c.black, bg = c.bg })
hi("BlinkCmpDoc", { fg = c.white, bg = c.black })
hi("BlinkCmpDocBorder", { fg = c.black, bg = c.bg })

-- Active row highlighting: stark black text on clear solid white banner
hi("BlinkCmpSelection", { fg = "#161616", bg = "#dfdfe0", bold = true })

-- Semantic Token Highlighting within suggestion panel
hi("BlinkCmpLabel", { fg = c.white })
hi("BlinkCmpLabelMatch", { fg = c.yellow, bold = true }) -- Colors matched characters
hi("BlinkCmpKind", { fg = c.cyan })
-- ==============================================================================
-- MODERN TREESITTER AST PARSING EXTENSIONS
-- ==============================================================================
hi("@comment", { link = "Comment" })
hi("@variable", { fg = c.white })
hi("@variable.builtin", { fg = c.red, italic = true })
hi("@variable.parameter", { fg = c.white, italic = true })
hi("@member", { fg = c.cyan })
hi("@property", { fg = c.cyan })
hi("@keyword", { link = "Keyword" })
hi("@keyword.function", { fg = c.blue })
hi("@keyword.return", { fg = c.blue })
hi("@function", { link = "Function" })
hi("@function.builtin", { fg = c.yellow, bold = true })
hi("@function.call", { fg = c.yellow })
hi("@string", { link = "String" })
hi("@number", { link = "Number" })
hi("@boolean", { link = "Boolean" })
hi("@type", { link = "Type" })
hi("@type.builtin", { fg = c.cyan, italic = true })
hi("@constant", { link = "Constant" })
hi("@constant.builtin", { fg = c.magenta, bold = true })
hi("@operator", { link = "Operator" })
hi("@punctuation.bracket", { fg = c.white })
hi("@punctuation.delimiter", { fg = c.white })

-- ==============================================================================
-- UI TELEMETRY INTERFACES
-- ==============================================================================
hi("LineNr", { fg = c.gray })
hi("CursorLineNr", { fg = c.yellow, bold = true })
hi("WinSeparator", { fg = c.black })
hi("SignColumn", { bg = "none" })
hi("Title", { fg = c.blue, bold = true })
hi("Directory", { fg = c.blue })

-- ==============================================================================
-- MINI.STATUSLINE PERFORMANCE HIGH-CONTRAST THEME BINDINGS
-- ==============================================================================
-- Mode indicators mapping text background to active terminal colors
hi("MiniStatuslineModeNormal", { fg = "#161616", bg = c.blue, bold = true })
hi("MiniStatuslineModeInsert", { fg = "#161616", bg = c.green, bold = true })
hi("MiniStatuslineModeVisual", { fg = "#161616", bg = c.magenta, bold = true })
hi("MiniStatuslineModeCommand", { fg = "#161616", bg = c.yellow, bold = true })

-- Center content blocks mapping to your standard dark panel canvas background
hi("MiniStatuslineDevinfo", { fg = c.white, bg = c.black })     -- Git / Diagnostic Telemetry
hi("MiniStatuslineFilename", { fg = c.white, bg = c.black })    -- Active file path string
hi("MiniStatuslineFileinfo", { fg = c.white, bg = c.black })    -- Filetype details
hi("StatusLine", { fg = c.white, bg = c.black })                -- Inactive window boundaries

-- Oil.nvim file browser alignments
hi("OilDir", { fg = c.blue, bold = true })
hi("OilLink", { fg = c.cyan, underline = true })
