---
layout: post
title: How Does VM Boot Up in Azure
comments: true
---

One of the frequent complaints in Azure support is that customers cannot RDP / SSH into their VMs.  In many cases there
are very few options for the users other than retry or filing a support ticket.  After all, many components may go
wrong, trace logs are internal, and no one can put hands on the physical machine and check what is happening.  I hope a
brief explanation can give you some insight and make your life slightly easier. :-)

**WARNING**: some technical details are omitted, accuracy is not guaranteed.  Maybe more importantly, some design parts
may sound suboptimal or even controversial.  In public space many companies like to brag how great their culture is and
how much they care engineering quality.  The reality is, in a work-intensive environment, engineers often just "make
stuff work and ship it", fortunately people learn and grow over time so products are improved gradually.

When you deploy a cloud service or start an IaaS VM via web portal or automation, a *Deployment* is created.  Inside
fabric controller, the deployment is called *Tenant*.  Service package (cspkg) and service configuration file (cscfg)
are translated to service description file (svd), tenant description file (trd), and images.  In each cluster, compute
manager and network managers are the two important roles to manage the resource inventory and the tenant life cycle.  At
regional level, some networking resources such as VIP and virtual networks (VNET) are managed by regional controller.
Each tenant is consisted of mutiple roles, each role has one or more role instances, each role instance live in a VM
which is called a container.  VMs are hosted by Hyper-V server, which are managed by the fabric controller running in
the cluster.  Fabric controller is also a tenant like all other customer tenants (imagine clusters managed by clusters).

*Create / update tenant*: svd/trd as well as regional resource is received by the compute manager.  This component will
allocate the resource and find physical nodes which have sufficient capacity to host the required containers.  After
compute resource allocation is completed, it will pass information to network manager (NM).  NM will then allocate
networking related resource and then send relevant information to the agent program running on the nodes where
containers will be running.  After NM sends back confirmation that the network allocation is done, the tenant is
successfully updated to the required service description.  The communication between compute and network managers is
implemented by single-direction WCF with net.tcp binding.  Many APIs are synchronous with certain configurable timeout.

*Start tenant*: Upon receiving this command from the frontend, the compute manager will drive the start container
workflow by sending goal state to compute agent running on the node.  At the same time, it will also notify NM that
certain role instances have to be *connected* (or in service).  NM will send the goal state to its agent for performing
the network programming.  Note this work will happen to multiple nodes in parallel.

Once compute agent receives the command to start container, it will download whatever needed from Azure storage (e.g.
VHD file for IaaS, service package for PaaS), then create a VM via Hyper-V WMI.  By default, the VM NIC port is blocked,
no network traffic can go through.  NM agent program periodically gets the list of all the VM NICs on the host, checks
if the goal state is achieved, and program the interface if needed.  Once the programming is completed, the port is
unblocked then the VM can talk to outside.  Also note that compute and network agents are two different programs and are
driven by different manager components, and they work somewhat independently.

Assuming everything is working properly, the VM is created successfully, the port is unblocked, the guest OS boots up,
the DHCP client will send DHCP discover in order to get its IP configuration and other information.  DHCP packets will
be intercepted and encapsulated if needed, then forwarded to WDS in the cluster.  WDS receives all DHCP traffic in the
cluster, from both physical hosts and virtual machines.  A plugin in WDS will then forward the request to cluster
hardware management component, which will ask NM if the request is for the physical hosts or the tenants.  If the
former, this components will handle by itself, if the latter it will forward the request to NM.

After NM receives the DHCP, it will find out the corresponding tenant based on the MAC address then return IP address
and other relevant information.  After that the response goes back via the same path all the way to the VM.  Now the VM
has an IP configuration and continute to boot.

*Start role instance*: This is mainly for PaaS tenants but also relevant for IaaS.  Guest agent in the VM is configured
to start automatically.  In the DHCP response, there is a special DHCP custom option 245 named *wire server* address. It
is the IP address of a web server running on the physical host to which the guest agent (or anyone running inside VM)
can talk.  GA retrieves this address from DHCP response and does the following:

