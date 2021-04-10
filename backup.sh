#!/bin/sh

PRGDIR=`dirname "$0"`

. $PRGDIR/config.sh
. $PRGDIR/functions.sh

DAY_OF_WEEK=`date +%w`
DAY_TODAY=`date +%Y%m%d`
HOSTNAME=`hostname`

UPLOADCX="OK"

TEST_BKP_OWNER="OK"

# Define mail command
MAILCMD=`which mail`

MAILALERT=`mktemp /tmp/mpzbackup.XXXXXXXXXXXX` || exit 1

BKPABORT=`mktemp /tmp/mpzbackup.XXXXXXXXXXXX` || exit 1

# Check if archives directory exists
# Exit the program if not
# With error in mail report
checkdir $ARCH_DIR
if [ $? != 0 ]  || [ ! $ARCH_DIR ];then
	echo "The archives directory does not exist or or ARCH_DIR variable is empty\n" >> $BKPABORT
	echo "Please check ARCH_DIR variable in config.sh\n" >> $BKPABORT
	echo "Backup aborted" >> $BKPABORT
	if [ $MAILCMD ];then
		mail -s "CRITICAL : $HOSTNAME backup" $MAIL_REPORT_DEST < $BKPABORT
		rm $BKPABORT
	fi
	exit 1
fi

# Check TAR_DAY_MASTER
if [ ! $TAR_DAY_MASTER ] || [ ! -z $(echo $TAR_DAY_MASTER | sed -e 's/[0-6]//g') ];then
        echo "ERROR: TAR_DAY_MASTER is not set, or TAR_DAY_MASTER is not a number between 0 and 6" >> $BKPABORT
        echo "Please set a number between 0 and 6, 0 = sunday, 1 = monday ...\n" >> $BKPABORT
	echo "Backup aborted" >> $BKPABORT
	if [ $MAILCMD ];then
		mail -s "CRITICAL: $HOSTNAME backup" $MAIL_REPORT_DEST < $BKPABORT
		rm $BKPABORT
	fi
        exit 1
fi

# Check if report  directory exists
# Do not exit the program if not
# report directory will be ARCH_DIR if REPORT_DIR wrong or empty
checkdir $REPORT_DIR
if [ $? != 0 ] || [ -z $REPORT_DIR ];then
	REPORT_DIR=$ARCH_DIR
fi

# Set BKP_PREFIX if not set in config.sh
if [ -z $BKP_PREFIX ];then
	BKP_PREFIX=$HOSTNAME
fi


# Define report file name
BKP_REPORT=${REPORT_DIR}/${BKP_PREFIX}_backup-report.$DAY_TODAY.txt
[ ! -f $BKP_REPORT ] || rm -f $BKP_REPORT

if [ $UPLOAD_METHOD ];then
	if [ $UPLOAD_METHOD != ssh ] && [ $UPLOAD_METHOD != ftp ];then
 		echo "Upload method $UPLOAD_METHOD does not exist" >> ${BKP_REPORT}
 		echo "Please check UPLOAD_METHOD variable in config.sh\n" >> ${BKP_REPORT}
 		echo "WARNING" >> $MAILALERT
 		UPLOADCX="NOK"
	fi
else
	UPLOAD_METHOD="NOK"
	UPLOADCX="NOK"
fi


# Check backup owner
if [ $BKP_OWNER ];then
	grep -q -e "^$BKP_OWNER:" /etc/passwd
	if [ $? != 0 ];then
		echo "Backups owner: $BKP_OWNER does not exist" >> ${BKP_REPORT}
		echo "Please check BKP_OWNER variable in config.sh or create $BKP_OWNER user." >> ${BKP_REPORT}
		echo "Backup owner will be root user\n" >> ${BKP_REPORT}
		echo "WARNING" >> $MAILALERT
		TEST_BKP_OWNER="NOK"
	else
		echo "Backups owner will be $BKP_OWNER\n" >> ${BKP_REPORT}
	fi
else
	echo "No BKP_OWNER set. Backups owner will be root user\n" >> ${BKP_REPORT}
	TEST_BKP_OWNER="NOK"
fi


TAR_REPORT=${REPORT_DIR}/${BKP_PREFIX}_tar-report.$DAY_TODAY.txt
UPLOAD_REPORT=${REPORT_DIR}/${BKP_PREFIX}_upload-report.$DAY_TODAY.txt

