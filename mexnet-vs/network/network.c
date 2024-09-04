// network.c : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "network.h"

#define MAX_NETWORKS (10)
#define NETWORK_VALID(id) (((id) >= 0) && ((id) < MAX_NETWORKS) && networks[id].active)
#define NODE_VALID(net,id) (((id) >= 0) && ((id) < (net).nNodes) && ((net).nodes[id].inUse))

DEF_ARRAY_INDEX_OF(nodePtr, Node *) // define an arrayIndexOf function to work on Node ptrs

#define DEF_STACK_STRUCT(type) struct { type *arr; size_t top; }

typedef DEF_STACK_STRUCT(size_t) IndexStack;

#define STACK_ALLOC(stack, size) { (stack).arr = mxMalloc( sizeof(*(stack).arr)*(size) ); }

#define STACK_FREE(stack) { mxFree((stack).arr); }

#define STACK_PUSH(stack, val) { (stack).arr[(stack).top++] = (val); }

#define STACK_PUSH_ALL(stack, vals, n) { for(long i = (n)-1; i >= 0; i--) (stack).arr[(stack).top++] = (vals)[i]; }

//#define STACK_PUSH_ALL(stack, vals, n) { for(long i = (n)-1; i >= 0; i--) if (!(vals[i])->queued) {(stack).arr[(stack).top++] = (vals[i]); (vals[i])->queued = true;} }

#define STACK_POP(stack) (stack).arr[--((stack).top)]

#define STACK_IS_EMPTY(stack) ( (stack).top == 0 )

#define DEF_QUEUE_STRUCT(type) struct { type *arr; size_t in; size_t out; size_t n; }

#define QUEUE_ALLOC(q, size) { (q).arr = mxMalloc( sizeof(*(q).arr)*(size) ); (q).in = (q).out = 0; (q).n = (size); }

#define QUEUE_FREE(q) { mxFree((q).arr); }

//if ((q).in == (((q).out - 1 + (q).n) % (q).n)) return -1; // test for queue full minus one element

#define QUEUE_PUT(q, val) {if (!(val)->queued) {(q).arr[(q).in] = (val); (val)->queued = true; (q).in = ((q).in + 1) % (q).n; } }

#define QUEUE_PUT_ALL(q, vals, sz) for(size_t i = 0; i < sz; i++) { if (!(vals)[i]->queued) { (q).arr[(q).in] = (vals)[i]; (vals)[i]->queued = true; (q).in = ((q).in + 1) % (q).n; } }

#define QUEUE_GET(q) (q).arr[(q).out]; { (q).arr[(q).out]->queued = false; (q).out = ((q).out + 1) % (q).n; }

#define QUEUE_IS_EMPTY(q) ( (q).in == (q).out )

Network networks[MAX_NETWORKS];

IndexStack transact(Network net, Node* node, SQ_NODE_DATA_TYPE *value);

BOOL flattenStruct(Node* node);

NETWORK_API int sqCreateNetwork(size_t size, mxArray *deleteCallback)
{
	int idx = nextFreeNetwork();
	if (idx >= 0) {
		networks[idx] = (const Network){ 0 }; // re-initialise network
		networks[idx].nodes = mxCalloc(size, sizeof(Node)); //alloc memory for size nodes
		mexMakeMemoryPersistent(networks[idx].nodes); //ensure the memory will persist
		networks[idx].nNodes = size; // record the number of nodes in our network
		networks[idx].deleteCallback = deleteCallback;
		networks[idx].active = TRUE;
	}
	return idx;
}

NETWORK_API void sqDeleteNetwork(int net)
{
	if (NETWORK_VALID(net)) {
		Network network = networks[net];
		mexPrintf("Deleting net(%d)\n", net);
		networks[net].active = FALSE; // set network inactive for safety (possible reentrancy)
		if (network.deleteCallback) {
			mexCallMATLABWithTrap(0, NULL, 1, &network.deleteCallback, "apply");
			mxDestroyArray(network.deleteCallback);
		}
		for (int i = 0; i < network.nNodes; i++) {
			if (network.nodes[i].inUse)
				cleanupNode(&network.nodes[i], false);
		}
		mxFree(network.nodes); // clean up array of nodes
		networks[net] = (const Network){ 0 }; // clear network info
	}
	else {
		mexPrintf("%d is not a valid network id\n", net);
	}
}

