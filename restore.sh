#!/bin/bash

# Error-checking section
if [ "$#" -ne 2 ]
then
  echo "Usage Error: wprestore.sh backupfile.tar.gz destination"
  echo "A valid backup file and a destination store (dev, stag, prod) are required parameters"
  exit 1
fi

backupfile=$1
store=$2

if [ ${backupfile:0:4} != "prod" ] && [ ${backupfile:0:4} != "stag" ] && [ ${backupfile:0:3} != "dev" ]
then
	echo "Backup file specified doesn't appear to be valid"
	exit
fi

if [ ${backupfile: -7} != ".tar.gz" ]
then
	echo "Backup file specified is not a valid .tar.gz archive"
	exit
fi

if [ $store != "prod" ] && [ $store != "stag" ] && [ $store != "dev" ]
then
	echo "Store specified was not valid (must be dev, stag, or prod"
	exit
fi
# END: Error-checking section

# Read in config file
echo "Reading in config file"
source scripts_config.cfg

# Set up local variables
if [ $store == "dev" ]; then
	server_root=$dev_server_root
	server_folder=$dev_server_folder
	server_path=$dev_server_root$dev_server_folder
	folder_permissions=$dev_folder_permissions
	file_permissions=$dev_file_permissions
	owner_permissions=$dev_owner_permissions
	user=$dev_user
	host=$dev_host
	dest_url=$dev_url
	mysql_db=$dev_mysql_db
	mysql_user=$dev_mysql_user
	mysql_pass=$dev_mysql_pass
	wpcli_installed=$dev_wpcli_installed
	wp_user=$dev_wp_user
elif [ $store == "stag" ]; then
	server_root=$stag_server_root
	server_folder=$stag_server_folder
	server_path=$stag_server_root$stag_server_folder
	folder_permissions=$stag_folder_permissions
	file_permissions=$stag_file_permissions
	owner_permissions=$stag_owner_permissions
	user=$stag_user
	host=$stag_host
	dest_url=$stag_url
	mysql_db=$stag_mysql_db
	mysql_user=$stag_mysql_user
	mysql_pass=$stag_mysql_pass
	wpcli_installed=$stag_wpcli_installed
	wp_user=$stag_wp_user
elif [ $store == "prod" ]; then
	server_root=$prod_server_root
	server_folder=$prod_server_folder
	server_path=$prod_server_root$prod_server_folder
	folder_permissions=$prod_folder_permissions
	file_permissions=$prod_file_permissions
	owner_permissions=$prod_owner_permissions
	user=$prod_user
	host=$prod_host
	dest_url=$prod_url
	mysql_db=$prod_mysql_db
	mysql_user=$prod_mysql_user
	mysql_pass=$prod_mysql_pass
	wpcli_installed=$prod_wpcli_installed
	wp_user=$prod_wp_user
fi

if [ ${backupfile:0:4} == "prod" ]; then
	source_url=$prod_url
elif [ ${backupfile:0:4} == "stag" ]; then
	source_url=$stag_url
elif [ ${backupfile:0:3} == "dev" ]; then
	source_url=$dev_url
fi

# Send files to web server
if [ $project_type == "wordpress" ] && [ $wpcli_installed == false ]; then
	scp $backupfile wp-cli.phar $user@$host:$server_root
elif [ $project_type == "drupal" ]; then
	scp $backupfile $user@$host:$server_root
else
	scp $backupfile $user@$host:$server_root
fi
echo "Files sent to webserver"

ssh $user@$host "
cd $server_root

if [ -d $server_folder ]; then
	rm -rf $server_folder/*
	echo 'Emptied existing web folder'
else
	mkdir $server_folder
	echo 'Cerated new web folder'
fi

nice -n 19 tar xzf $backupfile -C $server_folder
echo 'File restore done'

chmod $folder_permissions $server_folder
find $server_folder -type f -exec chmod $file_permissions {} +
find $server_folder -type d -exec chmod $folder_permissions {} +
chown -R $owner_permissions $server_folder
echo 'Permissions updated'

nice -n 19 zcat -f $server_folder/db-backup.sql.gz | mysql -u $mysql_user -p$mysql_pass $mysql_db
echo 'Database restore done'

if [ $project_type == 'wordpress' ]; then
	cp wp-cli.phar $server_folder/wp-cli.phar
	cd $server_folder
	touch wp-cli.yml
	echo 'user: $wp_user
core config:
	dbuser: $mysql_user
	dbpass: $mysql_pass
apache_modules:
	 - mod_rewrite' >> wp-cli.yml
	if [ $wpcli_installed == true ]; then
		wp cache flush
		wp search-replace $source_url $dest_url
		wp rewrite flush --hard
	else
		php wp-cli.phar cache flush
		php wp-cli.phar search-replace $source_url $dest_url
		php wp-cli.phar rewrite flush --hard
	fi
elif [ $project_type == 'wordpress2' ]; then
	cp wp-cli.phar $server_folder/wp-cli.phar
	cp wp-cli.yml $server_folder/wp-cli.yml
	cd $server_folder
	if [ $wpcli_installed == true ]; then
		wp cache flush
		wp search-replace $source_url $dest_url
		wp rewrite flush --hard
	else
		echo $source_url $dest_url
		php wp-cli.phar cache flush
		php wp-cli.phar search-replace $source_url $dest_url
		php wp-cli.phar rewrite flush --hard
	fi
fi
cd ..

rm $backupfile
if [ $project_type == 'wordpress' ]; then
	rm wp-cli.*
	rm $server_folder/wp-cli.*
fi
rm $server_folder/db-backup.sql.gz
echo 'temp files removed'
"

echo "Restore Complete."