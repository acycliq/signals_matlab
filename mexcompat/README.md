# mexcompat

Pure MATLAB drop-in replacements for the old mexnet functions, so code written
against the mex engine keeps working on the pure engine without being
changed.

## Purpose

The signal propagation engine used to be compiled C (see `mexnet-vs/`),
called from MATLAB through mex functions addressed by network id, for
example `submit(netId, nodeId, value)`. The engine is now pure MATLAB
(`sig.node.Node/transact`), but some code outside this repository still
uses the old call signatures. The only known runtime caller is Rigbox:
`exp.SignalsExp/quit` stops an experiment with a `submit` followed by an
`applyNodes` (Rigbox `+exp/SignalsExp.m`, around line 451).

## How it works

`submit` resolves the network through `sig.Net.byId` (nets register in
a table of live networks, like the C's `networks[]` array) and runs the
whole transaction through `Node.transact`. `applyNodes` then has
nothing left to do and just validates its arguments. This fused
behaviour matches every known runtime caller, which always calls the
two back to back. It is NOT equivalent for code that inspects working
values between the two calls; only the legacy plumbing tests in
`tests/Signals_test.m` do that, and they are kept unchanged as mex era
artifacts.

`addSignalsPaths` adds this folder in place of `mexnet/`. If both end
up on the path, this folder should come first so the .m files win over
the .mexw64 binaries.

## If this folder is off the path

If `submit` or `applyNodes` is called without this folder on the path,
the call reaches the old mex binaries in `mexnet/`, which find no C
network and fail with "1 is not a valid network id" followed by "One or
more output arguments not assigned during call to submit". 
For example: running the signalsPong demo and pressing Abort crashed 
with those errors, the quit code calls submit and there is no C network 
anymore. Keeping this folder on the path, ahead of `mexnet/`, routes 
those calls to the pure engine instead.
