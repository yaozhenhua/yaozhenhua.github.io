---
layout: post
title: Auto-Generate an Interface Implementation in C# During Build 
comments: true
---

Given an interface, it is straightforward to generate implementations of all members (or missing ones of abstract class)
using either Visual Studio or ReSharper.  Sometimes, code generation in IDE may not be enough for handling boilerplate
code.  Recently I have to deal with a WCF service proxy, where retry and logic mechanism needs to be put in every
method.  Basically the scenario is the following:

* There is a WCF service running on multiple-replica setup, and the interface is changing constantly.
* The client side wants to call the service and has to deal with unreliable channel with reconnect.  However, the
  client code simply takes an interface object and uses it just like all other libraries, i.e. without any special
  logic of retry / reconnect / timeout.
* It is preferable to not make any change to the client code.  Finding all references of the interface and fixing the
  use pattern is not an option, and it may be huge amount of work anyway.

My solution is providing a service proxy, which implements the service interface and forwards all calls to the actual
service endpoint with proper logic.  As one can imagine, boilerplate code has to be put in every method of the proxy
class, something like:

{% highlight c# %}
    ...
    CallWithRetry(clientChannel => {
        retValue = clientChannel.SomeMethod(...);
    });
    ...
    return retValue;
{% endhighlight %}

Thanks to reflection, it is fairly easy to inspect the interface type to discover the full details, and then generate
the boilaterplate code automatically.  This can be performed in both C# and PowerShell.  However, to integrate this
process with the build, it is simpler to use PowerShell.  The basic process is the following:

1. Load the interface assembly using `System.Reflection.Assembly.LoadFrom`
2. Load the interface type using `Assembly.GetType`
3. Discover all methods using `Type.GetMethods`
4. For each method, generate the code based on `ReturnType` and the list of parameters using `GetParameters`

For the parameter type, we need to check if it is input, output, or ref parameter and handle the code generation
accordingly.  Another thing to consider is handling the generic types, which `Name` or `ToString()` will generate a
string like:

    System.Collections.Generic.List`1[System.IO.FileStream]

which will not work unless converting to C# declaration `List<FileStream>`.  The issue of type resolving can be handled
using embedded C# code in the script:

{% highlight c# %}
        public static string ResolveType(Type t)
        {
            if (t.IsByRef) {
                t = t.GetElementType();
            }

            if (t.IsGenericType) {
                var pType = t.FullName.Split('`');
                return string.Concat(pType[0], "<", string.Join(", ", 
                    t.GetGenericArguments().Select(i => ResolveType(i))), ">");
            }
            else {
                return t.ToString();
            }
        }
{% endhighlight %}

If you are interested, you may download the script [here](~/code/GenerateContractImpl.ps1).
