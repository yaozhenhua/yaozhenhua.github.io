---
layout: post
title: Shift focus to scenario testing
---

In the past, the test team invested heavily on the component level functional testing. Many efforts were spent on understanding the design spec, reviewing the product code, coming up the test cases to verify the implementation was consistent with the design, ensuring the functional requirements were satisfied, and checking the components were engineered correctly. This in-depth testing has been the front line of overall product quality assurance, followed with scenario/end-to-end testing and various non-functional testing.

Along with the team restructuring and shifting of resource, the component level functional testing will have to be owned by dev teams. Going forward, the test team will shift focus to system integration testing, scenario testing, and onwards. To understand better what we should do with this change, we need to take a deeper look at what scenario testing is and how to align with the new direction.

In the product development, a scenario describes how end users interact with the computer system/software product. A scenario is designed to reach certain functional goals, which leads to defining of functional requirements. In some extent, a scenario tells what a product is and how it’s supposed to be used in a predefined context of activity, within a transaction/operation/period of time. Note that scenarios define the software behavior *visible by customers*. Scenario testing is to validate the product can accomplish the defined scenario successfully with defined behaviors observed.

It is important to test and only test the customer visible behaviors. Internal interfaces between components are usually not in the scope of scenario testing. Behaviors that are not visible to customers do not affect the customer experience, thus they should not be tested. Functional requirements and some correctness are generally in the scope of component level functional testing and should be owned by dev team. Additionally, the test team will assume the correctness of components to be test is verified by unit testing and functional testing before conducting scenario testing. Of course, in reality this assumption is often false, and testers may help developers to fill the gap of functional testing.

In the Improvement development model, many end-to-end scenarios may span across more than one improvement. In each improvement, the Improvement Definition Document articulates the goals and use cases. These are the basis of defining scenario test cases. The functional requirements, detailed behaviors, and internal design may be reflected into the component level functional tests and unit tests, however duplication of efforts should be avoided.

For some components or improvements, the behaviors may not be visible to customers. In this case, we may think about:

* Do only other internal components consume the components/features in this improvement?
* If certain behaviors or design are changed, will it affect the customer experience or customer won’t notice it at all?

Then we can decide if the scenarios should be defined at system integration level and based on collaborative behaviors of multiple components/features. If the answer is yes, we may merge the scenario testing from two or more improvements. Sometimes those behaviors may cause side effects on the customer experience indirectly, for instance performance or responsiveness. Then they may be reflected in the scenario testing in a different perspective. Ultimately, all verifications and validations in the scenario tests should reflect the customer experience one way or another.
