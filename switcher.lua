local api = {
   beautiful  = require("beautiful"),
   wibox      = require("wibox"),
   awful      = require("awful"),
   screen     = require("awful.screen"),
   layout     = require("awful.layout"),
   keygrabber = require("awful.keygrabber"),
   naughty    = require("naughty"),
   gears      = require("gears"),
   dpi        = require("beautiful.xresources").apply_dpi,
}

local label_font_family = api.beautiful.get_font(
   api.beautiful.mono_font or api.beautiful.font):get_family()
local label_size = api.dpi(30)
local border_color = "#ffffffc0"
local fill_color = "#00000080"

local function start(c)
   local screen = c.screen
   local layout = api.layout.get(screen)
   if c.floating or layout.get_regions == nil then return end

   local infobox = api.wibox({
         x = screen.workarea.x,
         y = screen.workarea.y,
         width = screen.workarea.width,
         height = screen.workarea.height,
         bg = "#ffffff00",
         opacity = 1,
         ontop = true
   })
   infobox.visible = true

   local function draw_info(context, cr, width, height)
      cr:set_source_rgba(0, 0, 0, 0)
      cr:rectangle(0, 0, width, height)
      cr:fill()

      local msg, ext
      local regions = layout.get_regions()
      for i, a in ipairs(regions) do
         cr:rectangle(a.x, a.y, a.width, a.height)
         cr:clip()
         cr:set_source(api.gears.color(fill_color))
         cr:rectangle(a.x, a.y, a.width, a.height)
         cr:fill()
         cr:set_source(api.gears.color(border_color))
         cr:rectangle(a.x, a.y, a.width, a.height)
         cr:set_line_width(10.0)
         cr:stroke()
         cr:reset_clip()

         cr:select_font_face(label_font_family, "normal", "normal")
         cr:set_font_size(label_size)
         cr:set_font_face(cr:get_font_face())
         msg = tostring(i)
         ext = cr:text_extents(msg)
         cr:move_to(a.x + a.width / 2 - ext.width / 2 - ext.x_bearing, a.y + a.height / 2 - ext.height / 2 - ext.y_bearing)
         cr:text_path(msg)
         cr:set_source_rgba(1, 1, 1, 1)
         cr:fill()
         
      end
   end

   infobox.bgimage = draw_info

   local kg
   kg = keygrabber.run(
      function (mod, key, event)
         if event == "release" then return end

         if key == "Escape" then
            infobox.visible = false
            kg.stop()
         end
      end
   )
end

return {
   start = start,
}
