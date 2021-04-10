#!/bin/sh

# checkdir function
# what : test if a local directory exists
# arguments : the directory name (complete path)
# return : "0" if OK "1" if NOK
checkdir () {
	test -d $1
	if [ $? = 0 ];then
		return 0
	else
		return 1
	fi
}

# nameformat function
# what : replace "/" by "-" and delete the first "/"
# argument : the directory name (complete path)
nameformat () {
	TAR_NAME=`echo $1 | sed -e "s/\//-/g" -e "s/^-//"`
	echo $TAR_NAME
}

# sshcheckcx function
# what : test ssh connectivity
# arguments : -i "ssh key" -u "ssh user name" -h "ssh host"
# default variable : PORT (change it if not 22)
# return : "0" if OK "1" if NOK
sshcheckcx () {
	local KEY=
	local USER=
	local HOST=
	local PORT=22

	while [ $# -gt 0 ]
	do
	case $1 in
		-i) local KEY=$2 ; shift ;;
		-u) local USER=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

	ssh -i $KEY -p $PORT $USER@$HOST hostname > /dev/null 2>&1
	if [ $? = 0 ];then
		return 0
	else
		return 1
	fi
}
	

# sshcheckdir function
# what : test if a disntant (on an ssh server) directory exists
# arguments : -i "ssh key" -u "ssh user name" -h "ssh host" -d "remote directory to check"
# default variable : PORT (change it if not 22)
# return : "0" if OK "1" if NOK
sshcheckdir () {
	local KEY=
	local USER=
	local HOST=
	local RDIR=
	local PORT=22

	while [ $# -gt 0 ]
	do
	case $1 in
		-i) local KEY=$2 ; shift ;;
		-u) local USER=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		-d) local RDIR=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

	ssh -i $KEY $USER@$HOST "test -d $RDIR" > /dev/null 2>&1
	if [ $? = 0 ];then
		return 0
	else
		return 1
	fi
}

# sshcopy function
# what : copy a local file to a distant ssh server
# arguments : -i "ssh key" -u "ssh user name" -h "ssh host" -f "file to copy" -d "remote directory on ssh server" -R "report file"
# default variable : PORT (change it if not 22)
# return : "0" if OK "1" if NOK
sshcopy () {
	local KEY=
	local USER=
	local HOST=
	local LFILE=
	local RDIR=
	local REP=
	local PORT=22

	while [ $# -gt 0 ]
	do
	case $1 in
		-i) local KEY=$2 ; shift ;;
		-u) local USER=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		-F) local LFILE=$2 ; shift ;;
		-d) local RDIR=$2 ; shift ;;
		-R) local REP=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

	scp -i $KEY -C -P $PORT $LFILE $USER@$HOST:$RDIR > ${REP} 2>&1
	if [ $? = 0 ];then
		return 0
	else
		return 1
	fi
}

# sshcheckmd5 function
# what : compare MD5 sum between a local file and a distant file on a SSH server
# arguments : -i "ssh key" -u "ssh user name" -h "ssh host" -F "local file" -f "remote file"
# default variable : PORT (change it if not 22)
# return : "0" if OK "1" if NOK
sshcheckmd5 () {
	local KEY=
	local USER=
	local HOST=
	local LFILE=
	local RFILE=
	local REP=
	local PORT=22

	while [ $# -gt 0 ]
	do
	case $1 in
		-i) local KEY=$2 ; shift ;;
		-u) local USER=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		-F) local LFILE=$2 ; shift ;;
		-f) local RFILE=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

	LMD5=`md5sum $LFILE | awk -F" " '{print $1}'`
	RMD5=`ssh -i $KEY $USER@$HOST "md5sum $RFILE" | awk -F" " '{print $1}'`
	if [ $LMD5 = $RMD5 ];then
		return 0
	else
		return 1
	fi
}

# tarmethod function
# what : determines which tar to do
# arguments : none (stbackup.sh dedicated function)
# return : TAR_METHOD="total" for master tar, TAR_METHOD="inc" for incremental tar
tarmethod () {
	# Tar method variable initialisation
	TAR_METHOD=

	# Master TAR day and incremental-list.txt does not exists : do a master tar
	if [ $DAY_OF_WEEK = $TAR_DAY_MASTER ] && [ ! -e ${INC_LIST} ];then
		TAR_METHOD="total"
	fi

	# Master TAR day and incremental-list.txt exist : delete incremental list and do a master tar
	if [ $DAY_OF_WEEK = $TAR_DAY_MASTER ] && [ -e ${INC_LIST} ];then
		rm ${INC_LIST}
		TAR_METHOD="total"
	fi

	# Incremental day and incremental-list.txt does not exists : master tar
	if [ $DAY_OF_WEEK != $TAR_DAY_MASTER ] && [ ! -e ${INC_LIST} ];then
		TAR_METHOD="total"
	fi

	# Incremental day and incremental-list.txt exists : incremental tar
	if [ $DAY_OF_WEEK != $TAR_DAY_MASTER ] && [ -e ${INC_LIST} ];then
		TAR_METHOD="inc"
	fi
}


