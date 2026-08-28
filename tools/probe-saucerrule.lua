-- The size rule at rom:L_F581: a small saucer results either when the
-- score's 10,000s byte (ram_0047) reaches 2 -- i.e. 20,000 points -- or,
-- below that, when a random byte beats ram_00E5/2, where ram_00E5 is seeded
-- per difficulty and decreases by 3 with each saucer spawned. Log both
-- inputs at each spawn to see which path fired.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
TAP = mem:install_write_tap(0xA5,0xA5,"st",function(off,data)
  if F>200 and (data==0x25 or data==0x14) then
    local sc=""
    for i=0,3 do sc=sc..string.format("%02X",mem:read_u8(0x46+i)) end
    print(string.format("f%-5d %s  score=%-8s ram_0047=$%02X  ram_00E5=$%02X (half=$%02X)  saucerCount=$%02X",
      F, data==0x25 and "LARGE" or "small", tonumber(sc) or 0,
      mem:read_u8(0x47), mem:read_u8(0xE5), mem:read_u8(0xE5)//2, mem:read_u8(0xC3)))
  end
  return data
end)
emu.register_frame_done(function() F=F+1 ; if F>6450 then M:exit() end end)
