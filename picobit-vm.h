/* file: "picobit-vm.h" */

/*
 * Copyright 2004-2009 by Marc Feeley and Vincent St-Amour, All Rights Reserved.
 */

#ifndef PICOBIT_VM_H
#define PICOBIT_VM_H

#define DEBUG_not
#define DEBUG_GC_not
#define INFINITE_PRECISION_BIGNUMS

/*---------------------------------------------------------------------------*/

// types

#ifndef SIXPIC
// these types are already defined in SIXPIC
typedef char int8;
typedef short int16;
typedef long int32;
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned long uint32;
#endif

typedef uint8 word_t;

typedef uint16 ram_addr;
typedef uint16 rom_addr;

// pointers are 13 bits
typedef uint16 obj;

/*---------------------------------------------------------------------------*/

#include "arch/ram.h"
#include "arch/arch.h"

/*---------------------------------------------------------------------------*/

// miscellaneous definitions
// TODO put at the end ?

// TODO these 2 are only used in negp, use them elsewhere ?
#define true  1
#define false 0

/*---------------------------------------------------------------------------*/

// debugging

#ifdef DEBUG
#define IF_TRACE(x) x
#define IF_GC_TRACE(x) x
#else
#define IF_TRACE(x)
#define IF_GC_TRACE(x)
#endif

#ifdef LESS_MACROS
uint8 RAM_GET_FIELD0_MACRO(uint16 o) {return ram_get (OBJ_TO_RAM_ADDR(o,0));}
void  RAM_SET_FIELD0_MACRO(uint16 o, uint8 val) {ram_set (OBJ_TO_RAM_ADDR(o,0), val);}
uint8 ROM_GET_FIELD0_MACRO(uint16 o) {return rom_get (OBJ_TO_ROM_ADDR(o,0));}
#else
#define RAM_GET_FIELD0_MACRO(o) ram_get (OBJ_TO_RAM_ADDR(o,0))
#define RAM_SET_FIELD0_MACRO(o,val) ram_set (OBJ_TO_RAM_ADDR(o,0), val)
#define ROM_GET_FIELD0_MACRO(o) rom_get (OBJ_TO_ROM_ADDR(o,0))
#endif

#ifdef LESS_MACROS
uint8 RAM_GET_GC_TAGS_MACRO(uint16 o) {return (RAM_GET_FIELD0_MACRO(o) & 0x60);}
uint8 RAM_GET_GC_TAG0_MACRO(uint16 o) {return (RAM_GET_FIELD0_MACRO(o) & 0x20);}
uint8 RAM_GET_GC_TAG1_MACRO(uint16 o) {return (RAM_GET_FIELD0_MACRO(o) & 0x40);}
void  RAM_SET_GC_TAGS_MACRO(uint16 o, uint8 tags) {(RAM_SET_FIELD0_MACRO(o,(RAM_GET_FIELD0_MACRO(o) & 0x9f) | (tags)));}
void  RAM_SET_GC_TAG0_MACRO(uint16 o, uint8 tag)  {RAM_SET_FIELD0_MACRO(o,(RAM_GET_FIELD0_MACRO(o) & 0xdf) | (tag));}
void  RAM_SET_GC_TAG1_MACRO(uint16 o, uint8 tag)  {RAM_SET_FIELD0_MACRO(o,(RAM_GET_FIELD0_MACRO(o) & 0xbf) | (tag));}
#else
#define RAM_GET_GC_TAGS_MACRO(o) (RAM_GET_FIELD0_MACRO(o) & 0x60)
#define RAM_GET_GC_TAG0_MACRO(o) (RAM_GET_FIELD0_MACRO(o) & 0x20)
#define RAM_GET_GC_TAG1_MACRO(o) (RAM_GET_FIELD0_MACRO(o) & 0x40)
#define RAM_SET_GC_TAGS_MACRO(o,tags)                                      \
  (RAM_SET_FIELD0_MACRO(o,(RAM_GET_FIELD0_MACRO(o) & 0x9f) | (tags)))
#define RAM_SET_GC_TAG0_MACRO(o,tag)                                    \
  RAM_SET_FIELD0_MACRO(o,(RAM_GET_FIELD0_MACRO(o) & 0xdf) | (tag))
#define RAM_SET_GC_TAG1_MACRO(o,tag)                                    \
  RAM_SET_FIELD0_MACRO(o,(RAM_GET_FIELD0_MACRO(o) & 0xbf) | (tag))
#endif