NETWORK_API void sqDeleteNetworks(void) {
	int i;
	for (i = 0; i < MAX_NETWORKS; i++) {
		if (NETWORK_VALID(i))
			sqDeleteNetwork(i);
	}
}

NETWORK_API size_t sqAddNode(int net, size_t inputs[], size_t nInputs, Transferer transferer, bool appendValues)
{
	if (NETWORK_VALID(net)) {
		size_t nodeidx = nextFreeNode(net);
		if (nodeidx >= 0) {
			Node *n = &networks[net].nodes[nodeidx];
			/*mxArray *mxInputIdxs = mxCreateDoubleMatrix(nInputs, 1, mxREAL);
			double *dInputIdxs = mxGetPr(mxInputIdxs);
			mexMakeArrayPersistent(mxInputIdxs);
			for (i = 0; i < nInputs; i++)
			dInputIdxs[i] = (double)inputs[i];*/
			n->netId = net;
			n->id = nodeidx;
			// TODO: handle allocation fails etc
			n->nTargets = 0;
			n->targets = mxMalloc(0); // 'dummy' targets array
			setNodeInputs(n, inputs, nInputs);
			n->transferer = transferer;
			updateTransfererArgs(n); // fill transferer args with new node info
			n->appendValues = appendValues;
			n->inUse = TRUE;
			return nodeidx;
		}
	}
	return -1;
}

NETWORK_API void sqDeleteNode(int net, size_t node)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		cleanupNode(&networks[net].nodes[node], true);
	}
}

NETWORK_API void sqSetNodeCurrValue(int net, size_t node, mxArray *value, bool append)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		setNodeCurrValue(&networks[net].nodes[node], value, append);
	}
}

NETWORK_API void sqSetNodeEventsTarget(int net, size_t node, mxArray *value) {
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		if (networks[net].nodes[node].eventsTarget) {
			mxDestroyArray(networks[net].nodes[node].eventsTarget);
			//mexPrintf("destroying event target\n");
		}
		networks[net].nodes[node].eventsTarget = value;
	}
}

NETWORK_API SQ_NODE_DATA_TYPE *sqGetNodeCurrValue(int net, size_t node)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		return networks[net].nodes[node].currValue;
	}
	return (SQ_NODE_DATA_TYPE *)NULL;
}

NETWORK_API void sqSetNodeWorkingValue(int net, size_t node, SQ_NODE_DATA_TYPE *value)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		setNodeWorkingValue(&networks[net].nodes[node], value);
	}
}

NETWORK_API SQ_NODE_DATA_TYPE *sqGetNodeWorkingValue(int net, size_t node)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		return networks[net].nodes[node].workingValue;
	}
	return (SQ_NODE_DATA_TYPE *)NULL;
}

NETWORK_API void sqSetNodeInputs(int net, size_t node, const mxArray *inputs)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		double *inputsd = mxGetPr(inputs);
		size_t nInputs = mxGetNumberOfElements(inputs);
		size_t *inputsi = mxMalloc(sizeof(size_t)*nInputs);
		for (size_t i = 0; i < nInputs; i++) {
			inputsi[i] = (size_t)roundl(inputsd[i]);
		}
		setNodeInputs(&networks[net].nodes[node], inputsi, nInputs);
		mxFree(inputsi);
	}
}

NETWORK_API mxArray *sqGetNodeInputs(int net, size_t node)
{
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		Node* n = &networks[net].nodes[node];
		size_t nInputs = n->nInputs;
		Node** inputs = n->inputs;
		mxArray* inputids = mxCreateDoubleMatrix(1, nInputs, mxREAL);
		double *idprs = mxGetPr(inputids);
		for (size_t i = 0; i < nInputs; i++) {
			idprs[i] = (double)inputs[i]->id;
		}
		return inputids;
	}
	return (SQ_NODE_DATA_TYPE *)NULL;
}

NETWORK_API mxArray *sqGetTransfererCustomArg(int net, size_t node) {
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else {
		return mxDuplicateArray(networks[net].nodes[node].transferer.args[TRANSFER_CUSTOM_ARG_IDX]);
	}
	return (SQ_NODE_DATA_TYPE *)NULL;
}

NETWORK_API BOOL sqIsNetwork(int net) {
	return NETWORK_VALID(net);
}

NETWORK_API BOOL sqIsNode(int net, size_t node) {
	return NODE_VALID(networks[net], node);
}

