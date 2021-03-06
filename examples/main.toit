import gpio
import serial.protocols.i2c as i2c
import mcp342x

main:
  sda := gpio.Pin 19
  scl := gpio.Pin 21
  bus := i2c.Bus --sda=sda --scl=scl

  device := bus.device mcp342x.I2C_ADDRESS

  adc := mcp342x.Driver device

  adc.on

  adc.configure --resolution=mcp342x.RESOLUTION_14_BITS

  10.repeat:
    print adc.read
