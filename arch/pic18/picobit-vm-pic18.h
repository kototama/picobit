#ifndef PICOBIT_PIC18_VM_H
#define PICOBIT_PIC18_VM_H


#ifdef HI_TECH_C

#include <pic18.h>

static volatile near uint8 FW_VALUE_UP       @ 0x33;
static volatile near uint8 FW_VALUE_HI       @ 0x33;
static volatile near uint8 FW_VALUE_LO       @ 0x33;

#define ACTIVITY_LED1_LAT LATB
#define ACTIVITY_LED1_BIT 5
#define ACTIVITY_LED2_LAT LATB
#define ACTIVITY_LED2_BIT 4
static volatile near bit ACTIVITY_LED1 @ ((unsigned)&ACTIVITY_LED1_LAT*8)+ACTIVITY_LED1_BIT;
static volatile near bit ACTIVITY_LED2 @ ((unsigned)&ACTIVITY_LED2_LAT*8)+ACTIVITY_LED2_BIT;

// error handling

void halt_with_error () {while(1);}

// ram
uint8 ram_get(uint16 a) {
  uint8 *p = a+0x200;
  return *p;
}
void ram_set(uint16 a, uint8 x) {
  uint8 *p = a+0x200;
  *p = x;
}

uint8 rom_get (rom_addr a){
  return flash_read(a);
}

#endif

// ram
#ifdef MCC18
#ifdef LESS_MACROS
uint8 ram_get(uint16 a) {return *(uint8*)(a+0x200);}
void  ram_set(uint16 a, uint8 x) {*(uint8*)(a+0x200) = (x);}
#else
#define ram_get(a) *(uint8*)(a+0x200)
#define ram_set(a,x) *(uint8*)(a+0x200) = (x)
#endif
#endif

uint8 rom_get (rom_addr a){
  return *(rom uint8*)a;
}

#endif


