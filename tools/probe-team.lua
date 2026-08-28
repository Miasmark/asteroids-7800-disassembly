-- The user reports Team mode shows a SHARED score at top-centre. The score
-- routine indexes by CurrentPlayer(ram_007A)*4, and its bonus-ship path
-- special-cases CurrentPlayer==2 when ram_0082==1 -- implying a THIRD score
-- slot at ram_004E-ram_0051 used as the shared team score, plus a per-slot
-- reserve-ship count at ram_0052,X. Watch all three scores, the mode byte,
-- the player index, and the reserve counts.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local function sc(b)
  local s="" ; for i=0,3 do s=s..string.format("%02X",mem:read_u8(b+i)) end
  return tonumber(s) or 0
end
local last={}
emu.register_frame_done(function()
  F=F+1
  local v={sc(0x46),sc(0x4A),sc(0x4E),mem:read_u8(0x82),mem:read_u8(0x7A),
           mem:read_u8(0x52),mem:read_u8(0x53),mem:read_u8(0x54)}
  local key=table.concat(v,",")
  if key~=last.k then
    print(string.format("f%-6d mode=%d cur=%d | P1=%-7d P2=%-7d SLOT2=%-7d | ships %d/%d/%d",
      F,v[4],v[5],v[1],v[2],v[3],v[6],v[7],v[8]))
    last.k=key
  end
  if F>13960 then M:exit() end
end)
