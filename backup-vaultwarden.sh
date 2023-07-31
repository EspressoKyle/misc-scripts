#!/bin/bash

###CONFIG-START###
CONTAINER_NAMES="vaultwarden caddy" 		# delimited by single space
DATA_DIRECTORY="<REPLACE>"					# directory containing vaultwarden and caddy docker container files
WORKING_DIR=$(mktemp -d)					# create temporary working container
TIMESTAMP=$(date -d "today" +"%Y%m%d%H%M")  # generate static timestamp for use throughout the script
MAIL_SENDER="<REPLACE>"						# what email is going to send the notifications
MAIL_RECEIVER="<REPLACE>"					# what email is going to receive the notifications
MAIL_SERVER="<REPLACE>"					# smtp host that will be leveraged to send the notifications
MAIL_PASSWD="<REPLACE>"						# pqssword of the $MAIL_SENDER emaqil address
BACKUP_PASSWD="<REPLACE>"					# password that should be used to create the encrypted zip backup file
###CONFIG-END###


function SEND_MAIL () {
	curl -s --url "smtps://$MAIL_SERVER:465" --ssl-reqd --mail-from "$MAIL_SENDER" --mail-rcpt "$MAIL_RECEIVER" --user "$MAIL_SENDER":"$MAIL_PASSWD" -T <(echo -e "From: $MAIL_SENDER
To: $MAIL_RECEIVER
Subject:$1

 $2")
}

function START_STOP_CONTAINERS () {
	for NAME in $CONTAINER_NAMES; do
		docker $1 $NAME 1>/dev/null 2>/dev/null
		if [[ $? -eq 0 ]]; then
			echo "SUCCESS: Executed '$1' task on docker container ($NAME)"
		else
			echo "FAIL: Issue encountered while executing '$1' task on container ($NAME)"
			SEND_MAIL "VAULTWARDEN BACKUP: FAILURE" "Failed executing '$1' task on container ($NAME)."
			exit
		fi
	done
}

cd $WORKING_DIR

START_STOP_CONTAINERS "stop"


tar -cf $WORKING_DIR/vaultwarden-$TIMESTAMP.tar $DATA_DIRECTORY 1>/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then
	echo "SUCCESS: Successfully created tar archive of '$DATA_DIRECTORY'"
else
	echo "FAIL: Issue encountered while creating tar archive of '$DATA_DIRECTORY'"
	SEND_MAIL "VAULTWARDEN BACKUP: FAILURE" "Issue encountered while creating tar archive of '$DATA_DIRECTORY'."
	exit
fi

sha256sum ./vaultwarden-$TIMESTAMP.tar > $WORKING_DIR/vaultwarden-$TIMESTAMP.sha256sum 2>/dev/null
if [[ $? -eq 0 ]]; then
	echo "SUCCESS: Generated sha256 checksum"
else
	echo "FAIL: Issue encountered while generating checksum"
	SEND_MAIL "VAULTWARDEN BACKUP: FAILURE" "Issue encountered generating checksum file."
	exit
fi

zip -e -0 --password "$BACKUP_PASSWD" $WORKING_DIR/vaultwarden-$TIMESTAMP.zip $WORKING_DIR/vaultwarden-$TIMESTAMP.tar $WORKING_DIR/vaultwarden-$TIMESTAMP.sha256sum 1>/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then
	echo "SUCCESS: Created encrypted zip archive"
else
	echo "FAIL: Issue encountered while creating encrypted zip archive"
	SEND_MAIL "VAULTWARDEN BACKUP: FAILURE" "Issue encountered creating encrypted zip archive."
	exit
fi


rclone copy $WORKING_DIR/vaultwarden-$TIMESTAMP.zip dropbox:Backup 1>/dev/null 2>/dev/null
if [[ $? -eq 0 ]]; then
	echo "SUCCESS: Uploaded backup to Dropbox 'Backup/' folder"
else
	echo "FAIL: Issue encountered while uploading backup to Dropbox"
	SEND_MAIL "VAULTWARDEN BACKUP: FAILURE" "Issue encountered while uploading backup to Dropbox."
	exit
fi

rclone copy $WORKING_DIR/vaultwarden-$TIMESTAMP.zip GoogleDrive:Backup
if [[ $? -eq 0 ]]; then
	echo "SUCCESS: Uploaded backup to Google Drive 'Backup/' folder"
else
	echo "FAIL: Issue encountered while uploading backup to Google Drive"
	SEND_MAIL "VAULTWARDEN BACKUP: FAILURE" "Issue encountered while uploading backup to Google Drive."
	exit
fi

START_STOP_CONTAINERS "start"

SEND_MAIL "VAULTWARDEN BACKUP: SUCCESS" "Successfully backed up Vaultwarden data to both Google Drive and Dropbox. Backup file name is 'Backup/vaultwarden-$TIMESTAMP.zip' and is encrypted with a key that starts with the letter 'E'."
