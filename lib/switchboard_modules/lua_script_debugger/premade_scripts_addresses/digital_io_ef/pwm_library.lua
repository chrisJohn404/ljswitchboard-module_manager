--This script can be used as a library of functions to configure the PWM registers for output and write new duty cycles to the PWM channel.
--PWM is available on the T7 on FIO0-FIO5 (T4 PWM is on FIO6 & FIO7)
--See the device datasheet for more information on PWM output.
-- Details about compatible DIO channels (tables 13.2-1 and -2): https://labjack.com/support/datasheets/t-series/digital-io/extended-features
-- PWM specific details: https://labjack.com/support/datasheets/t-series/digital-io/extended-features/pwm-out

--Functions to configure T7/T4

outPin = 0--FIO0. Changed if T4 instead of T7
pwmFrequency = 50 -- 50 Hz
pwmDutyCycle = 5 -- 5%

devType = MB.R(60000, 3)
if devType == 4 then
	outPin = 6--FIO6 on T4
end
-- Create PWM library.
PWM = {}--add local variables here
function PWM.init (self, ichan, ifreq, iduty, iclk, idivisor)--duty should be in %, not decimal
  irollValue = (80000000/ifreq)/idivisor
  self.rollValue = irollValue--store local values for future use vvvv
  self.chan = ichan
  self.freq = ifreq
  self.duty = iduty
  self.clk = iclk
  self.divisor = idivisor--store local values for future use ^^^^
  MB.W(44900+iclk*10, 0, 0)--Disable clock source
  --Set Clock# divisor and roll value to configure frequency
  MB.W(44901+iclk*10, 0, idivisor)--Configure Clock# divisor
  MB.W(44904+iclk*10, 1, irollValue)--Configure Clock# roll value
  MB.W(44900+iclk*10, 0, 1)--enable clock source
  --Configure EF Channel Registers:
  MB.W(44000+ichan*2, 1, 0)--Disable the EF system for initial configuration
  MB.W(44100+ichan*2, 1, 0)--Configure EF system for PWM
  MB.W(44200+ichan*2, 1, iclk)--Configure what clock source to use: Clock#
  MB.W(44300+ichan*2, 1, irollValue*iduty/100)--Configure duty cycle
end
function PWM.enable (self)
  MB.W(44000+self.chan*2, 1, 1)--enable the EF system
end
function PWM.disable (self)
  MB.W(44000+self.chan*2, 1, 0)--disable the EF system
end
function PWM.changeFreq (self, ifreq)
  irollValue = (80000000/ifreq)/self.divisor
  self.rollValue = irollValue--store local values for future use
  self.freq = ifreq
  MB.W(44904+self.clk*10, 1, self.rollValue)--Configure Clock# roll value
  MB.W(44300+self.chan*2, 1, self.rollValue*self.duty/100)--reconfigure duty cycle
end
function PWM.changeDutyCycle (self, iduty)
  self.duty = iduty--re-store local value
  MB.W(44300+self.chan*2, 1, self.rollValue*self.duty/100)--Configure duty cycle
end

myPWM = PWM

myPWM.init(myPWM, outPin, pwmFrequency, pwmDutyCycle, 0, 1)--init on outPin with 50Hz (20ms) and 50% duty cycle
myPWM.enable(myPWM)

-- Initialize the user RAM registers 46000 and 46002 registers.
MB.W(46002, 3, pwmFrequency)
MB.W(46000, 3, pwmDutyCycle)

LJ.IntervalConfig(1, 1000)
while true do               --you can test the function an using an LED or an oscilloscope on the FIO pin
  if LJ.CheckInterval(1) then
    newDC = MB.R(46000, 3)
    newFreq = MB.R(46002, 3)
    if myPWM.duty ~= newDC then
      myPWM.changeDutyCycle(myPWM, newDC)
    end
    if (myPWM.freq ~= newFreq and newFreq ~= 0) then
      myPWM.changeFreq(myPWM, newFreq)
    end
    print("On FIO0 a ", myPWM.freq, "Hz signal at a ", myPWM.duty, "% duty cycle has been generated")--print out what is being generated
  end
end
