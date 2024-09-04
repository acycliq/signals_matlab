#include "reoml.h"

void cleanupUsedPackets(unsigned streamIdx) {
  PaUtilRingBuffer *usedPacketsPtr = &packetStreams[streamIdx].usedPackets;
  while (PaUtil_GetRingBufferReadAvailable(usedPacketsPtr)) {
    Packet in;
    PaUtil_ReadRingBuffer(usedPacketsPtr, &in, 1);
//     mexPrintf("[%.1f %.1f %.1f ... ]\n", in.buffer[0], in.buffer[1], in.buffer[2]);
    mxFree(in.buffer);
//     mexPrintf("cleared %u\n", in.buffer);
  }
}

int done(Packet *packet)
{
  return (packet->pos >= packet->len);
}