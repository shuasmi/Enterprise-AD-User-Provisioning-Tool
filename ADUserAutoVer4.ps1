Import-Module ActiveDirectory

#Configuration
$Domain = "EastCharmer.local"
$CSVPath = "C:\AD Automation Project\users.csv"
$LogFile = "C:\AD Automation Project\CreationLogs.txt"



#Department Configuration

$DepartmentConfig = @{

    IT = @{
    
        OU = "OU=IT,OU=Europe,DC=EastCharmer,DC=local"

        Group = "IT Users"
    
    }

    HR = @{
    
        OU = "OU=HR,OU=Europe,DC=EastCharmer,DC=local"

        Group = "HR Users"
    
    }

    Finance = @{
    
        OU = "OU=Finance,OU=Europe,DC=EastCharmer,DC=local"

        Group = "Finance Users"

    }

   

}


#Logging Function

function Write-Log {

    param(
    
        [string]$Message,
        [string]$Status
    
    )

    $Time = Get-Date -Format "dd-MM-yyyy HH:mm:ss"

    $Entry = "$Time | $Status | $Message"

    Add-Content -Path $LogFile -Value $Entry
    

}

#Function TestMandatoryFields
function Test-MandatoryFields
{

    
    param(
    
        $User

    )

    $RequiredFields = @(
    
        "FirstName"
        "LastName"
        "SamAccountName"
        "Department"
        "Title"
        "EmployeeID"
        "Office"
        "Manager"

    )

    $MissingFields = @()

    foreach ($Field in $RequiredFields)
    {
    
        if ([string]::IsNullOrWhiteSpace($User.$Field))
        {
        
            $MissingFields += $Field

        }

    }
    
    return $MissingFields
}

#Function to verify Department
function Test-Department
{

    param(
    
        [string]$Department,
        [hashtable]$DepartmentConfig

    )

    if(-not $DepartmentConfig.ContainsKey($Department))
    {
    
        return $null

    }

    return $DepartmentConfig[$Department]

}

#Function To verify if user already exist.
function Test-ExistingUser
{

    param(
    
        [string]$SamAccountName,
        [string]$UserPrincipalName,
        [string]$EmployeeID

    )

    $User = Get-ADUser `
        -Filter "SamAccountName -eq '$SamAccountName' -or UserPrincipalName -eq '$UserPrincipalName' -or EmployeeID -eq '$EmployeeID'" `
        -Properties UserPrincipalName, EmployeeID `
        -ErrorAction SilentlyContinue

    if(-not $User)
    {
    
        return $null

    }

    foreach($us in $User)
    {
    
        if($us.SamAccountName -eq $SamAccountName)
        {
        
            return [PSCustomObject]@{
            
                ConflictType = "SamAccountName"
                ConflictValue = $SamAccountName
                ExistingUser = $us

            }

        }

        if($us.UserPrincipalName -eq $UserPrincipalName)
        {
        
            return [PSCustomObject]@{
            
                ConflictType = "UserPrincipalName"
                ConflictValue = $UserPrincipalName
                ExistingUser = $us


            }

        }

        if($us.EmployeeID -eq $EmployeeID)
        {
        
            return [PSCustomObject]@{
            
                ConflictType = "EmployeeID"
                ConflictValue = $EmployeeID
                ExistingUser = $us

            }

        }

    }
       


    return $null

}

#Function To verify if Manager Exists
function Test-manager
{

    param(
    
        [string]$Manager

    )

    $Manager = $Manager.Trim()

    try {
        $ManagerObject = Get-ADUser `
            -Identity $Manager `
            -ErrorAction Stop

        return [PSCustomObject]@{
            IsValid = $true
            Manager = $Manager
            User = $ManagerObject
        }
    }
    catch {
        return [PSCustomObject]@{
            IsValid = $false
            Manager = $Manager
            User = $null
        }
    }

}

#Function To Create New ADUser
function New-CompanyADUser
{

    param(
    
        [string]$DisplayName,
        [string]$FirstName,
        [string]$LastName,
        [string]$SamAccountName,
        [string]$UserPrincipalName,
        [string]$Department,
        [string]$Title,
        [string]$EmployeeID,
        [string]$Office,
        [string]$EmailAddress,
        [string]$OU,
        [SecureString]$SecurePassword

    )

    New-ADUser `
        -Name $DisplayName `
        -GivenName $FirstName `
        -Surname $LastName `
        -DisplayName $DisplayName `
        -SamAccountName $SamAccountName `
        -UserPrincipalName $UserPrincipalName `
        -Department $Department `
        -Title $Title `
        -EmployeeID $EmployeeID `
        -Office $Office `
        -EmailAddress $EmailAddress `
        -Path $OU `
        -AccountPassword $SecurePassword `
        -Enabled $true `
        -ChangePasswordAtLogon $true `
        -ErrorAction Stop

}

#Function To Add User in Group
function Add-UserToGroup
{

    param(
    
        [string]$Group,
        [string]$SamAccountName

    )

    

    $ADGroup = Get-ADGroup `
        -Identity $Group `
        -ErrorAction SilentlyContinue

    if($ADGroup)
    {
        
        Add-ADGroupMember `
            -Identity $Group `
            -Members $SamAccountName `
            -ErrorAction stop

        Write-Host "Added to Group : $Group" -ForegroundColor Green

        Write-Log `
            -Message "$SamAccountName - Group Assignment - Successful : $Group" `
            -Status "SUCCESS"
            
        return $true
    }
    else
    {
    
        Write-Host "Group '$Group' not found." -ForegroundColor Yellow

        Write-Log `
            -Message "$SamAccountName - Group Assignment - Warning : $Group not found" `
            -Status "WARNING"

        return $false

    }


}

