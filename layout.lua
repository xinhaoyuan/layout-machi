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
   local priv = {}

   local function set_regions(regions)
      priv.regions = regions
   end

   local function get_regions()
      return priv.regions
   end

   set_regions(regions)

   return {
      name = "machi[" .. name .. "]",
      arrange = function (p) do_arrange(p, priv) end,
      get_region_count = function () return #priv.regions end,
      set_regions = set_regions,
      get_regions = get_regions,
   }
end

return { 
   create_layout = create_layout,
}
