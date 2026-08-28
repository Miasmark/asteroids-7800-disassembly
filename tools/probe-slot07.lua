-- Are the eight permanently-present $07 slots ($24-$2B) shots? If so their
-- positions must move, and must react to the fire button. If they are HUD
-- elements (score digits, reserve-ship icons) their positions will be
-- static. Watch position arrays ram_18A4 (X) / ram_18C8 (Y) for those slots
-- alongside the known-good $06 shot slots, and the fire button.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local moved07,moved06={},{}
local prevX,prevY={},{}
local fire=0
emu.register_frame_done(function()
  F=F+1
  if F>1400 and F<6000 then
    if (mem:read_u8(0xB8) & 0x80)~=0 then fire=fire+1 end
    for i=0x24,0x2B do
      local x,y=mem:read_u8(0x18A4+i),mem:read_u8(0x18C8+i)
      if prevX[i] and (x~=prevX[i] or y~=prevY[i]) then moved07[i]=(moved07[i] or 0)+1 end
      prevX[i],prevY[i]=x,y
    end
    for i=0x1C,0x1F do
      local x,y=mem:read_u8(0x18A4+i),mem:read_u8(0x18C8+i)
      if prevX[i] and (x~=prevX[i] or y~=prevY[i]) then moved06[i]=(moved06[i] or 0)+1 end
      prevX[i],prevY[i]=x,y
    end
  end
  if F>6000 then
    print("frames where position CHANGED (f1400-6000):")
    print("  the eight always-present $07 slots:")
    for i=0x24,0x2B do print(string.format("     [%02X] %d",i,moved07[i] or 0)) end
    print("  the known $06 shot slots, for comparison:")
    for i=0x1C,0x1F do print(string.format("     [%02X] %d",i,moved06[i] or 0)) end
    M:exit()
  end
end)
