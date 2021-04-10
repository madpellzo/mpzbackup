#!/bin/sh

PRGDIR=`dirname "$0"`

. $PRGDIR/config.sh
. $PRGDIR/functions.sh

clear

echo "##################"
echo "#   SART CHECK   #"
echo "##################"

echo

# Check UPLOAD_METHOD paramter
echo "#####################"
echo "#   UPLOAD METHOD   #"
echo "#####################"

if [ $UPLOAD_METHOD ];then
	if [ $UPLOAD_METHOD != ssh ] && [ $UPLOAD_METHOD != ftp ];then
		echo "ERROR: Upload method $UPLOAD_METHOD does not exist"
		echo "Please check UPLOAD_METHOD variable in config.sh\n"
		exit 1
	else
		echo "SUCCESS: Upload method is $UPLOAD_METHOD\n"
	fi
else
	echo "No upload method, backups will not be uploaded\n"
fi

# Case ftp or ssh upload method

case $UPLOAD_METHOD in

# Check SSH parameters
ssh)
echo "#########################"
echo "#   SSH UPLOAD METHOD   #"
echo "#########################"

sshcheckcx -i $SSH_KEY -u $SSH_USER -h $SSH_HOST
if [ $? != 0 ];then
        echo "ERROR: SSH server $SSH_HOST unreachable"
        echo "Please check SSH connectivity with the SSH server\n"
	exit 1
else
	echo "SUCCESS: SSH connectivity with $SSH_HOST is OK\n"
fi

sshcheckdir -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -d $UPLOAD_DIR
if [ $? != 0 ];then
	echo "ERROR : $UPLOAD_DIR does not exist on $SSH_HOST"
	echo "Please check UPLOAD_DIR variable in config.sh or create directory on SSH server\n"
	exit 1
else
	echo "SUCCESS: backup directory exists on $SSH_HOST\n"
fi
;;

# Check FTP parameter
ftp)
echo "#########################"
echo "#   FTP UPLOAD METHOD   #"
echo "#########################"

ftpcheckcx -u $FTP_USER -P $FTP_PASSWD -h $FTP_HOST
if [ $? != 0 ];then
	echo "ERROR : FTP server $FTP_HOST unreachable"
	echo "Please check FTP connectivity with the FTP server\n"
	exit 1
else
	echo "FTP connectivity with $FTP_HOST is OK\n"
fi

ftpcheckdir -u $FTP_USER -P $FTP_PASSWD -h $FTP_HOST -d $UPLOAD_DIR
if [ $? != 0 ];then
	echo "ERROR : $UPLOAD_DIR does not exist on $FTP_HOST"
	echo "Please check UPLOAD_DIR variable in config.sh or create directory on FTP server\n"
	exit 1
else
	echo "SUCCESS: backup directory exists on $FTP_HOST\n"
fi
;;

esac

# Check TAR_DAY_MASTER

echo "######################"
echo "#   TAR DAY MASTER   #"
echo "######################"

if [ $TAR_DAY_MASTER ] && [ -z $(echo $TAR_DAY_MASTER | sed -e 's/[0-6]//g') ];then
	echo "SUCCESS: master TAR day will be $TAR_DAY_MASTER"
	echo "0 = sunday, 1 = monday ...\n"
else
	echo "ERROR: TAR_DAY_MASTER is not set, or TAR_DAY_MASTER is not a number between 0 and 6"
	echo "Please set a number between 0 and 6, 0 = sunday, 1 = monday ...\n"
	exit 1
fi

# Check ARCH_DIR parameter

echo "###############################"
echo "#   LOCAL ARCHIVE DIRECTORY   #"
echo "###############################"

checkdir $ARCH_DIR
if [ $? != 0 ]  || [ ! $ARCH_DIR ];then
        echo "ERROR : The archives directory does not exist or ARCH_DIR variable is empty\n"
        echo "Please check ARCH_DIR variable in config.sh\n"
        exit 1
