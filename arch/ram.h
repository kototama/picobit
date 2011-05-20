#ifndef RAM_H
#define RAM_H


// address space layout
// TODO document each zone, also explain that since vector space is in ram, it uses the ram primitives

#define CODE_START 0x8000

#define MAX_VEC_ENCODING 2047
#define MIN_VEC_ENCODING 1280
#define VEC_BYTES ((MAX_VEC_ENCODING - MIN_VEC_ENCODING + 1)*4)
// if the pic has less than 8k of memory, start vector space lower

#define MAX_RAM_ENCODING 1279
#define MIN_RAM_ENCODING 512
#define RAM_BYTES ((MAX_RAM_ENCODING - MIN_RAM_ENCODING + 1)*4)

#define MIN_FIXNUM_ENCODING 3
#define MIN_FIXNUM -1
#define MAX_FIXNUM 255
#define MIN_ROM_ENCODING (MIN_FIXNUM_ENCODING + MAX_FIXNUM - MIN_FIXNUM + 1)

#ifdef LESS_MACROS
uint16 OBJ_TO_RAM_ADDR(uint16 o, uint8 f) {return ((((o) - MIN_RAM_ENCODING) << 2) + (f));}
uint16 OBJ_TO_ROM_ADDR(uint16 o, uint8 f) {return ((((o) - MIN_ROM_ENCODING) << 2) + (CODE_START + 4 + (f)));}
#else
#define OBJ_TO_RAM_ADDR(o,f) ((((o) - MIN_RAM_ENCODING) << 2) + (f))
#define OBJ_TO_ROM_ADDR(o,f) ((((o) - MIN_ROM_ENCODING) << 2) + (CODE_START + 4 + (f)))
#endif

#ifdef SIXPIC
#ifdef LESS_MACROS
uint8 ram_get(uint16 a) { return *(a+0x200); }
void  ram_set(uint16 a, uint8 x) { *(a+0x200) = (x); }
#else
#define ram_get(a) *(a+0x200)
#define ram_set(a,x) *(a+0x200) = (x)
#endif
#endif


#endif