NETWORK_API void sqDispNetwork(int net) {
	if (NETWORK_VALID(net)) {
		size_t nNodes = numActiveNodes(networks[net]);
		mexPrintf("Net %d with %d/%d active nodes\n", net, nNodes, networks[net].nNodes);
	}
	else {
		mexPrintf("%d is not a valid network id\n", net);
	}
}

NETWORK_API void sqDispNode(int net, size_t node) {
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
	}
	else
	{
		Node* n = &networks[net].nodes[node];
		mxArray *lhs;
		mexPrintf("{#%d,value:", n->id); // print id
		// print current value
		if (n->currValue) {
			if (mxIsNumeric(n->currValue)) {
				mexCallMATLAB(1, &lhs, 1, &n->currValue, "mat2str");
				char* valstr = mxArrayToString(lhs);
				mexPrintf("%s", valstr);
				mxFree(valstr);
				mxDestroyArray(lhs);
			}
			else {
				mexPrintf("{...}");
			}
			
		}
		else {
			mexPrintf("NULL");
		}
		mexPrintf(",inputs:[");
		printNodeIds(n->inputs, n->nInputs);

		mexPrintf("],targets:[");
		printNodeIds(n->targets, n->nTargets);
		mexPrintf("],transferer{funName:@%s,opCode:%d}}\n", n->transferer.funName, n->transferer.opCode);
	}
}

NETWORK_API mxArray *sqTransact(int net, size_t node, SQ_NODE_DATA_TYPE *value) {
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
		return NULL;
	}
	else if (!NODE_VALID(networks[net], node)) {
		mexPrintf("%d is not a valid node id\n", node);
		return NULL;
	}
	else
	{
		IndexStack affectedNodes = transact(networks[net], &networks[net].nodes[node], value);
		mxArray *affectedmxArr = mxCreateDoubleMatrix(affectedNodes.top, 1, mxREAL);
		double *affectedArr = mxGetPr(affectedmxArr) + affectedNodes.top;
		while (!STACK_IS_EMPTY(affectedNodes))
			*(--affectedArr) = (double)STACK_POP(affectedNodes);
		STACK_FREE(affectedNodes); // finished with affected stack
		return affectedmxArr;
	}
}

NETWORK_API mxArray *sqApply(int net, const mxArray *nodes, bool list) {
	if (!NETWORK_VALID(net)) {
		mexPrintf("%d is not a valid network id\n", net);
		return NULL;
	}
	else {
		mxArray *notifyArgs[2];
		Node *n = networks[net].nodes; // all the network's nodes
		size_t nApplied, i, nUpdates = mxGetNumberOfElements(nodes);
		double *dNodes = mxGetPr(nodes), *applieddArr;
		IndexStack applied = { 0 }; // set of all nodes that have had changes applied
		mxArray *appliedmxArray;

		if (list) {
			STACK_ALLOC(applied, nUpdates); // appliedSet will never be larger than nUpdates
		}

		// iterate over list of updates, applying to a node only once
		for (i = 0; i < nUpdates; i++) {
			size_t currNode = (size_t)dNodes[i];
			if (!NODE_VALID(networks[net], currNode)) {
				mexPrintf("Invalid node #%d.\n", currNode);
				continue;
			}
			// there might not be a working value to apply if:
			// 1) the transaction(s) ultimately unset the output
			//	OR
			// 2) we already applied it, and cleared it
			// both cases are flagged by a NULL working value
			if (n[currNode].workingValue) {
				// WARNING! we move rather than copy the value from working to current
				mxArray *v = n[currNode].workingValue;
				n[currNode].workingValue = (mxArray *)NULL;
				//mexPrintf(" #%d", nodes[currNode].id);
				setNodeCurrValue(&n[currNode], v, n[currNode].appendValues); // apply the value, ie working->current
				if (list) {
					STACK_PUSH(applied, currNode); // put the node idx into the applied set
				}
				// notify apply event, if any event target registered
				if (n[currNode].eventsTarget) {
					notifyArgs[0] = n[currNode].eventsTarget; // call function on target
					notifyArgs[1] = n[currNode].currValue;
					mexCallMATLAB(0, NULL, 2, notifyArgs, "valueChanged"); // TODO: trap and report errors
					//mxDestroyArray(notifyArgs[2]); // done with notifyArgs nodeid
				}
			}
		}
		
		if (list) {
			// turn the applied set stack into a double mxArray to return
			nApplied = applied.top;
			appliedmxArray = mxCreateDoubleMatrix(nApplied, 1, mxREAL);
			applieddArr = mxGetPr(appliedmxArray) + nApplied;
			while (!STACK_IS_EMPTY(applied)) {
				*(--applieddArr) = (double)STACK_POP(applied);
			}
			STACK_FREE(applied);
			return appliedmxArray;
		}
		else {
			return (mxArray*)NULL;
		}
	}
}

