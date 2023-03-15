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

######################################

<< CONTENT

#!/bin/bash

# 配置用户名和密码
username="username"
password="password"

# 配置服务器IP列表

servers=(
"10.0.0.1"
"10.0.0.2"
"10.0.0.3"
)

# 创建脚本日志文件
log_file="$(dirname "$0")/script.log"
echo "" > "$log_file"

for server in "${servers[@]}"
do
  # 进行互信
  sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no "$username@$server"

  # 检查互信是否成功，并记录日志
  if [ "$?" -eq "0" ]
  then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 互信成功 - $server" >> "$log_file"
  else
    echo "$(date +'%Y-%m-%d %H:%M:%S') - 互信失败 - $server" >> "$log_file"
  fi
done

CONTENT
