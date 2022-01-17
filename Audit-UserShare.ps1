﻿<#
.SYNOPSIS
    Audit your user share to identify potentially unneeded folders.

.PARAMETER DeleteNoAccounts
    Removes the user folders found with no Active Directory accounts accosiated to them.
    [OPTIONS] Move, Remove

.PARAMETER DeleteOldAccounts
    Removes the user folders who have not logged in within the time specifed with the -daysSinceLogin parameter.
    [OPTIONS] Move, Remove

.PARAMETER MovePath
    The value used when the Move option is specfied at the Delete parameters.

.PARAMETER daysSinceLogin 
    Looks for the users in the user share who haven't logged in the the past X days. 
    [Default: 60 Days]

.PARAMETER folderSize
   Calculates the folder sizes for the accounts found.

.PARAMETER searchDir
    Specifes the directory to search in through.
    [Default: The running users home directory]

.PARAMETER saveFolder
    The folder inwhich you would like to save output to. 
    If not specfied, it will be logged to the console. 
.PARAMETER Exclude
    Pass in any folder name seperated by a comma you would like to exclude.
.PARAMETER logPath
    Path to the log if required.

.EXAMPLE   
    Audit-UserShare -folderSize -searchDir \\server\users -daysSinceLogin 30
        SamAccountName Enabled No Account LastLogonDate          Size/GB
        -------------- ------- ---------- -------------          -------
        testUser1         True      False 11-11-2021 3:19:49 PM     0.12
        testUser2         True      False 11-12-2021 7:32:26 AM     0.25
        testUser3        False      False 11-12-2021 10:05:16 AM    0.68
        testUser4        False      False 11-14-2021 5:23:28 AM     0.64
        testUser5         True      False 11-10-2021 9:44:51 AM     0.09
        testUser6         True      False 10-27-2021 7:27:43 PM     0.02
        testUser7         True      False 11-05-2021 8:34:55 AM     1.03
        testUser8          N/A       True                           0.57
        testUser9         True      False 11-12-2021 3:17:10 PM      0.6
.EXAMPLE  
    Audit-UserShare -daysSinceLogin 30 -Exclude testUser8
        SamAccountName Enabled No Account LastLogonDate          Size/GB
        -------------- ------- ---------- -------------          -------
        testUser1         True      False 11-11-2021 3:19:49 PM     0.12
        testUser2         True      False 11-12-2021 7:32:26 AM     0.25
        testUser3        False      False 11-12-2021 10:05:16 AM    0.68
        testUser4        False      False 11-14-2021 5:23:28 AM     0.64
        testUser5         True      False 11-10-2021 9:44:51 AM     0.09
        testUser6         True      False 10-27-2021 7:27:43 PM     0.02
        testUser7         True      False 11-05-2021 8:34:55 AM     1.03
        testUser9         True      False 11-12-2021 3:17:10 PM      0.6
.EXAMPLE  
    Audit-UserShare -daysSinceLogin 30 -deleteNoAccount
        SamAccountName Enabled No Account LastLogonDate          Size/GB
        -------------- ------- ---------- -------------          -------
        testUser1         True      False 11-11-2021 3:19:49 PM     0.12
        testUser2         True      False 11-12-2021 7:32:26 AM     0.25
        testUser3        False      False 11-12-2021 10:05:16 AM    0.68
        testUser4        False      False 11-14-2021 5:23:28 AM     0.64
        testUser5         True      False 11-10-2021 9:44:51 AM     0.09
        testUser6         True      False 10-27-2021 7:27:43 PM     0.02
        testUser7         True      False 11-05-2021 8:34:55 AM     1.03
        testUser9         True      False 11-12-2021 3:17:10 PM      0.6
#>

param (
    [switch]$folderSize,

    [ValidateScript({Test-Path $_})]
    [String] $searchDir="",

    [ValidateScript({Test-Path $_})]
    [String]$saveFolder="",

    [ValidateSet(“Move”,”Remove”)]
    [String] $DeleteNoAccounts,

    [ValidateSet(“Move”,”Remove”)]
    [String] $DeleteOldAccounts,

    [ValidateScript({Test-Path $_})]
    [String] $MovePath='',

    [Int]$daysSinceLogin=60,

    [Array]$Exclude=@(),

    [ValidateScript({Test-Path $_})]
    [String]$logPath=''
)

Import-Module ActiveDirectory

$searchDir=$(get-aduser $env:username -Properties HomeDirectory).HomeDirectory -replace "$env:username"
$totalSize=0
$oldUser = @()
$Exclude += @("System.mdw","%USERNAME%")
$loopCount=0

