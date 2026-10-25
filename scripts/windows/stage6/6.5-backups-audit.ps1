# Этап 6.5: аудит доступа к каталогу резервных копий C:\Backups
function Run($c) { Write-Host "PS> $c" -ForegroundColor Yellow; Invoke-Expression $c | Out-Host }
. Run 'auditpol /set /subcategory:"{0CCE921D-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable'
. Run '$acl = Get-Acl C:\Backups -Audit'
. Run '$everyone = New-Object System.Security.Principal.SecurityIdentifier("S-1-1-0")'
. Run '$rights = [System.Security.AccessControl.FileSystemRights]"ReadData, WriteData, Delete"'
. Run '$rule = New-Object System.Security.AccessControl.FileSystemAuditRule($everyone, $rights, "ContainerInherit,ObjectInherit", "None", "Success,Failure")'
. Run '$acl.AddAuditRule($rule)'
. Run 'Set-Acl C:\Backups $acl'
. Run '(Get-Acl C:\Backups -Audit).Audit | Format-Table IdentityReference, FileSystemRights, AuditFlags -AutoSize'
. Run 'icacls C:\Backups /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F"'
. Run 'icacls C:\Backups'
