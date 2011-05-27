#ifndef PICOBIT_VM_WORKSTATION_H
#define PICOBIT_VM_WORKSTATION_H

#include "ram.h"

#include <stdio.h>
#include <stdlib.h>

#ifdef NETWORKING
#include <pcap.h>
#define MAX_PACKET_SIZE BUFSIZ
#define PROMISC 1
#define TO_MSEC 1
char errbuf[PCAP_ERRBUF_SIZE];
pcap_t *handle;
#define INTERFACE "eth0"
char buf [MAX_PACKET_SIZE]; // buffer for writing
#endif

#ifdef _WIN32

#include <sys/types.h>
#include <sys/timeb.h>
#include <conio.h>

#else

#include <sys/time.h>

#endif /* #ifdef _WIN32 */

// error handling

#define ERROR(prim, msg) error (prim, msg)
#define TYPE_ERROR(prim, type) type_error (prim, type)
void error (char *prim, char *msg);
void type_error (char *prim, char *type);

// ram
uint8 ram_mem[RAM_BYTES + VEC_BYTES];
#define ram_get(a) ram_mem[a]
#define ram_set(a,x) ram_mem[a] = (x)

#define ROM_BYTES 8192
uint8 rom_mem[ROM_BYTES] =
  {
#define RED_GREEN
#define PUTCHAR_LIGHT_not
#ifdef RED_GREEN
    0xFB, 0xD7, 0x03, 0x00, 0x00, 0x00, 0x00, 0x32
    , 0x03, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00
    , 0x08, 0x50, 0x80, 0x16, 0xFE, 0xE8, 0x00, 0xFC
    , 0x32, 0x80, 0x2D, 0xFE, 0xFC, 0x31, 0x80, 0x43
    , 0xFE, 0xFC, 0x33, 0x80, 0x2D, 0xFE, 0xFC, 0x31
    , 0x80, 0x43, 0xFE, 0x90, 0x16, 0x01, 0x20, 0xFC
    , 0x32, 0xE3, 0xB0, 0x37, 0x09, 0xF3, 0xFF, 0x20
    , 0xFC, 0x33, 0xE3, 0xB0, 0x40, 0x0A, 0xF3, 0xFF
    , 0x08, 0xF3, 0xFF, 0x01, 0x40, 0x21, 0xD1, 0x00
    , 0x02, 0xC0, 0x4C, 0x71, 0x01, 0x20, 0x50, 0x90
    , 0x51, 0x00, 0xF1, 0x40, 0xD8, 0xB0, 0x59, 0x90
    , 0x51, 0x00, 0xFF
#endif
#ifdef PUTCHAR_LIGHT
    0xFB, 0xD7, 0x00, 0x00, 0x80, 0x08, 0xFE, 0xE8
    , 0x00, 0xF6, 0xF5, 0x90, 0x08
#endif
  };
uint8 rom_get (rom_addr a) {
  return rom_mem[a-CODE_START];
}


// primitives
char *prim_name[64];

void show (obj o);
void print (obj o);

// debuggging functions
void show_type (obj o);
void show_state (rom_addr pc);


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