echo "Upload method : $UPLOAD_METHOD\n" >> ${BKP_REPORT}

if [ "$MYSQL_DATABASES" ];then
	echo "MySQL dump : Yes\n" >> ${BKP_REPORT}
else
	echo "MySQL dump : No\n" >> ${BKP_REPORT}
fi

if [ $GET_DIR_ACL = "yes" ];then
	echo "Get directories ACL : Yes\n" >> ${BKP_REPORT}
else
	echo "Get directories ACL : No\n" >> ${BKP_REPORT}
fi

echo "Backup report : ${BKP_REPORT}\n" >> ${BKP_REPORT}
echo "Tar report : ${TAR_REPORT}\n" >> ${BKP_REPORT}
echo "Upload report : ${UPLOAD_REPORT}\n" >> ${BKP_REPORT}

if [ $UPLOAD_METHOD = "ftp" ] && [ $UPLOADCX = "OK" ];then
FTPCX="OK"
FTPDIR="OK"

	ftpcheckcx -u $FTP_USER -P $FTP_PASSWD -h $FTP_HOST
	if [ $? != 0 ];then
		echo "WARNING : FTP server $FTP_HOST unreachable" >> ${BKP_REPORT}
		echo "Please check FTP connectivity with the FTP server\n" >> ${BKP_REPORT}
		echo "-------------------------------------------------\n" >> ${BKP_REPORT}
		echo "WARNING" >> $MAILALERT
		FTPCX="NOK"
	fi
	
	if [ $FTPCX = "OK" ];then
		ftpcheckdir -u $FTP_USER -P $FTP_PASSWD -h $FTP_HOST -d $UPLOAD_DIR
		if [ $? != 0 ];then
			echo "WARNING : $UPLOAD_DIR does not exist on $FTP_HOST" >> ${BKP_REPORT}
			echo "Please check UPLOAD_DIR variable in config.sh or create directory on FTP server\n" >> ${BKP_REPORT}
			echo "-------------------------------------------------\n" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
			FTPDIR="NOK"
		fi
	fi
fi
	

if [ $UPLOAD_METHOD = "ssh" ] && [ $UPLOADCX = "OK" ];then
SSHCX="OK"
SSHDIR="OK"

# Check if SSH backup server is reachable
# Do not exit the program if not
# Write warning in mail report 
# Put SSHCK variable to NOK to avoid upload backup
sshcheckcx -i $SSH_KEY -u $SSH_USER -h $SSH_HOST
if [ $? != 0 ];then
        echo "WARNING : SSH server $SSH_HOST unreachable" >> ${BKP_REPORT}
        echo "Please check SSH connectivity with the SSH server\n" >> ${BKP_REPORT}
	echo "-------------------------------------------------\n" >> ${BKP_REPORT}
	echo "WARNING" >> $MAILALERT
        SSHCX="NOK"
fi

# If SSH connection is OK, check if backup directory exists on SSH server
# Do not exit the program if not
# Write warning in mail report
# Put SSHDIR variable to NOK to avoid upload backup
if [ $SSHCX = "OK" ];then
sshcheckdir -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -d $UPLOAD_DIR
	if [ $? != 0 ];then
        	echo "WARNING : $UPLOAD_DIR does not exist on $SSH_HOST" >> ${BKP_REPORT}
        	echo "Please check UPLOAD_DIR variable in config.sh or create directory on SSH server\n" >> ${BKP_REPORT}
		echo "-------------------------------------------------\n" >> ${BKP_REPORT}
		echo "WARNING" >> $MAILALERT
        	SSHDIR="NOK"
	fi
fi

fi

EXCLUSIONS=`mktemp /tmp/mpzbackup.XXXXXXXXXXXX` || exit 1
for exdir in $EXCLUDE_TAR_DIR
do
	echo "$exdir" >> $EXCLUSIONS
done


# Check if TAR_DIR is not empty
if [ "$TAR_DIR" ];then

echo "-------------------------------------------------" >> ${BKP_REPORT}
echo " DIRECTORIES BACKUP SECTION " >> ${BKP_REPORT}
echo "-------------------------------------------------\n" >> ${BKP_REPORT}

# For each directory to backup in TAR_DIR 
for dirname in $TAR_DIR

