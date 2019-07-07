local function min(a, b)
   if a < b then return a else return b end
end

local function max(a, b)
   if a < b then return b else return a end
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

function do_arrange(p, priv)
   local wa = p.workarea
   local cls = p.clients
   local regions = priv.regions

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

         p.geometries[c] = {
            x = regions[region].x,
            y = regions[region].y,
            width = regions[region].width,
            height = regions[region].height,
         }

         print("Put client " .. tostring(c) .. " to region " .. region)

      end
   end
end

function create()
   local priv = { regions = {} }

   local function set_regions(regions)
      priv.regions = regions
   end

   local function get_regions()
      return priv.regions
   end

   -- move the closest region regardingly to the center distance
   local function resize_handler(c, context, h)
      if context ~= "mouse.move" then return end
      if #priv.regions == 0 then return end

      local center_x = h.x + h.width / 2
      local center_y = h.y + h.height / 2

      local choice = 1
      local choice_value = nil
      for i, r in ipairs(priv.regions) do
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
         c.x = priv.regions[choice].x
         c.y = priv.regions[choice].y
         c.width = priv.regions[choice].width
         c.height = priv.regions[choice].height
      end
   end

   return {
      arrange = function (p) do_arrange(p, priv) end,
      get_region_count = function () return #priv.regions end,
      set_regions = set_regions,
      get_regions = get_regions,
      resize_handler = resize_handler,
   }
end

return { 
   create = create,
   find_region = find_region,
}
