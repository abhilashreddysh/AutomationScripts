# Service Status
import subprocess,config
# Add/Remove services which should be monitered in config.py
services = config.services_to_be_monitered 

output = ''' 
<p>Service Status : </p>

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
        output += f'''<tr style="border: 1px solid black">
            <th style="border: 1px solid black">{service}</th>
            <th style="border: 1px solid black;background-color:green;">{servicestatus}</th>
        </tr>'''
    else:
        output += f'''<tr style="border: 1px solid black">
            <th style="border: 1px solid black">{service}</th>
            <th style="border: 1px solid black;background-color:red;">{servicestatus}</th>
        </tr>'''