#Removes or Moves user folder 
#Param $user: The custom object made in the main function
#Param $action: Derived from $DeleteNoUser or $deleteOldUser this specfies to remove or move
function Remove-Folder($user,$action){

    #Invoke-Command -ComputerName "ServerName" -scriptblock {Get-SmbOpenFile|Where-Object Path -like "PathToUserFolder"|Close-SmbOpenFile -Force}
    #move-Item "ServerPath" -Recurse -Force $searchDir\$i
    #Write-Warning -Message "You are able to (re)move folders, are you sure?" -WarningAction Inquire

    if($logPath -ne ''){
        Write-Output "$action : $($user.SamAccountName)" | Out-File $logPath\"UserShareAudit.log" -Append
    }

    if($action.ToLower() -eq "move"){
        Move-Item -Force $searchDir\$user.SamAccountName $MovePath -Confirm
    
    }elseif($action.ToLower() -eq "remove"){
        Remove-Item -Recurse -Force $searchDir\$user.SamAccountName -Confirm
    }
}

#Calculate the folder size of each users home folder
#Param: $user: The custom object made in the main function
function Get-FolderSize($user){

    if($logPath -ne ''){
        Write-Output "Calculating size : $($user.SamAccountName)" | Out-File $logPath\"UserShareAudit.log" -Append
    }

    $log=''
    $log=robocopy "$searchDir\$($user.SamAccountName)" NULL /L /S /NJH /BYTES /NC /NDL /XJ /R:0 /W:0 /MT:32 /NFL
    $Line = $log | Where-Object{$_ -match "^\s+Bytes.+"}
    $Line = $Line -split "\s+"
    
    $rtnValue = $($user | select-object -property *,@{n="Size/GB";e={$([math]::Round($Line[3]/1GB,2))}})
    return $rtnValue
}



$userShareList=$(get-childitem $searchDir)
$totalCount=$userShareList.count

#Loop through the list of users in the share and test for AD accounts if older than x days
#If -folderSize calculate the size of each users folder
foreach($i in $userShareList){
    Write-Progress -Activity "Searching: $searchDir$i" -PercentComplete $(($loopCount/$totalCount)*100)
        
    #Test for if folder and not excluded
    if($i.PSIsContainer -and $i.Name -notin $Exclude ){

        try{
            $user=$(Get-ADUser -Identity $i.Name -Properties "LastLogonDate" | Where-Object {($_.LastLogonDate -lt (Get-Date).AddDays(-$daysSinceLogin)) -and ($_.LastLogonDate -ne $NULL)})
            $user = $($user |select-object SamAccountName,Enabled,@{n="No Account";e={$false}},LastLogonDate)

        }catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
            $user = $(""|select-object @{n="SamAccountName";e={$i.Name}},@{n="Enabled";e={"N/A"}},@{n="No Account";e={$true}})
        }

        if($logPath -ne '' -and $user){
           Write-Output "User Found : $($user.SamAccountName)" | Out-File $logPath\"UserShareAudit.log" -Append 
        }

        if($folderSize -and $user){$user= Get-FolderSize $user; $totalSize+=$user."Size/GB"}

        $olduser+=$user
        $loopCount++
    }
}

if($saveFolder -notlike ""){

    if($logPath -ne ''){
        Write-Output "Saving Output" | Out-File $logPath\"UserShareAudit.log" -Append
    }

    if(!(test-path $saveFolder)){
        mkdir $saveFolder
    }
    $date=$(get-date -format "dd.MM.yyyy-HHmmss")
    if($folderSize){
        $olduser+=$(""|select-object -property @{n="SamAccountName";e={"Total Size"}},@{n="Size/GB";e={$totalSize}})
    }
    $oldUser | export-csv -NoTypeInformation "$saveFolder\UserShareAudit - $date.csv"
    
}else{
    $oldUser | Format-Table | Out-String | Write-Host
    if($folderSize){
        Write-Host("Total Size: $totalSize GB") -ForegroundColor Green
    }
        
}

#Verify MovePath is specfied when moving folders and follow through if correct
if($($DeleteNoAccounts.ToLower()) -like "move" -or $($DeleteOldAccounts.ToLower()) -like "move" -and $MovePath -eq ''){
    Write-Host "Specify -MovePath" -ForegroundColor Red
    Exit 1
}
if($DeleteNoAccounts -or $DeleteOldAccounts){
    foreach($user in $oldUser){
        if($DeleteNoAccounts -and $user."No Account" -eq $true){
            Remove-Folder $user $DeleteNoAccounts
        }
        if($DeleteOldAccounts -and $($user."No Account") -eq $false){
            Remove-Folder $user $DeleteOldAccounts
        }

    }
    
}