void setNodeInputs(Node *n, size_t inputs[], size_t nInputs) {
	// remove existing input connections
	removeTargetFromInputs(n->inputs, n->nInputs, n);
	if (n->inputs) {
		mxFree(n->inputs);
	}
	// add the new input connections
	n->inputs = nodePtrs(networks[n->netId].nodes, inputs, nInputs);
	n->nInputs = nInputs;
	addTargetToInputs(n->inputs, nInputs, n);
	updateTransfererArgs(n); // recompute the target's transferer inputs arg
}

void updateTransfererArgs(Node *n) {
	mxArray **args = n->transferer.args;
	if (!args[TRANSFER_NET_ARG_IDX]) { // node's network id not already set
		args[TRANSFER_NET_ARG_IDX] = mxCreateDoubleScalar((double)n->netId);
		mexMakeArrayPersistent(args[TRANSFER_NET_ARG_IDX]);
	}
	if (!args[TRANSFER_NODE_ARG_IDX]) { // node's id not already set
		args[TRANSFER_NODE_ARG_IDX] = mxCreateDoubleScalar((double)n->id);
		mexMakeArrayPersistent(args[TRANSFER_NODE_ARG_IDX]);
	}
	// always recompute node input ids
	if (args[TRANSFER_INPUTS_ARG_IDX]) { // free the existing element
		mxDestroyArray(args[TRANSFER_INPUTS_ARG_IDX]);
	}
	args[TRANSFER_INPUTS_ARG_IDX] = mxCreateDoubleMatrix(1, n->nInputs, mxREAL);
	double *inpids = mxGetPr(args[TRANSFER_INPUTS_ARG_IDX]);
	for (size_t i = 0; i < n->nInputs; i++) {
		inpids[i] = (double)n->inputs[i]->id;
	}
	mexMakeArrayPersistent(args[TRANSFER_INPUTS_ARG_IDX]);
}

void printNodeIds(Node **nodes, size_t n) {
	size_t j;
	for (j = 0; j < n; j++) {
		if (j > 0)
			mexPrintf(",");
		mexPrintf("%d", nodes[j]->id);
	}
}

void cleanupNode(Node *n, bool disconnect) {
	size_t i;
	//mexPrintf("Deleting #%d\n", n->id);
	if (disconnect) {
		// remove this node as a target of all its inputs
		removeTargetFromInputs(n->inputs, n->nInputs, n);
		// remove this node as an input for all its targets
		removeInputFromTargets(n->targets, n->nTargets, n);
	}
	n->inUse = FALSE; // set node inactive for safety (possible reentrancy)
	// free arrays of pointers to inputs, and targets
	mxFree(n->inputs);
	mxFree(n->targets);
	// free transfer data
	mxFree(n->transferer.funName);
	for (i = 0; i < NUMEL(n->transferer.args); i++)
		mxDestroyArray(n->transferer.args[i]);
	// free target field and index arrays
	if (n->transferer.targetFields)
		mxDestroyArray(n->transferer.targetFields);
	if (n->transferer.targetIndices)
		mxDestroyArray(n->transferer.targetIndices);
	// free the data values & events target
	if (n->currValue) {
		mxDestroyArray(n->currValue);
	}
	if (n->workingValue) {
		mxDestroyArray(n->workingValue);
	}
	if (n->eventsTarget) {
		mxDestroyArray(n->eventsTarget);
	}
	// clear all node data for safety
	*n = (const Node){ 0 };
}

size_t numActiveNodes(Network net) {
	int i, count = 0;
	for (i = 0; i < net.nNodes; i++) {
		if (net.nodes[i].inUse) {
			count++;
		}
	}
	return count;
}

