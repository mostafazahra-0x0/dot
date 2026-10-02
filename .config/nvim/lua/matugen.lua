 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '#fff8f3',
    base01 = '#f3ede8',
    base02 = '#ede7e2',
    base03 = '#7e766b',
    base04 = '#4d463c',
    base05 = '#1d1b19',
    base06 = '#1d1b19',
    base07 = '#1d1b19',
    base08 = '#ba1a1a',
    base09 = '#575f43',
    base0A = '#675d4e',
    base0B = '#6c593b',
    base0C = '#c1cba8',
    base0D = '#dcc39e',
    base0E = '#d3c4b3',
    base0F = '#efe0ce',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '#1d1b19',          bg = '#fff8f3' })
  hi('TelescopeBorder',         { fg = '#7e766b',             bg = '#fff8f3' })
  hi('TelescopePromptNormal',   { fg = '#1d1b19',          bg = '#fff8f3' })
  hi('TelescopePromptBorder',   { fg = '#7e766b',             bg = '#fff8f3' })
  hi('TelescopePromptPrefix',   { fg = '#6c593b',             bg = '#fff8f3' })
  hi('TelescopePromptCounter',  { fg = '#4d463c',  bg = '#fff8f3' })
  hi('TelescopePromptTitle',    { fg = '#fff8f3',             bg = '#6c593b' })
  hi('TelescopePreviewTitle',   { fg = '#fff8f3',             bg = '#675d4e' })
  hi('TelescopeResultsTitle',   { fg = '#fff8f3',             bg = '#575f43' })
  hi('TelescopeSelection',      { fg = '#1d1b19',          bg = '#ede7e2' })
  hi('TelescopeSelectionCaret', { fg = '#6c593b',             bg = '#ede7e2' })
  hi('TelescopeMatching',       { fg = '#6c593b',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '#1d1b19',          bg = '#fff8f3' })
  hi('MiniPickBorder',         { fg = '#7e766b',             bg = '#fff8f3' })
  hi('MiniPickPrompt',   { fg = '#1d1b19',          bg = '#fff8f3' })
  hi('MiniPickPromptPrefix',   { fg = '#6c593b',             bg = '#fff8f3' })
  hi('MiniPickBorderText',    { fg = '#fff8f3',             bg = '#6c593b' })
  hi('MiniPickMatchCurrent',      { fg = '#1d1b19',          bg = '#ede7e2' })
  hi('MiniPickPromptCaret', { fg = '#6c593b',             bg = '#ede7e2' })
  hi('MiniPickMatchRanges',       { fg = '#6c593b',             bold = true })
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
