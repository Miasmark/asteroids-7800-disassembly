-- Walk the live DLL at $1A98 and report the screen's shape, so its DMA cost
-- can be costed with dmabudget.py. Read at a fixed frame, mid-play.
local M = (type(manager.machine)=="function") and manager:machine() or manager.machine
local mem = M.devices[":maincpu"].spaces["program"]
local F = 0
local AT = tonumber(os.getenv("AT_FRAME") or "3000")
emu.register_frame_done(function()
  F = F + 1
  if F ~= AT then return end
  local dll, lines, out = 0x1A98, 0, {}
  for z = 0, 31 do
    local b0 = mem:read_u8(dll + z*3)
    local hi = mem:read_u8(dll + z*3 + 1)
    local lo = mem:read_u8(dll + z*3 + 2)
    local off = (b0 & 0x0F) + 1
    local dl, n, widths = (hi << 8) | lo, 0, {}
    local i = 0
    while i < 60 do
      local e1 = mem:read_u8(dl + i + 1)
      if e1 == 0 then break end
      if (e1 & 0x1F) == 0 then          -- 5-byte entry
        local w = 32 - (mem:read_u8(dl + i + 3) & 0x1F)
        n = n + 1; widths[#widths+1] = w; i = i + 5
      else
        local w = 32 - (e1 & 0x1F)
        n = n + 1; widths[#widths+1] = w; i = i + 4
      end
    end
    local sum = 0
    for _, w in ipairs(widths) do sum = sum + w end
    out[#out+1] = string.format("%d:%d@%d", off, n, n > 0 and math.floor(sum/n) or 0)
    lines = lines + off
    if lines >= 240 then break end
    if b0 == 0 and hi == 0 then break end
  end
  print("DLLSHAPE frame=" .. F .. " lines=" .. lines .. " " .. table.concat(out, " "))
  M:exit()
end)
