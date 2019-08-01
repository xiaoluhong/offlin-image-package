#!/bin/bash -x 
# 定义日志
ALI_DOCKER_USERNAME=$ALI_DOCKER_USERNAME
ALI_DOCKER_PASSWORD=$ALI_DOCKER_PASSWORD
REGISTRY=registry.cn-shanghai.aliyuncs.com

docker login --username=${ALI_DOCKER_USERNAME}  -p${ALI_DOCKER_PASSWORD} ${REGISTRY}

rancher_version=2.2.7

repo=rancher/rancher
# 定义rancher 版本
version=$( curl -s https://api.github.com/repos/$repo/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 | grep -v ^0. | grep -v ^1. )
# 下载helm
curl -LSs -O https://storage.googleapis.com/kubernetes-helm/helm-`curl https://api.github.com/repos/helm/helm/releases/latest | jq .tag_name -r`-linux-amd64.tar.gz 
tar -zxf helm*.tar.gz 
cd linux-amd64
chmod +x helm 
./helm  init --client-only
./helm  repo update
./helm  fetch stable/cert-manager
mv cert-manager-*.tgz cert-manager.tgz

# 下载RKE

## 小于0.2
rke1_ver=$( curl -s https://api.github.com/repos/rancher/rke/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | awk -F"." '{arr[$1"."$2]=$3}END{for(var in arr){if(arr[var]==""){print var}else{print var"."arr[var]}}}' | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3  | grep -v 0.2 )
curl -LSs -o /tmp/rke-$rke1_ver  https://github.com/rancher/rke/releases/download/v$rke1_ver/rke_linux-amd64 
chmod +x /tmp/rke-$rke1_ver

## 大于0.2
rke2_ver=$( curl -s https://api.github.com/repos/rancher/rke/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | awk -F"." '{arr[$1"."$2]=$3}END{for(var in arr){if(arr[var]==""){print var}else{print var"."arr[var]}}}' | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3  | grep -v 0.1 )
curl -LSs -o /tmp/rke-$rke2_ver https://github.com/rancher/rke/releases/download/v$rke2_ver/rke_linux-amd64 
chmod +x /tmp/rke-$rke2_ver

# RKE IMAGES
/tmp/rke-$rke1_ver config --system-images --all | grep -v 'time=' >> ./rke1-images.txt
./helm template ./cert-manager.tgz | grep -oP '(?<=image: ").*(?=")' >> ./rke1-images.txt
echo busybox >> ./rke1-images.txt

/tmp/rke-$rke2_ver config --system-images --all | grep -v 'time=' >> ./rke2-images.txt
./helm template ./cert-manager.tgz | grep -oP '(?<=image: ").*(?=")' >> ./rke2-images.txt
echo busybox >> ./rke2-images.txt

if [[ `expr $rancher_version \> 2.2.0` -gt 0 ]] || [[ `expr $rancher_version = 2.2.0` -gt 0 ]]; then

    curl -LSs https://github.com/$repo/releases/download/v${rancher_version}/rancher-images.txt > rancher-images.txt
    cat rke2-images.txt >> rancher-images.txt
    sort -u rancher-images.txt -o rancher-images.txt

else
    curl -LSs https://github.com/$repo/releases/download/v${rancher_version}/rancher-images.txt > rancher-images.txt
    cat rke1-images.txt >> rancher-images.txt
    sort -u rancher-images.txt -o rancher-images.txt

fi
ls
for i in $(cat rancher-images.txt); 
do
	docker pull ${i}
	
	docker save ${i} > $(echo $i | sed "s#/#-#g; s#:#-#g").tgz

done

cp ../Dockerfile .

docker build -t registry.cn-shanghai.aliyuncs.com/rancher/offlin-image-package:v$rancher_version .

docker push registry.cn-shanghai.aliyuncs.com/rancher/offlin-image-package:v$rancher_version