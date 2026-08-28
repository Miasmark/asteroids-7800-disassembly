-- Corrected instrumentation. rom:sub_D66A reads a two-button ProLine
-- controller into ram_00B8,X (button A) and ram_00BA,X (button B), X=player,
-- inverted so 'pressed' shows as bit7 set. Watch BOTH buttons per player and
-- correlate presses with ram_00A5 going to $FF (the byte rom:D79E branches on
-- to take a ship away) and with ReserveShips actually dropping.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local lastA5, prevB = nil, {}
local pressF = {}          -- last frame each button went down
local nPress = {0,0,0,0}
emu.register_frame_done(function()
  F=F+1
  -- index 1,2 = players' button A ; 3,4 = players' button B
  local b={mem:read_u8(0xB8),mem:read_u8(0xB9),mem:read_u8(0xBA),mem:read_u8(0xBB)}
  for i=1,4 do
    local down = (b[i] & 0x80)~=0
    local was  = prevB[i] and ((prevB[i] & 0x80)~=0) or false
    if down and not was then pressF[i]=F; nPress[i]=nPress[i]+1 end
    prevB[i]=b[i]
  end
  local a5=mem:read_u8(0xA5)
  if a5==0xFF and lastA5~=0xFF then
    local gaps={}
    for i=1,4 do gaps[i] = pressF[i] and (F-pressF[i]) or -1 end
    print(string.format("f%-6d A5->FF mode=%d cur=%d | frames since last press  P1a=%-5d P2a=%-5d P1b=%-5d P2b=%-5d",
      F,mem:read_u8(0x82),mem:read_u8(0x7A),gaps[1],gaps[2],gaps[3],gaps[4]))
  end
  lastA5=a5
  if F>13960 then
    print(string.format("=== total presses: P1 btnA=%d  P2 btnA=%d  P1 btnB=%d  P2 btnB=%d ===",
      nPress[1],nPress[2],nPress[3],nPress[4]))
    M:exit()
  end
end)
