-- run-03 reportedly ends with TWO small saucers: one flew into an asteroid
-- and died on its own, the other was shot by the player (+1000). Watch the
-- dedicated saucer slot ($19) for any type other than the known large
-- saucer $25, and log score awards, so the small saucer's type byte and
-- both of its death routes can be identified.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local prev19,prevScore=nil,0
local function score()
  local s="" ; for i=0,3 do s=s..string.format("%02X",mem:read_u8(0x46+i)) end
  return tonumber(s) or 0
end
emu.register_frame_done(function()
  F=F+1
  local v=mem:read_u8(0x8C+0x19)
  if v~=prev19 then
    print(string.format("f%-5d slot[19] %s -> $%02X",F,
      prev19 and string.format("$%02X",prev19) or "?", v))
    prev19=v
  end
  local sc=score()
  if sc>prevScore then print(string.format("f%-5d    score +%d",F,sc-prevScore)) end
  prevScore=sc
  if F>6450 then M:exit() end
end)
