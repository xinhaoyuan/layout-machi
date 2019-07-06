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
local border_color = "#ffffff80"
local fill_color = "#00000040"
-- for comparing floats
local threshold = 0.1

local function start(c)
   local screen = c.screen
   local layout = api.layout.get(screen)
   if c.floating or layout.get_regions == nil then return end

   local regions = layout.get_regions()

   local infobox = api.wibox({
         screen = screen,
         x = screen.workarea.x,
         y = screen.workarea.y,
         width = screen.workarea.width,
         height = screen.workarea.height,
         bg = "#ffffff00",
         opacity = 1,
         ontop = true
   })
   infobox.visible = true

   local traverse_x = c.x + c.width / 2
   local traverse_y = c.y + c.height / 2

   local function draw_info(context, cr, width, height)
      cr:set_source_rgba(0, 0, 0, 0)
      cr:rectangle(0, 0, width, height)
      cr:fill()

      local msg, ext
      for i, a in ipairs(regions) do
         if i ~= c.machi_region then
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

      -- -- show the traverse point
      -- cr:rectangle(traverse_x - api.dpi(5), traverse_y - api.dpi(5), api.dpi(10), api.dpi(10))
      -- cr:set_source_rgba(1, 1, 1, 1)
      -- cr:fill()
   end

   infobox.bgimage = draw_info

   local kg
   kg = keygrabber.run(
      function (mod, key, event)
         if event == "release" then return end

         if key == "Up" or key == "Down" or key == "Left" or key == "Right" then
            local choice = nil
            local choice_value
            local choice_x
            local choice_y

            for i, a in ipairs(regions) do
               local v
               local x = traverse_x
               local y = traverse_y
               if key == "Up" then
                  if a.x < traverse_x + threshold
                  and traverse_x < a.x + a.width + threshold then
                     v = traverse_y - a.y - a.height
                     y = a.y + a.height
                  else
                     v = -1
                  end
               elseif key == "Down" then
                  if a.x < traverse_x + threshold
                  and traverse_x < a.x + a.width + threshold then
                     v = a.y - traverse_y
                     y = a.y
                  else
                     v = -1
                  end
               elseif key == "Left" then
                  if a.y < traverse_y + threshold
                  and traverse_y < a.y + a.height + threshold then
                     v = traverse_x - a.x - a.width
                     x = a.x + a.width
                  else
                     v = -1
                  end
               elseif key == "Right" then
                  if a.y < traverse_y + threshold
                  and traverse_y < a.y + a.height + threshold then
                     v = a.x - traverse_x
                     x = a.x
                  else
                     v = -1
                  end
               end

               if (v > threshold) and (choice_value == nil or choice_value > v) then
                  choice = i
                  choice_value = v
                  choice_x = x
                  choice_y = y
               end
            end

            if choice ~= nil and choice_value > threshold then
               c.machi_region = choice
               api.layout.arrange(screen)

               traverse_x = choice_x
               traverse_y = choice_y

               infobox.bgimage = draw_info
            end
         elseif key == "Escape" then
            infobox.visible = false
            keygrabber.stop(kg)
         end
      end
   )
end

return {
   start = start,
}
