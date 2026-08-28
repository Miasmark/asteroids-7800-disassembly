-- run-06 is a competitive two-player run recorded to capture the 500-point
-- award for destroying the other player's ship -- the one entry in the
-- score table never confirmed live. Log every score change for both
-- players alongside GameMode and both ships' ObjType, so a +500 can be tied
-- to a ship actually being destroyed.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local function sc(b)
  local s="" ; for i=0,3 do s=s..string.format("%02X",mem:read_u8(b+i)) end
  return tonumber(s) or 0
end
local p1,p2=0,0
local hist={}
emu.register_frame_done(function()
  F=F+1
  local a,b=sc(0x46),sc(0x4A)
  if F>300 then
    if a~=p1 and a>p1 then
      local d=a-p1 ; hist[d]=(hist[d] or 0)+1
      if d==500 then print(string.format("f%-5d  P1 +500  mode=%d  ships: A4=$%02X A5?=.. ",F,mem:read_u8(0x82),mem:read_u8(0xA4))) end
    end
    if b~=p2 and b>p2 then
      local d=b-p2 ; hist[d]=(hist[d] or 0)+1
      if d==500 then print(string.format("f%-5d  P2 +500  mode=%d",F,mem:read_u8(0x82))) end
    end
  end
  p1,p2=a,b
  if F>2890 then
    print("=== score-delta histogram (both players) ===")
    local k={} ; for x in pairs(hist) do k[#k+1]=x end ; table.sort(k)
    for _,x in ipairs(k) do print(string.format("   +%-5d x%d",x,hist[x])) end
    print(string.format("   final GameMode=%d  Difficulty=%d",mem:read_u8(0x82),mem:read_u8(0x83)))
    M:exit()
  end
end)
