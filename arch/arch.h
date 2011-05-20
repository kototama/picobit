#ifndef ARCH_H
#define ARCH_H

// environment

#ifdef PICOBOARD2
#define ROBOT
#endif

#if defined(MCC18) || defined(HI_TECH_C)
#include "pic18/picobit-vm-pic18.h"
#define ROBOT
#endif

#ifdef SIXPIC
#define ROBOT
#endif

#ifdef ARDUINO
#include "arduino/picobit-vm-arduino.h"
#define ROBOT
#endif

#ifndef ROBOT
#define WORKSTATION
#endif

#ifdef WORKSTATION
#include "workstation/picobit-vm-workstation.h"
#endif

// error handling
#ifndef WORKSTATION
#define ERROR(prim, msg) halt_with_error()
#define TYPE_ERROR(prim, type) halt_with_error()
#endif

#endif

