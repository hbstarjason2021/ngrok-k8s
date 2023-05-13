#! /bin/bash

while true
do
    value=$(date '+%H')
    if [ $value -eq 00 ]
    then 
       echo "It is 8AM now, stop curl"
       break
    else
       curl -X GET https://www.baidu.com
       sleep 2
    fi
done


#####
for i in $(seq 1 100) 
do
     curl 10.105.65.45:80 >> /root/curl.log
done

#####
