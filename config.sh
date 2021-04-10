#!/bin/sh

# Upload method : "ssh" or "ftp"
# Live blank if no upload
export UPLOAD_METHOD="ssh"

# SSH parameters
export SSH_HOST="backupserver"
export SSH_USER="mpzbackup"
export SSH_KEY="/var/mpzbackup/.ssh/id_rsa"

# FTP parameters
export FTP_HOST="backupserver"
export FTP_USER="mpzbackup"
export FTP_PASSWD="mpzbackup"

# Directory to uplaod backups
export UPLOAD_DIR="/var/mpzbackup/servername"

# Set archive directory where tar will be generated
# The veriable MUST be set. The programme does not work if this variable is wrong or empty
export ARCH_DIR="/var/pmzbackup/servername"

# Set the backups owner on this server
# Leave blank for root user owner
BKP_OWNER="pmzbackup"

# TTL in archives directory
export LOCAL_TTL="7"

# TTL in upload directory, no purge if TTL empty
export UPLOAD_TTL="20"

# Directories to backup, put the fukk path with space separated.
# DO NOT PUT SYMBOLIC LINK, PUT REAL DIRECTORY
export TAR_DIR="/etc /opt /var/www"

# Directories to exclude from the backup
export EXCLUDE_TAR_DIR="/tmp /var/tmp /dev /proc /sys $ARCH_DIR"

# When the master backup is done. 0=sunday, 1=monday ...
export TAR_DAY_MASTER="0"

# Set BKP_PREFIX, prefix for backups name
export BKP_PREFIX=${HOSTNAME}

# Set reporting directory. If wrong or empty, REPORT_DIR = ARCH_DIR
export REPORT_DIR="${ARCH_DIR}/reports"
export MAIL_REPORT_DEST="mail@domain.com"

# MySQL Dump, put ALL if you want to backup all databases
# Live blank if no database to backup
export MYSQL_DATABASES="mysql database1 database2"
export MYSQL_HOST="localhost"
export MYSQL_USER="root"
export MYSQL_PASSWD="password"

# Get directory ACL : answer yes if you want to
export GET_DIR_ACL="no"
