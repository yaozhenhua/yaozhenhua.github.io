---
layout: post
title: Managed Code Memory Analysis Using SOS
---

Memory consumption of managed code program is often a problem.  With automatic memory management and garbage collection,
there is no direct control over when the memory can be freed and how much the code uses.  Recently my team found that
our program somtimes uses over 12 GB of memory.  But we were not sure why -- the numbers from the underlying data model
didn't add up.  So I took a crash dump of the live process and looked into it.  Here I'd like to share my experience.

Firstly make sure the dump file is *full* memory dump, not the minidump since it will not contain sufficient information
for analyzing the managed heap. Then load the dump file with the latest windbg:

    windbg -z MyProc.dmp

SOS debugging extension is the primary tool in this post, it helps us to inspect the internal CLR environment.  SOS.dll
is installed by default with the .NET framework.  If there is managed thread in the process, windbg will load SOS, if
not you can load it by:

    .loadby sos clr

We can take a look at the summary of virtual address space by `!VMStat`, the output shows each type of memory (free,
reserved, committed, private, mapped, image).  We primarily interest in committed memory usage:

```
0:000> !vmstat
TYPE             MINIMUM          MAXIMUM      AVERAGE  BLK COUNT         TOTAL
~~~~             ~~~~~~~          ~~~~~~~      ~~~~~~~  ~~~~~~~~~         ~~~~~
Free:
...
Reserve:
...
Commit:
Small                 4K              64K          16K      2,674       44,773K
Medium               68K           1,020K         290K        379      110,111K
Large             1,028K       6,687,940K     136,015K        138   18,770,159K
Summary               4K       6,687,940K       5,930K      3,191   18,925,045K

Private:
...
Mapped:
...
Image:
Small                 4K              64K           8K      2,087       18,318K
Medium               68K           1,012K         265K        239       63,367K
Large             1,060K          19,336K       4,695K         28      131,463K
Summary               4K          19,336K          90K      2,354      213,151K
```

Large amount of committed memory is not a concern by itself, as long as it does not cause severe paging issue.  Once the
memory is reserved and then committed, no access violation will happen when the code accesses it.  Before a hard page
fault happens, OS will not do anything.

Managed objects live on the managed heaps.  For server applications, each processor has a managed heap which is further
divided by Small Object Heap (SOH) and Large Object Heap (LOH).  Any allocation greater or equal to 85,000 bytes goes to
LOH. Garbage Collection (GC) compacts SOH, but not for LOH.  This is because cost of copying bytes outweights the
possible CPU cache usage improvements brought by heap compaction.  In addition, LOH is only collected during a
generation 2 collection. The assumption is that large object allocations are infrequent.  Using `!HeapStat`, we can see
exactly how much space objects are allocated on each heap, how much is free, and how much is taken by dead objects
(a.k.a. unrooted):

```
0:000> !heapstat -iu
Heap             Gen0         Gen1         Gen2          LOH
Heap0        15988552      2958560    774468432    210563928
Heap1         5547832      5080304    778093800    195105512
Heap2        28976440      4958064    660314584    213120288
Heap3        16072088      4515272    667190112    217145664
Heap4        41189144      3688312    678696944    201086848
Heap5        31180824      3057552    620113960    229572712
Heap6        15786888      4272280    767817176    189603856
Heap7        11623488      3580976    817979536    233935064
Heap8        30912664      4537848    704721632    245739848
Heap9        20466896      5430632    688921920    265062448
Heap10       43988200      4227656    625657856    243210672
Heap11       39502880      4759888    627548456    201059768
Total       301235896     51067344   8411524408   2645206608

Free space:                                                 Percentage
Heap0          179288           24    401097600    148441240SOH: 50% LOH: 70%
Heap1           50464           24    389119224    141631088SOH: 49% LOH: 72%
Heap2         5347256        16040    309754872    161108872SOH: 45% LOH: 75%
Heap3          155952          104    310747840    162905832SOH: 45% LOH: 75%
Heap4           16872           24    315464576    136555088SOH: 43% LOH: 67%
Heap5          217984           24    278783920    188880264SOH: 42% LOH: 82%
Heap6        10688424           24    371690200    134803920SOH: 48% LOH: 71%
Heap7          104312           24    407638688    110714312SOH: 48% LOH: 47%
Heap8        24032488           24    340847488    184815376SOH: 49% LOH: 75%
Heap9          252120           24    323667344    205462616SOH: 45% LOH: 77%
Heap10       27836760         4136    293073936    196325600SOH: 47% LOH: 80%
Heap11       22937960           24    279416840    148830192SOH: 45% LOH: 74%
Total        91819880        20496   4021302528   1920474400

Unrooted objects:                                           Percentage
Heap0        14722744      1437760      3221872     14659248SOH:  2% LOH:  6%
Heap1         5251848      3792600      3148112     10520952SOH:  1% LOH:  5%
Heap2        20784064      3812328      3258392     11658608SOH:  4% LOH:  5%
Heap3        14661456      3529864      3836832     14142104SOH:  3% LOH:  6%
Heap4        40598120      2375256      3574880     22224832SOH:  6% LOH: 11%
Heap5        30044536      2480656      3173816     11332488SOH:  5% LOH:  4%
Heap6         4609088      1684536      4356016     17064128SOH:  1% LOH:  8%
Heap7        10865792      1742864      4685744      9514808SOH:  2% LOH:  4%
Heap8         5603856      3151520      3188216     25086352SOH:  1% LOH: 10%
Heap9        18946008      3536448      3856056     12516424SOH:  3% LOH:  4%
Heap10       14333424      2814648      3214352      9052368SOH:  3% LOH:  3%
Heap11       15230736      3415320      3665504     14080072SOH:  3% LOH:  7%
Total       195651672     33773800     43179792    171852384
```

