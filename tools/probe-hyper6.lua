-- Pair each hyperspace jump with the exact frame a ship is actually lost.
-- run-01's 40-45 frame window was too short: the loss lands ~100+ frames
-- after the jump. Also logs ram_00A5 at re-entry, which run-02 shows is
-- $FF on EVERY jump including survivals -- so it cannot be the decider.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F,jump,lastJump=0,0,nil
local prev7E,prevS={},{}
emu.register_frame_done(function()
  F=F+1
  local s={mem:read_u8(0x52),mem:read_u8(0x53),mem:read_u8(0x54)}
  for p=0,1 do
    local s7e=mem:read_u8(0x7E+p)
    if s7e==2 and prev7E[p]~=2 then
      jump=jump+1
      lastJump={n=jump,f=F,a5=nil}
      print(string.format("f%-5d JUMP #%d", F, jump))
    end
    prev7E[p]=s7e
    if lastJump and not lastJump.a5 and mem:read_u8(0x80+p)==0x29 then
      lastJump.a5=mem:read_u8(0xA5)
      print(string.format("f%-5d   re-entry checkpoint: ram_00A5=0x%02X",F,lastJump.a5))
    end
  end
  for i=1,3 do
    if prevS[i] and s[i]<prevS[i] then
      local since = lastJump and (F-lastJump.f) or -1
      print(string.format("f%-5d   *** SHIP LOST *** slot%d %d->%d   (%d frames after JUMP #%s)",
        F,i-1,prevS[i],s[i],since, lastJump and lastJump.n or "?"))
    end
    prevS[i]=s[i]
  end
  if F>3110 then M:exit() end
end)
