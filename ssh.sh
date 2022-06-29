!/bin/bash -e

### install sshpass
### export SSHPASS=YOUR_PASSWAORD

cd $(dirname $0)/..

IPS=("192.168.0.120" "192.168.0.238" "192.168.0.134" "192.168.0.122" "192.168.0.162" "192.168.0.159")

for ip in $IPS[*];  
do
  ssh-keygen -f "ssh/id_rsa_${ip}" -t rsa -N ''
  sshpass -e ssh-copy-id -o "StrictHostKeyChecking no" -i "ssh/id_rsa_${ip}" root@$ip -f 
  ssh -i ssh/id_rsa root@$ip <<'ENDSSH'
      sed -i 's/^PasswordAuthentication\s*yes$/PasswordAuthentication no/g' /etc/ssh/sshd_config
      service sshd restart
ENDSSH
done
