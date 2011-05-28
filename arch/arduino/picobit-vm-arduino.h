#ifndef PICOBIT_ARDUINO_VM_H
#define PICOBIT_ARDUINO_VM_H

#include <avr/io.h>
#include <avr/pgmspace.h>

#include "ram.h"

#define ram_get(a) *(uint8*)(a+0x200)
#define ram_set(a,x) *(uint8*)(a+0x200) = (x)

uint8 rom_get (rom_addr a){ 
    return pgm_read_byte(a);
}

void halt_with_error () {while(1);}

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
void prim_xor (); // 10

void prim_pairp ();
obj cons (obj car, obj cdr);
void prim_cons ();
void prim_car ();
void prim_cdr ();
void prim_set_car ();
void prim_set_cdr ();
void prim_nullp (); // 18

void prim_u8vectorp ();
void prim_make_u8vector ();
void prim_u8vector_ref ();
void prim_u8vector_set ();
void prim_u8vector_length (); // 23

void prim_eqp ();
void prim_not ();
void prim_symbolp ();
void prim_stringp ();
void prim_string2list ();
void prim_list2string ();
void prim_booleanp (); // 30

void prim_print ();
uint32 read_clock ();
void prim_clock ();
void prim_pin_mode (); // void prim_motor ();
void prim_digital_write(); // void prim_led ();
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
