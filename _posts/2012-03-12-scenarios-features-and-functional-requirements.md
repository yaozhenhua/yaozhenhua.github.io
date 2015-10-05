---
layout: post
title: Scenarios, features, and functional requirements
---

In the last post [Shift focus to scenario testing](/2012/03/11/shift-focus-to-scenario-testing/), I described what a *scenario* is.  In this post, I would like to think more on features and functional requirements.

The Institute of Electrical and Electronics Engineers (IEEE) has several standards on software documentation.  Among these standards, IEEE 829-1998 “Standards for Software Test Documentation” specifies the form of documents for the various stages of software testing:

* Test plan
* Test design spec
* Test case spec
* Test procedure spec
* Test item transmittal report
* Test log
* Test incident report
* Test summary report

In this standard, the term *feature* is defined as “a distinguish characteristic of a software item (e.g. performance, portability, or functionality).  Often times, features refer to the functional capabilities of a program, and then also called functions.  In the context of *functional requirement*, which describes functions of a software program and its components, function refers to inputs, behaviors, and outputs in a defined context.  Functional requirements describes the functionalities that a system is supposed to accomplish, for instance, this program can do blah.  There are also non-functional requirements, which often specify overall characteristics and imposes certain constraints on the system in terms of performance, portability, security, reliability, accessibility, etc.

In software testing, features and functional requirements are the basis of the component level testing.  In the software development process, the requirements are gathered from users and stakeholders, the high-level architecture of the product is defined, the end-to-end scenarios are compiled, then the features are proposed to support those scenarios, and the functional requirements to be implemented are derived to ensure those scenarios can be performed by the users.

Obviously a feature or a functional requirement can serve multiple scenarios.  Also It is important to always put them in the context of end-to-end scenario, understand why it’s need, and track it throughout the development life cycle.  This is necessary to properly evaluate the customer experience.  In many product groups that I know of, engineers categorize scenarios by their priorities:

* P0: cannot ship without them
* P1: must have
* P2: nice to have

Each scenario is further broken down to features/requirements by their priorities.  The idea is that approaching to the end of development cycle, if the team is lack of resource to complete all features, low priority features will be cut, and low priority scenarios may be dropped.  Personally I have not seen any team is not lack of resource, as a consequence many if not all P2 features are cut, P2 bugs discovered late get postponed to next release.  In other words, the product works but bells and whistles are gone.  There are also practices that the features/requirements are analyzed and put into the system on an isolated basis, without the context of meaningful customer scenario.  Engineers are passionate to deliver a “feature-rich” product, while the customers feel confused and show little appreciation.

We must change this.  A good tester needs to put things in context and represent customers’ interests at all times.  Ultimately software testing is not just exercise the product in different ways and find as many bugs as possible.  The real purpose is to evaluate the customer experience and make an appropriate tradeoff among quality, cost, and time to market.  In the new era of software testing, test team needs to push the quality upstream and downstream, in order to delight our customers and grow our business.
