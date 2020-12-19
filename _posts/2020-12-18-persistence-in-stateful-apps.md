---
layout: post
title: Persistence in Stateful Applications
comments: true
---

In cloud computing, we build highly available applications on commodity hardware. The software SLA is typically higher
thn the underlying hardware for an order or more. This is achieved by distributed application based on state machine
replication. If [strong consistency](https://en.wikipedia.org/wiki/CAP_theorem) is required, state persistence based on
[Paxos algorithm](https://en.wikipedia.org/wiki/Paxos_(computer_science)) is often used. Depending on the requirements
on layering, latency, availability, failure model, and other factors, there are several solutions available.

## Cosmos DB or Azure SQL Database

Most apps build on top of core Azure platform can take dependency of [Cosmos
DB](https://docs.microsoft.com/en-us/azure/cosmos-db/introduction) or [Azure SQL
Database](https://azure.microsoft.com/en-us/services/sql-database/). Both are easier to use and integrate with existing
apps. This is often the most viable path with the least resistence, particularly Cosmos DB with excellent availability,
scalability, and performance.

If you are looking for lowest latency possible, the state is better to be persisted locally and cache inside the
process. In this case, remote persistence such as Cosmos DB may not be desirable. For services within the platform below
Cosmos DB, this approach may not be viable.

## RSL

Although not many people have noticed it, [Replicated State Library](https://github.com/Azure/RSL) is one of the
greatest contributions to OSS from Microsoft. It is a verified and well tested Paxos implmentation, which has been in
production for many years. RSL has been the core layer to power the Azure core control plane since the beginning. The
version released on GitHub is the one used in the product as of now. Personally I am not aware of other implementation
with greater scale, performance, and reliability (in term of bugs) on Windows platform. If you have to store 100 GBs of
data with strong consistency in a single ring, RSL is well capable of doing the job.

Note that it is for Windows platforms only, both native and managed code is supported. I guess it is possible to port it
to Linux, however no one has looked into it and no plan to do so.

In-Memory Object Store (IMOS) is a proprietary managed code on top of RSL to provide transaction semantics, strong-typed
object, object collections, relationships, and code-generation from UML class diagrams. Although the performance and
scale are sacrificed somewhat, it is widely used because of convenience and productivity.

## Service Fabric Reliable Collections

RSL and IMOS are often used by "monolithic" distributed applications before [Service
Fabric](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-overview) is widely adopted. SF is a great
platform to build scalable and reliable microservices, in particular *stateful* services. Hosting RSL on SF isn't
impossible but it is far from straightforward. At least, the primary election in RSL is totally independent of SF, you'd
better ensure both are consistent via some trick. In addition, SF may move the replicas around any time, and this must
be coordinated with RSL dynamic replica set reconfiguration. Therefore, the most common approach is to use SF [reliable
collections](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-reliable-services-reliable-collections)
in the stateful application as recommended. Over time, this approach will be the mainstream in the foundational layer.

## Ring Master

If you need distributed synchorinization and are not satisfied with [ZooKeeper](https://zookeeper.apache.org/) because
of its scale, or you want native SF integration, then you should consider adopting [Ring
Master](https://github.com/Azure/RingMaster) which is released to open source. Essentially Ring Master provides a
superset of ZooKeeper semantics. This is the core component supporting the goal state delivery in several
mission-critical foundational services in the platform. The persistence layer can be replaced, the released source code
supports SF reliable collections for production use and in-memory for testing. If you want absolute best performance and
scale, considering persist to RSL.

If you have any question or comments, please leave a message in the discussion. Thanks!
