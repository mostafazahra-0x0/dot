 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#130d09',
    base01 = '#201811',
    base02 = '#271e16',
    base03 = '#827266',
    base04 = '#baa89a',
    base05 = '#f6e2d3',
    base06 = '#f6e2d3',
    base07 = '#f6e2d3',
    base08 = '#f97758',
    base09 = '#fffbd6',
    base0A = '#e2c0a5',
    base0B = '#f1bc8f',
    base0C = '#ede8a4',
    base0D = '#ebb78a',
    base0E = '#f1ceb2',
    base0F = '#ffdcc1',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#f6e2d3',          bg = '#130d09' })
  hi('TelescopeBorder',         { fg = '#827266',             bg = '#130d09' })
  hi('TelescopePromptNormal',   { fg = '#f6e2d3',          bg = '#130d09' })
  hi('TelescopePromptBorder',   { fg = '#827266',             bg = '#130d09' })
  hi('TelescopePromptPrefix',   { fg = '#f1bc8f',             bg = '#130d09' })
  hi('TelescopePromptCounter',  { fg = '#baa89a',  bg = '#130d09' })
  hi('TelescopePromptTitle',    { fg = '#130d09',             bg = '#f1bc8f' })
  hi('TelescopePreviewTitle',   { fg = '#130d09',             bg = '#e2c0a5' })
  hi('TelescopeResultsTitle',   { fg = '#130d09',             bg = '#fffbd6' })
  hi('TelescopeSelection',      { fg = '#f6e2d3',          bg = '#271e16' })
  hi('TelescopeSelectionCaret', { fg = '#f1bc8f',             bg = '#271e16' })
  hi('TelescopeMatching',       { fg = '#f1bc8f',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#f6e2d3',          bg = '#130d09' })
  hi('MiniPickBorder',         { fg = '#827266',             bg = '#130d09' })
  hi('MiniPickPrompt',   { fg = '#f6e2d3',          bg = '#130d09' })
  hi('MiniPickPromptPrefix',   { fg = '#f1bc8f',             bg = '#130d09' })
  hi('MiniPickBorderText',    { fg = '#130d09',             bg = '#f1bc8f' })
  hi('MiniPickMatchCurrent',      { fg = '#f6e2d3',          bg = '#271e16' })
  hi('MiniPickPromptCaret', { fg = '#f1bc8f',             bg = '#271e16' })
  hi('MiniPickMatchRanges',       { fg = '#f1bc8f',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
