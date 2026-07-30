Import-Module ActiveDirectory

#Configuration
$Domain = "EastCharmer.local"
$CSVPath = "C:\users.csv"
$LogFile = "C:\CreationLogs.txt"

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
    
        [string]$FirstName,
        [string]$Lastname,
        [string]$SamAccountName,
        [string]$Department,
        [string]$Password


    )

    if(
        [string]::IsNullOrWhiteSpace($FirstName)-or
        [string]::IsNullOrWhiteSpace($Lastname)-or
        [string]::IsNullOrWhiteSpace($SamAccountName)-or
        [string]::IsNullOrWhiteSpace($Department)-or
        [string]::IsNullOrWhiteSpace($Password)

    )
    {

        return $false

    }

    return $true

}#Function to verify Department
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
    
        [string]$SamAccountName

    )

    $User = Get-ADUser `
        -Filter "SamAccountName -eq '$SamAccountName'" `
        -ErrorAction SilentlyContinue


    return $User

}

#Function To verify if Manager Exists
function Test-manager
{

    param(
    
        [string]$Manager

    )

    if([string]::IsNullOrWhiteSpace($Manager))
    {
    
        return $null

    }

    $ManagerObject = Get-ADUser `
        -Identity $Manager `
        -ErrorAction SilentlyContinue

    return $ManagerObject

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
            -Message "$SamAccountName added to Group $Group" `
            -Status "SUCCESS"
            
    }
    else
    {
    
        Write-Host "Group '$Group' not found." -ForegroundColor Yellow

        Write-Log `
            -Message "$Group not found." `
            -Status "WARNING"

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

#Processing Each User

foreach ($User in $Users)
{
    #Setting Manager Value to null
    $ManagerObject = $null

    
    

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
    $Password       = $User.Password
    $EmployeeID     = $User.EmployeeID
    $Office         = $User.Office
    $Manager        = $User.Manager

    #Validate Mandatory Fields

    if(
    
        -not (Test-MandatoryFields `
            -FirstName $FirstName `
            -Lastname $LastName `
            -SamAccountName $SamAccountName `
            -Department $Department `
            -Password $Password)

    )
    {
    
        Write-Host "Mandatory Fields are Missing." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName -Missing Mandatory Fields" `
            -Status "FAILED"

        $SkippedCount++

        continue
    
    }

    #Validate Department
    $DepartmentInfo = Test-Department `
        -Department $Department `
        -DepartmentConfig $DepartmentConfig

    if(-not $DepartmentInfo)
    {
    
        Write-Host "Department '$Department' is not configured." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Invalid Department" `
            -Status "FAILED"

        $SkippedCount++

        continue
            
    
    }

    #Select OU and Group
    $OU = $DepartmentInfo.OU
    $Group = $DepartmentInfo.Group

    
    #Check if user already exist
    $ExistingUser = Test-ExistingUser `
        -SamAccountName $SamAccountName

    if($ExistingUser)
    {
    
        Write-Host "$SamAccountName already exists." -ForegroundColor Yellow

        Write-Log `
            -Message "$SamAccountName already exist" `
            -Status "FAILED"

        $SkippedCount++

        continue

    }

    #Convert Password to secure

    $SecurePassword = ConvertTo-SecureString `
        $Password `
        -AsPlainText `
        -Force
    

    #Generate Values
    $DisplayName = "$FirstName $LastName"
    $UserPrincipalName = "$SamAccountName@$Domain"
    $EmailAddress = "$SamAccountName@$Domain"

    #Verify the manager exist.

    $ManagerObject = Test-manager `
        -Manager $Manager

    if($Manager -and -not $ManagerObject)
    {
    
        Write-Host "Manager '$Manager' not found." -ForegroundColor Red

        Write-Log `
            -Message "$SamAccountName - Invalid Manager" `
            -Status "FAILED"

        $SkippedCount++

        continue
            

    }


    #Create new user

    try{
    
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


        #Add manager if exist
        Set-UserManager `
            -SamAccountName $SamAccountName `
            -ManagerObject $ManagerObject

        #Verify User Creation
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
                -Message "$SamAccountName created successfully" `
                -Status "SUCCESS"
                
        
        }


        #Calling Group Addition Function
        Add-UserToGroup `
            -Group $Group `
            -SamAccountName $SamAccountName
        
        $CreatedCount++
    
    }
    catch
    {
    
        Write-Host ""
        Write-Host "User Creation Failed." -ForegroundColor Red
        Write-Host $_.Exception.Message

        Write-Log `
            -Message "$SamAccountName - $($_.Exception.Message)" `
            -Status "FAILED"

        $FailedCount++

    }


   
}

Show-ProvisioningSummary `
    -CreatedCount $CreatedCount `
    -SkippedCount $SkippedCount `
    -FailedCount $FailedCount