#Function for Display Provisioning
function Show-ProvisioningSummary
{

    param(
    
        [int]$CreatedCount,
        [int]$SkippedCount,
        [int]$FailedCount

    )

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Provisioning Summary"
    Write-Host "=========================================" -ForegroundColor Cyan

    Write-Host "Users Created : $CreatedCount" -ForegroundColor Green
    Write-Host "Users Skipped : $SkippedCount" -ForegroundColor Yellow
    Write-Host "Users Failed  : $FailedCount" -ForegroundColor Red

    Write-Host "=========================================" -ForegroundColor Cyan

}

#Function for show User Info
function Show-UserInformation
{

    param(
    
        [string]$DisplayName,
        [string]$SamAccountName,
        [string]$Department,
        [string]$Title,
        [string]$Office,
        [string]$EmployeeID,
        [string]$EmailAddress


    )

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "User Created Successfully" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green

    Write-Host "Name         : $DisplayName"
    Write-Host "Username     : $SamAccountName"
    Write-Host "Department   : $Department"
    Write-Host "Title        : $Title"
    Write-Host "Office       : $Office"
    Write-Host "Employee ID  : $EmployeeID"
    Write-Host "Email        : $EmailAddress"

    Write-Host "=========================================" -ForegroundColor Green

}

#Function to set Manager

