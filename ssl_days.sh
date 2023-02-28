#!/bin/bash
#当前日期时间
now_dates=`date`

#当天的时间戳
now_times=`date +%s -d "${now_dates}"`

for names_ssl in  `cat domain_list.txt`
do
output=`echo | openssl s_client -servername ${names_ssl} -connect ${names_ssl}:443 2>/dev/null | openssl x509 -noout -dates`

after_times=`echo ${output} | awk -F '=' '{print $3}' `

#域名证书最后截止日期时间戳
date_times=`date +%s -d "${after_times}"`
#域名的到期时间
normal_times=`date -d @${date_times}`
normal_times_02=`date -d @${date_times} +"%Y-%m-%d %H:%M:%S"`

#得到域名证书的剩余天数
get_shijianchuo=`echo ${date_times}-${now_times} | bc`
last_days=`echo $((${get_shijianchuo}/86400))`
#输出
echo "域名 ${names_ssl}    到期时间: $normal_times_02 剩余天数:${last_days}" 
done
