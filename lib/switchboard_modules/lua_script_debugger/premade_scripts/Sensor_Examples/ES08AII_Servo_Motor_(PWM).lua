--NOTE: This example does not use the PWM library (found under Digital IO EF) but is fully functional
print("Example for servo motor using PWM output.")
--Users must first configure a digital I/O for PWM out
--NOTE: Servos draw a significant amount of current. Capacitors may be needed to prevent brownout conditions. 
--After PWM output is enabled, the duty cycle can be updated easily by changing DIO0_EF_CONFIG_A
--http://labjack.com/support/datasheets/t7/digital-io/extended-features/pwm-out
--default for most servo motors is 50 Hz or one cycle every 20ms

local mbWrite=MB.W		--local functions for faster processing

local roll=25000
local dutyCycle=10--as a percentage
print("duty cycle:", dutyCycle)
--configure clock
mbWrite(44900, 0, 0)     --turn off clk0 for config
mbWrite(44901, 0, 8)    --Configure Clock0 divisor
mbWrite(44904, 1, roll) --Configure Clock0 roll value
mbWrite(44900, 0, 1)     --enable clock0

DIO_EF_pin_offset = 0
devType = MB.R(60000, 3)
if devType == 7 then--if T7
	DIO_EF_pin_offset = 0--for FIO 0
elseif devType == 4 then--if T4
	DIO_EF_pin_offset = 12--for FIO6
end

--configure FIO
mbWrite(44000+DIO_EF_pin_offset, 1, 0)     --disable DIO0_EF_ENABLE for initial config
mbWrite(44100+DIO_EF_pin_offset, 1, 0)     --configure EF for PWM
mbWrite(44200+DIO_EF_pin_offset, 1, 0)     --Configure what clock source to use: Clock0

local processing=0
LJ.IntervalConfig(0, 500)
local checkInterval=LJ.CheckInterval
while processing~=3 do
  if checkInterval(0) then
    if processing==0 then
      mbWrite(44300+DIO_EF_pin_offset, 1, roll/((1/dutyCycle)*100)) --Configure duty cycle (DIO#_EF_CONFIG_A) to be: 50%
      mbWrite(44000+DIO_EF_pin_offset, 1, 1)         --Enable the EF system, PWM wave is now being outputted
      print("duty cycle:", dutyCycle+10)
      processing=1
    elseif processing==1 then   --"off" state.
      mbWrite(44000+DIO_EF_pin_offset, 1, 0)         --disable FIO after 3 seconds to set the servo position
      dutyCycle=dutyCycle+10    --set NEW DUTY CYCLE TO 10% more than previous
      processing=0
      if (dutyCycle>=100) then  --check if over 100%
        processing=3            --break out of loop
      end
    end
  end
end