#
# Title : NoSleep
# Goal : Keep your computer awake by programmatically pressing the ScrollLock key every X seconds
# Owner : Abhi
# Version : 2.0    
# Changelog : 
# v1.0  :   Toggle Scroll Lock for every x Seconds
# v2.0  :   Script will now end after the end time
#           Proper messages of what is happening in the script
#

param($sleep = 120) # seconds
$announcementInterval = 1 # loops
# Clear the current screen
Clear-Host

$WShell = New-Object -com "Wscript.Shell"
$date = Get-Date -Format "dddd MM/dd HH:mm (K)"

$stopwatch
# Some environments don't support invocation of this method.
try {
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()
} catch {
   Write-Host "Couldn't start the stopwatch."
}

Write-Host "Executing ScrollLock-toggle NoSleep."
Write-Host "Start time:" $(Get-Date -Format "dddd MM/dd HH:mm (K)") -fore red

$index = 0
Write-Host "The default time is 5:00 PM." -fore green
$Hour = (Read-Host -Prompt 'Input your end time in 24H format greater than 0') -as [int]
if($Hour -isnot [int] -or ($Hour -eq 0)){
    Write-Host "`nYour input has to be a number greater than 0." -fore magenta
    Write-Host "`nSetting the default time as 5:00 PM." -fore green
    $Hour = 17
}else{
    Write-Host "Your end time is "$Hour":00" -fore green
}


$DateTimeNow = Get-Date
$DateTimeLogout = Get-Date -Hour $Hour -Minute 00      # by default Script will not run after 5:00 PM
if($DateTimeNow.TimeOfDay -lt $DateTimeLogout.TimeOfDay){
    Write-Host "Script started!!! Enjoy your time <3`n" -fore green
    Write-Host "Use Ctrl+c to exit the script."
    while ( $true )
    {
        $DateTimeNow = Get-Date
        if($DateTimeNow.TimeOfDay -lt $DateTimeLogout.TimeOfDay){
            $WShell.sendkeys("{SCROLLLOCK}")
            Start-Sleep -Seconds 1
            $WShell.sendkeys("{SCROLLLOCK}")
            Start-Sleep -Seconds $sleep
            # Announce runtime on an interval
            if ( $stopwatch.IsRunning -and (++$index % $announcementInterval) -eq 0 ){
                $Title = "I am AWAKE!!, Elapsed time: " + $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
                $host.UI.RawUI.WindowTitle = $Title
        }
        }else{
            Write-Host "Elapsed time: " + $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
            Write-Host "Script Complete!!!!"
            $host.UI.RawUI.WindowTitle = "Script Complete!!! Script is not currently active."
            Write-Host "`nTo close, press any key..."
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            exit
        }
    }
}
else{
        Write-Host "`n"$DateTimeNow
        Write-Host "`nThe end time has passed. Script ended." -fore yellow
        Write-Host "`nTo close, press any key..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit
    }
