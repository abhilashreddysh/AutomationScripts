#
# -- NoSleep --
# Goal : Keep your computer awake by programmatically pressing the Scroll Lock key every X seconds
# Owner : Abhi
# Version : 2.3    
# Changelog : Script will now end after the logout time
#             Ask for Hour and Minutes to end the script
#             Skip Scroll Lock toggle if there is any mouse movement between the time interval


param($sleep = 120) # seconds
$announcementInterval = 2 # loops
# Clear the current screen
Clear-Host

$WShell = New-Object -com "Wscript.Shell"
# $date = Get-Date -Format "dddd MM/dd HH:mm (K)"

$stopwatch
# Some environments don't support invocation of this method.
try {
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()
} catch {
   Write-Host "Couldn't start the stopwatch."
}

Write-Host "Executing ScrollLock-toggle NoSleep  [Ver : 2.4]"
Write-Host "Start time:" $(Get-Date -Format "dddd MM/dd HH:mm (K)") -fore magenta

$index = 0
$Min = 00
Write-Host "`nInput your end time in 24H format greater than 0" -fore red
Write-Host "The default time is 6:00 PM.`n" -fore green
$Hour = (Read-Host -Prompt 'Hour') -as [int]
if($Hour -isnot [int] -or ($Hour -eq 0)){
    Write-Host "`nYour input has to be a number greater than 0." -fore red
    Write-Host "`nSetting the default time as 6:00 PM." -fore green
    $Hour = 18
}else{
    $Min = (Read-Host -Prompt 'Minutes') -as [int]
    if($Min -isnot [int] -or ($Min -eq 0)){
        Write-Host "`nYour input has to be a number greater than 0." -fore red
        Write-Host "`nSetting the default time as "$Hour":00 PM." -fore green
        $Min = 00
    }else{
        Write-Host "Your end time is "$Hour":"$Min"." -fore green
    }
}

Add-Type -AssemblyName System.Windows.Forms
$pos2 = [System.Windows.Forms.Cursor]::Position
$DateTimeNow = Get-Date
$DateTimeLogout = Get-Date -Hour $Hour -Minute $Min      # by default Script will not run after 5:00 PM
if($DateTimeNow.TimeOfDay -lt $DateTimeLogout.TimeOfDay){
    Write-Host "Script started!!! Enjoy your time <3" -fore green
    Write-Host "`nUse Ctrl+c to exit the script."
    
    while ( $true )
    {
        $pos1 = [System.Windows.Forms.Cursor]::Position
        $DateTimeNow = Get-Date
        if($DateTimeNow.TimeOfDay -lt $DateTimeLogout.TimeOfDay){  
            if($pos1.X -eq $pos2.X -and $pos1.Y -eq $pos2.Y) {
                $WShell.sendkeys("{SCROLLLOCK}")
                Start-Sleep -Milliseconds 10
                $WShell.sendkeys("{SCROLLLOCK}")
            }
            else {
                # pass
            }
            $pos2 = [System.Windows.Forms.Cursor]::Position
            Start-Sleep -Seconds $sleep
            
            # Announce runtime on an interval
            if ( $stopwatch.IsRunning -and (++$index % $announcementInterval) -eq 0 ){
                $Title = "I am ONLINE!!, Elapsed time: " + $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
                $host.UI.RawUI.WindowTitle = $Title
            }
        }else{
            Write-Host "Congratulations for completing the day." -fore green
            Write-Host "Elapsed time: " + $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
            $host.UI.RawUI.WindowTitle = "Day Complete!!! Script is not running now."
            exit
        }
    }
}
else{
        Write-Host "`n"$DateTimeNow
        Write-Host "`nHey, the hour has come. Don't pretend you are working :(`n`nYou are not needed to use this script; you may leave right away! :)" -fore yellow
        Write-Host "`nTo close, press any key..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit
    }
