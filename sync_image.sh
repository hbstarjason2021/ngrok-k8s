#! /bin/bash	
	
docker_repo="k8smirror" # your docker hub username or organization name	
registry="gcr.io" # the registry of original image, e.g. gcr.io, quay.io	
repo="google_containers" # the repository name of original image	
	
sync_one(){	
  docker pull ${registry}/${repo}/${1}:${2}	
  docker tag ${registry}/${repo}/${1}:${2} docker.io/${docker_repo}/${1}:${2}	
  docker push docker.io/${docker_repo}/${1}:${2}	
  docker rmi -f ${registry}/${repo}/${1}:${2} docker.io/${docker_repo}/${1}:${2}	
}	
	
sync_all_tags() {	
  for image in $*; do	
    tags_str=`curl https://${registry}/v2/${repo}/$image/tags/list | jq '.tags' -c | sed 's/\[/\(/g' | sed 's/\]/\)/g' | sed 's/,/ /g'`	
    echo "$image $tags_str"	
    src="	
sync_one(){	
  docker pull ${registry}/${repo}/\${1}:\${2}	
  docker tag ${registry}/${repo}/\${1}:\${2} docker.io/${docker_repo}/\${1}:\${2}	
  docker push docker.io/${docker_repo}/\${1}:\${2}	
  docker rmi -f ${registry}/${repo}/\${1}:\${2} docker.io/${docker_repo}/\${1}:\${2}	
}	
tags=${tags_str}	
echo \"$image ${tags_str}\"	
for tag in \${tags[@]}	
do	
  sync_one $image \${tag}	
done;"	
    bash -c "$src"	
  done 	
}	
	
sync_with_tags(){	
  image=$1	
  skip=1	
  for tag in $*; do	
    if [ $skip -eq 1 ]; then	
	  skip=0	
    else	
      sync_one $image $tag	
	fi	
  done 	
}	
	
sync_after_tag(){	
  image=$1	
  start_tag=$2	
  tags_str=`curl https://${registry}/v2/${repo}/$image/tags/list | jq '.tags' -c | sed 's/\[/\(/g' | sed 's/\]/\)/g' | sed 's/,/ /g'`	
  echo "$image $tags_str"	
  src="	
sync_one(){	
  docker pull ${registry}/${repo}/\${1}:\${2}	
  docker tag ${registry}/${repo}/\${1}:\${2} docker.io/${docker_repo}/\${1}:\${2}	
  docker push docker.io/${docker_repo}/\${1}:\${2}	
  docker rmi -f ${registry}/${repo}/\${1}:\${2} docker.io/${docker_repo}/\${1}:\${2}	
}	
tags=${tags_str}	
start=0	
for tag in \${tags[@]}; do	
  if [ \$start -eq 1 ]; then	
    sync_one $image \$tag	
  elif [ \$tag == '$start_tag' ]; then	
    start=1	
  fi	
done"	
  bash -c "$src"	
}	
	
get_tags(){	
  image=$1	
  curl https://${registry}/v2/${repo}/$image/tags/list | jq '.tags' -c	
}	
	
#sync_with_tags etcd 2.0.12 2.0.13 # sync etcd:2.0.12 and etcd:2.0.13	
#sync_after_tag etcd 2.0.8 # sync tag after etcd:2.0.8	
#sync_all_tags etcd hyperkube # sync all tags of etcd and hyperkube
