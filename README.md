# Audit-UserShare

Audit your users home directory by finding folders that are no longer needed. 


## Purpose
    Quickly review your users roaming home directory and provide output to make decisions on the accounts and folders.

    This can be pointed at any directory with subdirectories with Active Directory SamAccountNames. 

## Usage
Parameter |Explanation 
----------|--------------
-folderSize| Calculates the folder sizes for the accounts found.
-Remove| Request to remove a group of users folders. [OPTIONS] “NoAccount”,”DisabledUser”,"Old"
-Move| Request to move a group of users to another folder. [OPTIONS] “NoAccount”,”DisabledUser”,"Old"
-MovePath| The value used when the Move option is specfied at the Delete parameters.
-daysSinceLogin| Looks for the users in the user share who haven't logged in the the past X days. [Default: 60 Days]
-searchDir| Specifes the directory to search in through. [Default: The running users home directory queried from AD]
-saveFolder| The folder inwhich you would like to save output to. If not specfied, it will be logged to the console.
-Exclude| Pass in any folder name seperated by a comma you would like to exclude from the search.
-logPath| Path to the log if required.


## Example of Usage:

### Locate old user, and nonexistant user who still have files stored on your fileserver:
    Audit-UserShare -searchDir \\server\userFolder 

### Calculate the folder sizes and deleted those that are nolonger needed:
    Audit-UserShare -folderSize -searchDir \\server\userFolder 
    Audit-UserShare -Move ”DisabledUser” -searchDir \\server\userFolder 
    Audit-UserShare -Remove NoAccount -searchDir \\server\userFolder


## Example of output:

    SamAccountName Enabled No Account LastLogonDate
    -------------- ------- ---------- -------------
    TestUser1         True      False 11-24-2021 9:08:03 AM
    TestUser1         True      False 11-10-2021 9:44:51 AM
    TestUser1         True      False 10-27-2021 7:27:43 PM
    TestUser1         True      False 11-22-2021 1:48:54 PM
    TestUser1        False      False 11-22-2021 6:25:20 AM
    TestUser1         True      False 12-09-2021 9:51:31 AM
    TestUser1        False      False 11-25-2021 10:34:46 AM
    TestUser1         True      False 11-05-2021 8:34:55 AM
    TestUser1        False      False 12-02-2021 1:00:17 PM
