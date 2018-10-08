#!/bin/bash
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sleep 10s
export username=`cat /tmp/docker_username.txt`
export password=`cat /tmp/docker_password.txt`
export image=`cat /tmp/docker_image_name.txt`
export version=`cat /tmp/docker_image_version.txt`
echo "Logging into your Docker Repository"
sudo docker login -u$username -p$password
echo "Pulling the Image from your Docker Repository"
sudo docker pull $image:$version
echo "Running your Docker Image"
sudo docker run -p 80:80 -p 8080:8080 -itd $image:$version
sudo docker exec `sudo docker ps | awk {'print $1'} | tail -1` bash /tmp/start.sh