#ifdef LESS_MACROS
uint8 RAM_GET_FIELD1_MACRO(uint16 o) {return ram_get (OBJ_TO_RAM_ADDR(o,1));}
uint8 RAM_GET_FIELD2_MACRO(uint16 o) {return ram_get (OBJ_TO_RAM_ADDR(o,2));}
uint8 RAM_GET_FIELD3_MACRO(uint16 o) {return ram_get (OBJ_TO_RAM_ADDR(o,3));}
void  RAM_SET_FIELD1_MACRO(uint16 o, uint8 val) {ram_set (OBJ_TO_RAM_ADDR(o,1), val);}
void  RAM_SET_FIELD2_MACRO(uint16 o, uint8 val) {ram_set (OBJ_TO_RAM_ADDR(o,2), val);}
void  RAM_SET_FIELD3_MACRO(uint16 o, uint8 val) {ram_set (OBJ_TO_RAM_ADDR(o,3), val);}
uint8 ROM_GET_FIELD1_MACRO(uint16 o) {return rom_get (OBJ_TO_ROM_ADDR(o,1));}
uint8 ROM_GET_FIELD2_MACRO(uint16 o) {return rom_get (OBJ_TO_ROM_ADDR(o,2));}
uint8 ROM_GET_FIELD3_MACRO(uint16 o) {return rom_get (OBJ_TO_ROM_ADDR(o,3));}
#else
#define RAM_GET_FIELD1_MACRO(o) ram_get (OBJ_TO_RAM_ADDR(o,1))
#define RAM_GET_FIELD2_MACRO(o) ram_get (OBJ_TO_RAM_ADDR(o,2))
#define RAM_GET_FIELD3_MACRO(o) ram_get (OBJ_TO_RAM_ADDR(o,3))
#define RAM_SET_FIELD1_MACRO(o,val) ram_set (OBJ_TO_RAM_ADDR(o,1), val)
#define RAM_SET_FIELD2_MACRO(o,val) ram_set (OBJ_TO_RAM_ADDR(o,2), val)
#define RAM_SET_FIELD3_MACRO(o,val) ram_set (OBJ_TO_RAM_ADDR(o,3), val)
#define ROM_GET_FIELD1_MACRO(o) rom_get (OBJ_TO_ROM_ADDR(o,1))
#define ROM_GET_FIELD2_MACRO(o) rom_get (OBJ_TO_ROM_ADDR(o,2))
#define ROM_GET_FIELD3_MACRO(o) rom_get (OBJ_TO_ROM_ADDR(o,3))
#endif

word_t ram_get_gc_tags (obj o) { return RAM_GET_GC_TAGS_MACRO(o); }
word_t ram_get_gc_tag0 (obj o) { return RAM_GET_GC_TAG0_MACRO(o); }
word_t ram_get_gc_tag1 (obj o) { return RAM_GET_GC_TAG1_MACRO(o); }
void ram_set_gc_tags (obj o, word_t tags) { RAM_SET_GC_TAGS_MACRO(o, tags); }
void ram_set_gc_tag0 (obj o, word_t tag) { RAM_SET_GC_TAG0_MACRO(o,tag); }
void ram_set_gc_tag1 (obj o, word_t tag) { RAM_SET_GC_TAG1_MACRO(o,tag); }
word_t ram_get_field0 (obj o) { return RAM_GET_FIELD0_MACRO(o); }
word_t ram_get_field1 (obj o) { return RAM_GET_FIELD1_MACRO(o); }
word_t ram_get_field2 (obj o) { return RAM_GET_FIELD2_MACRO(o); }
word_t ram_get_field3 (obj o) { return RAM_GET_FIELD3_MACRO(o); }
void ram_set_field0 (obj o, word_t val) { RAM_SET_FIELD0_MACRO(o,val); }
void ram_set_field1 (obj o, word_t val) { RAM_SET_FIELD1_MACRO(o,val); }
void ram_set_field2 (obj o, word_t val) { RAM_SET_FIELD2_MACRO(o,val); }
void ram_set_field3 (obj o, word_t val) { RAM_SET_FIELD3_MACRO(o,val); }
word_t rom_get_field0 (obj o) { return ROM_GET_FIELD0_MACRO(o); }
word_t rom_get_field1 (obj o) { return ROM_GET_FIELD1_MACRO(o); }
word_t rom_get_field2 (obj o) { return ROM_GET_FIELD2_MACRO(o); }
word_t rom_get_field3 (obj o) { return ROM_GET_FIELD3_MACRO(o); }