# maketar function
# what : make a total tar (tar with 'master' in file name)
# arguments : first argument = method (total or incremental) second arguement = report file
# return : 0 if tar OK and 1 if tar NOK
maketar () {
	case $1 in
	total)
	tar zcf $ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.master.tgz --exclude-from=$2 \
		--listed-incremental=$ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.incremental-list.txt  $dirname >> $3 2>&1
	if [ $? = 0 ];then
		return 0
	else
		return 1
	fi
	;;
	incremental)
	tar zcf $ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.$DAY_TODAY.tgz --exclude-from=$2 \
		--listed-incremental=$ARCH_DIR/${BKP_PREFIX}_${TAR_NAME}.incremental-list.txt  $dirname >> $3 2>&1
	if [ $? = 0 ];then
		return 0
	else
		return 1
	fi
	;;
	esac
}

# ftpcopy function
# what : copy a local file to a distant ftp server
# arguments : -u "ftp user name" -P "password"-h "ftp host" -F "file to copy" -d "destination directory on ftp server" -R "report file"
ftpcopy () {
	local USER=
	local PASSWD=
	local HOST=
	local FILE=
	local DDIR=
	local REP=

	while [ $# -gt 0 ]
	do
	case $1 in
		-u) local USER=$2 ; shift ;;
		-P) local PASSWD=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		-F) local FILE=$2 ; shift ;;
		-D) local LDIR=$2 ; shift ;;
		-d) local DDIR=$2 ; shift ;;
		-R) local REP=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

ftp -n $HOST << FTPCMD >> ${REP} 2>&1
user $USER $PASSWD
bin
lcd $LDIR
cd $DDIR
put $FILE
quit
FTPCMD

}

# ftpcheckcx function
# what : check FTP connection
# arguments : -u "ftp user name" -P "password" -h "ftp host"
# return : "0" if OK "1" if NOK
ftpcheckcx () {
	local USER=
	local PASSWD=
	local HOST=

	while [ $# -gt 0 ]
	do
	case $1 in
		-u) local USER=$2 ; shift ;;
		-P) local PASSWD=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

ftp -nv $HOST << FTPCMD >> /tmp/ftp.log 2>&1
user $USER $PASSWD
quit
FTPCMD

	grep -qe "^230" /tmp/ftp.log
	if [ $? = 0 ];then
		rm -f /tmp/ftp.log
		return 0
	else
		rm -f /tmp/ftp.log
		return 1
	fi

}

# ftpcheckdir function
# what : check directory on a FTP server
# arguments : -u "ftp user name" -P "password" -h "ftp host" d "distant directory to check"
# return : "0" if OK "1" if NOK
ftpcheckdir () {
	local USER=
	local PASSWD=
	local DDIR=
	local HOST=

	while [ $# -gt 0 ]
	do
	case $1 in
		-u) local USER=$2 ; shift ;;
		-P) local PASSWD=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		-d) local DDIR=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

ftp -nv $HOST << FTPCMD >> /tmp/ftp.log 2>&1
user $USER $PASSWD
cd $DDIR
quit
FTPCMD

	grep -qe "^550" /tmp/ftp.log
	if [ $? = 0 ];then
		rm -f /tmp/ftp.log
		return 1
	else
		rm -f /tmp/ftp.log
		return 0
	fi
rm -f /tmp/ftp.log
}

# ftpcheckupload function
# what : check if a file was uploaded to a FTP server
# arguments : -u "ftp user name" -P "password" -h "ftp host" -F "local file" -f "distant file" -d "distant directory"
# return : "0" if OK "1" if NOK
ftpcheckupload () {
	local USER=
	local PASSWD=
	local HOST=
	local LFILE=
	local DFILE=
	local DDIR=
	local LSIZE=
	local DSIZE=

	while [ $# -gt 0 ]
	do
	case $1 in
		-u) local USER=$2 ; shift ;;
		-P) local PASSWD=$2 ; shift ;;
		-h) local HOST=$2 ; shift ;;
		-F) local LFILE=$2 ; shift ;;
		-f) local DFILE=$2 ; shift ;;
		-d) local DDIR=$2 ; shift ;;
		--) shift ; break ;;
		*) break ;;
	esac
	shift
	done

ftp -nv $HOST << FTPCMD >> /tmp/ftp.log 2>&1
user $USER $PASSWD
cd $DDIR
size $DFILE
quit
FTPCMD

	LSIZE=`ls -l $LFILE | awk -F" " '{print $5}'`
	DSIZE=`grep -e "^213" /tmp/ftp.log | awk -F" " '{print $2}'`

	if [ $LSIZE = $DSIZE ];then
		rm -f /tmp/ftp.log
		return 0
	else
		rm -f /tmp/ftp.log
		return 1
	fi

}



