---
layout: post
title: Primary Tracker
comments: true
---

I believe in [KISS principle](https://en.wikipedia.org/wiki/KISS_principle).  Albert Einstein said:

> Make everything as simple as possible, but not simpler.

This is one of guiding prinicples that I follow in every designs and implementations.  Needless to say, this principle
is particularly important in cloud computing.  Simplicity makes it easier to reason about the system behaviors and drive
code defects down to zero.  For critical components, decent performance and reliability are two attributes to let you
sleep well in the night.  Primary Tracker in networking control plane is a good example to explain this topic.

## Basic layering of fabric controller

Fabric Conrtoller (FC) is the operational center of Azure platform.  FC gets customer orders from the Red Dog Front End
(RDFE) and/or modern replacement Azure Resource Manager (ARM) and then performs all the heavy-lifting work such as
hardware management, resource inventory management, provisioning and commanding tenants / virtual machines (VMs),
monitoring, etc.  It is a "distributed stateful application distributed across data center nodes and fault domains".

Three most important roles of FC are data center manager (DCM), tenant manager (TM), and network manager (NM).  They
manage three key aspects of the platform, i.e. data center hardware, compute, networking.  In production, FC roles
instances are running with 5 update domains (UDs).

![FC layering](/public/20160601-ControllerLayering.svg)

The number of UDs is different in test clusters.  Among all UDs, one of them is elected to the *primary* controller, all
others are considered as *backup*.  The election of primary is based on [Paxos
algorithm](http://research.microsoft.com/en-us/um/people/lamport/pubs/paxos-simple.pdf).  If primary role instance
fails, all the remaining backup replicas will vote a new primary which will resume the operation.  As long as there are
3 or more replicas, a quorum can be made and FC will operate normally.

In the above diagram, different nodes communicate with each other and form a ring via the bottom layer RSL.  On top of
it is a layer of cluster framework, libraries, utilities, collectively we call it *CFX*.  Via CFX and RSL a storage
cluster management service is provided where In-Memory Object Store (IMOS) is served.  Each FC role defines several data
models living in IMOS which is used to persis the state of the role.

Note that [eventual consistency](https://en.wikipedia.org/wiki/Eventual_consistency) model is not used in FC as far as
one role is concerned.  In fact, strong consistency model is used to add the safety guarantee (read [Data Consistency
Primer](https://msdn.microsoft.com/en-us/library/dn589800.aspx) for more information on consistency models).  Whether
this model is best for FC is debatable, I may explain more in a separate post later.

## Primary tracker

Clients from outside of a cluster communicate with FC via [Virtual IP
address](https://en.wikipedia.org/wiki/Virtual_IP_address) (VIP), and the software load balancer (SLB) routes the
request to the right node at where primary replica is located.  In the event of primary fail-over, SLB ensures the
traffic to the VIP always (or eventually) reaches the new primary.  For performance consideration, communication among
FC roles does not go through VIP but Dynamic IP address (DIP) directly.  Note that primary of one role is often
different from the primary of another role, although sometimes they can be the same.  Then the question is, where is the
primary?  The wrong answer of this question has the same effect of service unavailability.

This is why we have *Primary Tracker*.  Basically primary tracker keeps track of IP address of primary replica and
maintains a WCF channel factory so ensure the request to the role can be made reliably.  The job is as simple as finding
a primary, and re-finding the primary if the old one fails over.

Storage cluster management service provides an interface that, once connecting to any replica, it can tell where the
primary is as long as the replica serving the request is not disconnected from the ring.  Obviously this is a basic
operation of any leader election algorithm, nothing mysterious. So primary tracker sounds trivial.

In Azure environment there are a few more factors to consider.  Primary tracker object can be shared by multiple threads
when many requests are processed concurrently.  WCF client channel cannot be shared among multiple threads reliably,
re-creating channel factory is too expensive.  Having too many concurrent requests may be a concern to the healthy of the
target service.  So it is necessary to maintain a shared channel factory and perform request throttling (again, this is
debatable).

Still this does not sound complicated.  In fact, with proper compoentization and decoupling, many problems can be
modeled in a simple way.  Therefore, we had a *almost*-working implementation, and it has been in operation for a while.

## Use cases

From the perspective of networking control plane, two important use cases of the primary tracker are:

* Serving tenant command and control requests from TM to NM.
* Serving VM DHCP requests from DCM to NM.

Load of both cases depends on how busy a cluster is, for instance if customers are starting many new deployments or
stopping existing ones.

## Problems

Although the old primary tracker worked, it often gave us some headache.  Sometimes customers complained that starting
VMs took a long time or even got stuck, and we root caused the issue to unresponsiveness of DHCP requests.  Occasionally
a whole cluster was unhealthy because DHCP stopped, and no new deployment could start because the start container failed
repeatedly and pushed physical blades to Human Investigate (HI) state.  Eventually the problem happened more often to
the frequency of more than once per week, DRI on rotation got nervous since they did not know when the phone would ring
them up after going to bed.

Then we improved monitoring and alerting in this area to collect more data, and more importantly got notified as soon as
failure occured.  This gave us right assessment of the severity but did not solve the problem itself.  With careful
inspection of the log traces, we found that failover of primary replica would cause the primary track losing contact to
any primary for indefinite amount of time, anywhere from minutes to hours.

## Analysis

During one of Sev-2 incident investigation, a live dump of the host processs of the primary tracker was taken.  The
state of object as well as all threads were analyzed, and the conclusion was astonishingly simple -- there was a
prolonged race condition triggered by channel factory disposal upon the primary failover, then all the threads accessing
the shared object just started an endless fight with each other.  I will not repeat the tedius process of the analysis
here, basically it is backtracking from the snapshot of 21 threads to the failure point with the help of log traces,
nothing really exciting.

Once having the conclusion, the evidence in the source code became obivious.  The irony part is that the first line of
the comment said:

> This class is not designed to be thread safe.

But in reality the primary use case is in a multi-thread environment.  And the red flag is that the shared state is
mutable by multiple thread without proper synchronization.

## Fix

Strictly speaking the bugfix is a rewrite of the class with existing behavior preserved.  As one can imagine it is not a
complicated component, the core design is using [reader-writer
lock](https://en.wikipedia.org/wiki/Readers%E2%80%93writer_lock), specifically `ReaderWriterLockSlim` class (see the
[reference source
here](http://referencesource.microsoft.com/#System.Core/system/threading/ReaderWriterLockSlim/ReaderWriterLockSlim.cs)).
In addition, a concept of *generation* is introduced to the shared channel factory in order to prevent the problem of
different threads finding new primary multiple times after failover.

### Stress test

The best way to check the reliability is to run a stress test with as much load as possible.  Since the new
implementation is backward compatible with the old one, it is straightforward to conduct the comparative study.  The
simulated stress environment has many threads sending requests continuously, and the artificial primary failover occurs
much more often than any production cluster, furthermore the communication channel is injected with random faults and
delay. It is a harsh environment for this component.

It turns out the old implementation breaks down within 8 minutes.  The exact failure pattern is observed as the ones
happening in production clusters.  On the contrary, the new implementation has not failed so far.

### Performance measurement

Although the component is perf sensitive, it has no regular perf testing.  A one-time perf measurement conducted in the
past shows that the maximum load it is able to handle is around 150 to 200 request/sec in a test cluster.  This number
is more than twice of the peak traffic in a production cluster under normal operational condition, according to live
instrumentation data.  Is it good enough?  Different people have different opinions.  My principle is to design for the
worst scenario and ensure the extreme case is covered.

As a part of bugfix work, a new perf test program is added to measure both the throughput and latency of the system.
The result shows that the new component is able to process about ten times of load, and the per-request overhead is less
than one millisecond.  After tuning a few parameters (which is a bit different than production setup), the throughput is
increased further by about 30-40%.

## Rollout

Despite the fear of severe incident caused by the change in critical component, with the proof of functional / perf /
stress test data, the newly designed primary tracker has been rolled out to all production clusters.  Finally the
repeated incidents caused by primary tracking failure no longer wake up DRIs during the night.  From customers
perspective, this means less number of VM starting failure and shorter VM bootup time.
