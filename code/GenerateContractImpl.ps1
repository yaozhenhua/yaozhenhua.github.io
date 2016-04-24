<#
.SYNOPSIS
    Generates a dummy interface implementation for accessing WCF service with retry logic

.PARAMETER Namespace
    Specifies the namespace of generated class

.PARAMETER ClassName
    Specifies the name of generated class

.PARAMETER InterfaceName
    Specifies the interface to be implemented

.PARAMETER AssemblyPath
    Specifies the full path of the interface assembly
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $Namespace,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $ClassName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $InterfaceName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $AssemblyPath
)
Set-StrictMode -Version latest

# Convert IL type name to a proper C# type name
Add-Type -TypeDefinition '
    using System;
    using System.Linq;

    public static class Helpers
    {
        public static string ResolveType(Type t)
        {
            if (t.IsByRef) {
                t = t.GetElementType();
            }

            if (t.IsGenericType) {
                var pType = t.FullName.Split(''`'');
                return string.Concat(pType[0], "<", string.Join(", ", 
                    t.GetGenericArguments().Select(i => ResolveType(i))), ">");
            }
            else {
                return t.ToString();
            }
        }
    }
'

# Generate code for a given interface method
function GenerateMethods($methods)
{
    foreach ($method in $methods) {
        # return type of the method, e.g. System.Collections.Generic.List<System.String>
        $return = [Helpers]::ResolveType($method.ReturnType)

        # System.Void cannot be properly handled
        if ($return -eq "System.Void") {
            $return = "void"
        }

        "        public virtual {0} {1}(" -f $return, $method.Name

        # Statements before the call
        $prelogue = @()
        # Statements after the call
        $postlogue = @()
        # Parameters of the generated method
        $params = @()
        # Parameters to call WCF service
        $callParams = @()

        $method.GetParameters() | % {
            # Type of the parameter
            $paramType = [Helpers]::ResolveType($_.ParameterType)

            if ($_.IsIn -and $_.IsOut) {
                $mod = "ref "
                $prelogue +=   "            {0} {1}_Ref = {1};" -f $paramType, $_.Name
                $postlogue +=  "            {0} = {0}_Ref;" -f $_.Name
                $callParams += "                    ref {0}_Ref" -f $_.Name
            }
            elseif ($_.IsOut) {
                $mod = "out "
                $prelogue +=   "            {0} {1}_Out = default({0});" -f $paramType, $_.Name
                $postlogue +=  "            {0} = {0}_Out;" -f $_.Name
                $callParams += "                    out {0}_Out" -f $_.Name
            }
            else {
                $mod = ""
                $callParams += "                    {0}" -f $_.Name
            }

            $params += "            {0}{1} {2}" -f $mod, $paramType, $_.Name        
        }

        # Finish generating the header
        $params -join ",`r`n"

        "            )"
        "        {"

        if ($return -ne "void") {
            "            {0} returnValue = default({0});" -f $return
        }

        $prelogue -join "`r`n"

        "            CallWithRetry(clientChannel => {"

        if ($return -eq "void") {
            "                clientChannel.{0}(" -f $method.Name
        }
        else {
            "                returnValue = clientChannel.{0}(" -f $method.Name
        }

        $callParams -join ",`r`n"
        "                    );"
        "            });"

        $postlogue -join "`r`n"

        if ($return -ne "void") {
            "            return returnValue;"
        }

        "        }`r`n"
    }
}

$asm = [System.Reflection.Assembly]::LoadFrom($AssemblyPath)
$type = $asm.GetType($InterfaceName)

"// Auto-generated code.  All changes in this file will be discarded."
"namespace $Namespace"
"{"
"    using System;"
"    using System.ServiceModel;"
""
"    [System.CodeDom.Compiler.GeneratedCode(""GenerateContractImpl.ps1"", ""1.0"")]"
"    public partial class $ClassName : $InterfaceName"
"    {"

"    #region Interface methods"

# Generate for all methods defined in the interface
GenerateMethods $type.GetMethods()

"    #endregion"

$type.GetInterfaces() | % {
    "    #region Interface $($_.Name)"

    # Generate for all methods defined in the inerited interface
    GenerateMethods $_.GetMethods()

    "    #endregion"
}

"    }"
"}"

