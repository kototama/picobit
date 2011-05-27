/* file: "dispatch.c" */

/*
 * Copyright 2004-2009 by Marc Feeley and Vincent St-Amour, All Rights Reserved.
 */

#ifdef ARDUINO
#include "dispatch-arduino.c"
#else
#include "dispatch-default.c"
#endif
#include "picobit-vm.h"
