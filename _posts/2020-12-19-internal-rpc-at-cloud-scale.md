---
layout: post
title: Internal RPC at Cloud Scale
comments: true
---

In cloud computing, a prevailing design pattern is multiple loosely coupled
[microservice](https://en.wikipedia.org/wiki/Microservices) working in synergy to build the app, and
[RPC](https://en.wikipedia.org/wiki/Remote_procedure_call) is used for inter-service communication. The platform itself
is no exception. If you are interested in how we (mainly the services I worked on) use RPC, keep reading.

## External and Internal Interface

Some services are exposed to public internet using published API contract, for instance xRP (resource providers).
Usually the API is defined in a consistent and platform-neutral manner, such as REST with JSON payload. Typically the
underlying framework is some form of ASP.NET. In this note customer facing services are not discussed.

For internal services that are not exposed to external customers, we have a lot of freedom to choose what works the best
for the context from the technical perspective. In theory, one can choose any protocol one may feel appropriate. In
practice, because of conformity and familiarity, most of time the design choice is converged to a few options as
discussed in the note.

## Authentication

Before starting further discussion, it is helpful to understand a little bit on service to service authentication, which
always scopes down the number of options facing us. In the past, when we choose the communication protocol we look at if
two services are within the same [trust boundary](https://en.wikipedia.org/wiki/Trust_boundary) or not. If a unsecure
protocol is used for talking to a service outside of your trust boundary, the design will be shot down before anyone has
a chance to use it in either internal review or compliance review with the security team. The trust boundary of services
can be the fabric tenant boundary at deployment unit level, or within the same Service Fabric cluster. The most common
case is within the trust boundary use unencrypted protocol, outside of trust boundary secure protocol must be used.

The most common authentication is based on [RBAC](https://en.wikipedia.org/wiki/Role-based_access_control). No one has
persisted privileged access to the service, engineers request JIT access before conducting privileged operations, source
service has to request security token in order to talk to destination service. Foundational services typically use
[claims-based identity](https://en.wikipedia.org/wiki/Claims-based_identity) associated with the
[X.509](https://en.wikipedia.org/wiki/X.509) certificate provisioned with the service. For people who are familiar with
[HTTP authentication](https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication), the authentication is
orthogonal and usually separated from the data contract for the service communication. This means we need some way to
carry the OOB payload for the authentication headers.

Some services choose to not use RBAC due to various reasons, for instance it must be able to survive when all other
services are down, or resolve the circular dependency in the buildout stage. In this case, certificate-based
authentication is used with stringent validation. Because certficate exchange occurs at the transport level, it is
simpler to understand and more flexible to implement, although I personally don't like it because of the security.

## WCF

WCF, or [Windows Communication Foundation](https://docs.microsoft.com/en-us/dotnet/framework/wcf/) is a framework for
implementing [Service-Oriented Architecture](https://en.wikipedia.org/wiki/Service-oriented_architecture) on .NET
platform. Based on [SOAP](https://en.wikipedia.org/wiki/SOAP) WCF supports interoperability with standard web services
built on non-Windows platform as well. It is extremely flexible, powerful, and customizable. And the adoption barrier is
low for developers working on .NET platform. Naturally, it has been the default option for internal RPC. As of today,
many services are still using it.

The common pattern is that unencrypted communication uses [NetTcp
binding](https://docs.microsoft.com/en-us/dotnet/api/system.servicemodel.nettcpbinding), if cert-based authentication is
required [HTTP binding](https://docs.microsoft.com/en-us/dotnet/api/system.servicemodel.wshttpbinding) is used, if RBAC
is needed [federation HTTP
binding](https://docs.microsoft.com/en-us/dotnet/api/system.servicemodel.federation.wsfederationhttpbinding) is used.

For years WCF has been supporting the cloud well without being criticized. However, it is not without downside,
particularly people feel it offers too much flexibility and complexity that we often use it incorrectly. The fact is
most people follow the existing code patterns and do not learn it in a deep level prior to using the technology. After
enough mistakes are made, the blame is moving from people to the technology itself, we need to make things easy to use
otherwise it won't be sustainable. The following are common problems at this point.

### Timeout and retries

When using WCF, it is important to [configure timeout
values](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/configuring-timeout-values-on-a-binding)
correctly. Unfortunately, not everyone know it, and the price is live-site incident. Considering the following scenario:

1. Client sends a request to serve. Now it waits for response back. Receive timeout is one minute.
1. The operation is time consuming. It is completed at the server side at 1.5 minutes.
1. No response is received at the client side after 1 minute, so the client side considers the request has failed.
1. Now the state at client and server sides is inconsistent.

The issue must be considered in the implementation. Often times, the solution is to handle the failures at the transport
layer with retries. Different kinds of back-off logic and give-up threshold may be used, but usually retry logic is
required to deal with intermittent failures, for instance catch the exception, if communication exception then tear down
the channel and establish a new one. In the testing or simulation environment this works well. In real world, when a
customer sends a request to the front-end, several hops is needed to reach the backend which is responsible for the
processing, and each hop has its own retry logic. Sometimes uniform backoff is used at certain hop to ensure the
responsiveness as a local optimization. When unexpected downtime occurs, cascading effect is caused, the failure is
propagated to the upper layer, multi-layer retry is triggered, then we see avalanche of requests. Now a small
availability issue becomes a performance problem and it lasts much longer than necessary.

The problem is well known and has been dealt with. However, it never goes away completely.

### Message size

For every WCF binding we must configure the message size and various parameters correctly. The default values don't work
in all cases. For transferring large data,
[streaming](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/large-data-and-streaming) can be used,
however in reality often times only buffered mode is an option. As the workload increases continuously, the quota is
exceeded occasionally. This has caused live-site incidents several times. Some libraries (e.g. WCF utility in SF) simply
increase those parameters to the maximum, and that caused different set of problems.

### Load balancer friendly

In many cases, server to service communication goes through virtualized IP which is handled by load balancer.
Unsurprising, not many people understand the complication of LB in the middle and how to turn WCF parameters to work
around it. Consequently,
[MessageSecurityException](https://docs.microsoft.com/en-us/dotnet/api/system.servicemodel.security.messagesecurityexception)
happens after service goes online, and it becomes difficult to tune the parameters without making breaking change.

### Threading

This is more coding issue than WCF framework problem -- service contracts are often defined as sync API, and this is
what people feel more comfortable to use. When the server receives short burst of requests and the processing gets
stuck, the number of I/O completion port threads increases sharply, often times the server can no longer receive more
requests. To be fair, this is configuration problem of [service
throttling](https://docs.microsoft.com/en-us/dotnet/framework/configure-apps/file-schema/wcf/servicethrottling), but
uninformed engineers mistakenly treat it as WCF issue.

### Support on .NET core

There is no supported way to host WCF service in a .NET core program, and the replacement is [ASP.NET core
gRPC](https://docs.microsoft.com/en-us/aspnet/core/grpc/why-migrate-wcf-to-dotnet-grpc). Forward-looking projects move
away from WCF rightfully.

### Performance (perceived)

The general impression is WCF is slow and the scalability is underwhelming. In some case it is true. For instance when
using WS federation HTTP, SOAP XML serialization performance isn't satisfying, payload on the wire is relatively large
comparing with JSON or protobuf, now adding over 10 kB of authentication header (correct, it is that large) to every
request you won't expect a great performance out of that. On the other hand, NetTcp can be very fast when authentication
isn't a factor -- it is slower than gRPC but much faster than what control plane services demand. Much of the XML
serialization can be tuned to be fast.  Unfortunately, few people know how to do it and leave most parameters as factory
default.

### Easy mistakes in data contract

With too much power, it is easy to get hurt. I have seen people use various options or flags in unintended way and are
surprised later. The latest one is
[IsReference](https://docs.microsoft.com/en-us/dotnet/framework/wcf/feature-details/interoperable-object-references) on
data contract and
[IsRequired](https://docs.microsoft.com/en-us/dotnet/api/system.runtime.serialization.datamemberattribute.isrequired)
on data members misconfiguration. Human error it is, people wish they didn't have to deal with this.

### RPC inside transaction

Making WCF calls gives inaccurate impression that the statement is no different from calling a regular method in another
object (maybe for novices), so it is casually used everywhere including inside of IMOS transactions. It works most of
time until connection issue arises, then we see mystery performance issue. Over time, people are experienced to steer
away from anti-patterns like this.

As we can see, some of the problems are caused by WCF but many are incorrect use pattern. However, the complexity is
undisputable, the perception is imprinted in people's mind. We have to move forward.

By the way, I must point out that WCF use does not correlate with low availability or poor performance directly. For
instance, the SLA of a foundational control plane service is hovering around four to five 9's most of time but it is
still using WCF as both server and client (i.e. communicating with other WCF services).

## REST using ASP.NET

It is no doubt that ASP.NET is superior in many aspects. The performance, customizability, and supportibility is
unparalleled. Many services moved to this framework before the current recommendation becomes mainstream. However, it
does have more boilerplate than WCF, not as convenient in some aspects.

## Message exchange

Some projects use custom solution for highly specialized scenarios. For instance, exchange
[bond](https://microsoft.github.io/bond/why_bond.html) messages over TCP or HTTP connection, or even customize the
serialization. This is hardly "RPC" and painful to maintain. Over time this approach is being deprecated.

## Protobuf over gRPC

As many .NET developers can see, gRPC has more or less become the "north star" as far as RPC concerned. Once green light
is given, the prototyping and migration has started. Initially it was [Google gRPC](https://grpc.io/), later [ASP.NET
core gRPC](https://docs.microsoft.com/en-us/aspnet/core/grpc/) becomes more popular because of integration with ASP.NET,
customizability, and security to some extent. The journey isn't entirely smooth, for instance people coming from WCF
background has encountered several issues such as:

- Inheritance support in protobuf.
- Reference object serialization, cycling in large object graph.
- Managed type support, such as Guid, etc.
- Use certificate object from certificate store instead of PEM files.
- Tune of parameters to increase max larger header size to handle oversized authentication header (solved already).

Usually people find a solution after some hard work, and sometimes a workaround or adopting new design paradigm. In a
few cases, the team back off to ASP.NET instead. Overall trend of using gRPC is going up across the board. Personally I
think this will be beneficial for building more resilient and highly available services with better performance.
