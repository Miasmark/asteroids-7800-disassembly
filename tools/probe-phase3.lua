-- Where do the survived jumps (1-4) and the fatal ones (5,6) diverge?
-- Log every ShipSpecialState transition with the ShipPhaseTimer value at
-- that moment, so the phase-3 timeline of each jump can be compared.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F,prev,jump=0,nil,0
emu.register_frame_done(function()
  F=F+1
  local s=mem:read_u8(0x7E)
  if s~=prev then
    if s==2 then jump=jump+1 ; print(string.format("--- JUMP #%d (f%d) ---",jump,F)) end
    print(string.format("   f%-5d state %s -> %-3s  timer=0x%02X",
      F, prev and string.format("%d",prev) or "?", string.format("%d",s), mem:read_u8(0x80)))
    prev=s
  end
  if F>3110 then M:exit() end
end)
