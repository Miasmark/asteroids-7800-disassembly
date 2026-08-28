-- run-01 contains three +200 awards (large saucer per the manual) and no
-- +1000. Catch those exact events and dump ObjType either side, to identify
-- the saucer's type byte the same way the asteroid sizes were decoded.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local function types()
  local t={} ; for i=0,0x2F do t[#t+1]=mem:read_u8(0x8C+i) end ; return t
end
local function fmt(t)
  local s={} ; for i,v in ipairs(t) do if v~=0xFF then s[#s+1]=string.format("[%02X]=%02X",i-1,v) end end
  return table.concat(s," ")
end
local function score()
  local s="" ; for i=0,3 do s=s..string.format("%02X",mem:read_u8(0x46+i)) end
  return tonumber(s) or 0
end
local prev,prevT,hist=0,nil,{}
emu.register_frame_done(function()
  F=F+1
  local sc=score()
  local d=sc-prev
  if F>1400 and (d==200 or d==1000) then
    print(string.format("f%-5d  +%d  (saucer)",F,d))
    print("   before: "..fmt(prevT))
    print("   after : "..fmt(types()))
  end
  -- also track which types are ever present, to spot a saucer arriving
  for i,v in ipairs(types()) do if v~=0xFF then hist[v]=(hist[v] or 0)+1 end end
  prev=sc ; prevT=types()
  if F>13960 then
    print("=== every ObjType value seen, by frames present ===")
    local k={} ; for v in pairs(hist) do k[#k+1]=v end ; table.sort(k)
    for _,v in ipairs(k) do print(string.format("   $%02X  x%d",v,hist[v])) end
    M:exit()
  end
end)
