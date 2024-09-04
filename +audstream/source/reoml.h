#include <windows.h>
#include "mex.h"
#include "reo.h"

#define NCHANS (2)
#define SAMPLE_RATE (44100)
#define FRAMES_PER_BUFFER (64)
#define RING_BUFFER_SIZE (256)

void cleanupUsedPackets(unsigned streamIdx);