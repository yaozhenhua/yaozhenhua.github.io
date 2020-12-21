---
layout: post
title: Layman's Quick Guide on Crashdump Debugging
comments: true
---

In distributed computing, we rely on traces and metrics to understand the runtime behavior of programs. However, in some
cases we still need assistance from debuggers for live-site issues. For instance, if the service crashes all of sudden
and no trace offers any clue, we need to load crashdump into debugger. Or some exception is raised but traces are
insufficient to understand the nature of the problem, we may need to capture a full state of the process.

In old days, at least starting in Windows 3.1, there was a [Dr. Watson](https://en.wikipedia.org/wiki/Dr._Watson_(debugger))
to collect the error information following a process crash, mainly the crash dump file. Every time I saw it, something
bad happened. Nowadays it has been under the new name of [Windows Error
Reporting](https://docs.microsoft.com/en-us/windows/win32/wer/windows-error-reporting), or WER. Inside the platform,
there is still a "watson" service to collect all the crashdumps created by the platform code, process it, assign to the
right owner, and send alerts as configured. Some times during live-site investigation, we can also request a dump file
collection using "Node Diagnostiics", then the file will be taken over by Watson (assuming your hand isn't fast enough
to move the file somewhere else).

Like it or not, to look at the dump file you have to use
[windbg](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools). You can choose cdb
or windbgx but they are not really different. If you are too busy to [learn how windbg
works](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/getting-started-with-windbg), particularly
managed code debugging using
[SOS](https://docs.microsoft.com/en-us/dotnet/framework/tools/sos-dll-sos-debugging-extension), then you may use this
quick guide to save some time.

## Debugger extensions

Download sosex from [Steve's TechSpot](http://www.stevestechspot.com/) and save the DLL in the extension directory.

Download mex from [Microsoft download](https://www.microsoft.com/en-us/download/details.aspx?id=53304) and save the
DLL in the extension directory.

To find the extension directory, find the directory at where windbg.exe is located using Task Manager, then go to
`winext` directory.

## Basic commands

**Exit windbg**: enter `qd` or simply Alt-F4.

**Display process environment block**

    !peb

Wou will see where the execution image is, all the environment variables which contains the machine name, processor ID,
count, etc.

**CPU usage**

To check which threads have consumed how much CPU time:

    !runaway

To check CPU utilization, thread pool worker thread and completion port thread usage:

    !threadpool

**List of threads**: check if how many threads there are, any threads are terminated or hitting some exception, etc.

    !threads

If you click the blue underlined link you can switch to that thread, then use the following to see the native stack
trace:

    k

or see the managed stack trace

    !clrstack

To check the object on the stack run the following:

    !dso

To check the local variables of a specific frame (use the frame number in "k" output):

    !mdv [FrameNumber]

**Object count**: to get the statistics of objects in the managed heap.

    !dumpheap -stat

If you want to get the live objects (the objects that cannot be garbage collected), add `-live` parameter. If you want
to get the dead object, add `-dead` parameter.

**Find object by type name**: firstly find the list of types with statistics by the type name (either full name of
partial):

    !dumpheap -stat -type MyClassName

Then click the method table link, which is essentially:

    !dumpheap /d -mt [MethodTableAddress]

You can click the address link to dump the object, or

    !do [ObjectAddress]

A better way to browse the object properties is to use sosex:

    !sosex.mdt [ObjectAddress]

To know why it's live, or the GC root:

    !gcroot [ObjectAddress]

or use sosex

    !sosex.mroot [ObjectAddress]

## Symbols

Check the current symbol path, you use use menu or

    .sympath

Add a directory where PDB files (symbols) are located, use menu or 

    .sympath+ \\mynetworkshare\directory\symbols

Find all the class names and properties with a particular string (use your own wildcard string):

    !sosex.mx *NetworkManager

List of all modules loaded:

    lm

To get the details about a module, click the link in above output or:

    lmDvm MyNameSpace_MyModule

Here you can see the file version, product version string, timestamp, etc. For the files from many repos, you can see
the branch name and commit hash. If you are interested in the module info:

    !lmi MyNameSpace_MyModule

To show disassembled IL code, firstly switch to a managed frame, then run mu:

    !sosex.mframe 70
    !sosex.mu

## Advanced

**Find unique stack traces**: this will go through the stack trace of all threads, group them by identical ones, and
show you which stack has shown up how many times:

    !mex.us

Often times you can see lock contentions or slow transaction isuse, etc.

**Find all exceptions**:

    !mex.dae

**Dump all async task objects**:

    !mex.tasks

If you have to debug memory related issue, refer to my previous post.

## Further reading

Many debugging topics are not covered, for instance finalization, deadlock, locking, etc. If quick guidance is
insufficient, please spend some time starting from [Getting Started With Windows
Debugging](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/getting-started-with-windows-debugging) or
the book [Advanced .NET
Debugging](https://www.amazon.com/Advanced-NET-Debugging-Mario-Hewardt/dp/0321578899/ref=pd_sbs_4?pd_rd_w=eiq5r&pf_rd_p=ed1e2146-ecfe-435e-b3b5-d79fa072fd58&pf_rd_r=MJFW6YVTQMQS2HTBQRTK&pd_rd_r=05522991-7eaf-4b64-b70c-9fecd7a9bbfd&pd_rd_wg=0WZpk&pd_rd_i=0321578899&psc=1).
