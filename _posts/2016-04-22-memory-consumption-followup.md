---
layout: post
title: High Memory Consumption Issue Follow-up
comments: true
---

In previous post I discussed how to use SOS to analyze the memory consumption issue in managed code.  An object leak
issue is found in a store component where neither ref-count nor GC is used to manage the object life cycle -- it simply
trusts the client to do the right thing.  Unfortunately we did not.  As a part of upscaling the clusters, memory
consumption must be under control, over 20 GB of usage is unacceptable.  After the fix, our program on a specific
production cluster which used to take 8.4 GB on fresh start now consumes 2.5 GB of private working set.  Peak time
consumption is reduced significantly.  Moreover, the codex size, which reflects the amount of objects being managed by
the control center, is reduced by 86% on a cluster.  Proper RCA and high code quality is proven to be an effective way
to push the platform to a new level.
