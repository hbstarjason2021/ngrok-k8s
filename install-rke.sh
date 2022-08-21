#!/usr/bin/env bash

RKE_VERSION="1.3.13"

echo "###########################################"
echo "Downloading rke package ${RKE_VERSION} from Rancher"
echo "###########################################"
echo " "

if [ -f /usr/local/bin/rke ]
then
echo "File is found, Skipping Download.."
echo "" 
else
   echo "File is not found! Downloading it with Wget from Rancher availabe releases"
   wget --no-check-certificate https://github.com/rancher/rke/releases/download/v${RKE_VERSION}/rke_linux-amd64
   echo -n "\o/"
   sleep 1.0
   echo -n "_o_"
   sleep 1.0
   echo -n "\o/"
   sleep 1.0
   echo -n "_o_"
   echo -e


   echo "#################################################"
   echo "Updating it name to rke .. giving it exec permission"
   echo "#################################################"
   echo " "

   echo "mv rke_linux_amd64 rke"
   mv rke_linux-amd64 rke
   echo "chmod +x rke"
   chmod +x rke
   echo ""


   echo "#################################################"
   echo "Moving rke to /usr/local/bin .. needs sudo passwd!"
   echo "#################################################"
   echo " "

   echo "sudo mv rke /usr/local/bin"
   sudo mv rke /usr/local/bin


   echo -n "\o/"
   sleep 1.0
   echo -n "_o_"
   sleep 1.0
   echo -n "\o/"
   sleep 2.0
   echo -n "_o_"
   echo ""
   echo -e "Rancher is installed.."
fi



echo "rke --version"
rke --version
