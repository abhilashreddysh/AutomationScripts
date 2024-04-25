import smtplib,subprocess
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

gmailUser = '<senders_mail_here>'
gmailPassword = '<password_here>'
recipient = '<recipients_mail_list>'

osname=subprocess.check_output('cat /etc/*release | grep "PRETTY_NAME" | cut -d "=" -f 2- | xargs',shell=True,text=True)
servername=subprocess.check_output('hostname -f',shell=True,text=True)
uptime=subprocess.check_output('uptime -p',shell=True,text=True)
# diskinfo=subprocess.check_output('df -H -x zfs -x squashfs -x tmpfs -x devtmpfs -x overlay --output=target,pcent,used,size',shell=True,text=True)

# Service Status

# Add/Remove services which should be monitered
services = ['smbd','nginx','sshd','deluged','deluge-web']

table_skel = ''' 
    <table style="border: 1px solid black">
      <tr style="border: 1px solid black">
        <th style="border: 1px solid black">Service</th>
        <th style="border: 1px solid black">Status</th>
      </tr>
      '''

for service in services:
    servicestatus=subprocess.check_output(f'systemctl show -p SubState --value {service}',shell=True,text=True).strip()
    # print(f'{service}:{servicestatus}')
    if servicestatus == 'running':
        table_skel += f'''<tr style="border: 1px solid black">
            <th style="border: 1px solid black">{service}</th>
            <th style="border: 1px solid black;color:green;">{servicestatus}</th>
        </tr>'''
    else:
        table_skel += f'''<tr style="border: 1px solid black">
            <th style="border: 1px solid black">{service}</th>
            <th style="border: 1px solid black;color:red;">{servicestatus}</th>
        </tr>'''


# Email Body
message = f"""
<h1><i><b>{servername}</b></i></h1>
<p>OS : {osname}</p>
<p>Uptime : {uptime}</p>
<p>Service Status : </p>
{table_skel}
"""

msg = MIMEMultipart()
msg['From'] = f'"Hound" <{gmailUser}>'
msg['To'] = recipient
msg['Subject'] = "[Hound] Status Update"
msg.attach(MIMEText(message,'html','utf-8'))

try:
    mailServer = smtplib.SMTP('smtp.gmail.com', 587)
    mailServer.ehlo()
    mailServer.starttls()
    mailServer.ehlo()
    mailServer.login(gmailUser, gmailPassword)
    mailServer.sendmail(gmailUser, recipient, msg.as_string())
    mailServer.close()
    print ('Email sent!')
except:
    print ('Something went wrong...!!!')
