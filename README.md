# s3ftp
Contains an enhanced version of the **s3ftp.install.sh** script as referenced within the popular CloudAcademy blog article: [S3 FTP: Build a Reliable and Inexpensive FTP Server Using Amazon’s S3](https://cloudacademy.com/blog/s3-ftp-server/).

Notable changes:
- SSL support
- Prompts at the start of the script to collect values for S3 bucket, region, ftp user and ftp password
- Using EC2 instance metadata to fetch the public IPv4 address
- All paths have been stored as variables
- More comments, for educational purpuses 

The **s3ftp.install.sh** script can be used to provision an [S3FS](https://github.com/s3fs-fuse/s3fs-fuse) FTP based setup.

![S3FS FTP CloudAcademy Blog](/doc/s3fs.blog.png)
