#include "portaudio.h"
#include "pa_ringbuffer.h"

#define NELEMS(x)  (sizeof(x) / sizeof(x[0]))

#define MAX_STREAMS (32)

//#define FRAMES_PER_BUFFER (64)
#define RING_BUFFER_SIZE (256)

typedef struct
{
	size_t pos;
	size_t len;
	float* buffer;
}
Packet;

typedef struct output Output;
typedef struct packetStream PacketStream;

typedef struct packetStream
{
	Packet current;
	PaUtilRingBuffer incomingPackets;
	void* incomingPacketsData;
	PaUtilRingBuffer usedPackets;
	void* usedPacketsData;
	Output* output;
	BOOL active;
	volatile BOOL playing;
	// each stream forms part of a doubly linked list
	PacketStream* previous;
	PacketStream* next;
	
}
PacketStream;

typedef struct output
{
	PaStream *paOutputStream;
	PaDeviceIndex devId;
	int nChans;
	double sampleRate;
	PaTime suggestedLatency;
	PacketStream* streams;
	// each output forms part of a doubly linked list
	Output* previous;
	Output* next;
}
;

void cleanupUsedPackets(unsigned streamIdx);

int firstFreeStream();

BOOL anyStreamsActive();

extern PacketStream packetStreams[];