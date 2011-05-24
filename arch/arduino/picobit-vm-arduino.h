#ifndef PICOBIT_ARDUINO_VM_H
#define PICOBIT_ARDUINO_VM_H

#include "ram.h"

#define ram_get(a) *(uint8*)(a+0x200)
#define ram_set(a,x) *(uint8*)(a+0x200) = (x)

/* TODO, implement this. Yet this would probably read the RAM addresses */
uint8 rom_get (rom_addr a){ 
    return *(/* rom */ uint8*)a;
}

void halt_with_error () {while(1);}

#endif
