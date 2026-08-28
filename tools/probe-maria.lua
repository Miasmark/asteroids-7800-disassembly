-- MARIA's registers are write-only, so they must be caught on the write.
-- Tap CHARBASE ($34) and the display-list pointer ($2C/$30) to learn where
-- MARIA is actually fetching character data from during play.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local seen={}
TAP = mem:install_write_tap(0x2C,0x34,"maria",function(off,data)
  if F>1500 then
    local k=string.format("$%02X=$%02X",off,data)
    if not seen[k] then seen[k]=F ; print(string.format("f%-6d MARIA write %s",F,k)) end
  end
  return data
end)
emu.register_frame_done(function() F=F+1 ; if F>3000 then M:exit() end end)
