-- This is a Re:VIEW writer for pandoc.  It produces Re:VIEW
-- fomat file.
--
-- Invoke with: pandoc -t review.lua
--
-- Note:  you need not have lua installed on your system to use this
-- writer.

-- Character escaping
-- local function escape(s, in_attribute)
--   return s:gsub("[<>&\"']",
--     function(x)
--       if x == '<' then
--         return '&lt;'
--       elseif x == '>' then
--         return '&gt;'
--       elseif x == '&' then
--         return '&amp;'
--       elseif x == '"' then
--         return '&quot;'
--       elseif x == "'" then
--         return '&#39;'
--       else
--         return x
--       end
--     end)
-- end

-- counter to generate table_id
local table_counter = 0

local function escape_inline(s)
  return s:gsub("}", "\\}")
end

local function escape_href(s)
  return s:gsub(",", "\\,")
end


-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      table.insert(attr_table, ' ' .. x .. '="' .. y .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Run cmd on a temporary file containing inp and return result.
local function pipe(cmd, inp)
  local tmp = os.tmpname()
  local tmph = io.open(tmp, "w")
  tmph:write(inp)
  tmph:close()
  local outh = io.popen(cmd .. " " .. tmp,"r")
  local result = outh:read("*all")
  outh:close()
  os.remove(tmp)
  return result
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep()
  return "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add(body)
  if #notes > 0 then
    --add('<ol class="footnotes">')
    for _,note in pairs(notes) do
      add("//footnote" .. note .. "" )
    end
    --add('</ol>')
  end
  return table.concat(buffer,'\n')
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
  return s
end

function Space()
  return " "
end

function LineBreak()
  return "@<br>{}"
end

function Emph(s)
  return "@<em>{" .. escape_inline(s) .. "}"
end

function Strong(s)
  return "@<strong>{" .. escape_inline(s) .. "}"
end

function Subscript(s)
  return "@<sub>{" .. escape_inline(s) .. "}"
end

function Superscript(s)
  return "@<sup>{" .. escape_inlin(s) .. "}"
end

function SmallCaps(s)
  return '@<smallcaps>{' .. escape_inline(s) .. '}'
end

function Strikeout(s)
  return '@<del>{' .. escape_inline(s) .. '}'
end

function Link(s, src, tit)
  --  print("LINK:" .. s .. ":" .. src .. ":" .. tit .. "\n")
  if s == src then
    return "@<href>{" .. escape_href(src) .. "}"
  else
    return "@<href>{" .. escape_href(src) .. "," .. s .. "}"
  end
end

function Image(s, src, tit)
  local filename = string.gsub(src, "(.*/)(.*)$", "%2")
  local basename = string.gsub(filename, "(%a*)%.(%w*)$", "%1")
  if string.len(tit) == 0 then
    return "//image[" .. basename .. "][" .. tit .. "]{\n//}\n"
  else
    return "//indepimage[" .. basename .. "]\n"
  end
end


function CaptionedImage(src, attr, tit)
  local filename = string.gsub(src, "(.*/)(.*)$", "%2")
  local basename = string.gsub(filename, "(%a*)%.(%w*)$", "%1")
  if string.len(tit) == 0 then
    return "//image[" .. basename .. "][" .. tit .. "]{\n//}\n"
  else
    return "//indepimage[" .. basename .. "]\n"
  end
end

function Code(s, attr)
  return "@<tt>{" .. escape_inline(s) .. "}"
end

function InlineMath(s)
  return "@<m>{" .. escape_inline(s) .. "}"
end

function DisplayMath(s)
  return "\n//texequation{\n" ..s .. "\n//}\n"
end

function Note(s)
  local num = #notes + 1
  -- add a list item with the note to the note table.
  table.insert(notes, '[fn' .. num .. '][' .. string.gsub(s,"\n","") .. ']')
  -- return the footnote reference, linked to the note.
  return '@<fn>{fn' .. num .. '}'
end

function Span(s, attr)
  return s
end

function Cite(s, cs)
  local ids = {}
  for _,cit in ipairs(cs) do
    table.insert(ids, cit.citationId)
  end
  --return "<span class=\"cite\" data-citation-ids=\"" .. table.concat(ids, ",") ..
  --  "\">" .. s .. "</span>"
  return "" .. s .. ""
end

function Plain(s)
  return s
end

function Para(s)
  return s .. "\n"
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
  --return "#@# header_attribte: " .. attributes(attr) ..  "\n" .. string.rep("=",lev) .. " " .. s .. "\n\n"
  return "\n" .. string.rep("=",lev) .. " " .. s .. "\n\n"
end

function BlockQuote(s)
  return "\n//quote{\n" .. s .. "\n//}\n"
end

function HorizontalRule()
  return "\n//hr\n"
end

function CodeBlock(s, attr)
  if ((attr.language == "Command") or (attr.language == "command"))  then
    return "//cmd{\n" .. s .. "\n//}\n"
  else
    lang = languageCode(attr.language)
    if attr["number"] then
      return "//emlistnum[][" .. lang .. "]{\n" .. s .. "\n//}\n"
    else
      return "//emlist[][" .. lang .. "]{\n" .. s .. "\n//}\n"
    end
  end
end

function languageCode(s)
  if s then
    if s == "nginx.conf" then
      return ""
    else
      return string.lower(s)
    end
  else
    return ""
  end
end

function BulletList(items)
  local buffer = {}
  for _, item in pairs(items) do
    if string.sub(item,1,1) == "*" then
      table.insert(buffer, "*" .. item)
    else
      table.insert(buffer, "* " .. item)
    end
  end
  return "\n " .. table.concat(buffer, "\n ") .. "\n"
end

function OrderedList(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, "1. " .. item)
  end
  return "\n " .. table.concat(buffer, "\n ") .. "\n"
end

-- Revisit association list STackValue instance.
function DefinitionList(items)
  local buffer = {}
  for _,item in pairs(items) do
    for k, v in pairs(item) do
      table.insert(buffer,": " .. k .. "\n    " ..
                     table.concat(v,"\n    ") .. "\n")
    end
  end
  return "\n" .. table.concat(buffer, "") .. ""
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

local function table_id()
  table_counter = table_counter + 1
  return table_counter
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  local table_id = table_id()

  if widths and widths[1] ~= 0 then
    local tsize = ""
    local ws2 = {}
    for _, w in pairs(widths) do
      table.insert(ws2, string.format("%d", w * 100))
    end
    add("//tsize[" .. table.concat(ws2, ",") .. "]")
  end

  if caption ~= "" then
    add("//table[" .. table_id .. "][" .. caption .. "]{")
  else
    add("//table[" .. table_id .. "]{")
  end
  local header_row = {}
  local empty_header = true
  for i, h in pairs(headers) do
    local align = html_align(aligns[i])
    table.insert(header_row, h)
    empty_header = empty_header and h == ""
  end
  if empty_header then
    head = ""
  else
    add(table.concat(header_row, "\t"))
    add("--------------------")
  end
  local class = "even"
  for _, row in pairs(rows) do
    --class = (class == "even" and "odd") or "even"
    --add('<tr class="' .. class .. '">')
    --for i,c in pairs(row) do
    --  add('<td align="' .. html_align(aligns[i]) .. '">' .. c .. '</td>')
    --end
    --add('</tr>')
    add(table.concat(row, "\t"))
  end
  add('//}')
  return table.concat(buffer,'\n')
end

function Div(s, attr)
  return "\n#@# <div" .. attributes(attr) .. ">\n" .. s .. "\n#@# </div>\n"
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return "" end
  end
setmetatable(_G, meta)

