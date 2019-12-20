# Requires AzureAD and Microsoft.Graph.Intune module
Connect-AzureAD
Connect-MSGraph

# User Groups to make device groups for devices of members
$UserGroupNames = @(
    "Intune_Department1_All",
    "Intune_Department2_All"
)

foreach ($UserGroupName in $UserGroupNames) {
    $DeviceGroupName = "$($UserGroupName)_Devices"

    $UserGroup = Get-AzureADGroup -SearchString "$UserGroupName" | Where-Object DisplayName -eq "$UserGroupName"
    $UserGroupMembers = $UserGroup | Get-AzureADGroupMember -All $true

    $DeviceGroup = Get-AzureADGroup -SearchString "$DeviceGroupName" | Where-Object DisplayName -eq "$DeviceGroupName"
    if ($DeviceGroup.count -eq 0) {
        New-AzureADGroup -Description "Devices belonging to members in $UserGroup" -DisplayName $DeviceGroupName -MailEnabled $false -MailNickName $false -SecurityEnabled $true
    }
    $DeviceGroupMembers = $DeviceGroup | Get-AzureADGroupMember -All $true

    $AllDevicesInIntune = Get-IntuneManagedDevice | Get-MSGraphAllPages
    $AllDevicesInAzureAD = Get-AzureADDevice -All $true
    $GroupMembersDevices = $AllDevicesInIntune | Where-Object UserPrincipalName -in $UserGroupMembers.UserPrincipalName

    $GroupMembersAzureADDevices = @()
    $GroupMembersDevices | ForEach-Object { $GroupMembersAzureADDevices += $AllDevicesInAzureAD | Where-Object DeviceID -eq $_.azureADDeviceId }

    if ($DeviceGroupMembers.count -eq 0) {
        $GroupMembersAzureADDevices | ForEach-Object { Add-AzureADGroupMember -ObjectId $DeviceGroup.ObjectId -RefObjectId $_.ObjectId }
    }
    else {
        # Compare Groups
        $Compared = Compare-Object -ReferenceObject $DeviceGroupMembers -DifferenceObject $GroupMembersAzureADDevices

        # Add/Remove Devices
        $Compared | Where-Object SideIndicator -eq "=>" | ForEach-Object { Add-AzureADGroupMember -ObjectId $DeviceGroup.ObjectId -RefObjectId $_.InputObject.ObjectId }
        $Compared | Where-Object SideIndicator -eq "<=" | ForEach-Object { Remove-AzureADGroupMember -ObjectId $DeviceGroup.ObjectId -MemberId $_.InputObject.ObjectId }
    }
}