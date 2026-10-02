local colors = require("noctalia-colors")

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local c = colors

        -- Base
        vim.api.nvim_set_hl(0, "Normal", {
          fg = c.foreground,
          bg = c.background,
        })

        vim.api.nvim_set_hl(0, "NormalNC", {
          fg = c.foreground,
          bg = c.background,
        })

        vim.api.nvim_set_hl(0, "NormalFloat", {
          fg = c.foreground,
          bg = c.surface,
        })

        -- Cursor
        vim.api.nvim_set_hl(0, "CursorLine", {
          bg = c.surface_variant,
        })

        vim.api.nvim_set_hl(0, "CursorLineNr", {
          fg = c.primary,
          bold = true,
        })

        -- Line numbers
        vim.api.nvim_set_hl(0, "LineNr", {
          fg = c.outline,
        })

        -- Selection
        vim.api.nvim_set_hl(0, "Visual", {
          fg = c.on_primary,
          bg = c.primary,
        })

        -- Borders
        vim.api.nvim_set_hl(0, "FloatBorder", {
          fg = c.outline,
          bg = c.surface,
        })

        -- Text
        vim.api.nvim_set_hl(0, "Comment", {
          fg = c.outline,
          italic = true,
        })

        vim.api.nvim_set_hl(0, "String", {
          fg = c.tertiary,
        })

        vim.api.nvim_set_hl(0, "Function", {
          fg = c.primary,
        })

        vim.api.nvim_set_hl(0, "Keyword", {
          fg = c.secondary,
        })

        -- Errors
        vim.api.nvim_set_hl(0, "Error", {
          fg = c.error,
        })

        vim.api.nvim_set_hl(0, "DiagnosticError", {
          fg = c.error,
        })

        -- Statusline
        vim.api.nvim_set_hl(0, "StatusLine", {
          fg = c.foreground,
          bg = c.surface,
        })

        vim.api.nvim_set_hl(0, "StatusLineNC", {
          fg = c.outline,
          bg = c.surface,
        })
      end,
    },
  },
}
