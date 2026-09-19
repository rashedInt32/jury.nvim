-- Minimal init for the test suite: this plugin plus effect-error-pretty from
-- the sibling checkout (or $EFFECT_ERROR_PRETTY_PATH). No network: the spec
-- installs a fake transport.
local here = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(here, ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.jury_test_root = root

local pretty = vim.env.EFFECT_ERROR_PRETTY_PATH or (vim.fn.fnamemodify(root, ":h") .. "/effect-error-pretty.nvim")
if vim.fn.isdirectory(pretty) == 1 then
  vim.opt.rtp:prepend(pretty)
  vim.g.jury_test_pretty = pretty
end
vim.o.swapfile = false
