-- The user reports that spamming hyperspace ("emergency teleport") sometimes
-- kills the ship with no collision. ram_00A5 is the byte the death path at
-- rom:D79E branches on ($FF = die). Log every transition of ram_00A5 to $FF
-- alongside whether a hyperspace input (joystick DOWN, active-low in SWCHA)
-- was held recently, and whether ReserveShips actually dropped.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local lastA5,lastShips=nil,{}
local downHist={}   -- frame -> true if either player held DOWN
emu.register_frame_done(function()
  F=F+1
  local sw=mem:read_u8(0x0280)
  -- active low: P1 down = bit5, P2 down = bit1
  local p1down = (sw & 0x20)==0
  local p2down = (sw & 0x02)==0
  downHist[F] = p1down or p2down
  local a5=mem:read_u8(0xA5)
  local s={mem:read_u8(0x52),mem:read_u8(0x53),mem:read_u8(0x54)}
  if a5==0xFF and lastA5~=0xFF then
    -- was hyperspace input held in the preceding 40 frames?
    local held=0
    for i=math.max(1,F-40),F do if downHist[i] then held=held+1 end end
    print(string.format("f%-6d A5->FF  mode=%d cur=%d state7B=%d ships=%d/%d/%d  DOWN held %d of last 40 frames",
      F,mem:read_u8(0x82),mem:read_u8(0x7A),mem:read_u8(0x7B),s[1],s[2],s[3],held))
  end
  for i=1,3 do
    if lastShips[i] and s[i]<lastShips[i] then
      print(string.format("f%-6d   -> ReserveShips[%d] %d->%d",F,i-1,lastShips[i],s[i]))
    end
    lastShips[i]=s[i]
  end
  lastA5=a5
  if F>13960 then M:exit() end
end)
