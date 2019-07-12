local layout = require(... .. ".layout")
local editor = require(... .. ".editor")
local switcher = require(... .. ".switcher")
local default_editor = editor.create()
local default_layout = layout.create("default", default_editor)

return {
   layout = layout,
   editor = editor,
   switcher = switcher,
   default_editor = default_editor,
   default_layout = default_layout,
}
