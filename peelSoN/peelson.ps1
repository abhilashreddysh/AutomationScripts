#
# -- NoSleep --
# Goal : Keep your computer awake by programmatically pressing the Scroll Lock key every X seconds
# Owner : Abhi
# Version : 3.0   
# Changelog : 
# Ver-2.4
# Script will now end after the logout time
# Ver-3.0
# Script will run anonymously and generate a bat file on desktop to kill it

Add-Type -AssemblyName System.Windows.Forms

#param([Parameter(Mandatory)] [int] $Hour,$Min, $sleep = 10) # seconds
param([int] $Hour,$Min, $sleep = 10) # seconds
$announcementInterval = 20 # loops
$date = (Get-Date).toString("dd_MM_yyyy")
$logdir = "C:\temp\peelSoN\logs"
$logFile = $logdir+"\peelslog_"+$date+".txt"
$WShell = New-Object -com "Wscript.Shell"
$global:balmsg = New-Object System.Windows.Forms.NotifyIcon
$path = (Get-Process -id $pid).Path

Clear-Host

if (!(Test-Path $logFile)) {
  New-Item -Force -Path $logFile -ItemType File
}

Function LogWrite
{
   param
    (
    [Parameter(Mandatory=$true)] [string] $Message
    )
   $TimeStamp = (Get-Date).toString("dd/MM/yyyy HH:mm:ss tt")
   $Line = "$TimeStamp - $Message"
   Add-content -Path $Logfile -Value $Line
}

$balmsg.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
$balmsg.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
$balmsg.Visible = $true

#$pidlog = $logdir+"\peelstaskpid.bat"
$pidlog = (Get-ItemProperty 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Desktop).Desktop+"\killpeel.bat"
$killcmd = "rem peels on self killer`n@echo off `ntaskkill /PID "+(Get-Process -id $pid).Id+" /F`n(goto) 2>nul & del `"`%~f0`""
if(Test-Path $pidlog){
    LogWrite "Killing old instance"
    cmd.exe /c $pidlog
    Clear-Host
}
$killcmd | Out-File $pidlog -Force -Encoding utf8
$pidlog = $logdir+"\peelstaskkiller.bat"
$killcmd | Out-File $pidlog -Force -Encoding utf8

Function ToastAlert{
    param
    (
    [Parameter(Mandatory=$true)] [string] $Message
    )
    $balmsg.BalloonTipText = $Message
    $balmsg.BalloonTipTitle = "[PON] Attention $Env:USERNAME"
    $balmsg.ShowBalloonTip(2000)
}

$temp = ""

$stopwatch
# Some environments don't support invocation of this method.
try {
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()
} catch {
   LogWrite  "Couldn't start the stopwatch."
}



LogWrite  "Start Time"

$index = 0
if($Hour -isnot [int] -or ($Hour -eq 0)){
    LogWrite  "Setting the default time as 6:00 PM." 
    $Hour = 18
}
if($Min -isnot [int] -or ($Min -eq 0)){
        $temp = "Setting the default time as "+$Hour+":00 PM."
        LogWrite   $temp
        $Min = 59
    }else{
        $temp = "Your end time is "+$Hour+":"+$Min 
        LogWrite $temp
    }


$pos2 = [System.Windows.Forms.Cursor]::Position
$DateTimeNow = Get-Date
$DateTimeLogout = Get-Date -Hour $Hour -Minute $Min      # by default Script will not run after 6:00 PM
if($DateTimeNow.TimeOfDay -lt $DateTimeLogout.TimeOfDay){
    LogWrite  "Script started now" 
    $temp = "`nPeels ON Script started now`nEnd Time : "+$Hour+" : "+$Min
    ToastAlert $temp
    
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
                $stopwatchtime =  $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
                LogWrite $stopwatchtime
            }
        }else{
            LogWrite  "End Time reached. Exiting" 
            $temp = "Elapsed time: " + $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
            LogWrite  $temp
            exit
        }
    }
}
else{
        LogWrite  "End Time Exceeded. Exiting the script." 
        exit
    }
