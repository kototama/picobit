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

// primitives

void prim_numberp ();
void prim_add ();
void prim_mul_non_neg ();
void prim_div_non_neg ();
void prim_rem ();
void prim_eq ();
void prim_lt ();
void prim_gt ();
void prim_ior ();
void prim_xor ();

void prim_pairp ();
obj cons (obj car, obj cdr);
void prim_cons ();
void prim_car ();
void prim_cdr ();
void prim_set_car ();
void prim_set_cdr ();
void prim_nullp ();

void prim_u8vectorp ();
void prim_make_u8vector ();
void prim_u8vector_ref ();
void prim_u8vector_set ();
void prim_u8vector_length ();

void prim_eqp ();
void prim_not ();
void prim_symbolp ();
void prim_stringp ();
void prim_string2list ();
void prim_list2string ();
void prim_booleanp ();

void prim_print ();
uint32 read_clock ();
void prim_clock ();
void prim_motor ();
void prim_led ();
void prim_led2_color ();
void prim_getchar_wait ();
void prim_putchar ();
void prim_beep ();
void prim_adc ();
void prim_sernum ();

void prim_network_init ();
void prim_network_cleanup ();
void prim_receive_packet_to_u8vector ();
void prim_send_packet_from_u8vector ();


#endif


