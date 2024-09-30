# deployAutomox

When using the deploy_automox.ps1 script from this article Automox Agent Installation Overview, you'll notice that you can use this example to assign a Parent Group:

.EXAMPLE
Run this script file with at least an AccessKey specified
```PowerShell
deploy_automox.ps1 -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Optionally include a Group and Parent Group Name as needed
```PowerShell
deploy_automox.ps1 -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupName "My Group Name" -ParentGroupName "My Parent Group Name"
```
Take note of the following:

If the parent group is also the child member of another group, then you do not need to include the parent's parent.

Example of incorrect assignment: 
```PowerShell
deploy_automox.ps1 -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupName "My Group Name" -ParentGroupName "My Parent's Parent Group Name/My Parent Group Name"
```
It is better to just use the immediate parent groups name for the Parent Group as shown in the first example. 

In addition, if the Parent Group is the Default group, there is no need to declare it in the command line as this is accounted for in the script:
```PowerShell
function Set-AxServerGroup
{
param (
[Parameter(Mandatory = $true)][String]$Group,
[Parameter(Mandatory = $false)][String]$ParentGroup
)
if ($ParentGroup)
{
$argList = "--setgrp `"Default Group/$ParentGroup/$Group`""
}
else
{
$argList = "--setgrp `"Default Group/$Group`""
}
Start-Process -FilePath $agentPath -ArgumentList "$argList" -Wait
Start-Process -FilePath $agentPath -ArgumentList "--deregister"
}
```
You would only need to include the child group as intended like:
```PowerShell
deploy_automox.ps1 -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupName "My Group Name"
```
