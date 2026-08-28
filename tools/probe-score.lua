-- Verify the point-value table at dat_FEDC/dat_FEE4 live: watch both
-- players' 4-byte packed-BCD scores and report every change as a delta.
-- Every delta should be one of the manual's values (20/50/100/200/500/1000)
-- or a sum of them if two awards land in the same frame.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local function score(base)
  local s=""
  for i=0,3 do s=s..string.format("%02X",mem:read_u8(base+i)) end
  return tonumber(s) or 0
end
local p1,p2=0,0
local seen={}
emu.register_frame_done(function()
  F=F+1
  local a,b=score(0x46),score(0x4A)
  if a~=p1 then
    local d=a-p1
    print(string.format("frame %6d  P1 %8d  (+%d)",F,a,d)); seen[d]=(seen[d] or 0)+1; p1=a
  end
  if b~=p2 then
    local d=b-p2
    print(string.format("frame %6d  P2 %8d  (+%d)",F,b,d)); seen[d]=(seen[d] or 0)+1; p2=b
  end
  if F>13960 then
    print("=== delta histogram ===")
    local k={} ; for d in pairs(seen) do k[#k+1]=d end ; table.sort(k)
    for _,d in ipairs(k) do print(string.format("   +%-6d x%d",d,seen[d])) end
    M:exit()
  end
end)
