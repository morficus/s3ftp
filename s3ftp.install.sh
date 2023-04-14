#!/usr/bin/env bash

echo "
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Cheap SFTP on AWS setup script
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

Before proceeding, make sure you have crated an IAM Policy that grants EC2 access to the proper S3 bucket.
This policy must be attached to your EC2 instnace BEFORE proceeding, othersie s3fs will not be able to mount S3.

You can reerence 'Step 2' in this tutorial for help on that: https://cloudacademy.com/blog/s3-ftp-server/

------------------

If that precondition is already met, then please answer the following four questions to proceed:

"

echo "(1/4) What is the name of an S3 bucket that should be used?"
read S3_BUCKET_NAME

echo "(2/4) What region is it in?"
read S3_BUCKET_REGION

echo "(3/4) What username should be used to access the FTP service?"
read FTP_USERNAME

echo "(4/4) And now a password for that user"
read FTP_PASSWORD

VSFTPD_SSL_PATH=/etc/vsftpd/vsftpd.pem
VSFTPD_CONFIG_PATH=/etc/vsftpd/vsftpd.conf
VSFTPD_USER_LIST=/etc/vsftpd.userlist

# this "magic IP" is an AWS thing: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html
EC2_META_URL_BASE=http://169.254.169.254/latest
EC2_META_URL_TOKEN=$EC2_META_URL_BASE/api/token
EC2_META_URL_IAM_CREDS=$EC2_META_URL_BASE/meta-data/iam/security-credentials/
EC2_META__URL_PUBLIC_IPV4=$EC2_META_URL_BASE/meta-data/public-ipv4
# create an auth token that is valid for 5 minutes
EC2_META_AUTH_TOKEN=`curl -X PUT "$EC2_META_URL_TOKEN" -H "X-aws-ec2-metadata-token-ttl-seconds: 300"`
#get the current EC2 isntances public IP address
EC2_PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $EC2_META_AUTH_TOKEN" -s $EC2_META__URL_PUBLIC_IPV4`

# =========================

sudo yum -y update

echo "=-=-=-=-=-=-="
echo "Installing s3fs"
echo "=-=-=-=-=-=-="

sudo yum -y install \
jq \
automake \
openssl-devel \
git \
gcc \
libstdc++-devel \
gcc-c++ \
fuse \
fuse-devel \
curl-devel \
libxml2-devel \
openssl-devel \
libcurl-devel \
libxml2-devel

# =========================

git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/

./autogen.sh
./configure --with-openssl

make
sudo make install

echo "=-=-=-=-=-=-="
echo "Done installing s3fs"
echo "=-=-=-=-=-=-="

# =========================

echo "=-=-=-=-=-=-="
echo "Creating ftp user"
echo "=-=-=-=-=-=-="

# create the system user account that will own and access the FTP service
sudo adduser $FTP_USERNAME
echo "$FTP_USERNAME:$FTP_PASSWORD" | sudo chpasswd

# =========================

sudo mkdir /home/$FTP_USERNAME/ftp
sudo chown nfsnobody:nfsnobody /home/$FTP_USERNAME/ftp
sudo chmod a-w /home/$FTP_USERNAME/ftp
sudo mkdir /home/$FTP_USERNAME/ftp/files
sudo chown $FTP_USERNAME:$FTP_USERNAME /home/$FTP_USERNAME/ftp/files


echo "=-=-=-=-=-=-="
echo "Done creating ftp user"
echo "=-=-=-=-=-=-="

# =========================

echo "=-=-=-=-=-=-="
echo "Installing and configuring vsftpd"
echo "=-=-=-=-=-=-="


sudo yum -y install vsftpd
sudo mv $VSFTPD_CONFIG_PATH $VSFTPD_CONFIG_PATH.bak

# generate certification to SFTP encryption
sudo openssl req -x509 -days 365 -newkey rsa:2048 -nodes \
-subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
-keyout $VSFTPD_SSL_PATH -out $VSFTPD_SSL_PATH



sudo bash -c "cat > $VSFTPD_CONFIG_PATH << EOF
anonymous_enable=NO
listen_ipv6=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
chroot_local_user=YES
listen=YES
pam_service_name=vsftpd
tcp_wrappers=YES
user_sub_token=\$USER
local_root=/home/\$USER/ftp
pasv_min_port=40000
pasv_max_port=50000
pasv_address=$EC2_PUBLIC_IP
userlist_file=$VSFTPD_USER_LIST
userlist_enable=YES
userlist_deny=NO

ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH

rsa_cert_file=$VSFTPD_SSL_PATH
rsa_private_key_file=$VSFTPD_SSL_PATH
EOF"

sudo cat $VSFTPD_CONFIG_PATH

echo "=-=-=-=-=-=-="
echo "Done installing and configuring vsftpd"
echo "=-=-=-=-=-=-="

# =========================

echo $FTP_USERNAME | sudo tee -a $VSFTPD_USER_LIST

# =========================

sudo systemctl start vsftpd
sudo systemctl status vsftpd

echo "=-=-=-=-=-=-="
echo "vsftpd should now be running"
echo "=-=-=-=-=-=-="

# =========================


echo "=-=-=-=-=-=-="
echo "Setting up s3fs"
echo "=-=-=-=-=-=-="

EC2_ROLE=`curl -H "X-aws-ec2-metadata-token: $EC2_META_AUTH_TOKEN" -s $EC2_META_URL_IAM_CREDS`
echo "EC2ROLE: $EC2_ROLE"
sudo /usr/local/bin/s3fs $S3_BUCKET_NAME \
-o use_cache=/tmp,iam_role="$EC2_ROLE",allow_other /home/$FTP_USERNAME/ftp/files \
-o url="https://s3.$S3_BUCKET_REGION.amazonaws.com" \
-o nonempty

echo "=-=-=-=-=-=-="
echo "Done setting up s3fs"
echo "=-=-=-=-=-=-="

# =========================

ps -ef | grep  s3fs

# =========================

echo All done! Have fun using FTP on the cheap 🎊
