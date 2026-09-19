local M = {}

local SUB = { "status", "judge", "clear" }

function M.setup()
  vim.api.nvim_create_user_command("Jury", function(cmd)
    local sub = cmd.fargs[1] or "status"
    local jury = require("jury")
    if not vim.tbl_contains(SUB, sub) then
      vim.notify("Jury: status | judge | clear", vim.log.levels.ERROR)
      return
    end
    jury[sub]()
  end, {
    nargs = "?",
    complete = function()
      return SUB
    end,
    desc = "jury: calibrated picks",
  })
end

return M
