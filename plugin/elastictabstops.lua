local ets_ns = vim.api.nvim_create_namespace('elastictabstops.nvim')
local ets_group = vim.api.nvim_create_augroup('elastictabstops.nvim', { clear = true })

local function create_extmark(bufnr, line, column, virt_text, virt_text_pos)
  return vim.api.nvim_buf_set_extmark(bufnr, ets_ns, line, column, {
    virt_text = { { virt_text } },
    virt_text_pos = virt_text_pos,
    hl_mode = 'combine',
  })
end

local function render_elastic_tabstops(bufnr, tabs)
  for line_idx, tab_list in ipairs(tabs) do
    for _, tab_pos in ipairs(tab_list) do
      create_extmark(bufnr, line_idx - 1, tab_pos.col - 1, '  ', 'overlay') -- hide tab character
      create_extmark(bufnr, line_idx - 1, tab_pos.col, string.rep(' ', tab_pos.virt_col), 'inline')
    end
  end
end

local function clear_elastic_tabstops(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ets_ns, 0, -1)
end

vim.api.nvim_create_user_command('ElasticTabstops', function(opts)
  if opts.args == "" then
    vim.b.elastictabstops = not vim.b.elastictabstops
  elseif opts.args == "enable" then
    vim.b.elastictabstops = true
  elseif opts.args == "disable" then
    vim.b.elastictabstops = false
  else
    vim.api.nvim_echo({ { "ElasticTabstops: Invalid option" } }, false, { err = true })
    return
  end

  if vim.b.elastictabstops then
    -- set local options
    vim.opt_local.list = true
    local listchars = vim.opt_global.listchars:get()
    listchars.tab = nil -- hack
    vim.opt_local.listchars = listchars
    vim.opt_local.expandtab = false

    local bufnr = vim.api.nvim_get_current_buf()
    local ets = require("elastictabstops")

    -- set autocommands
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = ets_group,
      buffer = bufnr,
      callback = function(ev)
        clear_elastic_tabstops(ev.buf)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        render_elastic_tabstops(ev.buf, ets.parse_elastic_tabstops(lines))
      end
    })

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    render_elastic_tabstops(bufnr, ets.parse_elastic_tabstops(lines))
  else
    -- reset options
    vim.opt_local.list = vim.opt_global.list:get()
    vim.opt_local.listchars = vim.opt_global.listchars:get()
    vim.opt_local.expandtab = vim.opt_global.expandtab:get()

    local bufnr = vim.api.nvim_get_current_buf()
    -- clear extmarks
    clear_elastic_tabstops(bufnr)

    -- remove autocommands
    local autocommands = vim.api.nvim_get_autocmds({
      buffer = bufnr,
      group = ets_group,
    })

    for _, autocmd in ipairs(autocommands) do
      vim.api.nvim_del_autocmd(autocmd.id)
    end
  end
end, {
  desc = "Toggle Elastic Tabstops on current buffer",
  nargs = "?",
  complete = function(arg_lead, cmd_line)
    return vim.tbl_filter(function(val)
      return vim.startswith(val, arg_lead)
    end, { "disable", "enable" })
  end
})
