# Audit-UserShare

Audit your users home directory.

## Purpose
    Quickly review your users roaming home directory and provide output to make decisions on the accounts and folders.

    This can be pointed at any directory with subdirectories with Active Directory SamAccountNames. 

## Usage
Audit-UserShare (-folderSize) (-DeleteNoAccounts [-MovePath]) (-DeleteOldAccounts [-MovePath]) (-daysSinceLogin) (-searchDir) (-Exclude) (logPath)

Parameter |Explanation 
----------|--------------
-folderSize| Calculates the folder sizes for the accounts found.
-DeleteNoAccounts| Removes the user folders found with no Active Directory accounts accosiated to them. [OPTIONS] Move, Remove
-DeleteOldAccounts| Removes the user folders who have not logged in within the time specifed with the -daysSinceLogin parameter. [OPTIONS] Move,Remove
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
    Audit-UserShare -deleteNoAccount -searchDir \\server\userFolder 
    Audit-UserShare -deleteOldAccount -searchDir \\server\userFolder


## Example of output:

    SamAccountName Enabled No Account
    -------------- ------- ----------
    TestUser1         True      False
    TestUser2         True      False
    TestUser3        False      False
    TestUser4        False      False
    TestUser5         True      False
    TestUser6         True      False
    TestUser7          N/A      True
    TestUser9         True      False

