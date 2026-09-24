 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#130d09',
    base01 = '#211811',
    base02 = '#281e16',
    base03 = '#837267',
    base04 = '#bba79b',
    base05 = '#f7e1d4',
    base06 = '#f7e1d4',
    base07 = '#f7e1d4',
    base08 = '#f97758',
    base09 = '#fff9e6',
    base0A = '#e4c0a6',
    base0B = '#f3bb91',
    base0C = '#eee4a0',
    base0D = '#eab38a',
    base0E = '#f2cdb4',
    base0F = '#ffdcc4',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#f7e1d4',          bg = '#130d09' })
  hi('TelescopeBorder',         { fg = '#837267',             bg = '#130d09' })
  hi('TelescopePromptNormal',   { fg = '#f7e1d4',          bg = '#130d09' })
  hi('TelescopePromptBorder',   { fg = '#837267',             bg = '#130d09' })
  hi('TelescopePromptPrefix',   { fg = '#f3bb91',             bg = '#130d09' })
  hi('TelescopePromptCounter',  { fg = '#bba79b',  bg = '#130d09' })
  hi('TelescopePromptTitle',    { fg = '#130d09',             bg = '#f3bb91' })
  hi('TelescopePreviewTitle',   { fg = '#130d09',             bg = '#e4c0a6' })
  hi('TelescopeResultsTitle',   { fg = '#130d09',             bg = '#fff9e6' })
  hi('TelescopeSelection',      { fg = '#f7e1d4',          bg = '#281e16' })
  hi('TelescopeSelectionCaret', { fg = '#f3bb91',             bg = '#281e16' })
  hi('TelescopeMatching',       { fg = '#f3bb91',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#f7e1d4',          bg = '#130d09' })
  hi('MiniPickBorder',         { fg = '#837267',             bg = '#130d09' })
  hi('MiniPickPrompt',   { fg = '#f7e1d4',          bg = '#130d09' })
  hi('MiniPickPromptPrefix',   { fg = '#f3bb91',             bg = '#130d09' })
  hi('MiniPickBorderText',    { fg = '#130d09',             bg = '#f3bb91' })
  hi('MiniPickMatchCurrent',      { fg = '#f7e1d4',          bg = '#281e16' })
  hi('MiniPickPromptCaret', { fg = '#f3bb91',             bg = '#281e16' })
  hi('MiniPickMatchRanges',       { fg = '#f3bb91',             bold = true })
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
