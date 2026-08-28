-- rom:L_DD15 branches on Difficulty three ways before calling the fragment
-- spawner rom:sub_DD3D: Novice falls to a single call, levels 1-2 to two
-- calls, and Expert gets a 1-in-4 EXTRA call before those. Count fragments
-- actually created per asteroid destruction to test that live.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local function live()
  local n=0
  for i=0,0x23 do
    local v=mem:read_u8(0x8C+i)
    if v==0x10 or v==0x21 or v==0x32 then n=n+1 end
  end
  return n
end
local function score()
  local s="" ; for i=0,3 do s=s..string.format("%02X",mem:read_u8(0x46+i)) end
  return tonumber(s) or 0
end
local prevN,prevS,pend=nil,0,nil
local hist={}
emu.register_frame_done(function()
  F=F+1
  local n,s=live(),score()
  local d=s-prevS
  if F>400 and (d==20 or d==50) then pend={f=F,n=prevN,d=d} end
  if pend and F==pend.f+6 then
    local made=n-pend.n
    hist[made]=(hist[made] or 0)+1
    pend=nil
  end
  prevN,prevS=n,s
  if F>3800 then
    print(string.format("  difficulty=%d",mem:read_u8(0x83)))
    local k={} ; for v in pairs(hist) do k[#k+1]=v end ; table.sort(k)
    for _,v in ipairs(k) do print(string.format("   net rock-count change %+d : %d splits",v,hist[v])) end
    M:exit()
  end
end)
