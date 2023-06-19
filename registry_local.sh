####

sudo dnf update -y
sudo dnf install -y yum-utils
sudo yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf update -y
sudo dnf repolist
sudo dnf remove -y podman buildah
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo docker version
sudo docker info

#### 

HOST=registry
DOMAIN=example.local

sudo firewall-cmd --add-port=5000/tcp --permanent
sudo firewall-cmd --reload

sudo dnf install -y httpd-tools

sudo mkdir -p /opt/registry/{auth,certs,data}

sudo htpasswd -bBc /opt/registry/auth/htpasswd admin admin

sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/$HOST.$DOMAIN.key -subj "/C=US/ST=California/L=Irvine/O=Ingram Micro Inc./CN=*.$DOMAIN" -x509 -addext "subjectAltName=DNS:$DOMAIN,DNS:$HOST.$DOMAIN" -days 365 -out /opt/registry/certs/$HOST.$DOMAIN.crt

sudo cp /opt/registry/certs/$HOST.$DOMAIN.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
sudo trust list | grep -i $DOMAIN

#### 
HOST=registry
DOMAIN=example.local

sudo systemctl restart docker
sudo docker rm -fv $(docker ps -aq)

sudo docker run --name myregistry -p 5000:5000 \
 -v /opt/registry/data:/var/lib/registry:z \
 -v /opt/registry/auth:/auth:z \
 -e REGISTRY_AUTH=htpasswd \
 -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
 -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
 -v /opt/registry/certs:/certs:z \
 -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/$HOST.$DOMAIN.crt \
 -e REGISTRY_HTTP_TLS_KEY=/certs/$HOST.$DOMAIN.key \
 -e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
 -d docker.io/library/registry:latest

sudo sleep 5
sudo curl -u admin:admin -k https://$HOST.$DOMAIN:5000/v2/_catalog
sudo openssl s_client -connect $HOST.$DOMAIN:5000 -showcerts </dev/null 2>/dev/null|openssl x509 -outform PEM > myregistry-ca.crt
## kubectl create configmap myregistry-ca -n openshift-config --from-file=$HOST.$DOMAIN..5000=myregistry-ca.crt