do

TAR_NAME=`nameformat $dirname`

CHK_TAR_DIR="OK"
checkdir $dirname
if [ $? != 0 ];then
	echo "WARNING : $dirname does not exist" >> ${BKP_REPORT}
	echo "Please check TAR_DIR variable in config.sh\n" >> ${BKP_REPORT}
	echo "-------------------------------------------------\n" >> ${BKP_REPORT}
	echo "WARNING" >> $MAILALERT
	CHK_TAR_DIR="NOK"
fi

echo "Backup $dirname\n" >> ${BKP_REPORT}

CHK_UPLOAD_RESULT="OK"

# Incremental list path defnition
INC_LIST=$ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.incremental-list.txt

# Call tarmehod function to determine total tar or incremental tar
tarmethod

case $TAR_METHOD in
	total)
	LOCAL_TAR_PATH=$ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.master.tgz
	TAR_FILE_NAME=${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.master.tgz
	REM_TAR_PATH=$UPLOAD_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.master.tgz
	if [ $CHK_TAR_DIR = "OK" ];then
		echo "$dirname total tar :" >> ${TAR_REPORT}
		maketar total ${EXCLUSIONS} ${TAR_REPORT}
		if [ $? != 0 ];then
			echo "WARNING : $dirname TOTAL backup" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
		else
			echo "OK : $dirname TOTAL backup\n" >> ${BKP_REPORT}
		fi
	fi
	;;

	inc)
	LOCAL_TAR_PATH=$ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.tgz
	TAR_FILE_NAME=${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.tgz
	REM_TAR_PATH=$UPLOAD_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.tgz
	if [ $CHK_TAR_DIR = "OK" ];then
		echo "$dirname incremental tar :" >> ${TAR_REPORT}
		maketar incremental ${EXCLUSIONS} ${TAR_REPORT}
		if [ $? != 0 ];then
			echo "WARNING : $dirname INCREMENTAL backup" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
		else
			echo "OK : $dirname INCREMENTAL backup\n" >> ${BKP_REPORT}
		fi
	fi
	;;

esac

if [ $GET_DIR_ACL = "yes" ] && [ $CHK_TAR_DIR = "OK" ];then
	LOCAL_ACL_PATH=$ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.ACL.gz
	REM_ACL_PATH=$UPLOAD_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.ACL.gz
	ACL_FILE_NAME=${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.ACL.gz
	getfacl -R $dirname 2>&1 | gzip > ${LOCAL_ACL_PATH}
fi

if [ $UPLOADCX = "OK" ];then
case $UPLOAD_METHOD in

	ssh)
	# Upload the tar file using ssh
	if [ $SSHCX = "OK" ] && [ $SSHDIR = "OK" ] && [ $CHK_TAR_DIR = "OK" ];then
		sshcopy -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_TAR_PATH} -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
		if [ $? != 0 ];then
			echo "WARNING : ${LOCAL_TAR_PATH} upload on $SSH_HOST\n" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
			CHK_UPLOAD_RESULT="NOK"
		else
			echo "OK : ${LOCAL_TAR_PATH} uploaded on $SSH_HOST\n" >> ${BKP_REPORT}
		fi

		if [ $CHK_UPLOAD_RESULT = "OK" ];then
			sshcheckmd5 -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_TAR_PATH} -f ${REM_TAR_PATH}
			if [ $? != 0 ];then
				echo "WARNING : ${LOCAL_TAR_PATH} MD5 sum\n" >> ${BKP_REPORT}
				echo "WARNING" >> $MAILALERT
			else
				echo "OK : ${LOCAL_TAR_PATH} MD5 sum\n" >> ${BKP_REPORT}
			fi
		fi
	fi

	# If ACL are backuped : upload the ACL file using ssh
	if [ $SSHCX = "OK" ] && [ $SSHDIR = "OK" ] && [ $CHK_TAR_DIR = "OK" ] && [ $GET_DIR_ACL = "yes" ];then
		sshcopy -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_ACL_PATH} -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
		if [ $? != 0 ];then
			echo "WARNING : ${LOCAL_ACL_PATH} upload on $SSH_HOST\n" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
			CHK_UPLOAD_RESULT="NOK"
		else
			echo "OK : ${LOCAL_ACL_PATH} uploaded on $SSH_HOST\n" >> ${BKP_REPORT}
		fi

		if [ $CHK_UPLOAD_RESULT = "OK" ];then
			sshcheckmd5 -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_ACL_PATH} -f ${REM_ACL_PATH}
			if [ $? != 0 ];then
				echo "WARNING : ${LOCAL_ACL_PATH} MD5 sum\n" >> ${BKP_REPORT}
				echo "WARNING" >> $MAILALERT
			else
				echo "OK : ${LOCAL_ACL_PATH} MD5 sum\n" >> ${BKP_REPORT}
			fi
		fi
	fi
	;;

	ftp)
	# Upload the tar file using ftp
	if [ $FTPCX = "OK" ] && [ $FTPDIR = "OK" ] && [ $CHK_TAR_DIR = "OK" ];then
		ftpcopy -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${TAR_FILE_NAME} -D $ARCH_DIR -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
		ftpcheckupload -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${LOCAL_TAR_PATH} -f ${TAR_FILE_NAME} -d $UPLOAD_DIR
		if [ $? != 0 ];then
			echo "WARNING : ${LOCAL_TAR_PATH} upload on $FTP_HOST\n" >> ${BKP_REPORT}
			echo "Local ${TAR_FILE_NAME} size is not equal to remote ${TAR_FILE_NAME} size" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
		else
			echo "OK : ${LOCAL_TAR_PATH} uploaded on $FTP_HOST\n" >> ${BKP_REPORT}
		fi
	fi

	# Upload the ACL file using ftp
	if [ $FTPCX = "OK" ] && [ $FTPDIR = "OK" ] && [ $CHK_TAR_DIR = "OK" ] && [ $GET_DIR_ACL = "yes" ];then
		ftpcopy -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${ACL_FILE_NAME} -D $ARCH_DIR -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
		ftpcheckupload -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${LOCAL_ACL_PATH} -f ${ACL_FILE_NAME} -d $UPLOAD_DIR
		if [ $? != 0 ];then
			echo "WARNING : ${LOCAL_ACL_PATH} upload on $FTP_HOST\n" >> ${BKP_REPORT}
			echo "Local ${ACL_FILE_NAME} size is not equal to remote ${ACL_FILE_NAME} size" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
		else
			echo "OK : ${LOCAL_ACL_PATH} uploaded on $FTP_HOST\n" >> ${BKP_REPORT}
		fi
	fi
	;;	

