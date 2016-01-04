---
layout: post
title: Bypass access restrictions in managed code
comments: true
---

For some reason I need to access a private field in a class in the system library.  .NET provides a way to do it.
I think it will be cool to share it although it is not a good coding practice that we will be using it on a regular
basis.

Hypothetically suppose we want to construct an instance of System.ConfigNode.  This class is an internal class in
mscorlib, and the constructor is internal too.  So we cannot just use it as usual.

![Reflector](/public/20120508-reflector.png)

Fortunately we have System.Reflection.  Firstly we load the assembly and find the type:

{% highlight c# %}
    var assembly = Assembly.Load("mscorlib, Version=2.0.0.0"); 
    var configNodeType = assembly.GetType("System.ConfigNode");
{% endhighlight %}

The we can construct an instance:

{% highlight c# %}
    var configNode = configNodeType.InvokeMember( 
                "", 
                BindingFlags.CreateInstance | BindingFlags.NonPublic | BindingFlags.Instance, 
                null, 
                null, 
                new object[] { "SampleConfigNode", null });
{% endhighlight %}

or

{% highlight c# %}
    var configNode = Activator.CreateInstance( 
        configNodeType, 
        BindingFlags.Instance | BindingFlags.NonPublic, 
        null, 
        new object[] { "SampleConfigNode", null }, 
        null);
{% endhighlight %}

Now we can change a private field:

{% highlight c# %}
configNodeType.InvokeMember( 
    "m_value", 
    BindingFlags.NonPublic | BindingFlags.SetField | BindingFlags.Instance, 
    null, 
    configNode, 
    new object[] { "new value" });
{% endhighlight %}

or call a private method:

{% highlight c# %}
    configNodeType.InvokeMember( 
        "AddAttribute", 
        BindingFlags.NonPublic | BindingFlags.InvokeMethod | BindingFlags.Instance, 
        null, 
        configNode, 
        new object[] { "some key", "some value" }); 
{% endhighlight %}

BTW, the format for the code is horrible.  I need to find a better way to handle this.

