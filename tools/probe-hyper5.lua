-- run-02 was recorded specifically to capture hyperspace deaths: most
-- asteroids cleared, teleport pressed repeatedly, and per the user the 6th
-- jump killed with no collision, then further deaths on later jumps, all
-- from teleport. Log every jump with the re-entry ram_00A5 value AND the
-- actual reserve-ship counts before/after, so 'branch taken' and 'ship
-- actually lost' can't be conflated the way they were on run-01.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local prev7E,prevS={},{}
local jump=0
local pend={}
emu.register_frame_done(function()
  F=F+1
  local s={mem:read_u8(0x52),mem:read_u8(0x53),mem:read_u8(0x54)}
  for p=0,1 do
    local s7e=mem:read_u8(0x7E+p)
    if s7e==2 and prev7E[p]~=2 then
      jump=jump+1
      pend[#pend+1]={n=jump,f=F,p=p,s={s[1],s[2],s[3]},a5=nil,done=false}
      print(string.format("f%-5d JUMP #%d  P%d  ships=%d/%d/%d",F,jump,p+1,s[1],s[2],s[3]))
    end
    prev7E[p]=s7e
    if pend[#pend] and not pend[#pend].a5 and mem:read_u8(0x80+p)==0x29 then
      pend[#pend].a5=mem:read_u8(0xA5)
    end
  end
  for _,e in ipairs(pend) do
    if not e.done and F-e.f>=45 then
      e.done=true
      local lost=(s[1]<e.s[1]) or (s[2]<e.s[2]) or (s[3]<e.s[3])
      print(string.format("      -> jump #%d: reentry ram_00A5=%s  ships now %d/%d/%d  => %s",
        e.n, e.a5 and string.format("0x%02X",e.a5) or "(not seen)",
        s[1],s[2],s[3], lost and "*** SHIP LOST ***" or "survived"))
    end
  end
  if F>3110 then M:exit() end
end)
