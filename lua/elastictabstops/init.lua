local ets_ns = vim.api.nvim_create_namespace('elastictabstops.nvim')
local ets_group = vim.api.nvim_create_augroup('elastictabstops.nvim', { clear = true })

local function create_extmark(bufnr, line, column, virt_text, virt_text_pos)
  return vim.api.nvim_buf_set_extmark(bufnr, ets_ns, line, column, {
    virt_text = { { virt_text } },
    virt_text_pos = virt_text_pos,
    hl_mode = 'combine',
  })
end

local function get_virt_col_sum(tabs, line_idx, tab_idx)
  if tabs[line_idx] == nil or tabs[line_idx][tab_idx] == nil then
    return 0
  end

  return tabs[line_idx][tab_idx].virt_col + get_virt_col_sum(tabs, line_idx, tab_idx - 1)
end


local function get_max_tab_column_index(tabs, line_idx, tab_idx, step)
  if tabs[line_idx] == nil or tabs[line_idx][tab_idx] == nil then
    return -1
  end

  local tab_pos = tabs[line_idx][tab_idx]
  return math.max(
    tab_pos.col + tab_pos.virt_col + get_virt_col_sum(tabs, line_idx, tab_idx - 1),
    get_max_tab_column_index(tabs, line_idx + step, tab_idx, step))
end

local function get_farthest_adjacent_tab_column(tabs, line_idx, tab_idx)
  return math.max(
    get_max_tab_column_index(tabs, line_idx, tab_idx, 1),
    get_max_tab_column_index(tabs, line_idx, tab_idx, -1))
end

local function align_tab_index(bufnr, tabs, line_idx, tab_idx)
  if tabs[line_idx] == nil or tabs[line_idx][tab_idx] == nil then
    return false
  end

  local farthest_adjacent_column = get_farthest_adjacent_tab_column(tabs, line_idx, tab_idx)
  local tab_pos = tabs[line_idx][tab_idx]
  local virt_col_sum = get_virt_col_sum(tabs, line_idx, tab_idx - 1)
  if farthest_adjacent_column > tab_pos.col + virt_col_sum then
    tab_pos.virt_col = farthest_adjacent_column - tab_pos.col - virt_col_sum
    create_extmark(bufnr, line_idx - 1, tab_pos.col, string.rep(' ', tab_pos.virt_col), 'inline')
  end
  return true
end

local function clear_elastic_tabstops(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ets_ns, 0, -1)
end

local function render_elastic_tabstops(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- replace tab nil character
  local tabs = {}
  for line_idx, line in ipairs(lines) do
    local tab_idx = 1
    local tab_list = {}
    local line_bytes = { line:byte(1, #line) }
    for column = 1, #line_bytes do
      if string.char(line_bytes[column]) == '\t' then
        create_extmark(bufnr, line_idx - 1, column - 1, '  ', 'overlay')
        tab_list[tab_idx] = { col = column, virt_col = 0 }
        tab_idx = tab_idx + 1
      end
    end
    if tab_idx > 1 then
      tabs[line_idx] = tab_list
    end
  end

  -- add elastic tabstops
  local tab_idx = 0
  local try_next = true
  while try_next do
    tab_idx = tab_idx + 1
    try_next = false

    for line_idx, _ in pairs(tabs) do
      local found = align_tab_index(bufnr, tabs, line_idx, tab_idx)
      try_next = try_next or found
    end
  end

end

local M = {}

M.setup = function()

  vim.api.nvim_create_user_command('ElasticTabstopsEnable', function()
    -- set local options
    vim.opt_local.list = true
    local listchars = vim.opt_global.listchars:get()
    listchars.tab = nil -- hack
    vim.opt_local.listchars = listchars
    vim.opt_local.expandtab = false

    local bufnr = vim.api.nvim_get_current_buf()
    -- create extmarks
    render_elastic_tabstops(bufnr)

    -- set autocommands
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = ets_group,
      buffer = bufnr,
      callback = function(ev)
        clear_elastic_tabstops(ev.buf)
        render_elastic_tabstops(ev.buf)
      end
    })
  end, {})

  vim.api.nvim_create_user_command('ElasticTabstopsDisable', function()
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
  end, {})

end

return M
