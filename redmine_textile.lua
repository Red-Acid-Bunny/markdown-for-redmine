-- redmine_textile.lua
-- Фильтр для конвертации Markdown → Textile (Redmine)
-- Использование: pandoc --lua-filter=redmine_textile.lua -f markdown -t textile file.md -o file.textile

-- Код-блоки: <pre><code class="lang"> ... </code></pre>
function CodeBlock(block)
  local lang = block.classes[1] or 'text'
  -- 1. Сначала "$ " (доллар + пробел) → HTML-сущность. Пробел явно возвращаем, чтобы не схлопнулся.
  local safe_code = block.text:gsub('%$ ', ' </code>&#36; <code class="' .. lang .. '">')
  safe_code = safe_code:gsub('%$', '</code>&#36;<code class="' .. lang .. '">')
  return pandoc.RawBlock('html', '<pre><code class="' .. lang .. '">\n' .. safe_code .. '\n</code></pre>\n\n')  -- +\n\n
end
-- Маркированные списки
function BulletList(list)
  local items = {}
  for _, item in ipairs(list.content) do
    local txt = pandoc.write(pandoc.Pandoc(item), 'textile')
    txt = txt:gsub('&#45;', '-'):gsub('&#95;', '_'):gsub('^p%.%s*', ''):gsub('^%s+', ''):gsub('%s*$', '')
    table.insert(items, '* ' .. txt)
  end
  return pandoc.RawBlock('textile', table.concat(items, '\n') .. '\n\n')
end

-- Нумерованные списки
function OrderedList(list)
  local items = {}
  for _, item in ipairs(list.content) do
    local txt = pandoc.write(pandoc.Pandoc(item), 'textile')
    txt = txt:gsub('&#45;', '-'):gsub('&#95;', '_'):gsub('^p%.%s*', ''):gsub('^%s+', ''):gsub('%s*$', '')
    table.insert(items, '# ' .. txt)
  end
  return pandoc.RawBlock('textile', table.concat(items, '\n') .. '\n\n')
end

-- Ловит "сломанные" списки в параграфах (когда в Markdown забыли пустую строку перед -)
function Para(para)
  local txt = pandoc.write(pandoc.Pandoc(para), 'textile')
  if txt:match('^&#45;%s') or txt:match('^%-%s') then
    txt = txt:gsub('&#45;', '-'):gsub('&#95;', '_')
    txt = txt:gsub('^%- ', '* '):gsub('^&#45; ', '* ')
    return pandoc.RawBlock('textile', txt .. '\n\n')
  end
  return nil
end

-- Inline-код: @code@
function Code(elem)
  return pandoc.RawInline('textile', '@' .. elem.text .. '@')
end

-- Вырезаем HTML-комментарии, но <!-- toc --> → {{>toc}}
function RawBlock(elem)
  if elem.format == 'html' and elem.text:match('^%s*<!%-%-.-%-%->%s*$') then
    if elem.text:lower():match('toc') then
      return pandoc.RawBlock('textile', '{{>toc}}\n\n')
    end
    return {}
  end
  return nil
end

-- Таблицы: конвертация в pipe-таблицы Textile
function Table(tbl)
  local function get_text(blocks)
    local result = pandoc.write(pandoc.Pandoc(blocks), 'textile')
    return result:gsub('^p%.%s*', '')
  end

  local lines = {}
  -- Заголовок: tbl.head.rows (List)
  for _, row in pairs(tbl.head.rows) do
    local parts = {}
    for _, cell in pairs(row.cells) do
      table.insert(parts, '|_. ' .. get_text(cell.content))
    end
    table.insert(lines, table.concat(parts, '') .. '|')
    break
  end
  -- Строки: tbl.bodies — table of TableBody, TableBody.body — List of Row
  for _, tbody in pairs(tbl.bodies) do
    for _, row in pairs(tbody.body) do
      local parts = {}
      for _, cell in pairs(row.cells) do
        table.insert(parts, '| ' .. get_text(cell.content))
      end
      table.insert(lines, table.concat(parts, '') .. '|')
    end
  end
  return pandoc.RawBlock('textile', table.concat(lines, '\n') .. '\n\n')
end
