# Python built packages
import smtplib,os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Check for config file
isExist = os.path.exists('./config.py')

if(isExist):
    print("Config File found...Continue!")
else:
    print("Config file not found.Generate a config file...!! [Hint: Use generateConfig.py to generate config file]")
    exit()

# imports from this Package
import config,linuxHeader,serviceMoniter

# Email Body
message = f"""
{linuxHeader.output}
{serviceMoniter.output}
"""

msg = MIMEMultipart()
msg['Subject'] = "System Status Check"
msg['From'] = f'"{linuxHeader.servername}" <{config.gmailUser}>'
msg['To'] = config.recipient
msg.attach(MIMEText(message,'html','utf-8'))

try:
    mailServer = smtplib.SMTP('smtp.gmail.com', 587)
    mailServer.ehlo()
    mailServer.starttls()
    mailServer.ehlo()
    mailServer.login(config.gmailUser, config.gmailPassword)
    mailServer.sendmail(config.gmailUser, config.recipient, msg.as_string())
    mailServer.close()
    print ('Email sent!')
except:
    print ('Something went wrong...!!!')