obj ram_get_car (obj o);
obj rom_get_car (obj o);
obj ram_get_cdr (obj o);
obj rom_get_cdr (obj o);
void ram_set_car (obj o, obj val);
void ram_set_cdr (obj o, obj val);

obj ram_get_entry (obj o);
obj rom_get_entry (obj o);

obj get_global (uint8 i);
void set_global (uint8 i, obj o);


/*---------------------------------------------------------------------------*/

/*
  OBJECT ENCODING:

  #f           0
  #t           1
  ()           2
  fixnum n     MIN_FIXNUM -> 3 ... MAX_FIXNUM -> 3 + (MAX_FIXNUM-MIN_FIXNUM)
  rom object   4 + (MAX_FIXNUM-MIN_FIXNUM) ... MIN_RAM_ENCODING-1
  ram object   MIN_RAM_ENCODING ... MAX_RAM_ENCODING
  u8vector     MIN_VEC_ENCODING ... 8191

  layout of memory allocated objects:

  Gs represent mark bits used by the gc

  ifdef INFINITE_PRECISION_BIGNUMS
  bignum n     00G***** **next** hhhhhhhh llllllll  (16 bit digit)
  TODO what to do with the gc tags for the bignums ? will this work ?
  TODO since bignums have only 1 field, only one gc tag is should be enough
  (only one is used anyway), so no conflict with closures
  
  ifndef INFINITE_PRECISION_BIGNUMS
  bignum n     00000000 uuuuuuuu hhhhhhhh llllllll  (24 bit signed integer)
  TODO doesn't work properly for the moment. only 16 bits are usable now

  pair         1GGaaaaa aaaaaaaa 000ddddd dddddddd
  a is car
  d is cdr
  gives an address space of 2^13 * 4 = 32k divided between simple objects,
  rom, ram and vectors

  symbol       1GG00000 00000000 00100000 00000000

  string       1GG***** *chars** 01000000 00000000

  u8vector     1GGxxxxx xxxxxxxx 011yyyyy yyyyyyyy
  x is length of the vector, in bytes (stored raw, not encoded as an object)
  y is pointer to the elements themselves (stored in vector space)

  closure      01Gxxxxx xxxxxxxx aaaaaaaa aaaaaaaa
  0x5ff<a<0x4000 is entry
  x is pointer to environment
  
  continuation 1GGxxxxx xxxxxxxx 100yyyyy yyyyyyyy
  x is parent continuation
  y is pointer to the second half, which is a closure (contains env and entry)
  
  An environment is a list of objects built out of pairs.  On entry to
  a procedure the environment is the list of parameters to which is
  added the environment of the closure being called.

  The first byte at the entry point of a procedure gives the arity of
  the procedure:

  n = 0 to 127    -> procedure has n parameters (no rest parameter)
  n = -128 to -1  -> procedure has -n parameters, the last is
  a rest parameter
*/

#define OBJ_FALSE 0
#define OBJ_TRUE  1
#define encode_bool(x) (x)

#define OBJ_NULL  2

// fixnum definitions in picobit-vm.h , address space layout section

#ifdef LESS_MACROS
uint16 ENCODE_FIXNUM(uint8  n) {return ((n) + (MIN_FIXNUM_ENCODING - MIN_FIXNUM));}
uint8  DECODE_FIXNUM(uint16 o) {return ((o) - (MIN_FIXNUM_ENCODING - MIN_FIXNUM));}
#else
#define ENCODE_FIXNUM(n) ((n) + (MIN_FIXNUM_ENCODING - MIN_FIXNUM))
#define DECODE_FIXNUM(o) ((o) - (MIN_FIXNUM_ENCODING - MIN_FIXNUM))
#endif

#ifdef LESS_MACROS
uint8 IN_VEC(uint16 o) {return ((o) >= MIN_VEC_ENCODING);}
uint8 IN_RAM(uint16 o) {return (!IN_VEC(o) && ((o) >= MIN_RAM_ENCODING));}
uint8 IN_ROM(uint16 o) {return (!IN_VEC(o) && !IN_RAM(o) && ((o) >= MIN_ROM_ENCODING));}
#else
#define IN_VEC(o) ((o) >= MIN_VEC_ENCODING)
#define IN_RAM(o) (!IN_VEC(o) && ((o) >= MIN_RAM_ENCODING))
#define IN_ROM(o) (!IN_VEC(o) && !IN_RAM(o) && ((o) >= MIN_ROM_ENCODING))
#endif

