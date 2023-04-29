# _Automation Scripts_ 

_This repository is a collection of scripts to help in daily tasks._

## Table of Contents

1. [No Sleep](#no-sleep) - Keeps your computer awake
2. [Linux Status Mail](#linux-status-mail) - Send current linux machine status to mail.

***
### [No Sleep](https://github.com/abhilashreddysh/AutomationScripts/blob/main/noSleep.ps1)

Use this script to keep your computer awake by programmatically pressing the ScrollLock key every X seconds
  
How to use:
- Save the [script](https://github.com/abhilashreddysh/AutomationScripts/blob/main/noSleep.ps1) as .ps1 file
- Right click and run it in powershell
- Enter end hour in HH (24 hour format)
- Enter end Minute in MM

If no input is given the script by default sets the time to 6:00 PM (18:00)

The script will now run until the time entered is greater than the system time.

Note: Later versions are moved to seperate repository as it contains more files to manage.

***
### [Linux Status Mail](https://github.com/abhilashreddysh/AutomationScripts/blob/main/linuxStatusMail.py)

Script to get linux services update through mail.
Can be automated and scheduled to run in time intervals using crontab.

**Edit the script by adding the senders email,password and recipient's list before running the script.**
