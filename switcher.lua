local api = {
   client     = client,
   beautiful  = require("beautiful"),
   wibox      = require("wibox"),
   awful      = require("awful"),
   screen     = require("awful.screen"),
   layout     = require("awful.layout"),
   keygrabber = require("awful.keygrabber"),
   naughty    = require("naughty"),
   gears      = require("gears"),
   lgi        = require("lgi"),
   dpi        = require("beautiful.xresources").apply_dpi,
}

-- -- Seems not needed?
-- local focus_timer = 0
-- api.client.connect_signal(
--    "focus",
--    function (c)
--       if c.focus_timer == nil or c.focus_timer < focus_timer then
--          c.focus_timer = focus_timer
--       end
--       focus_timer = c.focus_timer + 1
--       c.focus_timer = focus_timer
--    end
-- )

local function min(a, b)
   if a < b then return a else return b end
end

local function max(a, b)
   if a < b then return b else return a end
end

local function with_alpha(col, alpha)
   _, r, g, b, a = col:get_rgba()
   return api.lgi.cairo.SolidPattern.create_rgba(r, g, b, alpha)
end

local label_font_family = api.beautiful.get_font(
   api.beautiful.mono_font or api.beautiful.font):get_family()
local tablist_font_size = api.dpi(15)
local font_color = with_alpha(api.gears.color(api.beautiful.fg_normal), 1)
local label_size = api.dpi(30)
local border_color = with_alpha(api.gears.color(api.beautiful.border_focus), 0.75)
local fill_color = with_alpha(api.gears.color(api.beautiful.bg_normal), 0.5)
local fill_color_hl = with_alpha(api.gears.color(api.beautiful.bg_focus), 1)
-- for comparing floats
local threshold = 0.1
local traverse_radius = api.dpi(5)

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

   local tablist = nil
   local tablist_index = nil

   local traverse_x = c.x + traverse_radius
   local traverse_y = c.y + traverse_radius

   local function draw_info(context, cr, width, height)
      cr:set_source_rgba(0, 0, 0, 0)
      cr:rectangle(0, 0, width, height)
      cr:fill()

      local msg, ext
      for i, a in ipairs(regions) do
         cr:rectangle(a.x, a.y, a.width, a.height)
         cr:clip()

         if i == c.machi_region and tablist ~= nil then

            local x_offset = api.dpi(10)
            local y_offset = api.dpi(10)

            for index, tc in ipairs(tablist) do
               local label = tc.name
               cr:select_font_face(label_font_family, "normal", "normal")
               cr:set_font_face(cr:get_font_face())
               cr:set_font_size(tablist_font_size)
               local ext = cr:text_extents(label)
               cr:rectangle(a.x + x_offset - api.dpi(3), a.y + y_offset - api.dpi(3),
                            ext.width + api.dpi(6), ext.height + api.dpi(6))
               if index == tablist_index then
                  cr:set_source(fill_color_hl)
               else
                  cr:set_source(fill_color)
               end
               cr:fill()
               cr:move_to(a.x + x_offset - ext.x_bearing, a.y + y_offset - ext.y_bearing)
               cr:text_path(label)
               cr:set_source(font_color)
               cr:fill()

               y_offset = y_offset + ext.height + api.dpi(10)
            end
         end

         -- cr:set_source(fill_color)
         -- cr:rectangle(a.x, a.y, a.width, a.height)
         -- cr:fill()
         cr:set_source(border_color)
         cr:rectangle(a.x, a.y, a.width, a.height)
         cr:set_line_width(10.0)
         cr:stroke()
         cr:reset_clip()

         -- cr:select_font_face(label_font_family, "normal", "normal")
         -- cr:set_font_size(label_size)
         -- cr:set_font_face(cr:get_font_face())
         -- msg = tostring(i)
         -- ext = cr:text_extents(msg)
         -- cr:move_to(a.x + a.width / 2 - ext.width / 2 - ext.x_bearing, a.y + a.height / 2 - ext.height / 2 - ext.y_bearing)
         -- cr:text_path(msg)
         -- cr:set_source_rgba(1, 1, 1, 1)
         -- cr:fill()
      end

      -- show the traverse point
      cr:rectangle(traverse_x - traverse_radius, traverse_y - traverse_radius, traverse_radius * 2, traverse_radius * 2)
      cr:set_source_rgba(1, 1, 1, 1)
      cr:fill()
   end

   infobox.bgimage = draw_info

   local kg
   kg = keygrabber.run(
      function (mod, key, event)
         if event == "release" then return end
         if key == "Tab" then
            if tablist == nil then
               tablist = {}
               for _, tc in ipairs(screen.tiled_clients) do
                  if tc.machi_region == c.machi_region then
                     tablist[#tablist + 1] = tc
                  end
               end

               tablist_index = 1
            end

            if #tablist > 0 then
               tablist_index = tablist_index % #tablist + 1
               c = tablist[tablist_index]
               c:emit_signal("request::activate", "mouse.move", {raise=false})
               c:raise()

               infobox.bgimage = draw_info
            end
         elseif key == "Up" or key == "Down" or key == "Left" or key == "Right" then
            local choice = nil
            local choice_value

            for i, a in ipairs(regions) do
               local v
               if key == "Up" then
                  if a.x < traverse_x + threshold
                  and traverse_x < a.x + a.width + threshold then
                     v = traverse_y - a.y - a.height
                  else
                     v = -1
                  end
               elseif key == "Down" then
                  if a.x < traverse_x + threshold
                  and traverse_x < a.x + a.width + threshold then
                     v = a.y - traverse_y
                  else
                     v = -1
                  end
               elseif key == "Left" then
                  if a.y < traverse_y + threshold
                  and traverse_y < a.y + a.height + threshold then
                     v = traverse_x - a.x - a.width
                  else
                     v = -1
                  end
               elseif key == "Right" then
                  if a.y < traverse_y + threshold
                  and traverse_y < a.y + a.height + threshold then
                     v = a.x - traverse_x
                  else
                     v = -1
                  end
               end

               if (v > threshold) and (choice_value == nil or choice_value > v) then
                  choice = i
                  choice_value = v
               end
            end

            if choice ~= nil and choice_value > threshold then
               local shift = false
               for i, m in ipairs(mod) do
                  if m == "Shift" then shift = true end
               end

               local move_traverse = false

               if shift then
                  -- move the window
                  c.machi_region = choice
                  api.layout.arrange(screen)
                  move_traverse = true
               else
                  -- move the focus
                  for _, tc in ipairs(screen.tiled_clients) do
                     if tc.machi_region == choice then
                        c = tc
                        api.client.focus = c
                        move_traverse = true
                        break
                     end
                  end
               end

               if move_traverse then
                  traverse_x = max(regions[choice].x + traverse_radius, min(regions[choice].x + regions[choice].width - traverse_radius, traverse_x))
                  traverse_y = max(regions[choice].y + traverse_radius, min(regions[choice].y + regions[choice].height - traverse_radius, traverse_y))
                  tablist = nil
               end

               infobox.bgimage = draw_info
            end
         elseif key == "Escape" or key == "Return" then
            infobox.visible = false
            keygrabber.stop(kg)
         else
            print("Unhandled key " .. key)
         end
      end
   )
end

return {
   start = start,
}