else
	echo "SUCCESS: backup directory exists\n"
fi

# Check backup opwner if it is set

echo "#####################"
echo "#   BACKUPS OWNER   #"
echo "#####################"

if [ $BKP_OWNER ];then
	grep -q -e "^$BKP_OWNER:" /etc/passwd
	if [ $? != 0 ];then
		echo "WARNING: $BKP_OWNER does not exist. Backups owner will be root user"
		echo "Please check BKP_OWNER variable in config.sh or create $BKP_OWNER user\n"
	else
		echo "SUCCESS: $BKP_OWNER exists. Backups owner will be $BKP_OWNER\n"
	fi
else
	echo "SUCCESS: no BKP_OWNER set. Backups owner will be root user\n"
fi

# Check TTL parameter
echo "#############################"
echo "#       TTL PARAMETERS      #"
echo "#############################"

if [ $LOCAL_TTL ];then
	echo "Local backups TTL set to $LOCAL_TTL days"
	echo "Local backups older than $LOCAL_TTL days will be erased\n"
else
	echo "No local backup TTL" 
	echo "No local backup purge\n"
fi

if [ $UPLOAD_TTL ];then
        echo "Distant backups TTL set to $UPLOAD_TTL days"
        echo "Distant backups older than $UPLOAD_TTL days will be erased (ONLY for SSH upload method)\n"
else
        echo "No distant backup TTL"       
        echo "No distant backup purge\n"
fi


# Check TAR_DIR parameter

echo "#############################"
echo "#   DIRECTORIES TO BACKUP   #"
echo "#############################"

if [ '$TAR_DIR' ];then
for dirname in $TAR_DIR
do

checkdir $dirname
if [ $? != 0 ];then
        echo "WARNING : $dirname does not exist, no backup for this folder"
        echo "Please check TAR_DIR variable in config.sh\n"
else
	echo "SUCCESS: $dirname will be backupped\n"
fi

done
else
	echo "TAR_DIR is empty, no directories to backup\n"
fi

# Check ACL backup
echo "#######################"
echo "#      ACL BACKUP     #"
echo "#######################"

if [ $GET_DIR_ACL = "yes" ];then
	echo "ACL's backup directory will be saved\n"
else
	echo "No ACL backup directory to save\n"
fi

# Check MySQL databases
echo "#######################"
echo "#   MySQL DATABASES   #"
echo "#######################"

if [ "$MYSQL_DATABASES" ];then
	mysql -u ${MYSQL_USER} -p${MYSQL_PASSWD} -e 'show databases' 2>&1 > /dev/null
	if [ $? != 0 ];then
		echo "Database connection failed. Plase check databse parameters\n"
		exit 1
	else
		if [ "$MYSQL_DATABASES" = ALL ];then
			echo "All databases will be backupped:\n"	
			mysql -u ${MYSQL_USER} -p${MYSQL_PASSWD} -e 'show databases' | grep -v Database
		else
			for database in $MYSQL_DATABASES
			do
				mysql -u ${MYSQL_USER} -p${MYSQL_PASSWD} -e 'show databases' | grep -qE "^$database$"
				if [ $? != 0 ];then
					echo "WARNING: $database database does not exist!\n"
				else
					echo "SUCCESS: $database database will be backupped\n"
				fi
			done
		fi
	fi
else
	echo "No database to backup\n"
fi

echo "######################"
echo "#   E-MAIL REPORTS   #"
echo "######################"

MAILCMD=`which mail`
if [ $MAILCMD ];then
	echo "SUCCESS: mail command exists"
	echo "You will receive backup reports e-mail if \"$MAIL_REPORT_DEST\" is a valide e-mail address\n"
else
	echo "WARNING: mail command does not exist"
	echo "You will not receive backup reports e-mail even if \"$MAIL_REPORT_DEST\" is a valide e-mail address\n"
fi

echo "####################"
echo "#   END OF CHECK   #"
echo "####################"
