-- Rewrites "@@fig-x" as "[Fig. @fig-x]" (likewise tbl and sec).
local abbrev = { fig = "Fig.", tbl = "Tab.", sec = "Sec." }

local function make_cite(id, label)
  local c = pandoc.Citation(id, "NormalCitation")
  c.prefix = pandoc.Inlines({ pandoc.Str(label) })
  return pandoc.Cite({ pandoc.Str("[" .. label .. " @" .. id .. "]") }, { c })
end

function Inlines(inlines)
  for i = #inlines, 1, -1 do
    local el = inlines[i]
    if el.t == "Cite" and i > 1 then
      -- Case 1: Pandoc parsed "@@fig-x" as "@" followed by a citation
      local prev = inlines[i - 1]
      local c = el.citations[1]
      local label = abbrev[c.id:match("^(%a+)%-") or ""]
      if label and prev.t == "Str" and prev.text:sub(-1) == "@" then
        c.prefix = pandoc.Inlines({ pandoc.Str(label) })
        c.mode = "NormalCitation"
        el.citations[1] = c
        local rest = prev.text:sub(1, -2)
        if rest == "" then inlines:remove(i - 1)
        else inlines[i - 1] = pandoc.Str(rest) end
      end
    elseif el.t == "Str" then
      -- Case 2: "@@fig-x" left as plain text
      local pre, id, kind, post = el.text:match("^(.-)@@((%a+)%-[%w%-_]*)(.*)$")
      if pre and abbrev[kind] then
        inlines:remove(i)
        local pieces = {}
        if pre ~= "" then table.insert(pieces, pandoc.Str(pre)) end
        table.insert(pieces, make_cite(id, abbrev[kind]))
        if post ~= "" then table.insert(pieces, pandoc.Str(post)) end
        for j, p in ipairs(pieces) do inlines:insert(i + j - 1, p) end
      end
    end
  end
  return inlines
end