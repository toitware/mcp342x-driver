// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

import io
import serial.device as serial

I2C-ADDRESS ::= 0b1101000

RESOLUTION-12-BITS ::= 0b00
RESOLUTION-14-BITS ::= 0b01
RESOLUTION-16-BITS ::= 0b10
RESOLUTION-18-BITS ::= 0b11

GAIN-AMPLIFIER-1 ::= 0b00
GAIN-AMPLIFIER-2 ::= 0b01
GAIN-AMPLIFIER-4 ::= 0b10
GAIN-AMPLIFIER-8 ::= 0b11

/**
Driver for the MCP342x ADC device.
*/
class Driver:
  static CFG-RDY_       ::= 0b10000000
  static CFG-OC_        ::= 0b00010000

  device_/serial.Device ::= ?

  resolution_/int := RESOLUTION-12-BITS
  continous_/bool := false
  gain_/int       := GAIN-AMPLIFIER-1

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
      --resolution/int=RESOLUTION-12-BITS
      --gain=GAIN-AMPLIFIER-1
      --continous=false:
    resolution_ = resolution
    gain_ = gain
    continous_ = continous
    apply-config_

  /**
  Reads the current value from the device.
  */
  read -> float:
    if not continous_:
      // Trigger one-shot measure.
      apply-config_ --ready

    count := resolution_ == RESOLUTION-18-BITS ? 4 : 3
    while true:
      raw := device_.read count

      if raw.last & CFG-RDY_ != 0:
        // Not ready yet, try again in a few ms, scaled based on resolution.
        sleep --ms=resolution_ << (resolution_ + 1)
        continue

      value := io.BIG-ENDIAN.int24 raw 0
      if count < 4: value >>= 8
      result := value.to-float / (1000 << (resolution_ * 2))
      // Apply gain after to-float conversion, so we have more bits and
      // don't loose precision.
      result /= 1 << gain_
      return result

  apply-config_ --ready=false:
    cfg := gain_
    cfg |= resolution_ << 2
    if ready: cfg |= CFG-RDY_
    if continous_: cfg |= CFG-OC_
    device_.write
       ByteArray 1: cfg
