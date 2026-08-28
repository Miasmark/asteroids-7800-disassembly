-- Is rom:sub_F8B2's output uniform? It is an additive lagged-Fibonacci
-- generator over a 55-entry table at ram_2100, and every call writes its
-- result back into that table, so tapping writes to the table captures the
-- output stream. Histogram it, and specifically report P(x <= threshold)
-- for the thresholds the saucer-size decision actually used ($3B-$50).
local M=(type(manager.machine)=="function") and manager:machine() or manager.machine
local mem=M.devices[":maincpu"].spaces["program"]
local cpu=M.devices[":maincpu"]
local F=0
local n=0
local hist={}
for i=0,255 do hist[i]=0 end
TAP = mem:install_write_tap(0x2100,0x2136,"prng",function(off,data)
  -- only count writes made by the generator itself
  if cpu.state["GENPC"].value==0xF8BF or cpu.state["GENPC"].value==0xF8C2 then
    hist[data]=hist[data]+1 ; n=n+1
  end
  return data
end)
emu.register_frame_done(function()
  F=F+1
  if F>6400 then
    print(string.format("PRNG output samples: %d",n))
    if n>0 then
      local function cum(t) local c=0 ; for i=0,t do c=c+hist[i] end ; return c end
      for _,t in ipairs({0x3B,0x3E,0x41,0x44,0x47,0x4A,0x4D,0x50}) do
        print(string.format("   P(x <= $%02X) measured = %.1f%%   (uniform would be %.1f%%)",
          t, 100*cum(t)/n, 100*(t+1)/256))
      end
      local lo,hi=0,0
      for i=0,127 do lo=lo+hist[i] end
      for i=128,255 do hi=hi+hist[i] end
      print(string.format("   low half %.1f%%  high half %.1f%%",100*lo/n,100*hi/n))
    end
    M:exit()
  end
end)
