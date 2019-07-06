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
local info_size = api.dpi(60)
-- colors are in rgba
local border_color = "#ffffffc0"
local active_color = "#6c7ea780"
local open_color   = "#00000080"
local closed_color = "#00000080"
local init_max_depth = 2

local function is_tiling(c)
   return
      not (c.tomb_floating or c.floating or c.maximized_horizontal or c.maximized_vertical or c.maximized or c.fullscreen)
end

local function set_tiling(c)
   c.floating = false
   c.maximized = false
   c.maximized_vertical = false
   c.maximized_horizontal = false
   c.fullscreen = false
end

local function min(a, b)
   if a < b then return a else return b end
end

local function max(a, b)
   if a < b then return b else return a end
end

local function set_region(c, r)
   c.floating = false
   c.maximized = false
   c.fullscreen = false
   c.machi_region = r
   api.layout.arrange(c.screen)
end

-- find the best region for the area
local function fit_region(c, regions)
   local choice = 1
   local choice_value = nil
   local c_area = c.width * c.height
   for i, a in ipairs(regions) do
      local x_cap = max(0, min(c.x + c.width, a.x + a.width) - max(c.x, a.x))
      local y_cap = max(0, min(c.y + c.height, a.y + a.height) - max(c.y, a.y))
      local cap = x_cap * y_cap
      -- -- a cap b / a cup b
      -- local cup = c_area + a.width * a.height - cap
      -- if cup > 0 then
      --    local itx_ratio = cap / cup
      --    if choice_value == nil or choice_value < itx_ratio then
      --       choice_value = itx_ratio
      --       choice = i
      --    end
      -- end
      -- a cap b
      if choice_value == nil or choice_value < cap then
         choice = i
         choice_value = cap
      end
   end
   return choice
end

local function cycle_region(c)
   layout = api.layout.get(c.screen)
   regions = layout.get_regions and layout.get_regions()
   if type(regions) ~= "table" or #regions < 1 then
      c.float = true
      return
   end
   current_region = c.machi_region or 1
   if not is_tiling(c) then
      -- find out which region has the most intersection, calculated by a cap b / a cup b
      c.machi_region = fit_region(c, regions)
      set_tiling(c)
   elseif current_region >= #regions then
      c.machi_region = 1
   else
      c.machi_region = current_region + 1
   end
   api.layout.arrange(c.screen)
end

local function _area_tostring(wa)
   return "{x:" .. tostring(wa.x) .. ",y:" .. tostring(wa.y) .. ",w:" .. tostring(wa.width) .. ",h:" .. tostring(wa.height) .. "}"
end

local function shrink_area_with_gap(a, gap)
   return { x = a.x + (a.bl and 0 or gap / 2), y = a.y + (a.bu and 0 or gap / 2),
            width = a.width - (a.bl and 0 or gap / 2) - (a.br and 0 or gap / 2),
            height = a.height - (a.bu and 0 or gap / 2) - (a.bd and 0 or gap / 2) }
end

