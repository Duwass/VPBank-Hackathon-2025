#Install-Module -Name MsrcSecurityUpdates -Force
#Install-Module -Name kbupdate
Import-Module -Name kbupdate -Force
Import-Module -Name MsrcSecurityUpdates -Force

$osver = Get-ComputerInfo | Select-Object OSName
if($osver -match "server"){
    $fullos = $matches[0]
}else{
    $osver = $osver -replace '\D+'
    $osyear = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
    $fullos = "Windows " + $osver + " Version " + $osyear + " for x64-based Systems"
}

$date = Get-Date -UFormat "%Y-%b"

Remove-Item -LiteralPath "C:\temp" -Force -Recurse -ErrorAction SilentlyContinue
mkdir c:\temp\reports
$cvrfDoc = Get-MsrcCvrfDocument -ID $date -Verbose
$cvrfDoc | Get-MsrcSecurityBulletinHtml -Verbose | Out-File c:\temp\reports\"MSRC$($date)SecurityUpdates.html"
$productID = $cvrfDoc.ProductTree.FullProductName | Where-Object { $_.Value -eq $fullos } | Select-Object -ExpandProperty ProductID

$max = ($cvrfDoc.Vulnerability.Remediations | Where ProductID -EQ $productID | where FixedBuild -Match '\w+' |Measure-Object -Property Supercedence -Maximum).Maximum

$obj = $cvrfDoc.Vulnerability.Remediations | Where ProductID -EQ $productID | Where FixedBuild -Match '\w+' | Where Supercedence -EQ $max | Get-Unique

$url = $obj.URL 
$uri = [System.Uri]$url

$kbver = [System.Web.HttpUtility]::ParseQueryString($uri.Query).Get("q")
mkdir C:\temp\logs

Install-KbUpdate -HotfixId $kbver -ComputerName $env:computername | Out-File C:\tmp\logs\"log_update_$kbver.txt"

Get-KbNeededUpdate -ComputerName $env:computername | Install-KbUpdate |Out-File C:\tmp\logs\"log_update_needed.txt"

Get-WindowsUpdateLog -LogPath C:\temp\logs\WindowsUpdate.log

Restart-Computer