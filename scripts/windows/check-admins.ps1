# check-admins.ps1 — проверка членства в группе администраторов домена (Domain Admins)
# и в локальной группе Администраторы. Запускается при входе в систему (раздел реестра Run).
$Allowed = @("Administrator", "admin")
$Log     = "C:\Scripts\Logs\check-admins.log"
$Stamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Domain Admins читаем через ADSI — не нужен модуль ActiveDirectory (RSAT)
$Group   = [ADSI]"LDAP://CN=Domain Admins,CN=Users,DC=gerber,DC=org"
$Members = @($Group.member) | ForEach-Object { ([ADSI]"LDAP://$_").Properties["sAMAccountName"][0] }
$Extra   = $Members | Where-Object { $_ -notin $Allowed }

if ($Extra) {
    "$Stamp ВНИМАНИЕ: посторонние члены Domain Admins: $($Extra -join ', ')" | Add-Content $Log -Encoding UTF8
} else {
    "$Stamp OK: Domain Admins = $($Members -join ', ')" | Add-Content $Log -Encoding UTF8
}

# Локальная группа Администраторы по SID S-1-5-32-544 (не зависит от языка Windows)
$LocalAdmins = Get-LocalGroupMember -SID "S-1-5-32-544" | Select-Object -ExpandProperty Name
"$Stamp Локальные администраторы: $($LocalAdmins -join ', ')" | Add-Content $Log -Encoding UTF8
