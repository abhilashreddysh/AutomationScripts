# To generate config file
f = open('./config.py', 'w+')
gmailUser = input("Enter the sender's Email : ")
gmailPassword = input("Enter the sender's Password : ")
recipient = input("Enter the recipient's Email : ")
services_to_be_monitered = list(map(str, input("What services should be monitered [Ex: sshd smbd]: ").strip().split()))
print("Generating config file....")
output = f'''gmailUser = '{gmailUser}'
gmailPassword = '{gmailPassword}'
recipient = '{recipient}'
services_to_be_monitered = {services_to_be_monitered}
'''
f.write(output)
f.close()
# To generate config file
f = open('./config.py', 'w+')
gmailUser = input("Enter the sender's Email : ")
gmailPassword = input("Enter the sender's Password : ")
recipient = input("Enter the recipient's Email : ")
services_to_be_monitered = list(map(str, input("What services should be monitered [Ex: sshd smbd]: ").strip().split()))
print("Generating config file....")
output = f'''gmailUser = '{gmailUser}'
gmailPassword = '{gmailPassword}'
recipient = '{recipient}'
services_to_be_monitered = {services_to_be_monitered}
'''
f.write(output)
f.close()