function Set-UserManager
{

    param(
    
        [string]$SamAccountName,
        $ManagerObject

    )

    

    if($ManagerObject)
    {
    
        Set-ADUser `
            -Identity $SamAccountName `
            -Manager $ManagerObject.DistinguishedName `
            -ErrorAction Stop

        
    }

}

#Function to verify user is created or not.

function Test-CreatedUser
{

    param(
    
        [string]$SamAccountName

    )

    

    $CreatedUser = Get-ADUser `
        -Identity $SamAccountName `
        -Properties Department,Title,Office,EmployeeID,EmailAddress `
        -ErrorAction SilentlyContinue

    return $CreatedUser
}

#Banner

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Enterprise AD User Provisioning Tool"
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

#Import CSV

$Users = Import-Csv $CSVPath

#Counters
$CreatedCount = 0
$FailedCount = 0
$SkippedCount = 0
$PartialCount = 0

#Processing Each User

foreach ($User in $Users)
{
    #Setting Manager Value to null
    $ManagerObject = $null

    #Intilaizing Result
    $ProvisioningResult = "COMPLETED"
    

    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Processing User: $($User.SamAccountName)"
    Write-Host "=========================================" -ForegroundColor Cyan

    # Read values from CSV
    $FirstName      = $User.FirstName
    $LastName       = $User.LastName
    $SamAccountName = $User.SamAccountName
    $Department     = $User.Department
    $Title          = $User.Title
    $EmployeeID     = $User.EmployeeID
    $Office         = $User.Office
    $Manager        = $User.Manager

    #Validate Mandatory Fields
    $MissingField = Test-MandatoryFields -User $User

    if($MissingField.Count -gt 0)
    {
    
        Write-Host "Mandatory Fields are Missing" -ForegroundColor Red

        Write-Log `
            -Message "'$SamAccountName' -Missing Mandatory Fields : $($MissingField -join ', ')" `
            -Status "WARNING"

        $SkippedCount++

        Write-Log `
            -Message "$SamAccountName - Overall Provisioning Result: SKIPPED" `
            -Status "WARNING"

        continue
    
    }

    

    #Validate Department
    $Department = $Department.Trim()
    $DepartmentInfo = Test-Department `
        -Department $Department `
        -DepartmentConfig $DepartmentConfig

    if(-not $DepartmentInfo)
    {
    
        Write-Host "Department '$Department' is not configured." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Invalid Department : $Department" `
            -Status "WARNING"

        $SkippedCount++

        Write-Log `
            -Message "$SamAccountName - Overall Provisioning Result: SKIPPED" `
            -Status "WARNING"


        continue
            
    
    }

    #Select OU and Group
    $OU = $DepartmentInfo.OU
    $Group = $DepartmentInfo.Group

    #Generate Values
    $DisplayName = "$FirstName $LastName"
    $UserPrincipalName = "$SamAccountName@$Domain"
    $EmailAddress = "$SamAccountName@$Domain"

    
    #Check if user already exist
    $ExistingUser = Test-ExistingUser `
        -SamAccountName $SamAccountName `
        -UserPrincipalName $UserPrincipalName `
        -EmployeeID $EmployeeID

    if($ExistingUser)
    {
        Write-Host `
            "$($ExistingUser.ConflictType) $($ExistingUser.ConflictValue) already exists." `
            -ForegroundColor Yellow

        Write-Log `
            -Message "$SamAccountName - $($ExistingUser.ConflictType) $($ExistingUser.ConflictValue) already exists" `
            -Status "WARNING"

        $SkippedCount++

        Write-Log `
            -Message "$SamAccountName - Overall Provisioning Result: SKIPPED" `
            -Status "WARNING"


        continue

    }

    #Convert Password to secure
   
    #$SecurePassword = ConvertTo-SecureString `
       # $Password `
        #-AsPlainText `
        #-Force
   
    



    #Verify the manager exist.

    $ManagerResult = Test-manager `
        -Manager $Manager

    if(-not $ManagerResult.IsValid)
    {
    
        Write-Host "Manager $Manager not found." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Invalid Manager : $Manager" `
            -Status "WARNING"

        $SkippedCount++

        Write-Log `
            -Message "$SamAccountName - Overall Provisioning Result: SKIPPED" `
            -Status "WARNING"

        Continue
            

    }

    $ManagerObject = $ManagerResult.User

     # Get temporary password securely

    $SecurePassword = Read-Host `
           "Enter temporary password for $SamAccountName" `
            -AsSecureString

    #Creation New User
    try
    {
    
        New-CompanyADUser `
            -DisplayName $DisplayName `
            -FirstName $FirstName `
            -LastName $LastName `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UserPrincipalName `
            -Department $Department `
            -Title $Title `
            -EmployeeID $EmployeeID `
            -Office $Office `
            -EmailAddress $EmailAddress `
            -OU $OU `
            -SecurePassword $SecurePassword

            #Incrementing User Creation Count
            $CreatedCount ++

            Write-Log `
                -Message "$SamAccountName - User Creation - Successful" `
                -Status "SUCCESS"
    }
    catch
    {
    
        Write-Host ""
        Write-Host "User Creation Failed." -ForegroundColor Red
        Write-Host $_.Exception.Message

        Write-Log `
            -Message "$SamAccountName - User Creation Failed : $($_.Exception.Message)" `
            -Status "FAILED"

        Write-Log `
            -Message "$SamAccountName - Overall Provisioning Result: FAILED" `
            -Status "FAILED"

        $FailedCount++

        continue

    }

    #Setting Manager
    try
    {
    
        Set-UserManager `
            -SamAccountName $SamAccountName `
            -ManagerObject $ManagerObject

        Write-Log `
            -Message "$SamAccountName - Manager Assignment - Successful" `
            -Status "SUCCESS"


    }
    catch
    {
    
        Write-Host "Manager Assignment Failed for $SamAccountName." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Manager Assignment - Failed : $($_.Exception.Message)" `
            -Status "FAILED"

        $ProvisioningResult = "PARTIAL"
        

    }

    #Add User to Group
    try
    {
    
        $GroupResult = Add-UserToGroup `
            -Group $Group `
            -SamAccountName $SamAccountName

        if(-not $GroupResult)
        {
        
            $ProvisioningResult = "PARTIAL"
            

        }


    }
    catch
    {
    
        Write-Host "User Group Addition Failed." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Group Assignment - Failed : $($_.Exception.Message)" `
            -Status "FAILED"

        $ProvisioningResult = "PARTIAL"
        

    }
   

    #Verify User Created Successfully
    try
    {
    
        $CreatedUser = Test-CreatedUser `
            -SamAccountName $SamAccountName

        if($CreatedUser)
        {
        
            Show-UserInformation `
                -DisplayName $DisplayName `
                -SamAccountName $SamAccountName `
                -Department $Department `
                -Title $Title `
                -Office $Office `
                -EmployeeID $EmployeeID `
                -EmailAddress $EmailAddress

            Write-Log `
                -Message "$SamAccountName - Verification - Successful" `
                -Status "SUCCESS"
                

        }
        else
        {
            throw "User Verification failed. User $SamAccountName could not found after creation"

        }

    }
    catch
    {
    
        Write-Host "User verification failed." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Verification - Failed : $($_.Exception.Message)" `
            -Status "FAILED"

        $ProvisioningResult = "PARTIAL"

    }


    #Final Result
    Write-Log `
    -Message "$SamAccountName - Overall Provisioning Result: $ProvisioningResult" `
    -Status $(if($ProvisioningResult -eq "COMPLETED"){"SUCCESS"}else{"WARNING"})

    if($ProvisioningResult -eq "PARTIAL")
    {
        $PartialCount++
    }

   
}

Show-ProvisioningSummary `
    -CreatedCount $CreatedCount `
    -SkippedCount $SkippedCount `
    -FailedCount $FailedCount





if($FailedCount -gt 0) {
    $RunStatus = "FAILED"
}
elseif($SkippedCount -gt 0 -or $PartialCount -gt 0) {
    $RunStatus = "WARNING"
}
else {
    $RunStatus = "SUCCESS"
}

Write-Log `
    -Message "Provisioning Run Summary | Created: $CreatedCount | Skipped: $SkippedCount | Failed: $FailedCount" `
    -Status $RunStatus














