function Meta(meta)
  local function text(v)
    if v == nil then return "" end
    return pandoc.utils.stringify(v)
  end

  local authors = {}
  if meta.author then
    for _, author in ipairs(meta.author) do
      local name = text(author.name or author)
      local affiliation_marks = {}
      if author.affiliations then
        for _, affiliation in ipairs(author.affiliations) do
          table.insert(affiliation_marks, "\\aff{" .. text(affiliation) .. "}")
        end
      end
      local entry = name .. table.concat(affiliation_marks)
      if author.corresponding then
        local email = text(author.email)
        if email ~= "" then
          entry = entry .. "\\correspondingauthor{" .. name .. ", " .. email .. "}"
        else
          entry = entry .. "\\correspondingauthor{" .. name .. "}"
        end
      end
      table.insert(authors, entry)
    end
  end
  meta.ams_authors = pandoc.MetaString(table.concat(authors, ", "))

  local affiliations = {}
  if meta.affiliation then
    for _, affiliation in ipairs(meta.affiliation) do
      local id = text(affiliation.id)
      local name = text(affiliation.name)
      table.insert(affiliations, "\\aff{" .. id .. "}{" .. name .. "}")
    end
  end
  meta.ams_affiliations = pandoc.MetaString(table.concat(affiliations, "\\\\\n"))
  return meta
end