// bignum first byte : 00Gxxxxx
#define BIGNUM_FIELD0 0
#ifdef LESS_MACROS
uint8 RAM_BIGNUM(uint16 o) {return ((ram_get_field0 (o) & 0xc0) == BIGNUM_FIELD0);}
uint8 ROM_BIGNUM(uint16 o) {return ((rom_get_field0 (o) & 0xc0) == BIGNUM_FIELD0);}
#else
#define RAM_BIGNUM(o) ((ram_get_field0 (o) & 0xc0) == BIGNUM_FIELD0)
#define ROM_BIGNUM(o) ((rom_get_field0 (o) & 0xc0) == BIGNUM_FIELD0)
#endif

// composite first byte : 1GGxxxxx
#define COMPOSITE_FIELD0 0x80
#ifdef LESS_MACROS
uint8 RAM_COMPOSITE(uint16 o) {return ((ram_get_field0 (o) & 0x80) == COMPOSITE_FIELD0);}
uint8 ROM_COMPOSITE(uint16 o) {return ((rom_get_field0 (o) & 0x80) == COMPOSITE_FIELD0);}
#else
#define RAM_COMPOSITE(o) ((ram_get_field0 (o) & 0x80) == COMPOSITE_FIELD0)
#define ROM_COMPOSITE(o) ((rom_get_field0 (o) & 0x80) == COMPOSITE_FIELD0)
#endif

// pair third byte : 000xxxxx
#define PAIR_FIELD2 0
#ifdef LESS_MACROS
uint8 RAM_PAIR(uint16 o) {return (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == PAIR_FIELD2));}
uint8 ROM_PAIR(uint16 o) {return (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == PAIR_FIELD2));}
#else
#define RAM_PAIR(o) (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == PAIR_FIELD2))
#define ROM_PAIR(o) (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == PAIR_FIELD2))
#endif

// symbol third byte : 001xxxxx
#define SYMBOL_FIELD2 0x20
#ifdef LESS_MACROS
uint8 RAM_SYMBOL(uint16 o) {return (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == SYMBOL_FIELD2));}
uint8 ROM_SYMBOL(uint16 o) {return (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == SYMBOL_FIELD2));}
#else
#define RAM_SYMBOL(o) (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == SYMBOL_FIELD2))
#define ROM_SYMBOL(o) (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == SYMBOL_FIELD2))
#endif

// string third byte : 010xxxxx
#define STRING_FIELD2 0x40
#ifdef LESS_MACROS
uint8 RAM_STRING(uint16 o) {return (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == STRING_FIELD2));}
uint8 ROM_STRING(uint16 o) {return (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == STRING_FIELD2));}
#else
#define RAM_STRING(o) (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == STRING_FIELD2))
#define ROM_STRING(o) (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == STRING_FIELD2))
#endif

// vector third byte : 011xxxxx
#define VECTOR_FIELD2 0x60
#ifdef LESS_MACROS
uint8 RAM_VECTOR(uint16 o) {return (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == VECTOR_FIELD2));}
uint8 ROM_VECTOR(uint16 o) {return (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == VECTOR_FIELD2));}
#else
#define RAM_VECTOR(o) (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == VECTOR_FIELD2))
#define ROM_VECTOR(o) (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == VECTOR_FIELD2))
#endif

// continuation third byte : 100xxxxx
#define CONTINUATION_FIELD2 0x80
#ifdef LESS_MACROS
uint8 RAM_CONTINUATION(uint16 o) {return (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == CONTINUATION_FIELD2));}
uint8 ROM_CONTINUATION(uint16 o) {return (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == CONTINUATION_FIELD2));}
#else
#define RAM_CONTINUATION(o) (RAM_COMPOSITE (o) && ((ram_get_field2 (o) & 0xe0) == CONTINUATION_FIELD2))
#define ROM_CONTINUATION(o) (ROM_COMPOSITE (o) && ((rom_get_field2 (o) & 0xe0) == CONTINUATION_FIELD2))
#endif

// closure first byte : 01Gxxxxx
// closures are only found in RAM
#define CLOSURE_FIELD0 0x40
#ifdef LESS_MACROS
uint8 RAM_CLOSURE(uint16 o) {return ((ram_get_field0 (o) & 0xc0) == CLOSURE_FIELD0);}
#else
#define RAM_CLOSURE(o) ((ram_get_field0 (o) & 0xc0) == CLOSURE_FIELD0)
#endif

/*---------------------------------------------------------------------------*/

