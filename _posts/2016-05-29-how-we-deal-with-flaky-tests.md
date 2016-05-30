---
layout: post
title: How Do We Deal With Flaky Tests
comments: true
---

Today I read a blog article from [Google Testing Blog](http://googletesting.blogspot.com/) ["Flaky Tests at Google
and How We Mitigate Them"](http://googletesting.blogspot.com/2016/05/flaky-tests-at-google-and-how-we.html) and would
like to share my thoughts.

Flaky tests not unheard of for a large software project, particularly if test cases are owned by developers with variety
level of experience.  People hate flaky tests as much as failed tests, rerun takes more resource, false alarms waste
precious dev resource, and often times people tend to ignore them or disable them entirely.  Personally I do not agree
with the approach in the blog, it is simply not a quality-driven culture.

My opinion is always that, Heisenberg uncertain principle plays no role in software development, any "indeterministic"
behavior can be traced back to a quality issue, and the number of flaky tests should be driven down to zero.

In the past observation many flakiness is caused by test code issues.  There is no test code for the test code, and
people may not have the same level of quality awareness as the product code.  Besides unsafe threading, race conditions,
lack of synchronizations, etc., there are common anti-patterns causing flakiness (only what I can think of at the
moment):

* Checking driven by timeout instead of event: for instance, click a button on UI, wait for 5 seconds, then click the
  next button.
* Unaware the async event: for instance, load a web page and wait for finish by checking if a certain tag is found,
  then proceed to submit the form.  But the page actually has a iframe which has to be completed loading.
* Incorrect assumption of the runtime condition.  There are too many such exmaples.  In one case, a P1 test case owned
  by my team fails over the primary replica of the controller, then wait for its coming back by checking the primary IP
  address reported by the storage cluster management (SCM).  Unfortunately the checking is incorrect, because only the
  layer above SCM is able to tell if the new primary is up reliably.

Besides test code bugs, real product issues may also cause flakiness of the test execution.  This is particularly
dangerous in cloud environment since massive scale magnifies the probability of hitting the real issue in production.
We sometimes say that, if some bad thing has a small chance to happen, then it will happen after deployment.

Most of time, driving down flaky tests requires right mindset and right prioritization from leadership team.  As long as
flaky tests and failed tests are treated as rigorously as product bugs and live-site incidents in terms of priority and
resource assignment, nothing cannot be fixed.  As the tests become more reliable and more proven patterns are adopted,
improved CI experience will benefit everyone from IC to leadership.  One should not underestimate the ROI of driving for
better quality.