Node **nodePtrs(Node from[], size_t idxs[], size_t n) {
	Node **ptrs = mxMalloc(n*sizeof(Node*));
	size_t i;
	for (i = 0; i < n; i++) {
		size_t idx = idxs[i];
		// todo: ensure idx >= 0 && id < net.nNodes && net.nodes[id].inUse
		ptrs[i] = &from[idx];
	}
	mexMakeMemoryPersistent(ptrs);
	return ptrs;
}

void setNodeCurrValue(Node *n, mxArray *value, bool append) {
	if (append && value && (n->currValue)) {
		// todo: check size and data type of src and dst arrays match
		size_t nSrcCol = mxGetN(value), nSrcRow = mxGetM(value);
		size_t nDstCol = mxGetN(n->currValue), nDstRow = mxGetM(n->currValue);
		size_t nSrcElem = mxGetNumberOfElements(value), nDstElem = mxGetNumberOfElements(n->currValue);
		size_t nNewElem = nDstElem + nSrcElem;
		size_t elemSize = mxGetElementSize(n->currValue);
		void *src = mxGetData(value), *dst = mxGetData(n->currValue);
		bool isStruct = mxIsStruct(n->currValue);

		if (nSrcRow != nDstRow) {
			if (nDstCol == 0) { // destination currently empty so we can reshape
				mxSetM(n->currValue, nSrcRow);
			}
			else { // can't horzcat arrays with different numbers of rows
				mexErrMsgIdAndTxt("sq:dimensionsInconsistent",
					"Dimensions of matrices being concatenated are not consistent.");
			}
		}

		if (nNewElem > n->currValueAllocElems) { // need to realloc data array
			// make it double the size it needs to be
			size_t newSize = 2 * nNewElem*elemSize;
			newSize *= (isStruct ? mxGetNumberOfFields(n->currValue) : 1); // if it's a we need slots for each field
			//mexPrintf("allocating more space for data array to hold %d elems\n", 2 * nNewElem);
			dst = mxRealloc(dst, newSize);
			mxSetData(n->currValue, dst);
			n->currValueAllocElems = 2 * nNewElem;
		}
		if (mxIsNumeric(n->currValue)) {
			// copy new data in
			memcpy(((char *)dst) + elemSize*nDstElem, src, elemSize*nSrcElem);
		}
		else if (isStruct) {
			int nFields = mxGetNumberOfFields(n->currValue);
			for (size_t el = 0; el < nSrcElem; el++) {
				for (int field = 0; field < nFields; field++) {
					mxArray *newField = mxGetFieldByNumber(value, el, field);
					newField = mxDuplicateArray(newField);
					mxSetFieldByNumber(n->currValue, nDstElem + el, field, newField);
				}
			}
		}
		else {
			mexErrMsgIdAndTxt("sq:unsupportedType", "Trying to append an unsupported type");
		}
		mxSetN(n->currValue, nDstCol + nSrcCol); // expand N to include new columns
		mxDestroyArray(value);
	}
	else {
		if (n->currValue) { // free existing value
			mxDestroyArray(n->currValue);
			n->currValueAllocElems = 0;
		}
		n->currValue = value;
	}
}

void setNodeWorkingValue(Node *n, SQ_NODE_DATA_TYPE *value) {
	if (n->workingValue) { // free existing value
		mxDestroyArray(n->workingValue);
	}
	n->workingValue = value;
}

void addTargetToInputs(Node *inputs[], size_t nInputs, Node *target) {
	// adds a target to a bunch of nodes (which will be the inputs
	size_t i;
	for (i = 0; i < nInputs; i++) {
		Node* src = inputs[i];
		arrayAppend((void**)&src->targets, &src->nTargets, &target, sizeof(target));
		//mexPrintf("(%d)updated targets of input node[%d] (id#%d=%d)\n", i, src->id, target->id,
		//	src->targets[src->nTargets - 1]->id);
	}
	return;
}

void removeTargetFromInputs(Node *inputs[], size_t nInputs, Node *target) {
	int i;
	for (i = 0; i < nInputs; i++) { // iterate the sources, remove target from each
		Node* src = inputs[i];
		long targetIdx = nodePtrArrayIndexOf(src->targets, src->nTargets, target);
		//mexPrintf("Removing target #%d from #%d\n", target->id, src->id);
		arrayRemove((void**)&src->targets, &src->nTargets, targetIdx, sizeof(target));
	}
	return;
}