esac
fi

# echo a separator between each backup directory
echo "-------------------------------------------------\n" >> ${BKP_REPORT}
		
done

else
	echo "No directories to backup" >> ${BKP_REPORT}
	echo "Check TAR_DIR variable in config.sh\n" >> ${BKP_REPORT}
	echo "WARNING" >> $MAILALERT
fi

if [ "$MYSQL_DATABASES" ];then

	echo "-------------------------------------------------" >> ${BKP_REPORT}
	echo " MYSQL DATABASES BACKUP SECTION " >> ${BKP_REPORT}
	echo "-------------------------------------------------\n" >> ${BKP_REPORT}

	CHK_MYDUMP="OK"
	CHK_UPLOAD_RESULT="OK"

	if [ "$MYSQL_DATABASES" = ALL ];then

		LOCAL_MYSQL_DB_PATH=$ARCH_DIR/${BKP_PREFIX}.all-databases.$DAY_TODAY.sql.gz
		DUMP_FILE_NAME=${BKP_PREFIX}.all-databases.$DAY_TODAY.sql.gz
		REM_MYSQL_DB_PATH=$UPLOAD_DIR/${BKP_PREFIX}.all-databases.$DAY_TODAY.sql.gz
		mysqldump -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWD} \
			--events --opt --all-databases | gzip > ${LOCAL_MYSQL_DB_PATH}
		if [ $? != 0 ];then
			echo "WARNING : all databases backup\n" >> ${BKP_REPORT}
			echo "Try to namualy dump all databases to check" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
		else
			echo "OK : All databases backup\n" >> ${BKP_REPORT}
		fi

		if [ $UPLOADCX = "OK" ];then
		case $UPLOAD_METHOD in
		ssh)
		if [ $SSHCX = "OK" ] && [ $SSHDIR = "OK" ];then
			sshcopy -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_MYSQL_DB_PATH} -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
			if [ $? != 0 ];then
				echo "PROBLEM : ${LOCAL_MYSQL_DB_PATH} upload on $SSH_HOST" >> ${BKP_REPORT}
				echo "See ${UPLOAD_REPORT} for more details\n" >> ${BKP_REPORT}
				echo "WARNING" >> $MAILALERT
				CHK_UPLOAD_RESULT="NOK"
			else
				echo "OK : ${LOCAL_MYSQL_DB_PATH} uploaded on $SSH_HOST\n" >> ${BKP_REPORT}
			fi

			if [ $CHK_UPLOAD_RESULT = "OK" ];then
				sshcheckmd5 -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_MYSQL_DB_PATH} -f ${REM_MYSQL_DB_PATH}
				if [ $? != 0 ];then
					echo "PROBLEM : ${LOCAL_MYSQL_DB_PATH} MD5 sum\n" >> ${BKP_REPORT}
					echo "WARNING" >> $MAILALERT
				else
					echo "OK : ${LOCAL_MYSQL_DB_PATH} MD5 sum\n" >> ${BKP_REPORT}
				fi
			fi
		fi
		;;

		ftp)
		if [ $FTPCX = "OK" ] && [ $FTPDIR = "OK" ];then
		ftpcopy -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${DUMP_FILE_NAME} -D $ARCH_DIR -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
		ftpcheckupload -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${LOCAL_MYSQL_DB_PATH} -f ${DUMP_FILE_NAME} -d ${UPLOAD_DIR}
		if [ $? != 0 ];then
			echo "WARNING : ${LOCAL_MYSQL_DB_PATH} upload on $FTP_HOST" >> ${BKP_REPORT}
			echo "Local ${DUMP_FILE_NAME} size is not equal to remote ${DUMP_FILE_NAME} size\n" >> ${BKP_REPORT}
			echo "WARNING" >> $MAILALERT
		else
			echo "OK : ${LOCAL_MYSQL_DB_PATH} uploaded on $FTP_HOST\n" >> ${BKP_REPORT}
		fi
		fi
		;;	

		esac
		fi
			
			
	else
		for database in $MYSQL_DATABASES
		do
			CHK_DB="OK"

			mysql -u ${MYSQL_USER} -p${MYSQL_PASSWD} -e 'show databases' | grep -qE "^$database$"
			if [ $? = 0 ];then
				echo "$database database backup :\n" >> ${BKP_REPORT}
				LOCAL_MYSQL_DB_PATH=$ARCH_DIR/${BKP_PREFIX}.$database.$DAY_TODAY.sql.gz
				DUMP_FILE_NAME=${BKP_PREFIX}.$database.$DAY_TODAY.sql.gz
				REM_MYSQL_DB_PATH=$UPLOAD_DIR/${BKP_PREFIX}.$database.$DAY_TODAY.sql.gz
				mysqldump -h ${MYSQL_HOST} -u ${MYSQL_USER} -p${MYSQL_PASSWD} \
					--events --opt $database | gzip > ${LOCAL_MYSQL_DB_PATH}

				if [ $? != 0 ];then
					echo "WARNING : $database database backup" >> ${BKP_REPORT}
					echo "Try do manualy dump $database to check errors" >> ${BKP_REPORT}
					echo "WARNING" >> $MAILALERT
				else
					echo "OK : $database database backuped\n" >> ${BKP_REPORT}
				fi
			else
				echo "WARNING : $database database does not exists" >> ${BKP_REPORT}
				echo WARNING >> $MAILALERT
				CHK_DB="NOK"
			fi

			if [ $UPLOADCX = "OK" ];then
			case $UPLOAD_METHOD in
			ssh)
			if [ $SSHCX = "OK" ] && [ $SSHDIR = "OK" ] && [ $CHK_DB = "OK" ];then
				sshcopy -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_MYSQL_DB_PATH} -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
				if [ $? != 0 ];then
					echo "WARNING : ${LOCAL_MYSQL_DB_PATH} upload on $SSH_HOST" >> ${BKP_REPORT}
					echo "WARNING" >> $MAILALERT
					CHK_UPLOAD_RESULT="NOK"
				else
					echo "OK : ${LOCAL_MYSQL_DB_PATH} uploaded on $SSH_HOST\n" >> ${BKP_REPORT}
				fi

				if [ $CHK_UPLOAD_RESULT = "OK" ];then
					sshcheckmd5 -i $SSH_KEY -u $SSH_USER -h $SSH_HOST -F ${LOCAL_MYSQL_DB_PATH} -f ${REM_MYSQL_DB_PATH}
					if [ $? != 0 ];then
						echo "WARNING : ${LOCAL_MYSQL_DB_PATH} MD5 sum\n" >> ${BKP_REPORT}
						echo "WARNING" >> $MAILALERT
					else
						echo "OK : ${LOCAL_MYSQL_DB_PATH} MD5 sum\n" >> ${BKP_REPORT}
					fi
				fi
			fi
			;;

			ftp)
			if [ $FTPCX = "OK" ] && [ $FTPDIR = "OK" ] && [ $CHK_DB = "OK" ];then
			ftpcopy -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${DUMP_FILE_NAME} -D $ARCH_DIR -d $UPLOAD_DIR -R ${UPLOAD_REPORT}
			ftpcheckupload -u ${FTP_USER} -P ${FTP_PASSWD} -h ${FTP_HOST} -F ${LOCAL_MYSQL_DB_PATH} -f ${DUMP_FILE_NAME} -d $UPLOAD_DIR
			if [ $? != 0 ];then
				echo "WARNING : ${LOCAL_MYSQL_DB_PATH} upload on $FTP_HOST" >> ${BKP_REPORT}
				echo "Local ${DUMP_FILE_NAME} size is not equal to remote ${DUMP_FILE_NAME} size" >> ${BKP_REPORT}
				echo "WARNING" >> $MAILALERT
			else
				echo "OK : ${LOCAL_MYSQL_DB_PATH} uploaded on $FTP_HOST\n" >> ${BKP_REPORT}
			fi
			fi
			;;	

			esac
			fi
		echo "-------------------------------------------------\n" >> ${BKP_REPORT}
		done
	fi