// bignum definitions

#ifdef INFINITE_PRECISION_BIGNUMS

#define digit_width 16

typedef obj integer;
typedef uint16 digit; // TODO why these ? adds to the confusion
typedef uint32 two_digit;

#define obj_eq(x,y) ((x) == (y))
#define integer_hi_set(x,y) ram_set_car (x, y)

#define ZERO ENCODE_FIXNUM(0)
#define NEG1 (ZERO-1)
#define POS1 (ZERO+1)

integer make_integer (digit lo, integer hi);
integer integer_hi (integer x);
digit integer_lo (integer x);

integer norm (obj prefix, integer n);
uint8 negp (integer x);
uint8 cmp (integer x, integer y);
uint16 integer_length (integer x);
integer shr (integer x);
integer negative_carry (integer carry);
integer shl (integer x);
integer shift_left (integer x, uint16 n);
integer add (integer x, integer y);
integer invert (integer x);
integer sub (integer x, integer y);
integer neg (integer x);
integer scale (digit n, integer x);
integer mulnonneg (integer x, integer y);
integer divnonneg (integer x, integer y);
  
uint16 decode_int (obj o);
obj encode_int (uint16 n);

#endif

/*---------------------------------------------------------------------------*/

// garbage collector

// TODO explain what each tag means, with 1-2 mark bits
#define GC_TAG_0_LEFT   (1<<5)
#define GC_TAG_1_LEFT   (2<<5)
#define GC_TAG_UNMARKED (0<<5)

/* Number of object fields of objects in ram */
#ifdef LESS_MACROS
uint8 HAS_2_OBJECT_FIELDS(uint16 visit) {return (RAM_PAIR(visit) || RAM_CONTINUATION(visit));}
#ifdef INFINITE_PRECISION_BIGNUMS
uint8 HAS_1_OBJECT_FIELD(uint16 visit)  {return (RAM_COMPOSITE(visit) || RAM_CLOSURE(visit) || RAM_BIGNUM(visit));}
#else
uint8 HAS_1_OBJECT_FIELD(uint16 visit)  {return (RAM_COMPOSITE(visit) || RAM_CLOSURE(visit));}
#endif

#else
#define HAS_2_OBJECT_FIELDS(visit) (RAM_PAIR(visit) || RAM_CONTINUATION(visit))
#ifdef INFINITE_PRECISION_BIGNUMS
#define HAS_1_OBJECT_FIELD(visit)  (RAM_COMPOSITE(visit) \
				    || RAM_CLOSURE(visit) || RAM_BIGNUM(visit))
#else
#define HAS_1_OBJECT_FIELD(visit)  (RAM_COMPOSITE(visit) || RAM_CLOSURE(visit))
#endif
#endif
// all composites except pairs and continuations have 1 object field

#define NIL OBJ_FALSE

obj free_list; /* list of unused cells */
obj free_list_vec; /* list of unused cells in vector space */

obj arg1; /* root set */
obj arg2;
obj arg3;
obj arg4;
obj cont;
obj env;

rom_addr pc; /* interpreter variables */
uint8 glovars;
rom_addr entry;
uint8 bytecode;
uint8 bytecode_hi4;
uint8 bytecode_lo4;
uint16 a1;
uint16 a2;
uint16 a3;

// dispatch

#define FETCH_NEXT_BYTECODE() bytecode = rom_get (pc++)

#define PUSH_CONSTANT1     0x0
#define PUSH_CONSTANT2     0x1
#define PUSH_STACK1        0x2
#define PUSH_STACK2        0x3
#define PUSH_GLOBAL        0x4
#define SET_GLOBAL         0x5
#define CALL               0x6
#define JUMP               0x7
#if 1
#define JUMP_TOPLEVEL_REL4 0x8
#define GOTO_IF_FALSE_REL4 0x9
#define PUSH_CONSTANT_LONG 0xa
#define LABEL_INSTR        0xb
#else
#define JUMP_TOPLEVEL_REL4 0xa
#define GOTO_IF_FALSE_REL4 0xb
#define LABEL_INSTR        0x8
#define PUSH_CONSTANT_LONG 0x9
#endif

#define PRIM1              0xc
#define PRIM2              0xd
#define PRIM3              0xe
#define PRIM4              0xf

void push_arg1 ();
obj pop ();
void pop_procedure ();
uint8 handle_arity_and_rest_param (uint8 na);
uint8 build_env (uint8 na);
void save_cont ();
void interpreter ();

#endif

