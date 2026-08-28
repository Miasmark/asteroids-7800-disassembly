-- Watch the object-type array (ram_008C+) across a rock being destroyed.
-- A score change means something was shot; dumping the array either side of
-- it should show the destroyed slot change type and any fragments appear.
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local F=0
local function types()
  local t={}
  for i=0,0x2F do t[#t+1]=mem:read_u8(0x8C+i) end
  return t
end
local function fmt(t)
  local s={}
  for i,v in ipairs(t) do if v~=0xFF then s[#s+1]=string.format("[%02X]=%02X",i-1,v) end end
  return table.concat(s," ")
end
local function score()
  local s="" ; for i=0,3 do s=s..string.format("%02X",mem:read_u8(0x46+i)) end
  return tonumber(s) or 0
end
local prev,prevT=0,nil
local shown=0
emu.register_frame_done(function()
  F=F+1
  local sc=score()
  if F>1400 and sc>prev and shown<6 then
    shown=shown+1
    print(string.format("f%-5d score +%d", F, sc-prev))
    print("   before: "..fmt(prevT))
    print("   after : "..fmt(types()))
  end
  prev=sc ; prevT=types()
  if shown>=6 or F>4000 then M:exit() end
end)
