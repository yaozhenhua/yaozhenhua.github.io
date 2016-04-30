---
layout: post
title: DLL Load Error and Diamond Dependencies
comments: true
---

Recently the host OS in Azure is being upgraded to a new version.  As a part of this, a DLL of networking agent called
WVCDLL has to be upgraded too.  My team member tried and got a werid error.  Attaching debugger to the program, the IP
stopped at a logging entry, which did not make much sense.  Then I looked closely at the stack trace:

    ...
    0d 00000015`2b44dff0 00007ffe`2736fdbf wvcdll!__delayLoadHelper2+0x258
    0e 00000015`2b44e0b0 00007ffe`27321177 wvcdll!_tailMerge_OsLogger_dll+0x3f
    0f 00000015`2b44e120 00007ffe`273213a8 wvcdll!VirtualSwitchMgmtServiceClassFactory::GetInstance+0x87
    10 00000015`2b44e290 00007ff7`1ad6d26d wvcdll!VirtualSwitchMgmtServiceClassFactory::GetInstance+0x18
    11 00000015`2b44e2d0 00007ff7`1ab8713a NMAgent!IVirtualSwitchManagementService::~IVirtualSwitchManagementService+0x5dd
    ...

`__delayLoadHelper` caught my attention.  Once I saw the assembly it looked clear to me:

    0:019> uf 00007ffe`273210f0
    wvcdll!VirtualSwitchMgmtServiceClassFactory::GetInstance
       34 00007ffe`273210f0 4055            push    rbp
       34 00007ffe`273210f2 53              push    rbx
       34 00007ffe`273210f3 56              push    rsi
       34 00007ffe`273210f4 57              push    rdi
    ...
       37 00007ffe`2732114e 488d05fb960500  lea     rax,[wvcdll!`string' (00007ffe`2737a850)]
       37 00007ffe`27321155 4889442420      mov     qword ptr [rsp+20h],rax
       37 00007ffe`2732115a 4c8d0d5f970500  lea     r9,[wvcdll!`string' (00007ffe`2737a8c0)]
       37 00007ffe`27321161 4c8d442440      lea     r8,[rsp+40h]
       37 00007ffe`27321166 488b15a31b0800  mov     rdx,qword ptr [wvcdll!wvcLogger (00007ffe`273a2d10)]
       37 00007ffe`2732116d 488d4d90        lea     rcx,[rbp-70h]
       37 00007ffe`27321171 ff1599110800    call    qword ptr [wvcdll!_imp_??0FunctionLoggerOsLoggerQEAAPEAVILogger (00007ffe`273a2310)]
       37 00007ffe`27321177 90              nop

From the stack trace the problem occurred at `00007ffe 27321171`, the call instruction.  The symbol name indicates that
the code in WVCDLL is attempting to call a function defined in OsLogger via import table.  Therefore the error is caused
by either the dependency does not exist or it is a wrong version.

In native code, a dependency DLL can be set to *delay loaded* for two reasons:
* The main program may not call any function in the dependency at all.
* Even if it does, the function may be called late in the execution.

Delay-loading can improve the program load speed for obvious reason.  The downside is we may not see the dependency load
failure when the program is loaded, as previous failure shows.

In this case, a closer look turned out that the problem was caused by wrong version was used during the build.  This is
a typical scenario of *diamond dependencies*:
* Program depends on DLL A and B.
* DLL A and B are developed and distributed independently.
* Both A and B depend on DLL C.

Unlike managed code, native code does not check the version of DLL being loaded.  Suppose DLL A version 1 uses DLL C
version 1.1, DLL B version 2 uses DLL C version 1.2 which has a different import table, then we link A and B into the
same program, although the build process is successful, at runtime it will fail to resolve function entries.

Most teams in Microsoft have compoentized the code base and migrated the source repository from centralized SD to
distributed Git -- I may write another post to talk about how the engineering system looks like.  Since the release
cadence of different components are completely different, this problem may not be rare to see.

Lastly, in case anyone does not know one can check the version of loaded module in windbg using `lmvm`:

    0:019> lmvm wvcdll
    Browse full module list
    start             end                 module name
    00007ffe`27310000 00007ffe`273ad000   wvcdll     (deferred)             
        Image path: xxxxxxxxxxxxxxxxxxxxxxxxxxxx\wvcdll.dll
        Image name: wvcdll.dll
        Browse all global symbols  functions  data
        Timestamp:        Tue Mar  8 11:36:39 2016 (56DF29C7)
    ...
        File version:     6.0.36.1
        Product version:  6.0.36.1
    ...
        PrivateBuild:      (by corecet on CY1AZRBLD15)
        FileDescription:  xxxxxxxxxxxxxxxxxxxxxxxx r_mar_2016 (6f6baea) Microsoft Azure®

Based on the version and other info, one can load matching PDB for ease of debugging.
