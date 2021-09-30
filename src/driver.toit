// Copyright (C) 2021 Toitware ApS. All rights reserved.

import binary
import serial.device

I2C_ADDRESS ::= 0b1101000

RESOLUTION_12_BITS ::= 0b00
RESOLUTION_14_BITS ::= 0b01
RESOLUTION_16_BITS ::= 0b10
RESOLUTION_18_BITS ::= 0b11

GAIN_AMPLIFIER_1 ::= 0b00
GAIN_AMPLIFIER_2 ::= 0b01
GAIN_AMPLIFIER_4 ::= 0b10
GAIN_AMPLIFIER_8 ::= 0b11

/**
Driver for the MCP342x ADC device.
*/
class Driver:
  static CFG_RDY_       ::= 0b10000000
  static CFG_OC_        ::= 0b00010000

  device_/serial.Device ::= ?

  resolution_/int := RESOLUTION_12_BITS
  continous_/bool := false
  gain_/int       := GAIN_AMPLIFIER_1

  constructor .device_/serial.Device:

  on:
    // Validate the device responds.
    device_.write
      ByteArray 0

    // Apply default configuration.
    configure

  off:
    // Restore one-shot logic.
    configure

  /**
  Configures the peripheral at $resolution.

  To enable continous measing mode set the $continous flag.
    The default mode is one-shot where the device is passive until
    $read is invoked.
  */
  configure
      --resolution/int=RESOLUTION_12_BITS
      --gain=GAIN_AMPLIFIER_1
      --continous=false:
    resolution_ = resolution
    gain_ = gain
    continous_ = continous
    apply_config_

  /**
  Reads the current value from the device.
  */
  read -> float:
    if not continous_:
      // Trigger one-shot measure.
      apply_config_ --ready

    count := resolution_ == RESOLUTION_18_BITS ? 4 : 3
    while true:
      raw := device_.read count

      if raw.last & CFG_RDY_ != 0:
        // Not ready yet, try again in a few ms, scaled based on resolution.
        sleep --ms=resolution_ << (resolution_ + 1)
        continue

      value := binary.BIG_ENDIAN.int24 raw 0
      if count < 4: value >>= 8
      result := value / (1000 << resolution_ * 2).to_float
      // Apply gain after to-float conversion, so we have more bits and
      // don't loose precision.
      result /= 1 << gain_
      return result

  apply_config_ --ready=false:
    cfg := gain_
    cfg |= resolution_ << 2
    if ready: cfg |= CFG_RDY_
    if continous_: cfg |= CFG_OC_
    device_.write
       ByteArray 1: cfg
