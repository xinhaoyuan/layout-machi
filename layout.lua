local api = {
   screen = screen,
}

local function min(a, b)
   if a < b then return a else return b end
end

local function max(a, b)
   if a < b then return b else return a end
end

local function get_screen(s)
    return s and api.screen[s]
end

--- find the best region for the area-like object
-- @param c       area-like object - table with properties x, y, width, and height
-- @param regions array of area-like objects
-- @return the index of the best region
local function find_region(c, regions)
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

local function distance(x1, y1, x2, y2)
   -- use d1
   return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function find_lu(c, regions)
   local lu = nil
   for i, a in ipairs(regions) do
      if lu == nil or distance(c.x, c.y, a.x, a.y) < distance(c.x, c.y, regions[lu].x, regions[lu].y) then
         lu = i
      end
   end
   return lu
end

local function find_rd(c, regions, lu)
   assert(lu ~= nil)
   local rd = nil
   for i, a in ipairs(regions) do
      if a.x + a.width > regions[lu].x and a.y + a.height > regions[lu].y then
         if rd == nil or distance(c.x + c.width, c.y + c.height, a.x + a.width, a.y + a.height) < distance(c.x + c.width, c.y + c.height, regions[rd].x + regions[rd].width, regions[rd].y + regions[rd].height) then
            rd = i
         end
      end
   end
   return rd
end

local function set_geometry(c, region_lu, region_rd, useless_gap, border_width)
   -- We try to negate the gap of outer layer8
   c.x = region_lu.x - useless_gap
   c.y = region_lu.y - useless_gap
   c.width = region_rd.x + region_rd.width - region_lu.x + (useless_gap - border_width) * 2
   c.height = region_rd.y + region_rd.height - region_lu.y + (useless_gap - border_width) * 2
end

local function create(name, editor)
   local instances = {}

   local get_instance_name
   if type(name) == "function" then
      get_instance_name = name
   else
      get_instance_name = function () return name, true end
   end

   local function get_instance(tag)
      local name, persistent = get_instance_name(tag)
      if instances[name] == nil then
         instances[name] = {
            cmd = persistent and editor.get_last_cmd(name) or nil,
            regions_cache = {},
         }
      end
      return instances[name]
   end

   local function get_regions(workarea, tag)
      local instance = get_instance(tag)
      if instance.cmd == nil then return {}, false end

      local key = tostring(workarea.width) .. "x" .. tostring(workarea.height) .. "+" .. tostring(workarea.x) .. "+" .. tostring(workarea.y)
      if instance.regions_cache[key] == nil then
         instance.regions_cache[key] = editor.run_cmd(workarea, instance.cmd)
      end
      return instance.regions_cache[key], instance.cmd:sub(1,1) == "d"
   end

   local function set_cmd(cmd, tag)
      local instance = get_instance(tag)
      if instance.cmd ~= cmd then
         instance.cmd = cmd
         instance.regions_cache = {}
      end
   end

   local function arrange(p)
      local useless_gap = p.useless_gap
      local wa = get_screen(p.screen).workarea -- get the real workarea without the gap (instead of p.workarea)
      local cls = p.clients
      local regions, draft_mode = get_regions(wa, get_screen(p.screen).selected_tag)

      if #regions == 0 then return end

      if draft_mode then
         for i, c in ipairs(cls) do
            if c.floating then
            else
               local skip = false
               if c.machi_lu ~= nil and c.machi_rd ~= nil and
                  c.machi_lu <= #regions and c.machi_rd <= #regions
               then
                  if regions[c.machi_lu].x == c.x and
                     regions[c.machi_lu].y == c.y and
                     regions[c.machi_rd].x + regions[c.machi_rd].width - c.border_width * 2 == c.x + c.width and
                     regions[c.machi_rd].y + regions[c.machi_rd].height - c.border_width * 2 == c.y + c.height
                  then
                     skip = true
                  end
               end

               local lu = nil
               local rd = nil
               if not skip then
                  print("Compute regions for " .. c.name)
                  lu = find_lu(c, regions)
                  if lu ~= nil then
                     rd = find_rd(c, regions, lu)
                  end
               end

               if lu ~= nil and rd ~= nil then
                  c.machi_lu, c.machi_rd = lu, rd
                  p.geometries[c] = {}
                  set_geometry(p.geometries[c], regions[lu], regions[rd], useless_gap, 0)
               end
            end
         end
      else
         for i, c in ipairs(cls) do
            if c.floating then
               print("Ignore client " .. tostring(c))
            else
               if c.machi_region ~= nil and
                  regions[c.machi_region].x == c.x and
                  regions[c.machi_region].y == c.y and
                  regions[c.machi_region].width - c.border_width * 2 == c.width and
                  regions[c.machi_region].height - c.border_width * 2 == c.height
               then
               else
                  print("Compute regions for " .. c.name)
                  local region = find_region(c, regions)
                  c.machi_region = region
                  p.geometries[c] = {}
                  set_geometry(p.geometries[c], regions[region], regions[region], useless_gap, 0)
               end
            end
         end
      end
   end

   local function resize_handler (c, context, h)
      local workarea = c.screen.workarea
      local regions, draft_mode = get_regions(workarea, c.screen.selected_tag)

      if #regions == 0 then return end

      if draft_mode then
         local lu = find_lu(h, regions)
         local rd = nil
         if lu ~= nil then
            if context == "mouse.move" then
               local hh = {}
               hh.x = regions[lu].x
               hh.y = regions[lu].y
               hh.width = h.width
               hh.height = h.height
               rd = find_rd(hh, regions, lu)
            else
               rd = find_rd(h, regions, lu)
            end

            if rd ~= nil then
               c.machi_lu = lu
               c.machi_rd = rd
               set_geometry(c, regions[lu], regions[rd], 0, c.border_width)
            end
         end
      else
         if context ~= "mouse.move" then return end

         local workarea = c.screen.workarea
         local regions = get_regions(workarea, c.screen.selected_tag)

         if #regions == 0 then return end

         local center_x = h.x + h.width / 2
         local center_y = h.y + h.height / 2

         local choice = 1
         local choice_value = nil

         for i, r in ipairs(regions) do
            local r_x = r.x + r.width / 2
            local r_y = r.y + r.height / 2
            local dis = (r_x - center_x) * (r_x - center_x) + (r_y - center_y) * (r_y - center_y)
            if choice_value == nil or choice_value > dis then
               choice = i
               choice_value = dis
            end
         end

         if c.machi_region ~= choice then
            c.machi_region = choice
            set_geometry(c, regions[choice], regions[choice], 0, c.border_width)
         end
      end
   end

   return {
      name = "machi",
      arrange = arrange,
      resize_handler = resize_handler,
      machi_get_instance_name = get_instance_name,
      machi_set_cmd = set_cmd,
      machi_get_regions = get_regions,
   }
end

return {
   create = create,
   set_geometry = set_geometry,
}
