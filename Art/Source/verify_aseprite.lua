-- Independent check: the actual Aseprite application reopens every counterpart.
local root = app.params["root"]
local file = assert(io.open(root .. "/Art/Source/assets.json", "rb"))
local assets = json.decode(file:read("*a")); file:close()
local count = 0
for path, entry in pairs(assets) do
  local sprite = assert(app.open(root .. "/" .. entry.source:sub(7)), path)
  assert(#sprite.frames == entry.frames, path)
  assert(sprite.width > 0 and sprite.height > 0, path)
  sprite:close()
  count = count + 1
end
print("ASEPRITE REOPEN PASS " .. count)
