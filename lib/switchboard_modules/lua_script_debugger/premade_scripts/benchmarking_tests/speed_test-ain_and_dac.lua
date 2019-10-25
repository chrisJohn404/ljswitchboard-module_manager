--[[
    Name: speed_test-ain_and_dac.lua
    Desc: This example will output whatever is on AIN1 and mirror it as fast as
          possible on DAC1
    Note: In most cases, users should throttle their code execution using the
          functions: "LJ.IntervalConfig(0, 1000)", and "if LJ.CheckInterval(0)"

          On a T7 (FW 1.0282) this example runs at around 14kHz
          On a T4 (FW 1.0023) this example runs at around 11kHz
--]]

-- For sections of code that require precise timing assign global functions
-- locally (local definitions of globals are marginally faster)
local modbus_read = MB.R
local modbus_write = MB.W

print("Benchmarking Test: Mirror AIN1 on DAC1 as fast as possible.")
-- The throttle setting can correspond roughly with the length of the Lua
-- script. A rule of thumb for deciding a throttle setting is
-- Throttle = (3*NumLinesCode)+20. The default throttle setting is 10 instructions
local throttle = 40
LJ.setLuaThrottle(throttle)
throttle = LJ.getLuaThrottle()
print ("Current Lua Throttle Setting: ", throttle)

-- For the fastest AIN speeds, T7-PROs must use the 16-bit
-- high speed converter, instead of the slower 24-bit converter
-- Make sure the POWER_AIN register is "on"
modbus_write(48005, 0, 1)
-- Set AIN_ALL_RESOLUTION_INDEX to 1(fastest setting on both the T7 and T4)
modbus_write(43903, 0, 1)
-- Set range to +-10V
modbus_write(43900, 3,10)
local numcycles = 30000

-- Configure an interval of 1000ms
LJ.IntervalConfig(0, 1000)
-- Run the program in an infinite loop
while true do
  -- If a 1000ms interval is done
  if LJ.CheckInterval(0) then
    -- Read the CORE_TIMER register
    local starttime = modbus_read(61520,1)
    for i=1,numcycles do
      -- Read AIN1, write it to DAC0.
      -- DAC0 is at address 1000 and has a type of 3 (FLOAT32)
      modbus_write(1000, 3, modbus_read(2,3))
    end
    local endtime = modbus_read(61520,1)
    -- The core timer returns the number of 25ns ticks that have occurred (the
    -- core timer has a tick frequency of 40MHz, which translates to 25ns per
    -- tick). Convert the number of ticks that have occurred to seconds
    local totaltime = (endtime-starttime)*25/(10^9)
    print(
      string.format("Time to execute %d",numcycles),
      "read+writes (s): ",
      totaltime
    )
    print("Freq (Hz): ",numcycles/totaltime)
  end
end