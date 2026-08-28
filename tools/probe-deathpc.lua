-- Which code actually takes the ship? Write-tap ReserveShips and report the
-- PC. rom:D7BC is the state-machine/hyperspace path; anything else points at
-- a collision handler. (ReserveShips is RAM and rarely written, so tagging
-- the PC here is cheap -- and per the toolkit's own pitfall, the PC is only
-- trusted if the instruction there really references this address.)
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local cpu=M.devices[":maincpu"]
local F=0
TAP = mem:install_write_tap(0x52,0x54,"ships",function(off,data)
  if F>1500 then
    print(string.format("f%-5d write ReserveShips[%d] = %d   from PC=$%04X",F,off-0x52,data,cpu.state["GENPC"].value))
  end
  return data
end)
emu.register_frame_done(function() F=F+1 ; if F>3110 then M:exit() end end)