local function restore_data(data)
   if data.history_file then
      local file, err = io.open(data.history_file, "r")
      if err then
         print("cannot read history from " .. data.history_file)
      else
         data.cmds = {}
         for line in file:lines() do
            print("restore cmd " .. line)
            data.cmds[#data.cmds + 1] = line
         end
      end
   end

   return data
end

local function create(data)
   if data == nil then
      data = restore_data({
            history_file = ".machi_history",
            history_save_max = 100,
            gap = api.beautiful.useless_gap,
      })
   end

   local gap = data.gap or 0

   local closed_areas
   local open_areas
   local history
   local num_1
   local num_2
   local max_depth
   local current_info
   local current_cmd
   local to_exit
   local to_apply

   local function init(init_area)
      closed_areas = {}
      open_areas = {
         {
            x = init_area.x,
            y = init_area.y,
            width = init_area.width,
            height = init_area.height,
            border = 15,
            depth = 0,
            group_id = 0,
            -- we do not want to rely on BitOp
            bl = true, br = true, bu = true, bd = true,
         }
      }
      history = {}
      num_1 = nil
      num_2 = nil
      max_depth = init_max_depth
      current_info = ""
      current_cmd = ""
      to_exit = false
      to_apply = false
   end

   local function push_history()
      history[#history + 1] = {#closed_areas, #open_areas, {}, current_info, current_cmd, max_depth, num_1, num_2}
   end

   local function discard_history()
      table.remove(history, #history)
   end

   local function pop_history()
      if #history == 0 then return end
      for i = history[#history][1] + 1, #closed_areas do
         table.remove(closed_areas, #closed_areas)
      end

      for i = history[#history][2] + 1, #open_areas do
         table.remove(open_areas, #open_areas)
      end

      for i = 1, #history[#history][3] do
         open_areas[history[#history][2] - i + 1] = history[#history][3][i]
      end

      current_info = history[#history][4]
      current_cmd = history[#history][5]
      max_depth = history[#history][6]
      num_1 = history[#history][7]
      num_2 = history[#history][8]

      table.remove(history, #history)
   end

   local function pop_open_area()
      local a = open_areas[#open_areas]
      table.remove(open_areas, #open_areas)
      local idx = history[#history][2] - #open_areas
      -- only save when the position has been firstly poped
      if idx > #history[#history][3] then
         history[#history][3][#history[#history][3] + 1] = a
      end
      return a
   end

   local split_count = 0

   local function handle_split(method, alt)
      split_count = split_count + 1

      if num_1 == nil then num_1 = 1 end
      if num_2 == nil then num_2 = 1 end

      if alt then
         local tmp = num_1
         num_1 = num_2
         num_2 = tmp
      end

      local a = pop_open_area()
      local lu, rd

      print("split " .. method .. " " .. tostring(alt) .. " " .. _area_tostring(a))

      if method == "h" then
         lu = {
            x = a.x, y = a.y,
            width = a.width / (num_1 + num_2) * num_1, height = a.height,
            depth = a.depth + 1,
            group_id = split_count,
            bl = a.bl, br = false, bu = a.bu, bd = a.bd,
         }
         rd = {
            x = a.x + lu.width, y = a.y,
            width = a.width - lu.width, height = a.height,
            depth = a.depth + 1,
            group_id = split_count,
            bl = false, br = a.br, bu = a.bu, bd = a.bd,
         }
         open_areas[#open_areas + 1] = rd
         open_areas[#open_areas + 1] = lu
      elseif method == "v" then
         lu = {
            x = a.x, y = a.y,
            width = a.width, height = a.height / (num_1 + num_2) * num_1,
            depth = a.depth + 1,
            group_id = split_count,
            bl = a.bl, br = a.br, bu = a.bu, bd = false
         }
         rd = {
            x = a.x, y = a.y + lu.height,
            width = a.width, height = a.height - lu.height,
            depth = a.depth + 1,
            group_id = split_count,
            bl = a.bl, br = a.br, bu = false, bd = a.bd,
         }
         open_areas[#open_areas + 1] = rd
         open_areas[#open_areas + 1] = lu
      elseif method == "w" then
         local x_interval = a.width / num_1
         local y_interval = a.height / num_2
         for y = num_2, 1, -1 do
            for x = num_1, 1, -1 do
               local r = {
                  x = a.x + x_interval * (x - 1),
                  y = a.y + y_interval * (y - 1),
                  width = x_interval,
                  height = y_interval,
                  depth = a.depth + 1,
                  group_id = split_count,
               }
               if x == 1 then r.bl = a.bl else r.bl = false end
               if x == num_1 then r.br = a.br else r.br = false end
               if y == 1 then r.bu = a.bu else r.bu = false end
               if y == num_2 then r.bd = a.bd else r.bd = false end
               open_areas[#open_areas + 1] = r
            end
         end
      elseif method == "P" then
         -- XXX
      end

      num_1 = nil
      num_2 = nil
   end

   local function push_area()
      closed_areas[#closed_areas + 1] = pop_open_area()
   end

   local function handle_command(key)
      if key == "h" or key == "H" then
         handle_split("h", key == "H")
      elseif key == "v" or key == "V" then
         handle_split("v", key == "V")
      elseif key == "w" or key == "W" then
         if num_1 == nil and num_2 == nil then
            push_area()
         else
            handle_split("w", key == "W")
         end
      elseif key == "p" or key == "P" then
         handle_split("p", key == "P")
      elseif key == "s" or key == "S" then
         if #open_areas > 0 then
            key = "s"
            local times = num_1 or 1
            local t = {}
            while #open_areas > 0 do
               t[#t + 1] = pop_open_area()
            end
            for i = #t, 1, -1 do
               open_areas[#open_areas + 1] = t[(i + times - 1) % #t + 1]
            end
            num_1 = nil
            num_2 = nil
         else
            return nil
         end
      elseif key == " " or key == "-" then
         key = "-"
         if num_1 ~= nil then
            max_depth = num_1
            num_1 = nil
            num_2 = nil
         else
            push_area()
         end
      elseif key == "Return" or key == "." then
         key = "."
         while #open_areas > 0 do
            push_area()
         end
      elseif tonumber(key) ~= nil then
         local v = tonumber(key)
         if num_1 == nil then
            num_1 = v
         elseif num_2 == nil then
            num_2 = v
         else
            return nil
         end
      else
         return nil
      end

      while #open_areas > 0 and open_areas[#open_areas].depth >= max_depth do
         push_area()
      end

      return key
   end

   local function start_interactive()
      if data.cmds == nil then
         data.cmds = {}
      end

      local cmd_index = #data.cmds + 1
      data.cmds[cmd_index] = ""

      local screen = api.screen.focused()
      local kg
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

      local function cleanup()
         infobox.visible = false
      end

      local function draw_info(context, cr, width, height)
         cr:set_source_rgba(0, 0, 0, 0)
         cr:rectangle(0, 0, width, height)
         cr:fill()

         local msg, ext

         for i, a in ipairs(closed_areas) do
            local sa = shrink_area_with_gap(a, gap)
            cr:rectangle(sa.x, sa.y, sa.width, sa.height)
            cr:clip()
            cr:set_source(api.gears.color(closed_color))
            cr:rectangle(sa.x, sa.y, sa.width, sa.height)
            cr:fill()
            cr:set_source(api.gears.color(border_color))
            cr:rectangle(sa.x, sa.y, sa.width, sa.height)
            cr:set_line_width(10.0)
            cr:stroke()
            cr:reset_clip()
         end

         for i, a in ipairs(open_areas) do
            local sa = shrink_area_with_gap(a, gap)
            cr:rectangle(sa.x, sa.y, sa.width, sa.height)
            cr:clip()
            if i == #open_areas then
               cr:set_source(api.gears.color(active_color))
            else
               cr:set_source(api.gears.color(open_color))
            end
            cr:rectangle(sa.x, sa.y, sa.width, sa.height)
            cr:fill()

            cr:set_source(api.gears.color(border_color))
            cr:rectangle(sa.x, sa.y, sa.width, sa.height)
            cr:set_line_width(10.0)
            if i ~= #open_areas then
               cr:set_dash({5, 5}, 0)
               cr:stroke()
               cr:set_dash({}, 0)
            else
               cr:stroke()
            end
            cr:reset_clip()
         end

         cr:select_font_face(label_font_family, "normal", "normal")
         cr:set_font_size(info_size)
         cr:set_font_face(cr:get_font_face())
         msg = current_info
         ext = cr:text_extents(msg)
         cr:move_to(width / 2 - ext.width / 2 - ext.x_bearing, height / 2 - ext.height / 2 - ext.y_bearing)
         cr:text_path(msg)
         cr:set_source_rgba(1, 1, 1, 1)
         cr:fill()
         cr:move_to(width / 2 - ext.width / 2 - ext.x_bearing, height / 2 - ext.height / 2 - ext.y_bearing)
         cr:text_path(msg)
         cr:set_source_rgba(0, 0, 0, 1)
         cr:set_line_width(2.0)
         cr:stroke()
      end

      local function refresh()
         print("closed areas:")
         for i, a in ipairs(closed_areas) do
            print("  " .. _area_tostring(a))
         end
         print("open areas:")
         for i, a in ipairs(open_areas) do
            print("  " .. _area_tostring(a))
         end
         infobox.bgimage = draw_info
      end


      print("interactive layout editing starts")

      init(screen.workarea)
      refresh()

      kg = keygrabber.run(function (mod, key, event)
            if event == "release" then
               return
            end

            if key == "BackSpace" then
               pop_history()
            elseif key == "Escape" then
               table.remove(data.cmds, #data.cmds)
               to_exit = true
            elseif key == "Up" or key == "Down" then
               if current_cmd ~= data.cmds[cmd_index] then
                  data.cmds[#data.cmds] = current_cmd
               end

               if key == "Up" and cmd_index > 1 then
                  cmd_index = cmd_index - 1
               elseif key == "Down" and cmd_index < #data.cmds then
                  cmd_index = cmd_index + 1
               end

               print("restore history #" .. tostring(cmd_index) .. ":" .. data.cmds[cmd_index])
               init(screen.workarea)
               for i = 1, #data.cmds[cmd_index] do
                  cmd = data.cmds[cmd_index]:sub(i, i)

                  push_history()
                  local ret = handle_command(cmd)

                  current_info = current_info .. ret
                  current_cmd = current_cmd .. ret
               end

               if #open_areas == 0 then
                  current_info = current_info .. " (enter to save)"
               end
            elseif #open_areas > 0 then
               push_history()
               local ret = handle_command(key)
               if ret ~= nil then
                  current_info = current_info .. ret
                  current_cmd = current_cmd .. ret
               else
                  discard_history()
               end

               if #open_areas == 0 then
                  current_info = current_info .. " (enter to save)"
               end
            else
               if key == "Return" then
                  table.remove(data.cmds, #data.cmds)
                  -- remove duplicated entries
                  local j = 1
                  for i = 1, #data.cmds do
                     if data.cmds[i] ~= current_cmd then
                        data.cmds[j] = data.cmds[i]
                        j = j + 1
                     end
                  end
                  for i = #data.cmds, j, -1 do
                     table.remove(data.cmds, i)
                  end
                  -- bring the current cmd to the front
                  data.cmds[#data.cmds + 1] = current_cmd

                  if data.history_file then
                     local file, err = io.open(data.history_file, "w")
                     if err then
                        print("cannot save history to " .. data.history_file)
                     else
                        for i = max(1, #data.cmds - data.history_save_max + 1), #data.cmds do
                           print("save cmd " .. data.cmds[i])
                           file:write(data.cmds[i] .. "\n")
                        end
                     end
                  end

                  current_info = "Saved!"
                  to_exit = true
                  to_apply = true
               end
            end

            refresh()

            if to_exit then
               print("interactive layout editing ends")
               if to_apply then
                  local layout = api.layout.get(screen)
                  if layout.set_regions then
                     local areas_with_gap = {}
                     for _, a in ipairs(closed_areas) do
                        areas_with_gap[#areas_with_gap + 1] = shrink_area_with_gap(a, gap)
                     end
                     table.sort(
                        areas_with_gap,
                        function (a1, a2)
                           local s1 = a1.width * a1.height
                           local s2 = a2.width * a2.height
                           if math.abs(s1 - s2) < 0.01 then
                              return (a1.x + a1.y) < (a2.x + a2.y)
                           else
                              return s1 > s2
                           end
                        end
                     )
                     layout.cmd = current_cmd
                     layout.set_regions(areas_with_gap)
                     api.layout.arrange(screen)
                  end
                  api.gears.timer{
                     timeout = 1,
                     autostart = true,
                     singleshot = true,
                     callback = cleanup
                  }
               else
                  cleanup()
               end
               keygrabber.stop(kg)
               return
            end
      end)
   end

   local function set_by_cmd(layout, screen, cmd)
      init(screen.workarea)
      push_history()

      for i = 1, #cmd do
         local key = handle_command(cmd:sub(i, i))
      end

      local areas_with_gap = {}
      for _, a in ipairs(closed_areas) do
         areas_with_gap[#areas_with_gap + 1] = shrink_area_with_gap(a, gap)
      end
      table.sort(
         areas_with_gap,
         function (a1, a2)
            local s1 = a1.width * a1.height
            local s2 = a2.width * a2.height
            if math.abs(s1 - s2) < 0.01 then
               return (a1.x + a1.y) < (a2.x + a2.y)
            else
               return s1 > s2
            end
         end
      )
      layout.cmd = cmd
      layout.set_regions(areas_with_gap)
      api.layout.arrange(screen)
   end

   local function try_restore_last(layout, screen)
      local index = #data.cmds
      if index == 0 then return end

      set_by_cmd(layout, screen, data.cmds[#data.cmds])
   end

   return {
      start_interactive = start_interactive,
      set_by_cmd = set_by_cmd,
      try_restore_last = try_restore_last,
   }
end

return
   {
      set_region = set_region,
      cycle_region = cycle_region,
      create = create,
      restore_data = restore_data,
   }
