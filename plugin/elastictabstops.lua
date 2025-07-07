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
  for line_idx, tab_list in pairs(tabs) do
    for _, tab_pos in pairs(tab_list) do
      create_extmark(bufnr, line_idx - 1, tab_pos.col - 1, '  ', 'overlay') -- hide tab character
      create_extmark(bufnr, line_idx - 1, tab_pos.col, string.rep(' ', tab_pos.virt_col), 'inline')
    end
  end
end

local function clear_elastic_tabstops(bufnr, line_start, line_end)
  vim.api.nvim_buf_clear_namespace(bufnr, ets_ns, line_start, line_end)
end

---@param line string
local function is_line_empty(line)
  return line:match("^%s*$")
end

---@return number, number, string[]
local function get_current_paragraph_lines()
  local current_line = vim.fn.line(".")
  local current_line_content = vim.fn.getline(current_line)

  if is_line_empty(current_line_content) then
    return current_line, current_line, { current_line_content }
  end

  local paragraph_lines = {}
  local paragraph_start = current_line

  -- Find paragraph start and collect lines above
  for i = current_line - 1, 1, -1 do
    local line_content = vim.fn.getline(i)
    if is_line_empty(line_content) then
      break
    end
    paragraph_lines[i] = line_content
    paragraph_start = i
  end

  paragraph_lines[current_line] = current_line_content

  local last_buffer_line = vim.fn.line("$")
  local paragraph_end = current_line
  -- Find paragraph end and collect lines below
  for i = current_line + 1, last_buffer_line do
    local line_content = vim.fn.getline(i)
    if is_line_empty(line_content) then
      break
    end
    paragraph_lines[i] = line_content
    paragraph_end = i
  end

  return paragraph_start, paragraph_end, paragraph_lines
end

vim.api.nvim_create_user_command("ElasticTabstops", function(opts)
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

    -- set autocmds
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = ets_group,
      buffer = bufnr,
      callback = function(ev)
        local first, last, lines = get_current_paragraph_lines()
        clear_elastic_tabstops(ev.buf, first - 1, last)
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
    clear_elastic_tabstops(bufnr, 0, -1)

    -- remove autocommands
    local autocmds = vim.api.nvim_get_autocmds({
      buffer = bufnr,
      group = ets_group,
    })

    for _, autocmd in ipairs(autocmds) do
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