void removeInputFromTargets(Node *targets[], size_t nTargets, Node *input) {
	int i;
	for (i = 0; i < nTargets; i++) { // iterate the sources, remove target from each
		Node* target = targets[i];
		long inputIdx = nodePtrArrayIndexOf(target->inputs, target->nInputs, input);
		mexPrintf("Warning: removing input #%d from #%d\n", input->id, target->id);
		arrayRemove((void**)&target->inputs, &target->nInputs, inputIdx, sizeof(input));
		updateTransfererArgs(target); // recompute the target's transferer inputs arg
	}
	return;
}

void arrayAppend(void **srcPtr, size_t *nElemPtr, void *extraElem, size_t elemSize) {
	// reallocate with space for one element more
	*srcPtr = mxRealloc(*srcPtr, (*nElemPtr + 1)*elemSize);
	mexMakeMemoryPersistent(*srcPtr); // ensure it's persistent
	// copy the extra element into the final element of the new array
	memcpy((char*)(*srcPtr) + (*nElemPtr*elemSize), extraElem, elemSize);
	(*nElemPtr)++; // increement the element count
}

void arrayRemove(void **srcPtr, size_t *nElemPtr, size_t elemIdx, size_t elemSize) {
	char *src = (char *)*srcPtr; // source array cast as sizeof == 1 type
	void *dst = mxMalloc((*nElemPtr - 1)*elemSize); // allocate smaller by one array
	// copy the elements upto the removed element
	memcpy(dst, src, elemIdx*elemSize);
	// copy the elements from after the removed element
	memcpy(
		((char *)dst) + elemIdx*elemSize, // destination starting from vacated stlot
		src + (elemIdx + 1)*elemSize,	// src from the element after removed
		(*nElemPtr - elemIdx - 1)*elemSize); // # of elements after removed
	mexMakeMemoryPersistent(dst); //make new array persistent
	(*nElemPtr)--; // decrease the element count pointer
	*srcPtr = dst; // update ptr to new array
	mxFree(src); // free the original array
}

int nextFreeNetwork() {
	int i;

	for (i = 0; i < MAX_NETWORKS; i++) {
		if (!networks[i].active) return i;
	}
	return -1;
}

long nextFreeNode(int net) {
	size_t nNodes = networks[net].nNodes;
	Node *nodes = networks[net].nodes;

	for (long i = 0; i < nNodes; i++) {
		if (!nodes[i].inUse) return i;
	}
	return -1;
}

BOOL anyNetworksActive() {
	int i;
	for (i = 0; i < MAX_NETWORKS; i++) {
		if (networks[i].active) return TRUE;
	}
	return FALSE;
}

IndexStack transact(Network net, Node* node, SQ_NODE_DATA_TYPE *value) {
	Node *nodes = net.nodes;
	DEF_QUEUE_STRUCT(Node *) todo = { 0 };
	IndexStack affected = { 0 }; // list of nodes affected by transaction
	QUEUE_ALLOC(todo, net.nNodes); // size limit is safe since nodes can only be queued once
	STACK_ALLOC(affected, net.nNodes); // TODO: size is unsafe as nodes can be affected more than once

	//mexPrintf("transact begin on node #%d\n", node->id);

	setNodeWorkingValue(node, value); // update the working value of starting node
	QUEUE_PUT_ALL(todo, node->targets, node->nTargets); // starting node's targets need recomputing
	STACK_PUSH(affected, node->id); // add starting node to visited list
	while (!QUEUE_IS_EMPTY(todo)) {
		Node* curr = QUEUE_GET(todo); // next node to process
		curr->queued = false;
		BOOL propagate;
		// compute value from inputs, propagate when working output might be different
		propagate = transfer(curr);
		//mexPrintf("output changed = %d\n", changed);
		if (propagate) { // if current node's output might be different
			// add to set of affected nodes
			STACK_PUSH(affected, curr->id);
			// push its target nodes onto the todo list
			QUEUE_PUT_ALL(todo, curr->targets, (long)curr->nTargets);
		}
	}
	QUEUE_FREE(todo); // done with node transfer todo list
	return affected; // return indices of affected nodes
}

#define LATEST_VALUE(nodePtr) ((nodePtr)->workingValue ? (nodePtr)->workingValue : (nodePtr)->currValue)
#define IS_DOUBLE_SCALAR(v) (mxIsDouble(v) && mxGetNumberOfElements(v) == 1)
#define ANY_NEW_INPUT_OF_2(nodePtr) ((nodePtr)->inputs[0]->workingValue || (nodePtr)->inputs[1]->workingValue)

