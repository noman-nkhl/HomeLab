Write-Host "=== CURRENT DISK LAYOUT ===" -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used+$_.Free -gt 1GB } | ForEach-Object {
    Write-Host ("  {0}:  {1:N1} GB total, {2:N1} GB free" -f $_.Name, ($_.Used+$_.Free)/1GB, $_.Free/1GB)
}

Write-Host ""
Write-Host "Deleting D: partition and extending C:..." -ForegroundColor Yellow
@"
select disk 1
select partition 3
delete partition override
select partition 1
extend
"@ | diskpart

Write-Host ""
Write-Host "=== NEW DISK LAYOUT ===" -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used+$_.Free -gt 1GB } | ForEach-Object {
    Write-Host ("  {0}:  {1:N1} GB total, {2:N1} GB free" -f $_.Name, ($_.Used+$_.Free)/1GB, $_.Free/1GB)
}
Write-Host ""
Write-Host "Done." -ForegroundColor Green
