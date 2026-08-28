-- Honest version. The previous probe counted 'ram_00A5 negative at the
-- checkpoint' as a death, but that only ENTERS the branch at rom:L_D7A5 --
-- which then skips the ship loss when ram_007B==3, and in team mode routes
-- to the shared slot or skips entirely. Measure what actually happens:
-- for each hyperspace jump, did a ReserveShips slot really drop soon after?
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local prev7E,prevS={},{}
local pend={}
local nH,nD=0,0
emu.register_frame_done(function()
  F=F+1
  local s={mem:read_u8(0x52),mem:read_u8(0x53),mem:read_u8(0x54)}
  local dropped=false
  for i=1,3 do
    if prevS[i] and s[i]==prevS[i]-1 then dropped=true end
    prevS[i]=s[i]
  end
  for p=0,1 do
    local s7e=mem:read_u8(0x7E+p)
    if s7e==2 and prev7E[p]~=2 then
      nH=nH+1 ; pend[#pend+1]={f=F,p=p,mode=mem:read_u8(0x82),done=false}
    end
    prev7E[p]=s7e
  end
  for _,e in ipairs(pend) do
    if not e.done then
      if dropped and F-e.f<=40 then
        e.done=true ; nD=nD+1
        print(string.format("f%-6d P%d hyperspace(f%d, mode=%d) -> SHIP LOST %d frames later",F,e.p+1,e.f,e.mode,F-e.f))
      elseif F-e.f>40 then
        e.done=true
        print(string.format("f%-6d P%d hyperspace(f%d, mode=%d) -> survived",F,e.p+1,e.f,e.mode))
      end
    end
  end
  if F>13960 then
    print(string.format("=== %d hyperspace jumps, %d cost a ship within 40 frames (%.0f%%) ===",nH,nD,nH>0 and 100*nD/nH or 0))
    M:exit()
  end
end)
