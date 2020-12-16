---
layout: post
title: Notes on AWS Kinesis Event RCA
comments: true
---

Long time no post! I have written many technical analysis internally but probably I should share more with people who
have no access to that. :-)

As a senior engineer working in Azure Core, alerts and incidents are more common than what you might think. We (me and
my team) strive to build the most reliable cloud in the world and deliver the best customer experience. In reality, like
everyone in the battle field we make mistakes, we learn from them, and try not to make the same mistake twice. During
this Thanksgiving, we tried everything possible to not disturb the platform including suspending non-critical changes,
and it turned out be another non-eventful weekend thank goodness. When I heard the AWS outage in US east, my heart was
with the frontline engineers. Later I enjoyed reading the [RCA of the outage](https://aws.amazon.com/message/11201/).
The following is my personal takeaways.

The first lesson is *do not make changes during or right before high-priority event*. Most of time stuffs do not break
if you don't touch them. If your projection is more capacity may be required, carry out the expansion a few days prior
to the important period of time. Furthermore, even if something does not look quite right, be conservative and be sure
to not make it worse while making a "small" fix.

The second lesson is *monitoring gap*, in other words why did the team not get the high-severity alert to indicate the
actual source of the problem. Regarding the maximum number of threads being exceeded, or the high number of threads
problem, actually in my observation this isn't a rare event. A few days ago, I was invited to check why a backend
service replica did not make any progress. Once loading the crash dump in the debugger, it was quite obivious where the
problem is -- several thousands of threads were spin-waiting a shared resource, which was held by a poorly implemented
logging library. The difference in this case is the team did notice the situation by accurate monitoring and mitigated
the problem by failing over the process. If we know the number of threads should not exceed *N*, we absolutely need to
configure the monitor to know it immediately if it goes out of the expected range, and a troubleshooting guide should be
linked with the alert so even the half-waken junior engineers are able to follow the standard operation procedure to
mitigate the issue or escalate (in case the outcome is unexpected). I am glad to read the repair item for this:

> We are adding fine-grained alarming for thread consumption in the service...

In many services here, the threadpool worker thread growth can be unbounded under certain rare cases until we receive
alert to fix it. For instances, theorectically the number of threads can go up to 32767 although I've never seen that
many (maximum is about 5000-6000 in the past). In some services, the upbound is set to a much conservative number. So I
think the following is something we can learn:

> We will also finish testing an increase in thread count limits in our operating system configuration, which we believe
> will give us significantly more threads per server and give us significant additional safety margin there as well.

In addition, the following caught my attention:

> This information is obtained through calls to a microservice vending the membership information, retrieval of
> configuration information from DynamoDB, and continuous processing of messages from other Kinesis front-end servers
> ... It takes up to an hour for any existing front-end fleet member to learn of new participants.

Maybe the design philosophy in AWS (or upper layer) is different from the practice in my org. The service initialization
is an important aspect to check the performance and reliability. Usually, we try not take dependency from layers
above us, or assume certain components must be operating properly in order to bootstrap the service replica in question.
The duration of service initialization will be measured and tracked over time. If the initialization takes too long to
complete, we will be called. The majority of services in the control plane services takes seconds to be ready, outliers
hit high-severity incidents unfortunately. A few days ago a service in a busy datacenter took about 9 minutes to get
online (from process creation to ready to process incoming requests), that was such a pain during outage. In my opinion,
fundamental improvement has to be performed to fix this, and the following is on the right track:

> ...to radically improve the cold-start time for the front-end fleet...Cellularization is an approach we use to isolate
> the effects of failure within a service, and to keep the components of the service (in this case, the shard-map cache)
> operating within a previously tested and operated range...

Usually we favor *scale-out* the service insteading *scale-up*, however the following is right on spot in this context:

> we will be moving to larger CPU and memory servers, reducing the total number of servers and, hence, threads required
> by each server to communicate across the fleet. This will provide significant headroom in thread count used as the
> total threads each server must maintain is directly proportional to the number of servers in the fleet...

Finally, kudos to Kinesis team on mitigating the issue and finding the root cause. I greatly appreciate the detailed RCA
report which will benefit everyone working in cloud computing!
