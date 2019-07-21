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
      if instance.cmd == nil then return {} end

      local key = tostring(workarea.width) .. "x" .. tostring(workarea.height) .. "+" .. tostring(workarea.x) .. "+" .. tostring(workarea.y)
      if instance.regions_cache[key] == nil then
         instance.regions_cache[key] = editor.run_cmd(workarea, instance.cmd)
      end
      return instance.regions_cache[key]
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
      local regions = get_regions(wa, get_screen(p.screen).selected_tag)

      if #regions == 0 then return end

      for i, c in ipairs(cls) do
         if c.floating then
            print("Ignore client " .. tostring(c))
         else
            if c.machi_region == nil then
               c.machi_region = find_region(c, regions)
            elseif c.machi_region > #regions then
               c.machi_region = #regions
            elseif c.machi_region <= 1 then
               c.machi_region = 1
            end
            local region = c.machi_region

            -- Editor already handled useless_gap in the stored regions.
            -- We try to negate the gap of outer layer.
            p.geometries[c] = {
               x = regions[region].x - useless_gap,
               y = regions[region].y - useless_gap,
               width = regions[region].width + useless_gap * 2,
               height = regions[region].height + useless_gap * 2,
            }

            print("Put client " .. tostring(c) .. " to region " .. region)

         end
      end
   end

   -- move the closest region regardingly to the center distance
   local function resize_handler(c, context, h)
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
         c.x = regions[choice].x
         c.y = regions[choice].y
         c.width = max(1, regions[choice].width - 2 * border_width)
         c.height = max(1, regions[choice].height - 2 * border_width)
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
   find_region = find_region,
}
