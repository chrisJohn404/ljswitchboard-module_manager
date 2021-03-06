--[[
    Name: 23_counters_with_debounce.lua
    Desc: This program demonstrates how to configure counters, with debounce,
          using DIO channels.
    Note: The debounce time for each counter will be between debounceinterval and
          2*debounceinterval milliseconds. The debounce time is determined by the
          duration of the interval and when in the interval the first input
          is received.
--]]

--Array indexes 1-23 correspond with DIO0-22 as the following:
  --Index:  1             Channel:  FIO0  (DIO0)
  --Index:  2             Channel:  FIO1  (DIO1)
  --Index:  3             Channel:  FIO2  (DIO2)
  --Index:  4             Channel:  FIO3  (DIO3)
  --Index:  5             Channel:  FIO4  (DIO4)
  --Index:  6             Channel:  FIO5  (DIO5)
  --Index:  7             Channel:  FIO6  (DIO6)
  --Index:  8             Channel:  FIO7  (DIO7)
  --Index:  9             Channel:  EIO0  (DIO8)
  --Index:  10            Channel:  EIO1  (DIO9)
  --Index:  11            Channel:  EIO2  (DIO10)
  --Index:  12            Channel:  EIO3  (DIO11)
  --Index:  13            Channel:  EIO4  (DIO12)
  --Index:  14            Channel:  EIO5  (DIO13)
  --Index:  15            Channel:  EIO6  (DIO14)
  --Index:  16            Channel:  EIO7  (DIO15)
  --Index:  17            Channel:  CIO0  (DIO16)
  --Index:  18            Channel:  CIO1  (DIO17)
  --Index:  19            Channel:  CIO2  (DIO18)
  --Index:  20            Channel:  CIO3  (DIO19)
  --Index:  21            Channel:  MIO0  (DIO20)
  --Index:  22            Channel:  MIO1  (DIO21)
  --Index:  23            Channel:  MIO2  (DIO22)

-- For sections of code that require precise timing assign global functions
-- locally (local definitions of globals are marginally faster)
local modbus_read = MB.R
local modbus_write = MB.W
local check_interval = LJ.CheckInterval

print("Create and read 23 counters with debounce.")
-- Read the PRODUCT_ID register to get the device type. This script will not
-- run correctly on devices other than the T7
if (modbus_read(60000, 3) ~= 7) then
  print("This example is only for the T7. Exiting Lua Script.")
  -- Write a 0 to LUA_RUN to stop the script if not using a T7
  modbus_write(6000, 1, 0)
end

-- Use a 50ms debounce interval
local debounceinterval = 50
-- 1 = Rising edge, 0 = falling
local edge = {}
for i = 1, 23 do
  -- Set all 23 counters to increment on falling edges
  edge[i] = 0
end

local bits = {}
local newbits = {}
local count = {}
local debouncedcount = {}
-- 0 will mean that the counter has not recently been incremented
local recentlyinc = {}

-- The throttle setting can correspond roughly with the length of the Lua
-- script. A rule of thumb for deciding a throttle setting is
-- Throttle = (3*NumLinesCode)+20. The default throttle setting is 10 instructions
local throttle = 100
LJ.setLuaThrottle(throttle)
throttle = LJ.getLuaThrottle()
print ("Current Lua Throttle Setting: ", throttle)

-- Set FIO registers to input (by writing 0 to FIO_DIRECTION)
modbus_write(2600, 0, 0)
-- Set EIO registers to input (by writing 0 to EIO_DIRECTION)
modbus_write(2601, 0, 0)
-- Set COI registers to input (by writing 0 to CIO_DIRECTION)
modbus_write(2602, 0, 0)
-- Set MIO registers to input (by writing 0 to MIO_DIRECTION)
modbus_write(2603, 0, 0)

for i=1, 23 do
  bits[i] = 0
  newbits[i] = 99
  count[i] = 0
  debouncedcount[i] = 0
  recentlyinc[i] = 0
end

--Setup an interval(in ms) for the counter debounce
LJ.IntervalConfig(0, debounceinterval)
-- Run the program in an infinite loop
while true do
  -- Read digital channels DIO0-22
  for i=1, 23 do
    newbits[i] = modbus_read((i-1)+2000, 0)
  end

  for i=1, 23 do
    -- If bits[i] is different from newbits[i] the counter state changed
    if bits[i] ~= newbits[i] then
      -- If the counter should increase on a rising edge
      if edge[i] == 1 then
        -- If the last counter state was 0 then there was a rising edge, increment
        -- the counter
        if bits[i] == 0 then
          count[i] = count[i] + 1
        end
      -- If the counter should increase on a falling edge
      else
        -- If the last counter state was 1 then there was a falling edge,
        -- increment the counter
        if bits[i] == 1 then
          count[i] = count[i] + 1
        end
      end
      -- Adjust bits to reflect the new counter state
      bits[i] = newbits[i]
    end
  end

  -- Update the debounced counter
  -- If a debounce interval is done
  if check_interval(0) then
    for i=1, 23 do
      -- If the counter did not increase recently any new counts are not due to
      -- bounce
      if recentlyinc[i] == 0 then
        -- If there are new counts, add them to the debouncedcounts
        if count[i] > debouncedcount[i] then
          recentlyinc[i] = 1
          debouncedcount[i] = debouncedcount[i] + 1
          count[i] = debouncedcount[i]
          if edge[i] == 1 then
            print ("Counter: ", i, " Rising: ", debouncedcount[i])
          else
            print ("Counter: ", i, " Falling: ", debouncedcount[i])
          end
          -- Write the debounced counter values to USER_RAM
          modbus_write(((i-1)*2)+46000, 3, debouncedcount[i])
        end
      -- If the counter did increase recently it is likely due to bounce,
      -- ignore any increase to count
      else
        count[i] = debouncedcount[i]
        recentlyinc[i] = 0
      end
    end
  end
end
