-- Who writes the saucer's ObjType, and with which size? Write-tap
-- ObjTypeSaucer ($00A5) and report the value plus the writing PC. run-03
-- contains four large saucers ($25) then two small ones ($14), so the
-- selection rule should be visible in what differs between those writes.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local cpu=M.devices[":maincpu"]
local F=0
TAP = mem:install_write_tap(0xA5,0xA5,"st",function(off,data)
  if F>200 and data~=0xFF then
    print(string.format("f%-5d ObjTypeSaucer <- $%02X  from PC=$%04X  (wave-ish ram_005C=$%02X)",
      F,data,cpu.state["GENPC"].value,mem:read_u8(0x5C)))
  end
  return data
end)
emu.register_frame_done(function() F=F+1 ; if F>6450 then M:exit() end end)
