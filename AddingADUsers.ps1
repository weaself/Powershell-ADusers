################################
#Adding new users to the domain#
#Author-Adrian Wisla           #
################################



Try
{
    Import-Module ActiveDirectory -ErrorAction Stop
}
Catch
{
    Write-Host "[ERROR]`t ActiveDirectory Module could not be loaded. Script will stop!"
    Exit 1
}

################################
# STATIC VARIABLES TO USE
################################
$path = Split-Path -Parent $MyInvocation.MyCommand.Definition
$newpath = $path + "\import_create_ad_users.csv"
$log = $path + "\create_ad_users.log"
$date = Get-Date
$addn = (Get-ADDomain).DistinguishedName
$dnsroot = (Get-ADDomain).DNSRoot
$i = 1

###############################
# START FUNCTIONS
###############################

Function Start-Commands
{
    Create-Users
}

Function Create-Users
{
    "Processing started (on " + $date + "): " | Out-File $log -Append
    "-------------------------------------------" | Out-File $log -Append
    Import-CSV $newpath | ForEach-Object {
        If (($_.Implement.ToLower()) -eq "yes")  # Not sure what Implement is!
        {
            If (($_.GivenName -eq "") -Or ($_.Initials -eq "")) # How does the CSV Object see the entries?
            {
                Write-Host "
                [ERROR]`t Please provide valid GivenName, LastName and Initials. Processing skipped for line $(i$)`r`n" # pay attention to the line bit!
                
                "[ERROR]`t Please provide valid GivenName, LastName and Initials. Processing skipped for line $($i)`r`n"`
                | Out-File $log -append

            }
            Else
            {
            # Set the target OU
            $location = $_.TargetOU + ",$($addn)"

            # Set the Enabled and PasswordNeverExpires properties
            If (($_.Enabled.ToLower()) -eq "true") { $enabled = $true } 
            Else { $enabled = $false } # Enabled field in the CSV!
            If (($_.PassWordNeverExpires.ToLower()) -eq "true") { $expires = $true } 
            Else {$expires = $false }

            # A check for the country, because those were full names and need
            # land codes in order for AD to accept them.
            If($_.Country -eq "Netherlands") { $_.Country = "NL" }
            Else { $_.Country = "EN" }

            # Replace dots(.) in names, because AD will error when a name ends with a dot
            $replace = $_.Lastname.Replace(".","")
            If($replace.length -lt 4)  { $lastname = $replace }
            Else { $lastname = $replace.substring(0,4) }

            # Create samaccountname (win 200 logon name, up to 20 chars)
            # <FirstFourLettersLastname><Name initials>

            $sam = $_.Initials.substring(0,1).ToLower() + $lastname.ToLower()
            Try { $exists = Get-ADUser -LDAPFilter "(sAMAccountName=$sam)" }
            Catch {}
            If(!$exists)
            {
            # Set all variables according to the table names in the Excel sheet CSV.
            $setpass = ConvertTo-SecureString -AsPlainText $_.Password -force # or just give the password

            Try
            {
                Write-Host "[INFO]`t Creating user: $($sam)" | out-file $log -append # adding info to log
                New-ADUser $sam -GivenName $_.GivenName -Initials $_Initials `
                -Surname $_.LastName -DisplayName ($_.LastName + "," + $_.Initials + " " + $_.GivenName) `
                -profilepath $_.Profilepath -HomeDirectory $_.HomeDirectory 

                Write-Host "[INFO]`t Created new user: $($sam)"
                "[INFO]`t Created new user: $($sam)" | Out-File $log -append
            
            }
            Catch
            {
                Write-Host "[ERROR]`t Ooops, something went wrong: $($_.Exception.Message)`r`n"
            }
        Else
        {
          Write-Host "[SKIP]`t User $($sam) ($($_.GivenName) $($_.LastName)) already exists or returned an error!`r`n"
          "[SKIP]`t User $($sam) ($($_.GivenName) $($_.LastName)) already exists or returned an error!" | Out-File $log -append
        }

            }
        }
    
    }

}
}
Write-Host "STARTED SCRIPT`r`n"
Start-Commands
Write-Host "STOPPED SCRIPT"