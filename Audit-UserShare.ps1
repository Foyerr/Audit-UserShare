<#
.SYNOPSIS
    Audit your user share to identify potentially unneeded folders.

.PARAMETER Remove
    Request to remove a group of users folders.
    [OPTIONS] “NoAccount”,”DisabledUser”,"Old"

.PARAMETER Move
    Request to move a group of users to another folder.
    [OPTIONS] “NoAccount”,”DisabledUser”,"Old"

.PARAMETER MovePath
    The value used when the Move option is specfied to provide the path to move the folder to.

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
    Audit-UserShare -daysSinceLogin 30 -Remove Old
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
    [String] $searchDir=$null,

    [ValidateScript({Test-Path $_})]
    [String]$saveFolder=$null,

    [ValidateSet(“NoAccount”,”DisabledUser”,"Old")]
    [String] $Move,

    [ValidateSet(“NoAccount”,”DisabledUser”,"Old")]
    [String] $Remove,

    [ValidateScript({Test-Path $_})]
    [String] $MovePath='',

    [Int]$daysSinceLogin=60,

    [Array]$Exclude=@(),

    [ValidateScript({Test-Path $_})]
    [String]$logPath=''

)

Import-Module ActiveDirectory

#Removes or Moves user folder 
#Param $user: The custom object made in the main function
#Param $action: Derived from $DeleteNoUser or $deleteOldUser this specfies to remove or move
function Remove-Folder{
    [cmdletbinding()]
    Param($oldUser)
    #Invoke-Command -ComputerName "ServerName" -scriptblock {Get-SmbOpenFile|Where-Object Path -like "PathToUserFolder"|Close-SmbOpenFile -Force}
    #move-Item "ServerPath" -Recurse -Force $searchDir\$i
    #Write-Warning -Message "You are able to (re)move folders, are you sure?" -WarningAction Inquire
    $loopCount=0
    if($Move){$action="move"; $Group=$Move}
    elseif($Remove){$action="remove";$Group=$Remove}

    foreach($i in $oldUser){
       foreach($user in $i){
            Write-Progress -Activity "$($user.SamAccountName)" -PercentComplete $(($loopCount/($oldUser.count))*100)
            if($Group -like "NoAccount" -and $user."No Account" -eq $false){continue}
            elseif($Group -like "DisabledUser" -and $user.Enabled -eq $true){continue}
            elseif($Group -like "Old" -and $user.LastLogonDate -like $null){continue}

            if($logPath){logToPath $logPath "$action : $($user.SamAccountName)"}
            #Invoke-Command -ComputerName $searchDir

            if($action -eq "move"){

                #Verify MovePath is specfied when moving folders and follow through if correct
                if($MovePath -eq ''){
                    Write-Error -Message "Specify -MovePath" -Category InvalidArgument
                    Exit 1
                }
            
                Move-Item -Force $user.dir $MovePath 
                #Write-Host("Moving $user.SamAccountName")

            }elseif($action -eq "remove"){

                #Get-ChildItem  $searchDir\$($user.SamAccountName) -Include * -Recurse | ForEach  { $_.Delete()} #| Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Get-ChildItem $user.dir -Include * -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            $loopCount+=1
        }
    }

}

#Calculate the folder size of each users home folder
#Param: $oldUser: The custom object made in the main function
function Get-FolderSize($oldUser){
    $totalSize=0
    $loopCount=0
    $totalCount=$oldUser.count
    $rtnValue = [System.Collections.Generic.List[object]]::new()

    
    foreach($i in $oldUser){
        foreach($user in $i){
            Write-Progress -Activity "Calculating size of : $($user.SamAccountName)" -PercentComplete $(($loopCount/$totalCount)*100)
            #$user
            if($logPath){logToPath $logPath "Calculating size : $($user.SamAccountName)"}

            $log=''
            $log=robocopy $user.dir NULL /L /S /NJH /BYTES /NC /NDL /XJ /R:0 /W:0 /MT:32 /NFL
            $Line = $log | Where-Object{$_ -match "^\s+Bytes.+"}
            $Line = $Line -split "\s+"

    
            $rtnValue.add($($user | select-object -property *,@{n="Size/GB";e={$([math]::Round($Line[3]/1GB,2))}}))
            $loopCount++
        }
    }
    
    return $rtnValue
}


# Takes in path to usershare and a date to compare to the last time the user logedin 
# Returns List of users that they not logged in since this date as well as users unable to be queried
function Get-OldUsers($searchDir,$queryDate){

    $oldUser = [System.Collections.Generic.List[object]]::new()

    $userShareList=$(get-childitem $searchDir)
    $totalCount=$userShareList.count

    $loopCount=0    
    

    #Loop through the list of users in the share and test for AD accounts if older than x days
    foreach($dir in $userShareList){
        Write-Progress -Activity "Searching : $searchDir$dir" -PercentComplete $(($loopCount/$totalCount)*100)
        
        #Test for if folder and not excluded
        if($dir.PSIsContainer -and ($dir.Name -notin $Exclude)){

            try{
                $user=$(Get-ADUser -Identity $dir.Name -Properties "LastLogonDate" | Where-Object {($_.LastLogonDate -lt $queryDate) -and ($NULL -ne $_.LastLogonDate)})
                $user = $($user |select-object SamAccountName,Enabled,LastLogonDate,@{n="Dir";e={$dir.fullname}})

            }catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{
                $user = $(""|select-object @{n="SamAccountName";e={$dir.Name}},@{n="Enabled";e={"N/A"}},@{n="LastLogonDate";e={""}},@{n="Dir";e={$dir.fullname}})
            }

            if($logPath -and $user){logToPath $logPath "User Found : $($user.SamAccountName)"}
            if($user){
                
                $olduser.add($user)
             }
            $loopCount++
        }
    }
    return($olduser)
}

function logToPath($logPath,$message){
        $date=$(get-date -format "dd.MM.yyyy-HHmmss")
        Write-Output "$date : $message" | Out-File $logPath\"UserShareAudit.log" -Append
}




## Main ##
#$oldUser = [System.Collections.Generic.List[object]]::new()

if(!$searchDir){
    $searchDir=($(get-aduser $env:username -Properties HomeDirectory).HomeDirectory -replace "$env:username")
}

$queryDate = (Get-Date).AddDays(-$daysSinceLogin)
$olduser = (Get-OldUsers $searchDir $queryDate)
 
# If -FolderSize is specfied, pass oldUser var and calculate the folder size
if($folderSize){$olduser = Get-FolderSize $oldUser}

# If move or remove, pass oldUser to Remove-Folder Function
if($Move -or $Remove){Remove-Folder $oldUser}

# If saveFolder if specfied, save the output to a CSV file
# else output to console
if($saveFolder){
    if($logPath){logToPath $logPath "Saving Output"}

    $date=$(get-date -format "dd.MM.yyyy-HHmmss")
    $oldUser | export-csv -NoTypeInformation "$saveFolder\UserShareAudit - $date.csv"

}else{
    $oldUser | ft      
}


