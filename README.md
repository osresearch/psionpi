# Raspberry Pi for the Psion MX series
![Random collection of Psion parts](images/psion-parts.jpg)

The [Psion 5 MX](https://en.wikipedia.org/wiki/Psion_Series_5) was a
PDA manufactured in 1999 that had a decent physical keyboard in a clamshell
with a really unique sliding design that counterbalanced it.

You could buy a modern [Gemina PDA](https://www.www3.planetcom.co.uk/gemini-pda)
that has a color screen and a decent processor, or you could try to
fit a Pi Zero W and interface FPGA into the twenty year old gadget.


## Screen pinout

![FPC connector for the LCD](images/lcd-pinout.jpg)

The LCD is 640x240 with four levels of gray.  Likely a
[Hitachi SR16H005](datasheets/SR16H005.pdf) or similar.
Probing the FPC connector finds a similar four-bit wide
data path, along with pins for the touch screen:

| Pin | Function |
| -|- |
|  1 | GND? |
|  2 | Digitizer 3.3v and 2.0v |
|  3 | Digitizer 3.3v and 2.0v |
|  4 | Digitizer 3.3v and 2.0v |
|  5 | GND? |
|  6 | 3.3V |
|  7 | LCD Bias voltage? +20V |
|  8 | LCD Bias voltage? -17V |
|  9 | GND? |
| 10 | 1.1V? |
| 11 | GND? |
| 12 | Latch? 1.4 usec pulse every 59.6 usec |
| 13 | Clock at 2.8 MHz |
| 14 | GND? |
| 15 | Data at 2.8 Mhz |
| 16 | Data at 2.8 Mhz |
| 17 | Data at 2.8 Mhz |
| 18 | Data at 2.8 Mhz |
| 19 | GND? |
| 20 | Frame? 60 usec pulse every 68 Hz |
| 21 | 3.3V |
| 22 | 706 Hz square wave, 50% duty cycle. Not connected on the FPC? |
| 23 | GND? Connected to pin 25 and on the FPC |
| 24 | Backlight voltage |
| 25 | GND? But not connected on the FPC |
| 26 | Backlight voltage (~70V?) |
