local machi = {
   layout = require((...):match("(.-)[^%.]+$") .. "layout"),
}

local api = {
   beautiful  = require("beautiful"),
   wibox      = require("wibox"),
   awful      = require("awful"),
   screen     = require("awful.screen"),
   layout     = require("awful.layout"),
   keygrabber = require("awful.keygrabber"),
   naughty    = require("naughty"),
   gears      = require("gears"),
   gfs        = require("gears.filesystem"),
   lgi        = require("lgi"),
   dpi        = require("beautiful.xresources").apply_dpi,
}

local function with_alpha(col, alpha)
   local r, g, b
   _, r, g, b, _ = col:get_rgba()
   return api.lgi.cairo.SolidPattern.create_rgba(r, g, b, alpha)
end

local function max(a, b)
   if a < b then return b else return a end
end

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

local function fair_split(total, shares, shares_sum)
   local ret = {}
   local acc = 0
   local acc_ret = 0
   if shares_sum == nil then
      shares_sum = 0
      for i = 1, #shares do shares_sum = shares_sum + shares[i] end
   end
   for i = 1, #shares do
      acc = acc + shares[i]
      ret[i] = i < #shares and math.floor(total / shares_sum * acc - acc_ret + 0.5) or total - acc_ret
      acc_ret = acc_ret + ret[i]
   end
   return ret
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

--- fit the client into the machi of the screen
-- @param  c     the client to fit
-- @param  cycle whether to cycle the region if the window is already in machi
-- @return       whether any actions have been taken on the client
local function fit_region(c, cycle)
   local layout = api.layout.get(c.screen)
   local regions = layout.machi_get_regions and layout.machi_get_regions(c.screen.workarea, c.screen.selected_tag)
   if type(regions) ~= "table" or #regions < 1 then
      return false
   end
   local current_region = c.machi_region or 1
   if not is_tiling(c) then
      -- find out which region has the most intersection, calculated by a cap b / a cup b
      c.machi_region = machi.layout.find_region(c, regions)
      set_tiling(c)
   elseif cycle then
      if current_region >= #regions then
         c.machi_region = 1
      else
         c.machi_region = current_region + 1
      end
      api.layout.arrange(c.screen)
   else
      return false
   end
   return true
end

local function _area_tostring(wa)
   return "{x:" .. tostring(wa.x) .. ",y:" .. tostring(wa.y) .. ",w:" .. tostring(wa.width) .. ",h:" .. tostring(wa.height) .. "}"
end

local function shrink_area_with_gap(a, inner_gap, outer_gap)
   return { x = a.x + (a.bl and outer_gap or inner_gap / 2), y = a.y + (a.bu and outer_gap or inner_gap / 2),
            width = a.width - (a.bl and outer_gap or inner_gap / 2) - (a.br and outer_gap or inner_gap / 2),
            height = a.height - (a.bu and outer_gap or inner_gap / 2) - (a.bd and outer_gap or inner_gap / 2) }
end

-- local function parse(cmd)
--    root = {}
--    args = ""

--    open_areas = { root }

--    for c = 1, #cmd do
--       char = cmd:sub(c, c)

