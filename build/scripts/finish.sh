#!/bin/bash -e
cp ~/backup-files/passwd-s3fs /etc/passwd-s3fs
chmod 600 /etc/passwd-s3fs
cp ~/backup-files/* ~/the_hunting/backup-files/
cp ~/the_hunting/backup-files/s3fs.service /etc/systemd/system/s3fs.service
chmod 664 /etc/systemd/system/s3fs.service
systemctl daemon-reload
systemctl enable s3fs.service
apt update && apt upgrade -y
export S3_ENDPOINT=$(cat ./the_hunting/backup-files/s3-endpoint.txt)
export S3_BUCKET=$(cat ./the_hunting/backup-files/s3-bucket.txt)