BOOL transferInMATLAB(Node* node) {
	mxArray *lhs[2], *newOutput;
	BOOL newOutputSet = false, propagate = true;

	mexCallMATLAB(2, lhs, 4, node->transferer.args, node->transferer.funName);
	newOutputSet = mxIsLogicalScalarTrue(lhs[1]);
	mxDestroyArray(lhs[1]); // finished with returned arg2

	/* if new output was previously unset and is still unset, then it is not considered
	an output change. All other cases may require further propagation. */
	if (!newOutputSet) { // new output is unset...
		if (!node->workingValue) // and was already unset, no need to propagate
			propagate = false;
		else { // but was previously set, so clear it
			setNodeWorkingValue(node, (mxArray *)NULL);
		}
	}
	else { // new output set: it might be different so update & flag requiring as propagation
		newOutput = mxDuplicateArray(lhs[0]); // duplicate the returned new value
		mexMakeArrayPersistent(newOutput);	// make it persist...
		setNodeWorkingValue(node, newOutput); // and save to the node
	}
	mxDestroyArray(lhs[0]); // now finished with returned arg1
	return propagate;
}

BOOL transfer(Node* node) {
	int opCode = node->transferer.opCode;
	if (opCode > 0 && opCode < 20) { // BINARY OPS
		if (ANY_NEW_INPUT_OF_2(node)) {
			mxArray *leftArr = LATEST_VALUE(node->inputs[0]);
			mxArray *rightArr = LATEST_VALUE(node->inputs[1]);
			if (leftArr && rightArr) { // both arguments have values available
				if (IS_DOUBLE_SCALAR(leftArr) && IS_DOUBLE_SCALAR(rightArr)) {
					double lv = *mxGetPr(leftArr), rv = *mxGetPr(rightArr);
					mxArray *newOutput;
					switch (opCode) {
					case 1: // binary 'plus'
						newOutput = mxCreateDoubleScalar(lv + rv);
						break;
					case 2: // binary 'minus'
						newOutput = mxCreateDoubleScalar(lv - rv);
						break;
					case 3:	// binary 'times'
					case 4: // binary 'mtimes'
						newOutput = mxCreateDoubleScalar(lv * rv);
						break;
					case 5:	// binary 'rdivide'
					case 6: // binary 'mrdivide'
						newOutput = mxCreateDoubleScalar(lv / rv);
						break;
					case 10: // binary '>'
						newOutput = mxCreateLogicalScalar(lv > rv);
						break;
					case 11: // binary '>='
						newOutput = mxCreateLogicalScalar(lv >= rv);
						break;
					case 12: // binary '<'
						newOutput = mxCreateLogicalScalar(lv < rv);
						break;
					case 13: // binary '<='
						newOutput = mxCreateLogicalScalar(lv <= rv);
						break;
					case 14: // binary '=='
						newOutput = mxCreateLogicalScalar(lv == rv);
						break;
					default: // unknown opCode, compute transfer in MATLAB 
						mexPrintf("Unknown opcode encountered %d\n", opCode);
						return transferInMATLAB(node);
					}
					mexMakeArrayPersistent(newOutput);
					setNodeWorkingValue(node, newOutput);
					return true;
				}
				else { // if both inputs arent double scalars, compute transfer in MATLAB
					return transferInMATLAB(node);
				}
			}
		}
		// valid input arguments not available -> new output is unset...
	}
	else if (opCode >= 30) { // special cases
		switch (opCode) {
		case 30: // numel on one input only
			if (node->inputs[0]->workingValue) {
				mxArray *newOutput = mxCreateDoubleScalar(
					(double)mxGetNumberOfElements(node->inputs[0]->workingValue));
				mexMakeArrayPersistent(newOutput);
				setNodeWorkingValue(node, newOutput);
				return true;
			}
			break;
		case 40: // flattenStruct
			if (flattenStruct(node)) {
				return true;
			}
			break;
		//case 50: // identity
		//	if (node->inputs[0]->workingValue) {
		//		mxArray *newOutput = mxCreateDoubleScalar(
		//			(double)mxGetNumberOfElements(node->inputs[0]->workingValue));
		//		mexMakeArrayPersistent(newOutput);
		//		setNodeWorkingValue(node, newOutput);
		//		return true;
		//	}
		//	break;
		default:
			mexPrintf("Unknown opcode %d encountered.\n", opCode);
			return transferInMATLAB(node);
		}
	}
	else {
		return transferInMATLAB(node);
	}

	// if we reach here, new output is unset
	if (!node->workingValue) // and was already unset, no need to propagate
		return false;
	else { // but was previously set, so clear it
		setNodeWorkingValue(node, (mxArray *)NULL);
		return true;
	}
}

