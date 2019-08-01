#!/bin/bash +x

rancher_version=2.2.6

ALI_DOCKER_USERNAME=$ALI_DOCKER_USERNAME
ALI_DOCKER_PASSWORD=$ALI_DOCKER_PASSWORD
REGISTRY=registry.cn-shanghai.aliyuncs.com
docker login --username=${ALI_DOCKER_USERNAME}  -p${ALI_DOCKER_PASSWORD} ${REGISTRY}

repo=rancher/rancher

echo '定义rancher版本'

version=$( curl -s https://api.github.com/repos/$repo/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 | grep -v ^0. | grep -v ^1. )

echo  '下载helm'

curl -LSs -O https://storage.googleapis.com/kubernetes-helm/helm-`curl https://api.github.com/repos/helm/helm/releases/latest | jq .tag_name -r`-linux-amd64.tar.gz 

tar -zxf helm*.tar.gz 

cd linux-amd64

chmod +x helm 
./helm  init --client-only
./helm  repo update
./helm  fetch stable/cert-manager

mv cert-manager-*.tgz cert-manager.tgz

echo '下载RKE'

echo '小于0.2'
rke1_ver=0.1.18
curl -LSs -o rke-$rke1_ver https://github.com/rancher/rke/releases/download/v$rke1_ver/rke_linux-amd64 
chmod +x ./rke-$rke1_ver

echo '大于0.2'
rke2_ver=0.2.6
curl -LSs -o rke-$rke2_ver https://github.com/rancher/rke/releases/download/v$rke2_ver/rke_linux-amd64 
chmod +x ./rke-$rke2_ver

echo 'RKE IMAGES1'
./rke-$rke1_ver config --system-images --all | grep -v 'time=' >> ./rke1-images.txt
./helm template ./cert-manager.tgz | grep -oP '(?<=image: ").*(?=")' >> ./rke1-images.txt
echo busybox >> ./rke1-images.txt

echo 'RKE IMAGES2'
./rke-$rke2_ver config --system-images --all | grep -v 'time=' >> ./rke2-images.txt
./helm template ./cert-manager.tgz | grep -oP '(?<=image: ").*(?=")' >> ./rke2-images.txt
echo busybox >> ./rke2-images.txt

rm -rf *.tgz

if [[ `expr $rancher_version \> 2.2.0` -gt 0 ]] || [[ `expr $rancher_version = 2.2.0` -gt 0 ]]; then
	echo 'RKE IMAGES2'

    curl -LSs https://github.com/$repo/releases/download/v${rancher_version}/rancher-images.txt > rancher-images.txt
    cat rke2-images.txt >> rancher-images.txt
    sort -u rancher-images.txt -o rancher-images.txt

else
	echo 'RKE IMAGES1'

    curl -LSs https://github.com/$repo/releases/download/v${rancher_version}/rancher-images.txt > rancher-images.txt
    cat rke1-images.txt >> rancher-images.txt
    sort -u rancher-images.txt -o rancher-images.txt

fi

ls
mkdir -p images

for i in $(cat rancher-images.txt); 
do
	docker pull ${i}
	
	docker save ${i} > images/$(echo $i | sed "s#/#-#g; s#:#-#g").tgz

done
ls

cp ../Dockerfile .


docker build -t registry.cn-shanghai.aliyuncs.com/rancher/offlin-image-package:v$rancher_version .

docker push registry.cn-shanghai.aliyuncs.com/rancher/offlin-image-package:v$rancher_version