--       if char == "w" then
--          local a = open_areas[#open_areas]
--          table.remove(open_areas, #open_areas)

--          root.type = "w"
--          root.

--       else if tonumber(char) ~= nil then
--          args = args .. char
--       end
--    end
-- end

local function restore_data(data)
   if data.history_file then
      local file, err = io.open(data.history_file, "r")
      if err then
         print("cannot read history from " .. data.history_file)
      else
         data.cmds = {}
         data.last_cmd = {}
         local last_layout_name
         for line in file:lines() do
            if line:sub(1, 1) == "+" then
               last_layout_name = line:sub(2, #line)
            else
               if last_layout_name ~= nil then
                  print("restore last cmd " .. line .. " for " .. last_layout_name)
                  data.last_cmd[last_layout_name] = line
                  last_layout_name = nil
               else
                  print("restore cmd " .. line)
                  data.cmds[#data.cmds + 1] = line
               end
            end
         end
         file:close()
      end
   end

   return data
end

local function create(data)
   if data == nil then
      data = restore_data({
            history_file = api.gfs.get_cache_dir() .. "/history_machi",
            history_save_max = 100,
      })
   end

   if data.cmds == nil then
      data.cmds = {}
   end

   if data.last_cmd == nil then
      data.last_cmd = {}
   end

   local init_max_depth = 2

   local closed_areas
   local open_areas
   local history
   local args
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
      args = ""
      max_depth = init_max_depth
      current_info = ""
      current_cmd = ""
      to_exit = false
      to_apply = false
   end

   local function push_history()
      history[#history + 1] = {#closed_areas, #open_areas, {}, current_info, current_cmd, max_depth, args}
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
      args = history[#history][7]

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

      local a = pop_open_area()

      print("split " .. method .. " " .. tostring(alt) .. " " .. args .. " " .. _area_tostring(a))

      if method == "h" or method == "v" then

         if #args == 0 then
            args = "11"
         elseif #args == 1 then
            args = args .. "1"
         end

         local total = 0
         local shares = { }
         for i = 1, #args do
            local arg
            if not alt then
               arg = tonumber(args:sub(i, i))
            else
               arg = tonumber(args:sub(#args - i + 1, #args - i + 1))
            end
            if arg < 1 then arg = 1 end
            total = total + arg
            shares[i] = arg
         end
         local children = {}

         if method == "h" then
            shares = fair_split(a.width, shares, total)
            for i = 1, #shares do
               local child = {
                  x = i == 1 and a.x or children[#children].x + children[#children].width,
                  y = a.y,
                  width = shares[i],
                  height = a.height,
                  depth = a.depth + 1,
                  group_id = split_count,
                  bl = i == 1 and a.bl or false,
                  br = i == #shares and a.br or false,
                  bu = a.bu,
                  bd = a.bd,
               }
               children[#children + 1] = child
            end
         else
            shares = fair_split(a.height, shares, total)
            for i = 1, #shares do
               local child = {
                  x = a.x,
                  y = i == 1 and a.y or children[#children].y + children[#children].height,
                  width = a.width,
                  height = shares[i],
                  depth = a.depth + 1,
                  group_id = split_count,
                  bl = a.bl,
                  br = a.br,
                  bu = i == 1 and a.bu or false,
                  bd = i == #shares and a.bd or false,
               }
               children[#children + 1] = child
            end
         end

         for i = #children, 1, -1 do
            if children[i].x ~= math.floor(children[i].x)
               or children[i].y ~= math.floor(children[i].y)
               or children[i].width ~= math.floor(children[i].width)
               or children[i].height ~= math.floor(children[i].height)
            then
               print("warning, splitting yields floating area " .. _area_tostring(children[i]))
            end
            open_areas[#open_areas + 1] = children[i]
         end

      elseif method == "w" then

         if #args == 0 then
            args = "11"
         elseif #args == 1 then
            args = "1" .. args
         end

         if alt then args = string.reverse(args) end

         local h_split = tonumber(args:sub(#args - 1, #args - 1))
         local v_split = tonumber(args:sub(#args, #args))
         if h_split < 1 then h_split = 1 end
         if v_split < 1 then v_split = 1 end

         local x_shares = {}
         local y_shares = {}
         for i = 1, h_split do x_shares[i] = 1 end
         for i = 1, v_split do y_shares[i] = 1 end

         x_shares = fair_split(a.width, x_shares, h_split)
         y_shares = fair_split(a.height, y_shares, v_split)

         local children = {}
         for y_index = 1, v_split do
            for x_index = 1, h_split do
               local r = {
                  x = x_index == 1 and a.x or children[#children].x + children[#children].width,
                  y = y_index == 1 and a.y or (x_index == 1 and children[#children].y + children[#children].height or children[#children].y),
                  width = x_shares[x_index],
                  height = y_shares[y_index],
                  depth = a.depth + 1,
                  group_id = split_count,
               }
               if x_index == 1 then r.bl = a.bl else r.bl = false end
               if x_index == h_split then r.br = a.br else r.br = false end
               if y_index == 1 then r.bu = a.bu else r.bu = false end
               if y_index == v_split then r.bd = a.bd else r.bd = false end
               children[#children + 1] = r
            end
         end

         for i = #children, 1, -1 do
            if children[i].x ~= math.floor(children[i].x)
               or children[i].y ~= math.floor(children[i].y)
               or children[i].width ~= math.floor(children[i].width)
               or children[i].height ~= math.floor(children[i].height)
            then
               print("warning, splitting yields floating area " .. _area_tostring(children[i]))
            end
            open_areas[#open_areas + 1] = children[i]
         end

      elseif method == "p" then
         -- XXX
      end

      args = ""
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
         if args == "" then
            push_area()
         else
            handle_split("w", key == "W")
         end
      elseif key == "p" or key == "P" then
         handle_split("p", key == "P")
      elseif key == "s" or key == "S" then
         if #open_areas > 0 then
            key = "s"
            local times = args == "" and 1 or tonumber(args)
            local t = {}
            while #open_areas > 0 do
               t[#t + 1] = pop_open_area()
            end
            for i = #t, 1, -1 do
               open_areas[#open_areas + 1] = t[(i + times - 1) % #t + 1]
            end
            args = ""
         else
            return nil
         end
      elseif key == " " or key == "-" then
         key = "-"
         if args == "" then
            push_area()
         else
            max_depth = tonumber(args)
            args = ""
         end
      elseif key == "Return" or key == "." then
         key = "."
         while #open_areas > 0 do
            push_area()
         end
         args = ""
      elseif tonumber(key) ~= nil then
         args = args .. key
      else
         return nil
      end

      while #open_areas > 0 and open_areas[#open_areas].depth >= max_depth do
         push_area()
      end

      return key
   end

   local function set_gap(inner_gap, outer_gap)
      data.inner_gap = inner_gap
      data.outer_gap = outer_gap
   end

   local function start_interactive(screen, layout)
      local outer_gap = data.outer_gap or data.gap or api.beautiful.useless_gap * 2 or 0
      local inner_gap = data.inner_gap or data.gap or api.beautiful.useless_gap * 2 or 0
      local label_font_family = api.beautiful.get_font(
         api.beautiful.mono_font or api.beautiful.font):get_family()
      local label_size = api.dpi(30)
      local info_size = api.dpi(60)
      -- colors are in rgba
      local border_color = with_alpha(api.gears.color(api.beautiful.border_focus), 0.75)
      local active_color = with_alpha(api.gears.color(api.beautiful.bg_focus), 0.5)
      local open_color   = with_alpha(api.gears.color(api.beautiful.bg_normal), 0.5)
      local closed_color = open_color

      screen = screen or api.screen.focused()
      layout = layout or api.layout.get(screen)
      local tag = screen.selected_tag

      if layout.machi_set_cmd == nil then
         api.naughty.notify({
            text = "The layout to edit is not machi",
            timeout = 3,
         })
         return
      end

      local cmd_index = #data.cmds + 1
      data.cmds[cmd_index] = ""

      local start_x = screen.workarea.x
      local start_y = screen.workarea.y

      local kg
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

      local function cleanup()
         infobox.visible = false
      end

      local function draw_info(context, cr, width, height)
         cr:set_source_rgba(0, 0, 0, 0)
         cr:rectangle(0, 0, width, height)
         cr:fill()

         local msg, ext

         for i, a in ipairs(closed_areas) do
            local sa = shrink_area_with_gap(a, inner_gap, outer_gap)
            cr:rectangle(sa.x - start_x, sa.y - start_y, sa.width, sa.height)
            cr:clip()
            cr:set_source(closed_color)
            cr:rectangle(sa.x - start_x, sa.y - start_y, sa.width, sa.height)
            cr:fill()
            cr:set_source(border_color)
            cr:rectangle(sa.x - start_x, sa.y - start_y, sa.width, sa.height)
            cr:set_line_width(10.0)
            cr:stroke()
            cr:reset_clip()
         end

         for i, a in ipairs(open_areas) do
            local sa = shrink_area_with_gap(a, inner_gap, outer_gap)
            cr:rectangle(sa.x - start_x, sa.y - start_y, sa.width, sa.height)
            cr:clip()
            if i == #open_areas then
               cr:set_source(api.gears.color(active_color))
            else
               cr:set_source(api.gears.color(open_color))
            end
            cr:rectangle(sa.x - start_x, sa.y - start_y, sa.width, sa.height)
            cr:fill()

            cr:set_source(border_color)
            cr:rectangle(sa.x - start_x, sa.y - start_y, sa.width, sa.height)
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

      kg = keygrabber.run(
         function (mod, key, event)
            if event == "release" then
               return
            end

            local ok, err = pcall(
               function ()
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
                        local cmd = data.cmds[cmd_index]:sub(i, i)

                        push_history()
                        local ret = handle_command(cmd)

                        if ret == nil then
                           print("warning: ret is nil")
                        else
                           current_info = current_info .. ret
                           current_cmd = current_cmd .. ret
                        end
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

                        local instance_name, persistent = layout.machi_get_instance_name(tag)
                        if persistent then
                           data.last_cmd[instance_name] = current_cmd
                           if data.history_file then
                              local file, err = io.open(data.history_file, "w")
                              if err then
                                 print("cannot save history to " .. data.history_file)
                              else
                                 for i = max(1, #data.cmds - data.history_save_max + 1), #data.cmds do
                                    print("save cmd " .. data.cmds[i])
                                    file:write(data.cmds[i] .. "\n")
                                 end
                                 for name, cmd in pairs(data.last_cmd) do
                                    print("save last cmd " .. cmd .. " for " .. name)
                                    file:write("+" .. name .. "\n" .. cmd .. "\n")
                                 end
                              end
                              file:close()
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
                        layout.machi_set_cmd(current_cmd, tag)
                        api.layout.arrange(screen)
                        api.gears.timer{
                           timeout = 1,
                           autostart = true,
                           singleshot = true,
                           callback = cleanup,
                        }
                     else
                        cleanup()
                     end
                  end
            end)

            if not ok then
               print("Getting error in keygrabber: " .. err)
               to_exit = true
               cleanup()
            end

            if to_exit then
               keygrabber.stop(kg)
            end
         end
      )
   end

   local function run_cmd(init_area, cmd)
      local outer_gap = data.outer_gap or data.gap or api.beautiful.useless_gap * 2 or 0
      local inner_gap = data.inner_gap or data.gap or api.beautiful.useless_gap * 2 or 0
      init(init_area)
      push_history()

      for i = 1, #cmd do
         local key = handle_command(cmd:sub(i, i))
      end

      local areas_with_gap = {}
      for _, a in ipairs(closed_areas) do
         areas_with_gap[#areas_with_gap + 1] = shrink_area_with_gap(a, inner_gap, outer_gap)
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

      return areas_with_gap
   end

   local function get_last_cmd(name)
      return data.last_cmd[name]
   end

   return {
      start_interactive = start_interactive,
      run_cmd = run_cmd,
      get_last_cmd = get_last_cmd,
      set_gap = set_gap,
   }
end

return
   {
      set_region = set_region,
      fit_region = fit_region,
      create = create,
      restore_data = restore_data,
   }