SQ_NODE_DATA_TYPE* flattenSignalStruct(Node* target, SQ_NODE_DATA_TYPE* blueprint) {
	/* use a struct with signal fields as a blueprint to wire up signals as inputs 
	   to this target so that their values will set the field values directly in the
	   target's struct value */
	mxArray *lhs[4];
	mexCallMATLAB(4, lhs, 1, &blueprint, "sig.node.flattenSignalStruct");
	// list of field input nodes is second return arg
	mxArray* fieldNodes = lhs[1];
	// list of targetFields for each input is third return arg
	if (target->transferer.targetFields)
		mxDestroyArray(target->transferer.targetFields);
	target->transferer.targetFields = lhs[2];
	mexMakeArrayPersistent(lhs[2]);
	// list of target indices for each input is fourth return arg
	if (target->transferer.targetIndices)
		mxDestroyArray(target->transferer.targetIndices);
	target->transferer.targetIndices = lhs[3];
	mexMakeArrayPersistent(lhs[3]);
	// configure field inputs to this node
	size_t nInputs = 1 + mxGetNumberOfElements(fieldNodes); // blueprint input + field inputs
	size_t *inputsi = mxMalloc(sizeof(size_t)*nInputs); // list of all intended inputs
	double *fieldInputsd = mxGetPr(fieldNodes); // list of field inputs to copy to intended
	inputsi[0] = target->inputs[0]->id; // set the blueprint input as the first input
	for (size_t i = 1; i < nInputs; i++) { // then field inputs are 2nd onwards
		inputsi[i] = (size_t)fieldInputsd[i - 1];
	}
	setNodeInputs(target, inputsi, nInputs);
	mxFree(inputsi);
	
	//mxArray* val = mxDuplicateArray(lhs[0]); // duplicate the struct value
	//mexMakeArrayPersistent(lhs[0]);	// make it persist...
	//mxDestroyArray(lhs[0]); // cleanup the original
	return lhs[0];
}

BOOL flattenStruct(Node* node) {
	BOOL newOutputSet = false;
	SQ_NODE_DATA_TYPE* structval = NULL;
	Node* blueprintInp = node->inputs[0];
	if (blueprintInp->workingValue) { // new blueprint struct to reconfigure using
		structval = flattenSignalStruct(node, blueprintInp->workingValue);
		node->transferer.workingInputChanges = true;
		newOutputSet = true;
	} else { // no new blueprint struct to process
		if (node->transferer.workingInputChanges) { // need to undo input changes
			if (blueprintInp->currValue) { // existing blueprint available
				structval = flattenSignalStruct(node, blueprintInp->currValue);
			}
			else { // no blueprint available
				setNodeInputs(node, &blueprintInp->id, 1); // eliminate field inputs
				structval = mxCreateDoubleMatrix(0, 0, mxREAL); // this will just be destroyed later
			}
			node->transferer.workingInputChanges = false;
		}
		else { // no working input changes to undo
			structval = mxDuplicateArray(node->currValue);
		}
	}

	// check each field input, and update output if it's changed
	double* idxs = mxGetPr(node->transferer.targetIndices);
	double* fields = mxGetPr(node->transferer.targetFields);
	size_t nFieldInputs = node->nInputs - 1;
	for (int i = 0; i < nFieldInputs; i++) {// iterate field inputs (2nd input onwards)
		mxArray* inpwv = node->inputs[i + 1]->workingValue;
		if (inpwv) {
			// free existing field value
			mxDestroyArray(mxGetFieldByNumber(structval, (size_t)idxs[i] - 1, (int)fields[i] - 1));
			// set field value to copy of field input working value
			mxSetFieldByNumber(structval, (size_t)idxs[i] - 1, (int)fields[i] - 1, mxDuplicateArray(inpwv));
			newOutputSet = true;
		}
	}

	if (newOutputSet) {
		mexMakeArrayPersistent(structval);
		setNodeWorkingValue(node, structval);
		return true;
	}
	else {
		mxDestroyArray(structval);
		return false;
	}
}