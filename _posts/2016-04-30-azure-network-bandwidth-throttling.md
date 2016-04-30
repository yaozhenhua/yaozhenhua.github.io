---
layout: post
title: How Does Bandwidth Throttling Work in Azure?
comments: true
---

In the weekend I saw a few posts on [StackOverflow](http://www.stackoverflow.com) asking how the network traffic is
throttled in Azure, how much bandwidth a VM can use, etc.  There are some answers based on measurements or MSDN docs. I
hope this post may give a more complete picture from engineering perspective.

When we talk about bandwidth throttling, we refer to the network bandwidth cap at the VM / vNIC level for the outbound
traffic (or the transmit path).  Inbound traffic from public internet goes through Software Load Balancer but no
throttling is applied at the VM / host.  All network traffic going out of a VM, including both billed and unbilled
traffic, are throttled so the bandwidth is limited to a certain number.  For instance, a "Small" VM is capped at 500
Mbps.  Different sizes of VM have different caps, some of them are very high.

Then the question is, if a VM has more than one interface, is the cap shared by all interfaces or divided equally among
them?  If the value of the bandwidth cap is updated, will VM be rebooted? The answer is it depends.  Some time ago, the
network bandwidth is managed by tenant management component in FC.  Technically the agent running on the host sets a
bandwidth cap on VM switch using Hyper-V WMI when creating VM.  If there are multiple interfaces, the cap is divided by
the number of interfaces.  If we want to change the bandwidth of individual VM or all VMs with the same size, fabric
policy file in the cluster has to be updated and VMs have to be created to apply the new values.  Recently we changed
the design to let network management component in FC to handle this work.  Network programming agent program
communicates with a filter driver (VFP) on the host to create a QoS queue and then associates all interfaces with the
queue.  So all interfaces share the same cap.  For instance, if a small VM has two NICs, if the first NIC is idling the
second NIC can use up to 500 Mbps.  Basically now the cap should apply to the entire VM.  Some cluster may not have this
feature enabled temporarily, but this should be rare.

Another question is, since you call it "cap", does it mean my VM will get that amount of bandwidth in the best case, and
it may get less bandwidth if neighbors are noisy?  The answer is noisy neighbors do not affect the bandwidth throttling.
The allocation algorithm in FC knows how much resource exits on each host, including total network bandwidth, and the
container allocation is designed to allow each individual container uses its full capacity.  If you absolutely believes
the bandwidth is a lot less than advertised (note Linux VM needs Hyper-V IC being deployed), you may open a support
ticket, ultimately the engineering team will figure it out.  From our side, we can see the values in SDN controller as
well as the value set on QoS queue.

In term of latency and throughput, performance measurement shows no statistically significant difference between QoS
queue based throttling and VM switch based throttling.  Both are equally high performance.

The new design allows the seamless/fast update of bandwidth in a cluster -- the entire process takes less than a half
minute and no visible impact to the running VMs.  It also leaves room for further enhancement should upper layer
supports, for instance adjustable bandwidth for same container size based upon customer requirement.  Hope all customers
are satisfied with networking in Azure. :-)
