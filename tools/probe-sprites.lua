-- Build the direct-mode sprite inventory. Walks MARIA's display list every
-- frame from the real DLL ($1A98, obtained by write-tapping DPPH/DPPL) and
-- records every graphics pointer that lands in $C000-$CFFF together with the
-- entry's own width and the zone's line count -- the parameters gfx.py needs
-- to render an object at its true extent rather than a guessed one.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local DLL=0x1A98
local seen={}
emu.register_frame_done(function()
  F=F+1
  if F>1400 and F<6000 then
    for z=0,24 do
      local e=DLL+3*z
      local b0=mem:read_u8(e)
      local lines=(b0 & 0x0F)+1
      local dl=(mem:read_u8(e+1)<<8)|mem:read_u8(e+2)
      if dl>=0x1800 and dl<=0x27FF then
        local off=0
        for _=1,24 do
          local a=dl+off
          local b1=mem:read_u8(a+1)
          if b1==0 then break end
          if (b1 & 0x1F)==0 then off=off+5
          else
            local gfx=(mem:read_u8(a+2)<<8)|mem:read_u8(a)
            local w=32-(b1 & 0x1F)
            if gfx>=0xC000 and gfx<=0xCFFF then
              local k=string.format("%04X|%d|%d",gfx,w,lines)
              seen[k]=(seen[k] or 0)+1
            end
            off=off+4
          end
        end
      end
    end
  end
  if F>6000 then
    local k={} ; for x in pairs(seen) do k[#k+1]=x end ; table.sort(k)
    print("gfx      width  lines  frames")
    for _,x in ipairs(k) do
      local g,w,l=x:match("(%x+)|(%d+)|(%d+)")
      print(string.format("  $%s   %-5s  %-5s  %d",g,w,l,seen[x]))
    end
    print(string.format("  (%d distinct)",#k))
    M:exit()
  end
end)
