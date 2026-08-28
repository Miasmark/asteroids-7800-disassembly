-- Decisive test. rom:sub_D540 (button B) starts hyperspace: ram_007E,X=2 and
-- the phase timer ram_0080,X=$2C. The state machine at rom:L_D72E checks
-- ram_00A5 when that timer reaches $29 -- three steps later -- and a negative
-- ram_00A5 there costs a ship (rom:D7BC). Log each hyperspace start and what
-- happened at the $29 checkpoint.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local prev7E={} ; local armed={}
local nHyper,nDied=0,0
emu.register_frame_done(function()
  F=F+1
  for p=0,1 do
    local s7e=mem:read_u8(0x7E+p)
    local t  =mem:read_u8(0x80+p)
    if s7e==2 and prev7E[p]~=2 then
      nHyper=nHyper+1 ; armed[p]={f=F,ships=mem:read_u8(0x52+mem:read_u8(0x7A))}
    end
    if armed[p] and t==0x29 then
      local a5=mem:read_u8(0xA5)
      local die=(a5>=0x80)
      if die then nDied=nDied+1 end
      print(string.format("f%-6d P%d hyperspace(f%d) reached timer 0x29 : ram_00A5=0x%02X -> %s",
        F,p+1,armed[p].f,a5, die and "DIES" or "survives"))
      armed[p]=nil
    end
    prev7E[p]=s7e
  end
  if F>13960 then
    print(string.format("=== %d hyperspace jumps, %d ended in death (%.0f%%) ===",
      nHyper,nDied, nHyper>0 and 100*nDied/nHyper or 0))
    M:exit()
  end
end)