* ask wire server which version of the protocol is supported.
* periodically ask for the machine goal state, i.e. should the VM continue to run or shutdown.
* retrives the role configuration, which contains IP and other useful information about the runtime environment.
* keep the heartbeat with the wireserver, report the health state and current status.
* upon request start the role instance by loading the program on app VHD mounted in the OS.

Wire server is a low-previlege web app designed to be the middle man between fabric and containers.  If there is any
state request, for instance VM to be shut down, the request will be forwarded by compute agent to the wire server, and
the guest agent is supposed to poll it.  The state of the role instance, e.g. starting / running / busy / unresponsive,
is reported by the GA to the wire server and then compute agent.  Wire server and GA work together to keep VM in a
healthy and responsive state.

For PaaS containers, thanks to Hyper-V integration service (primarily heartbeat service) and GA, compute agent knows if
the guest OS receives proper DHCP offer, when the container is ready, if the container picks up the desired machine goal
state, if the role instance starts properly, and so on.  If unexpected thing happens, the compute stack will decide to
retry, or move the container to other hosts (assuming the problem is caused by malfunctioning physical host), or give up
to wait for engineering team investigation.

Once wire server / compute agent is notified of role instance state, the information will be propagated to the upper
layer and finally reflected in the web portal.  Assuming RDP / SSH endpoint is configuration properly, the incoming
request will be routed by the software load balancer, then it is up to the OS how to handle it.  Many other factors
determine if RDP / SSH works or not, including but not limited to firewall rules, service state, etc.

For IaaS VMs, the OS VHD may be uploaded by customers thus GA may not be installed, and the Hyper-V integration service
may not exist.  In this case, compute manager has no way to know what is running inside guest OS, so it will start the
VM using Hyper-V WMI.  As long as the VM is healthy from hypervisor perspective, even if the guest OS is stuck in the
boot process somewhere, compute agent will not do anything since it has no knowledge about it.

As you can see, many components participate in the VM / container boot process.  Most of time things work amazingly
well.  However, sometimes fabric controller or other parts of the platform may have glitches, sometimes even the Windows
OS may hit issues, consequently causing access issues for customers.  Personally I have seen a variety of incidents due
to platform quality issues, such as:

* General platform unavailability due to cluster outage.  In this case many number of VMs are offline.
* Storage incidents slows down OS VHD retrieval, and oddly enough breaks Base Filter Engine service during the boot.
* Physical networking issue causes packet drop.
* Networking agent does not program the interface properly so DHCP discover is blocked, so no IP address is available.
* Missing notification from compute manager or regional network controller so network manager does send correct goal
  state to network agent.
* After container in VNET tenant moving to different host, the DHCP response was incorrectly formed so the guest OS
  DHCP client fails to take the new lease.

Many more issues are caused by guest OS, such as:

* RDP endpoint misconfigured.
* DHCP disabled.
* Incorrect firewall configuration.
* Mistake in sysprep so Windows image stops working after moving to Azure Hyper-V server.
* Corrupted VHD so OS does not even boot into login screen.

There are also many Windows OS issues that engineers in Azure have to escalate to Windows team.  The number of options
to investigate at customer side is limited. Before contacting customer service, check a few things:

* VHD image works on local Hyper-V server.  Confirm the VHD is syspreped.
* Check firewall in the VM.
* Use appropriate tool when uploading VHD image to Azure storage.  It has to be page blob.
* Check the RDP endpoint configuration.
* Follow the steps on official document: [Troubleshoot Remote Desktop connections to an Azure virtual machine running
  Windows](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-troubleshoot-rdp-connection/)

Often times a support ticket has to be filed, so our engineers can collect detailed information and figure out if it is
caused by platform issue or not.  If you suspect platform issue is the culprit, for instance deployment stuck in
starting or provisioning state for a long time, contact customer support.  We will check all the way from frontend down
to the Hyper-V server, including both control path and data path, to mitigate and resolve the incident.  Security and
privacy are treated very seriously in Azure.  Without consent from customers, no one is able to check the internal state
of guest VM and/or attached VHD.  In some cases, cooperation from customers speeds up investigation significantly
because it allows engineers to read Windows events, logs, and perform kernel mode debugging to understand what exactly
prevents RDP from working.

This is a brief and high-level description of how VM boots up.  Later I may discuss a few components in more details to
give you more insight.  Thanks for reading!
