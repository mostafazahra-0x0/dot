-- duskember.lua
-- Custom colorscheme based on a warm dusk/autumn gradient palette
-- Place this file at: ~/.config/nvim/colors/duskember.lua
-- Then use it with: colorscheme = "duskember"

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.g.colors_name = "duskember"

local palette = {
  bg = "#2a2019", -- background
  bg_alt = "#332720", -- slightly lighter bg for statusline/floats
  bg_dark = "#1e1611", -- darker bg for sidebars
  fg = "#e8dcd0", -- warm off-white foreground
  fg_dim = "#a89a8c", -- dimmer foreground (line numbers, etc)

  blue_dusk = "#4a5a6b", -- gradient_color_1
  red_muted = "#a8503a", -- gradient_color_2
  orange_pri = "#c9762f", -- gradient_color_3
  orange_soft = "#d9975a", -- gradient_color_4
  yellow_aut = "#d4a94c", -- gradient_color_5

  error_red = "#c1443a",
  border = "#4a3a2e",
}

local hl = vim.api.nvim_set_hl

-- Editor UI
hl(0, "Normal", { fg = palette.fg, bg = palette.bg })
hl(0, "NormalFloat", { fg = palette.fg, bg = palette.bg_alt })
hl(0, "NormalNC", { fg = palette.fg, bg = palette.bg })
hl(0, "SignColumn", { bg = palette.bg })
hl(0, "LineNr", { fg = palette.fg_dim, bg = palette.bg })
hl(0, "CursorLineNr", { fg = palette.orange_pri, bold = true })
hl(0, "CursorLine", { bg = palette.bg_alt })
hl(0, "Visual", { bg = palette.blue_dusk, fg = palette.fg })
hl(0, "Search", { bg = palette.yellow_aut, fg = palette.bg })
hl(0, "IncSearch", { bg = palette.orange_pri, fg = palette.bg })
hl(0, "Pmenu", { fg = palette.fg, bg = palette.bg_dark })
hl(0, "PmenuSel", { fg = palette.bg, bg = palette.orange_pri })
hl(0, "StatusLine", { fg = palette.fg, bg = palette.bg_dark })
hl(0, "StatusLineNC", { fg = palette.fg_dim, bg = palette.bg_dark })
hl(0, "VertSplit", { fg = palette.border })
hl(0, "WinSeparator", { fg = palette.border })
hl(0, "Directory", { fg = palette.orange_soft })

-- Syntax
hl(0, "Comment", { fg = palette.blue_dusk, italic = true })
hl(0, "Constant", { fg = palette.yellow_aut })
hl(0, "String", { fg = palette.orange_soft })
hl(0, "Character", { fg = palette.orange_soft })
hl(0, "Number", { fg = palette.yellow_aut })
hl(0, "Boolean", { fg = palette.yellow_aut, bold = true })
hl(0, "Identifier", { fg = palette.fg })
hl(0, "Function", { fg = palette.orange_pri, bold = true })
hl(0, "Statement", { fg = palette.red_muted, bold = true })
hl(0, "Conditional", { fg = palette.red_muted })
hl(0, "Repeat", { fg = palette.red_muted })
hl(0, "Keyword", { fg = palette.red_muted, bold = true })
hl(0, "Operator", { fg = palette.fg })
hl(0, "PreProc", { fg = palette.blue_dusk })
hl(0, "Type", { fg = palette.yellow_aut })
hl(0, "Special", { fg = palette.orange_soft })
hl(0, "Underlined", { fg = palette.blue_dusk, underline = true })
hl(0, "Error", { fg = palette.error_red, bold = true })
hl(0, "Todo", { fg = palette.bg, bg = palette.yellow_aut, bold = true })

-- Diagnostics
hl(0, "DiagnosticError", { fg = palette.error_red })
hl(0, "DiagnosticWarn", { fg = palette.orange_pri })
hl(0, "DiagnosticInfo", { fg = palette.blue_dusk })
hl(0, "DiagnosticHint", { fg = palette.orange_soft })

-- Git signs (common with LazyVim)
hl(0, "GitSignsAdd", { fg = palette.yellow_aut })
hl(0, "GitSignsChange", { fg = palette.orange_pri })
hl(0, "GitSignsDelete", { fg = palette.red_muted })

-- Telescope / floats border
hl(0, "FloatBorder", { fg = palette.border, bg = palette.bg_alt })
