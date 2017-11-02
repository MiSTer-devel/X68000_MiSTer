# This is port of [Sharp X68000](http://fpga8801.seesaa.net) core

## Work in progress...

### What is working:
* FDD images on secondary SD card
* HDD images (SASI only!) on secondary SD card

### Issues:
* keyboard in disk emu screen sometimes doesn't work
* config file sometimes gets corrupted after save.
* floppy images mounted as ejected (Nios II source code required to get it fixed)
* Unused real HDD/FDD options should be deleted from menu.
* original screen not properly framed.

### Special keys
**F11** - switch to diskemu menu.
