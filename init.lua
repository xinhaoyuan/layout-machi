local layout = require(... .. ".layout")
local editor = require(... .. ".editor")
local switcher = require(... .. ".switcher")
local default_editor = editor.create()
local default_layout = layout.create("default", default_editor)
local gcolor = require("gears.color")

local beautiful = require("beautiful")
local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then
   local base = source:match("^@(.-)[^/]+$")
   beautiful.layout_machi = gcolor.recolor_image(
      base .. "icon.png", beautiful.fg_normal)
   print(beautiful.layout_machi)
end

return {
   layout = layout,
   editor = editor,
   switcher = switcher,
   default_editor = default_editor,
   default_layout = default_layout,
}
