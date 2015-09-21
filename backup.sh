#!/bin/bash

# Error-checking section
if [ "$#" -ne 1 ]
then
  echo "Usage Error: wprestore.sh destination"
  echo "A destination store (dev, stag, prod) is a required parameter"
  exit 1
fi

store=$1

if [ $store != "prod" ] && [ $store != "stag" ] && [ $store != "dev" ]
then
	echo "Store specified was not valid (must be dev, stag, or prod"
	exit
fi
# END: Error-checking section

# Data collection section
# Read in config file
echo "Reading in config file"
source wpscripts_config.cfg

# Set up local variables
if [ $store == "dev" ]; then
	url=$dev_url
	server_root=$dev_server_root
	server_folder=$dev_server_folder
	server_path=$dev_server_root$dev_server_folder
	user=$dev_user
	host=$dev_host
	mysql_db=$dev_mysql_db
	mysql_user=$dev_mysql_user
	mysql_pass=$dev_mysql_pass
elif [ $store == "stag" ]; then
	url=$stag_url
	server_root=$stag_server_root
	server_folder=$stag_server_folder
	server_path=$stag_server_root$prod_server_folder
	user=$stag_user
	host=$stag_host
	mysql_db=$stag_mysql_db
	mysql_user=$stag_mysql_user
	mysql_pass=$stag_mysql_pass
elif [ $store == "prod" ]; then
	url=$prod_url
	server_root=$prod_server_root
	server_folder=$prod_server_folder
	server_path=$prod_server_root$prod_server_folder
	user=$prod_user
	host=$prod_host
	mysql_db=$prod_mysql_db
	mysql_user=$prod_mysql_user
	mysql_pass=$prod_mysql_pass
fi
# END: Data collection section

backup_file_name=$store-$project_short_name-backup-$(date +%Y%m%d%H%M%S).tar.gz

# Remote Server work section
ssh $user@$host "
cd $server_path

mysqldump -u $mysql_user -p$mysql_pass $mysql_db | nice -n 19 gzip -f > db-backup.sql.gz
echo 'Database backup done'

tar czvf ../$backup_file_name *
echo 'File backup done'
cd ..

cp $backup_file_name $server_path/$backup_file_name
rm $backup_file_name
rm $server_path/db-backup.sql.gz
echo 'File backup copied to web root'
"
# END Remote Server work section

# Transfer backup file
if [ "$(uname)" == "Darwin" ]; then
    curl -O $url/$backup_file_name    
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    wget $url/$backup_file_name
fi

ssh $user@$host "
cd $server_path
rm $backup_file_name
echo 'Removed backup file from web root'
"

echo "Backup Complete..."