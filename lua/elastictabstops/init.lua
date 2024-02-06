local ets_ns = vim.api.nvim_create_namespace('elastictabstops.nvim')
local ets_group = vim.api.nvim_create_augroup('elastictabstops.nvim', { clear = true })

local function create_extmark(bufnr, line, column, virt_text, virt_text_pos)
  return vim.api.nvim_buf_set_extmark(bufnr, ets_ns, line, column, {
    virt_text = { { virt_text } },
    virt_text_pos = virt_text_pos,
    hl_mode = 'combine',
  })
end

local function get_max_tab_column_index(tabs, line_idx, tab_idx, step)
  if tabs[line_idx] == nil or tabs[line_idx][tab_idx] == nil then
    return -1
  end

  local tab_pos = tabs[line_idx][tab_idx]
  return math.max(tab_pos.col + tab_pos.virt_col, get_max_tab_column_index(tabs, line_idx + step, tab_idx, step))
end

local function get_higher_adjacent_tab_column(tabs, line_idx, tab_idx)
  return math.max(get_max_tab_column_index(tabs, line_idx, tab_idx, 1),
    get_max_tab_column_index(tabs, line_idx, tab_idx, -1))
end

local function align_tab_index(bufnr, tabs, line_idx, tab_idx)
  if tabs[line_idx] == nil or tabs[line_idx][tab_idx] == nil then
    return false
  end

  local longestAdjacentColumn = get_higher_adjacent_tab_column(tabs, line_idx, tab_idx)
  local tab_pos = tabs[line_idx][tab_idx]
  if longestAdjacentColumn > tab_pos.col + tab_pos.virt_col then
    local distance = longestAdjacentColumn - tab_pos.col - tab_pos.virt_col
    create_extmark(bufnr, line_idx, tab_pos.col + 1, string.rep(' ', distance), 'inline')
    tab_pos.virt_col = tab_pos.virt_col + distance
    -- update next tabs virt_col if any
    if tabs[line_idx][tab_idx + 1] ~= nil then
      for i = tab_idx + 1, #tabs[line_idx] do
        tabs[line_idx][i].virt_col = tabs[line_idx][i].virt_col + tab_pos.virt_col
      end
    end
  end
  return true
end

local function add_elastic_tab_stop(bufnr, tabs)
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

local function replace_tabs(bufnr)
  local tabs = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for line_idx, line in ipairs(lines) do
    local tab_idx = 1
    local tab_list = {}
    local line_bytes = { line:byte(1, #line) }
    for column = 1, #line_bytes do
      if string.char(line_bytes[column]) == '\t' then
        create_extmark(bufnr, line_idx - 1, column - 1, '  ', 'overlay')
        tab_list[tab_idx] = { col = column - 1, virt_col = 0 }
        tab_idx = tab_idx + 1
      end
    end
    if tab_idx > 1 then
      tabs[line_idx - 1] = tab_list
    end
  end

  add_elastic_tab_stop(bufnr, tabs)
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
    replace_tabs(bufnr)

    -- set autocommands
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = ets_group,
      buffer = bufnr,
      callback = function(ev)
        vim.api.nvim_buf_clear_namespace(ev.buf, ets_ns, 0, -1)
        replace_tabs(ev.buf)
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
    vim.api.nvim_buf_clear_namespace(bufnr, ets_ns, 0, -1)

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
