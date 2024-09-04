// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the REO_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// REO_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.
#ifdef REO_EXPORTS
#define REO_API __declspec(dllexport)
#else
#define REO_API __declspec(dllimport)
#endif

REO_API int reoOpen(double sampleRate, int nChans, int paDevIdx, double suggestedLatency);

REO_API void reoCloseAll(void);

REO_API void reoClose(int streamIdx);

REO_API void reoStart(int streamIdx);

REO_API void reoStop(int streamIdx);

REO_API void reoPost(int streamIdx, float* data, size_t count);

REO_API long reoUsedSlots(int streamIdx);

REO_API long reoFreeSlots(int streamIdx);

REO_API BOOL reoValidStream(int streamIdx);