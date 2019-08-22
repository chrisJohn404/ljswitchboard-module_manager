print("Get temperature from a DS18B20 1-wire sensor.")
--Requires firmware 1.0161 or newer
--First change the ROM ID to that of your sensor. Also change SensorPinNum, and ConversionFactor(if needed)
--Discover the ROM ID using the "1-Wire Read ROM ID" example.
--Note, there are several kinds of 1-wire sensors from Maxim.
--Some variants: DS1820, DS1821, DS1822, DS18S20, and DS18B20.
--T7 1-Wire documentation
--http://labjack.com/support/datasheets/t7/digital-io/1-wire
--DS18B20 datasheet
--http://datasheets.maximintegrated.com/en/ds/DS18B20.pdf

--The data line(DQ) needs a pullup resister of 2.2-4.7 kΩ to VS.
--This example used a 3.3kΩ resistor between VS and EIO0

local mbRead=MB.R		--Local functions for faster processing
local mbWrite=MB.W

--From the "1-Wire Read ROM ID" example, the 64-bit ID is:
local target_rom = {}
target_rom[0] = 21248 --MW
target_rom[1] = 4     --UW
target_rom[2] =	52728 --HW
target_rom[3] =	9000  --LW

local SensorPinNum = 8		  --Digital I/O 8 (EIO0)

local ConversionFactorDS18B20 = 0.0625    --12-bit default
--ConversionFactorDS18S20 = 0.5       --9-bit default
local ConversionDelayDS18B20 = 6    --conversion delay in 100 ms.  6 = 600ms for conversion
--ConversionDelayDS18S20 = 8    --conversion delay in 100 ms.  8 = 800ms for conversion

--initializing some other variables
local sensorNotFound = 0
local sensorFound = 1
local invalidReading = 2
local curStep = 0
local curDelay = 0
local tempC = 0
local tempF = 0


function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

function DS18xx_Start(target_rom)
  mbWrite(5307,0, 85)              --ONEWIRE_FUNCTION Set to 85=Match ROM, 51=Read, 240=Search, 204=Skip
  
  mbWrite(5320, 0, target_rom[0])  --ONEWIRE_ROM_MATCH_H
  mbWrite(5321, 0, target_rom[1])
  mbWrite(5322, 0, target_rom[2])  --ONEWIRE_ROM_MATCH_L
  mbWrite(5323, 0, target_rom[3])

  mbWrite(5300, 0, SensorPinNum)   --ONEWIRE_DQ_DIONUM data line (DQ)
  mbWrite(5302, 0, 0)              --ONEWIRE_OPTIONS, DPU Enable, DPU Polarity unused = 0
  mbWrite(5308, 0, 1)              --ONEWIRE_NUM_BYTES_TX Write one byte
  mbWrite(5309, 0, 0)              --ONEWIRE_NUM_BYTES_RX Read no bytes

  mbWrite(5340, 0, 0x4400)         --ONEWIRE_DATA_TX Send to the DS18B20 the start temperature conversion command (0x44)

  return mbWrite(5310, 0, 1)       --ONEWIRE_GO
end

function DS18xx_Read(target_rom)
  local temp = 0
  local error = 0
  local msb = 0
  local lsb = 0

  mbWrite(5307,0, 85)              --ONEWIRE_FUNCTION Set to 85=Match ROM, 51=Read, 240=Search, 204=Skip
  
  mbWrite(5320, 0, target_rom[0])  --ONEWIRE_ROM_MATCH_H
  mbWrite(5321, 0, target_rom[1])
  mbWrite(5322, 0, target_rom[2])  --ONEWIRE_ROM_MATCH_L
  mbWrite(5323, 0, target_rom[3])

  mbWrite(5300, 0, SensorPinNum)   --ONEWIRE_DQ_DIONUM data line (DQ)
  mbWrite(5302, 0, 0)              --ONEWIRE_OPTIONS, DPU Enable, DPU Polarity unused = 0
  mbWrite(5308, 0, 1)              --ONEWIRE_NUM_BYTES_TX Write one byte
  mbWrite(5309, 0, 9)              --ONEWIRE_NUM_BYTES_RX Read nine bytes
  
  mbWrite(5340, 0, 0xBE00)         --ONEWIRE_DATA_TX Send to the DS18B20 the read command (0xBE)
    
  mbWrite(5310, 0, 1)              --ONEWIRE_GO

  temp = mbRead(5370, 0)          --ONEWIRE_DATA_RX Read two bytes

  --handle some conversion steps
  lsb = temp / 256
  lsb = math.floor(lsb)
  msb = temp % 256
  msb = round(msb * 256, 0)
  -- print("temp",temp,"msb",msb,"signBit",signBit)
  temp = (msb  + lsb)
  if(temp == 0xFFFF) then
    error = sensorNotFound
  elseif(temp == 170) then
    error = invalidReading
    error = sensorFound
  elseif(msb == 1280) then
    error = invalidReading
    error = sensorFound
  else
    error = sensorFound
  end
  -- print("msb",msb,"lsb",lsb)
  return temp, error
end


LJ.IntervalConfig(0, 100)      --set interval to 100 for 100ms
local checkInterval = LJ.CheckInterval

while true do
  if checkInterval(0) then   --interval completed

    if(curStep == 0) then
      print("Starting Conversion...")
      DS18xx_Start(target_rom)
      curDelay = 0
      curStep = 1
    elseif(curStep == 1) then
      if(curDelay > ConversionDelayDS18B20) then
        curStep = 2
      end
      curDelay = curDelay + 1
    elseif(curStep == 2) then
      tempC, err = DS18xx_Read(target_rom)
      local sign = 1
      local signBit = tempC / 0x8000
      signBit = math.floor(signBit,0)
      -- print("raw",tempC)
      -- print("raw",tempC,"signBit",signBit)
      if(signBit == 1) then
        sign = -1
        tempC = 0xFFFF-tempC+1
      end
      tempC = sign * tempC * ConversionFactorDS18B20
      -- print("tempC",tempC)
      tempF = (tempC * 1.8) + 32
      if(err == sensorFound) then
        print("Reading:", tempF, "°F\n")
      elseif(err == sensorNotFound) then
        print("Reading:","N/A")
      elseif(err == invalidReading) then
        print("Reading:","Inv")
      else
        print("Reading:","Unknown State")
      end
      --save the temperature value in User RAM so an external PC running simple logging software can easily read the temperature
      mbWrite(46000, 3, tempF)  --USER_RAM0_F32
      curStep = 0
    else
      print("Err")
    end
  end
end
