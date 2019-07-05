function do_arrange(p, priv)
   local wa = p.workarea
   local cls = p.clients
   local regions = priv.regions

   for i, c in ipairs(cls) do
      if c.floating then
         print("Ignore client " .. tostring(c))
      else
         local region
         if c.machi_region == nil then
            c.machi_region = 1
            region = 1
         elseif c.machi_region > #regions then
            region = #regions
         elseif c.machi_region <= 1 then
            region = 1
         else
            region = c.machi_region
         end

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

function create_layout(name, regions)
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

   set_regions(regions)

   return {
      name = "machi[" .. name .. "]",
      arrange = function (p) do_arrange(p, priv) end,
      get_region_count = function () return #priv.regions end,
      set_regions = set_regions,
      get_regions = get_regions,
      resize_handler = resize_handler,
   }
end

return { 
   create_layout = create_layout,
}
