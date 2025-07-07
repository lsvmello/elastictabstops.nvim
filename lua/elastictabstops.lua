---@class TabstopPosition
---@field col number
---@field virt_col number
---@field prev_virt_col_sum number

local function get_max_tab_column_index(tabs, line_idx, tab_idx, step)
  if tabs[line_idx] == nil then
    return -1
  end
  if tabs[line_idx][tab_idx] == nil then
    return get_max_tab_column_index(tabs, line_idx + step, tab_idx, step)
  end

  local tab_pos = tabs[line_idx][tab_idx]
  return math.max(
    tab_pos.col + tab_pos.virt_col + tab_pos.prev_virt_col_sum,
    get_max_tab_column_index(tabs, line_idx + step, tab_idx, step))
end

local function get_farthest_adjacent_tab_column(tabs, line_idx, tab_idx)
  return math.max(
    get_max_tab_column_index(tabs, line_idx, tab_idx, 1),
    get_max_tab_column_index(tabs, line_idx, tab_idx, -1))
end

local function align_tab_index(tabs, line_idx, tab_idx)
  if tabs[line_idx] == nil or tabs[line_idx][tab_idx] == nil then
    return false
  end

  local farthest_adjacent_column = get_farthest_adjacent_tab_column(tabs, line_idx, tab_idx)
  local tab_pos = tabs[line_idx][tab_idx]
  if farthest_adjacent_column > tab_pos.col + tab_pos.prev_virt_col_sum then
    tab_pos.virt_col = farthest_adjacent_column - tab_pos.col - tab_pos.prev_virt_col_sum
  end
  if tabs[line_idx][tab_idx + 1] then
    tabs[line_idx][tab_idx + 1].prev_virt_col_sum = tab_pos.virt_col + tab_pos.prev_virt_col_sum
  end
  return true
end

local M = {}

M.parse_elastic_tabstops = function(lines)

  -- replace tab nil character
  local tabs = {}
  for line_idx, line in pairs(lines) do
    local tab_idx = 1
    ---@type TabstopPosition[]
    local tab_list = {}
    local line_bytes = { line:byte(1, #line) }
    for column = 1, #line_bytes do
      if string.char(line_bytes[column]) == '\t' then
        tab_list[tab_idx] = { col = column, virt_col = 0, prev_virt_col_sum = 0 }
        tab_idx = tab_idx + 1
      end
    end
    tabs[line_idx] = tab_list
  end

  -- add elastic tabstops
  local tab_idx = 0
  local try_next = true
  while try_next do
    tab_idx = tab_idx + 1
    try_next = false

    for line_idx, _ in pairs(tabs) do
      local found = align_tab_index(tabs, line_idx, tab_idx)
      try_next = try_next or found
    end
  end

  return tabs
end

M.setup = function() end

return M