fi


COUNT_MAIL_ALERTE_WARNING=`grep -c WARNING $MAILALERT`
COUNT_MAIL_ALERTE_CRITICAL=`grep -c CRITICAL $MAILALERT`


# If mail destinator is not empty and mail command exists send report by mail
if [ $MAIL_REPORT_DEST ] && [ $MAILCMD ];then
	if [ $COUNT_MAIL_ALERTE_CRITICAL != 0 ];then
		mail -s "$HOSTNAME backup report : CRITICAL" $MAIL_REPORT_DEST < ${BKP_REPORT}

	elif [ $COUNT_MAIL_ALERTE_WARNING != 0 ];then
		mail -s "$HOSTNAME backup report : WARNING" $MAIL_REPORT_DEST < ${BKP_REPORT}

	else 
		mail -s "$HOSTNAME backup report : OK" $MAIL_REPORT_DEST < ${BKP_REPORT}
	fi
fi 

rm -f $MAILALERT
rm -f $EXCLUSIONS

# Change owner section
if [ $BKP_OWNER ] && [ $TEST_BKP_OWNER = "OK" ];then
	chmod 700 $ARCH_DIR/
	chmod 600 $ARCH_DIR/*
	chown -R $BKP_OWNER $ARCH_DIR/
fi

# PURGE SECTION : local purge for file older then LOCAL_TTL days.
if [ $LOCAL_TTL ];then
	find $ARCH_DIR -type f -iname "$BKP_PREFIX*.gz" -mtime +$LOCAL_TTL -exec rm -f {} \;
	find $ARCH_DIR -type f -iname "$BKP_PREFIX*.tgz" -mtime +$LOCAL_TTL -exec rm -f {} \;
fi

# DISTANT PURGE if Upload Method is SSH
if [ $UPLOAD_TTL ] && [ $UPLOAD_METHOD = ssh ] && [ $SSHCX = OK ] && [ $SSHDIR = OK ];then
	ssh -i $SSH_KEY $SSH_USER@$SSH_HOST "find $UPLOAD_DIR -type f -iname "$BKP_PREFIX*.gz" -mtime +$UPLOAD_TTL -exec rm -f {} \;"
	ssh -i $SSH_KEY $SSH_USER@$SSH_HOST "find $UPLOAD_DIR -type f -iname "$BKP_PREFIX*.tgz" -mtime +$UPLOAD_TTL -exec rm -f {} \;"
fi
