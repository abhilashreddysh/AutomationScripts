
# peelSoN

Powershell script to prevent the system from going to sleep.


## Authors

- [@abhilashreddysh](https://www.github.com/abhilashreddysh)


## FAQ

#### How to setup ?

Save this folder with the name "peelSoN" in C:\temp and run the vbs script. You can also automate the task by setting up a task in task scheduler to run on every given interval.

#### How to stop the running session ?

Every time the task is executed, a bat file is created on the desktop as killpeel.bat
Double click this bat file to kill the session and turn off peelSoN.

#### Where are my logs stored ?

Logs are stored at C:\temp\peelSoN\logs
