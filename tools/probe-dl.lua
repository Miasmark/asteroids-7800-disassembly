-- Confirm what MARIA actually reads. rom:F506 sets CHARBASE=$E0, which would
-- mean glyph data is fetched straight from ROM $E000+ rather than copied to
-- RAM as in the sibling project. Dump RAM mid-play so the display list can
-- be walked, and report the live CHARBASE/DPP registers.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
emu.register_frame_done(function()
  F=F+1
  if F==2500 then
    local f=io.open("dl-play.bin","wb")
    for a=0x1800,0x27FF do f:write(string.char(mem:read_u8(a))) end
    f:close()
    print(string.format("CHARBASE($34)=$%02X  DPPH($2C)=$%02X  DPPL($30)=$%02X  CTRL($3C)=$%02X",
      mem:read_u8(0x34),mem:read_u8(0x2C),mem:read_u8(0x30),mem:read_u8(0x3C)))
    M:exit()
  end
end)
