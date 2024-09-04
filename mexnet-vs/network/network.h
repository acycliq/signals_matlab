// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the NETWORK_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// NETWORK_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.
#ifdef NETWORK_EXPORTS
#define NETWORK_API __declspec(dllexport)
#else
#define NETWORK_API __declspec(dllimport)
#endif

#define NUMEL(a) (sizeof(a) / sizeof(*a))

#define SQ_NODE_DATA_TYPE mxArray
#define NUM_TRANSFERER_ARGS (4)
#define TRANSFER_NET_ARG_IDX (0)
#define TRANSFER_INPUTS_ARG_IDX (1)
#define TRANSFER_NODE_ARG_IDX (2)
#define TRANSFER_CUSTOM_ARG_IDX (3)

#define DEF_ARRAY_INDEX_OF(prefix, type) \
	long prefix ## ArrayIndexOf(type *arr, size_t nelem, type elem) { \
		long i; \
		for (i = 0; i < nelem; i++) \
			if (arr[i] == elem) \
				return i; \
		return -1; \
	}

#define ARRAY_APPEND(arrPtr, nElemPtr, elem) { \
		/* reallocate with space for one element more*/ \
		*arrPtr = mxRealloc(*arrPtr, (*nElemPtr + 1)*sizeof(elem)); \
		mexMakeMemoryPersistent(*arrPtr); /* ensure it's persistent */ \
		/* copy the extra element into the final element of the new array */ \
		memcpy((*arrPtr) + *nElemPtr, elemPtr, sizeof(elem)); \
		(*nElemPtr)++; /* increment the element count */ \
	}

typedef struct
{
	int opCode;
	char *funName;
	mxArray *args[NUM_TRANSFERER_ARGS]; // TODO: tidy up and make safe when inputs deleted
	// the following are currently used for flattenStruct transforms
	bool workingInputChanges; // used to flag that inputs have changed due to unapplied transactions
	mxArray *targetIndices; // the index into the target that each input goes to
	mxArray *targetFields; // the field in the target that each input goes to
}
Transferer;

typedef struct Node
{
	size_t netId;
	size_t id;
	mxArray *currValue;
	mxArray *workingValue;
	struct Node** inputs;
	size_t nInputs;
	struct Node** targets;
	size_t nTargets;
	Transferer transferer;
	mxArray *eventsTarget;
	bool inUse;
	// transaction status info
	bool queued;
	// state for appending new values to existing ones
	bool appendValues;
	size_t currValueAllocElems; // # elems allocated for mxArray data array
}
Node;

typedef struct
{
	Node *nodes;
	size_t nNodes;
	BOOL active;
	mxArray *deleteCallback;
}
Network;

NETWORK_API mxArray *sqGetTransfererCustomArg(int net, size_t node);

NETWORK_API int sqCreateNetwork(size_t size, mxArray *deleteCallback);

NETWORK_API void sqDeleteNetwork(int net);

NETWORK_API void sqDeleteNetworks(void);

NETWORK_API size_t sqAddNode(int net, size_t inputs[], size_t nInputs, Transferer transferer, bool appendValues);

NETWORK_API void sqDeleteNode(int net, size_t node);

NETWORK_API void sqSetNodeCurrValue(int net, size_t node, mxArray *value, bool append);

NETWORK_API void sqSetNodeEventsTarget(int net, size_t node, mxArray *value);

NETWORK_API SQ_NODE_DATA_TYPE *sqGetNodeCurrValue(int net, size_t node);

NETWORK_API void sqSetNodeWorkingValue(int net, size_t node, SQ_NODE_DATA_TYPE *value);

NETWORK_API SQ_NODE_DATA_TYPE *sqGetNodeWorkingValue(int net, size_t node);

NETWORK_API void sqSetNodeInputs(int net, size_t node, const mxArray *inputs);

NETWORK_API mxArray *sqGetNodeInputs(int net, size_t node);

NETWORK_API BOOL sqIsNetwork(int net);

NETWORK_API BOOL sqIsNode(int net, size_t node);

NETWORK_API void sqDispNetwork(int net);

NETWORK_API void sqDispNode(int net, size_t node);

NETWORK_API mxArray *sqTransact(int net, size_t node, SQ_NODE_DATA_TYPE *value);

NETWORK_API mxArray *sqApply(int net, const mxArray *updatedNodes, bool list);

void setNodeInputs(Node *n, size_t inputs[], size_t nInputs);

void updateTransfererArgs(Node *n);

void printNodeIds(Node **nodes, size_t n);

void cleanupNode(Node* n, bool disconnect);

int nextFreeNetwork();

long nextFreeNode(int net);

size_t numActiveNodes(Network net);

Node **nodePtrs(Node from[], size_t idxs[], size_t n);

void setNodeCurrValue(Node *n, SQ_NODE_DATA_TYPE *value, bool append);

void setNodeWorkingValue(Node *n, SQ_NODE_DATA_TYPE *value);

void addTargetToInputs(Node *sources[], size_t nSources, Node *target);

void removeTargetFromInputs(Node *sources[], size_t nSources, Node *target);

void removeInputFromTargets(Node *targets[], size_t nSources, Node *input);

void arrayAppend(void **srcPtr, size_t *nElemPtr, void *extraElem, size_t elemSize);

void arrayRemove(void **srcPtr, size_t *nElemPtr, size_t elemIdx, size_t elemSize);

BOOL transfer(Node* node);