Adding Gen0/1/2 and LOH together, the total GC heap size is 11409034256 bytes.  Here we can see that although total
committed memory is close to 19 GB, total amount of heap isn't that large.  Furthermore, tons of space is free.  This is
inevitable price of using managed code.  On the other hand, objects take several GB in heaps, what are they?  This can
be found out by `!DumpHeap`.  It is a good practice to count the live objects and dead objects separately.  The output
shows the MethodTable address for each class, count of objects, total size taken by those objects, and the name of
class.  The statistics is ordered by TotalSize of each class, adding the numbers will show the precise memory
consumption.


Live objects statistics:
```
0:000> !dumpheap -stat -live
Statistics:
              MT    Count    TotalSize Class Name
...
000007fa34bc9378   186248     10429888 System.Net.IPAddress
000007fa34bd6938   172389     11032896 System.CodeDom.CodeCompileUnit
000007fa31b9e248   336283     13451320 System.Collections.Generic.List`1[[System.ServiceModel.Description.MessagePropertyDescription, System.ServiceModel]]
000007fa322b1100   336311     13452440 System.ServiceModel.Description.MessageDescriptionItems
...
000007f9d94ea448  1702166    217877248 Microsoft.Cis.Fabric.[XXX].BaseData
000007f9d94e8eb8  6180216    247208640 Microsoft.Cis.Fabric.[XXX].PropertyInt32
000007fa35b10e08  1911042    253174842 System.String
000007fa35aa4918  5733506    450962104 System.Object[]
000007f9d94e9848 11034288    706194432 Microsoft.Cis.Fabric.[XXX].Relationship
000007fa35b16888   101478    820560272 System.Byte[]
Total 65529511 objects
```

Dead objects statistics:
```
...
000007fa35b12090    83244     36607082 System.Char[]
000007fa35aa4918   339962     50435720 System.Object[]
000007fa35b10e08   840888    120361892 System.String
000007fa35b16888    14739    144078452 System.Byte[]
```

Copying the output to Excel, the numbers show that live objects larger than 10000000 are 4.26 GB in total, dead objects
are 364 MB in total.  This is what the program really used out of 19 GB of memory.  The output of `!dumpheap -stat` also
shows *free space*, which is fragmented space not being compacted yet.  In this case it is about 1.74 GB.

For live objects, we still want to understand if those objects are in use by the program or not.  If in use, the GC root
should end up in the running program and we should be aware of it.  In other cases, the objects are not directly in use,
but some part of the code holds strong reference to them so GC doesn't treat them as garbage.  To figure this out, we
can use `!GCRoot` to find where the references are:

```
0:000> !gcroot -all 000000266063fbf0
HandleTable:
    000000265e6317d8 (pinned handle)
    -> 0000002670395970 System.Object[]
    -> 000000266059b2d8 Microsoft.Cis.Fabric.[XXX].ObjectStore
...
    -> 000000266063fbf0 Microsoft.Windows.[XXX].AllocatedVip

Found 1 roots.
```

In this case we know the object should have been freed but it is incorrectly referenced by the ObjectStore, and all the
allocated object in the data model are accumulated in the store which is the cause of excessive memory consumption.
Now we know where to look for the problem further and perform the optimization.
