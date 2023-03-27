if vim.g.vscode then
  require("brizdotdev.core.vscode")
elseif vim.g.neovide then
  require("brizdotdev.core.neovide")
  require("brizdotdev.plugins.lazy")
else
  require("brizdotdev.core.terminal")
  require("brizdotdev.plugins.lazy")
end

require("brizdotdev.core.keymaps")
require("brizdotdev.core.options")