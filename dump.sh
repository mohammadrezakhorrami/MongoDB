  #!/bin/bash
#
# This tool will dump out a BSON file of MongoDB oplog changes based on a range of Timestamp() objects.


##Define variable

MONGODUMP_FLAGS='--db=local --collection=oplog.rs'
MONGODUMP_FLAGS1='--oplog '
Username='monUser'
Pass='db6895e'

CHECKOSLOGPATH=/dbdata1/cronJobs/output/`date +%y-%m-%d`_oplog.txt
CHECKOSLOGPATH_Rm=/dbdata1/cronJobs/output/
Log_path=/dbdata2/mongoLog/

# Number of days
DELETE_DAYS=2

IP=$(hostname -i)
FTPUSER='ftptest'
FTPPASSWD='Aa123456'
CURRENTDATE=$(date +%y-%m-%d)
FTPFILES1='/dbdata1/cronJobs/sh/ftpfiles.sh'
COUNTER=0
Directory=`date --date="-1 days" +%Y%m%d`
dayly=`date --date="-1 days" +%y-%m-%d`
YEAR=`date +%Y`
MONTH=`date +%Y%m`
HOSTNAME=`hostname -i`
FTPSRV='192.168.50.58'
FTPFILES2='/home/mongo/sc/ftpfiles.sh'
DAYOFWEEK=$(date +"%a")

# Function to check if a command is available
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if either 'mongo' or 'mongosh' command is available
if command_exists mongosh; then
 mongo=/usr/bin/mongosh
elif command_exists mongo; then
 mongo=/usr/bin/mongo
fi


# Function to clean up old files
cleanup_files() {
  local path=$1

  if [ -d "$path" ]; then
    echo "Cleaning up files and directories older than $DELETE_DAYS days in $path"
    current_time=$(date +%s)
    for item in "$path"/*; do
      if [ -e "$item" ]; then
        item_mtime=$(stat -c %Y "$item")
        item_age=$(( (current_time - item_mtime) / 86400 ))
        if [ "$item_age" -gt "$DELETE_DAYS" ]; then
          if [ -f "$item" ]; then
            if rm -f "$item"; then
              echo "Deleted file: $item"
            else
              echo "Error deleting file: $item"
              return 1
            fi
          elif [ -d "$item" ]; then
            if rm -rf "$item"; then
              echo "Deleted directory: $item"
            else
              echo "Error deleting directory: $item"
              return 1
            fi
          fi
        fi
      fi
    done

    echo "Cleanup completed."

  else
    echo "Directory $path does not exist."
    return 1
  fi
}


#DUMPLOGPATH1=(
    
#    "/backup01/cronJobs/dump"     # Instance 1
#	  "/dbdata3/cronJobs/dump"      # Instance 2
#    "/dbdata1/cronJobs/dump"      # Instance 2
#    # Add more paths as needed
#)

DUMPLOGPATH1=$( /usr/bin/find / -type d -path "*/cronJobs/dump" 2>/dev/null)
if [ -n "$DUMPLOGPATH1" ]; then

  /usr/bin/find "$DUMPLOGPATH1" -mindepth 1 | wc -l
  echo 'Dump path with find is : ' 
else
  echo "Directory not found"  
  exit 1
fi



echo $DUMPLOGPATH1

#if [ -d dump ]; then
#  echo "'dump' subdirectory already exists! Exiting!" >>$CHECKOSLOGPATH
#  exit 1
#fi
STARTTIME="$(date +%H:%M:%S)"
echo "BACKUP DATABASE Mongodb ">>$CHECKOSLOGPATH
echo -n "# Dumping oplogs start at ">>$CHECKOSLOGPATH
echo $STARTTIME >> $CHECKOSLOGPATH
echo "************************************************************************************************" >> $CHECKOSLOGPATH
##Find server role
REPL_ROLE=$( $mongo  --host 127.0.0.1 --port 27017 --authenticationDatabase admin --quiet  --username $Username  --password $Pass  --eval 'rs.isMaster().primary')
ME_ROLE=$($mongo  --host 127.0.0.1 --port 27017 --authenticationDatabase admin --quiet  --username $Username  --password $Pass  --eval 'rs.isMaster().me')

echo 'PRIMARY IS ' $REPL_ROLE>>$CHECKOSLOGPATH
echo 'MY IP IS ' $ME_ROLE>>$CHECKOSLOGPATH


if [ $REPL_ROLE = $ME_ROLE ]; then
#############################################################################################################Start Backup#############################################################################################################
#for DUMPLOGPATH1 in "${DUMPLOGPATH1[@]}"; do
    if [ -e "$DUMPLOGPATH1" ]; then
		DUMPLOGPATH1=$DUMPLOGPATH1/`date +%y-%m-%d`

		echo 'Export path 0 : '
		echo $DUMPLOGPATH1
		
		echo 'Start mongodump on path  '$DUMPLOGPATH1'   '>>$CHECKOSLOGPATH
		STARTTIME="$(date +%H:%M:%S)"
		echo -n "Backup Start Time " >> $CHECKOSLOGPATH
		echo $STARTTIME >> $CHECKOSLOGPATH


		#mkdir dump
		mongodump -u $Username -p $Pass --authenticationDatabase admin  $MONGODUMP_FLAGS  --gzip  --out  $DUMPLOGPATH1>>$CHECKOSLOGPATH
		mongodump -u $Username -p $Pass  $MONGODUMP_FLAGS1 --gzip  --out $DUMPLOGPATH1>>$CHECKOSLOGPATH
		echo -n "Backup End Time " >> $CHECKOSLOGPATH
		date +%H:%M:%S >> $CHECKOSLOGPATH

		##check backup status
		echo 'Export path 1 : '
		echo $DUMPLOGPATH1
		if [ -e "$DUMPLOGPATH1" ]; then
		  echo 'mongodump is on '$DUMPLOGPATH1'    '>>$CHECKOSLOGPATH
		  echo 'Backup successful' >>$CHECKOSLOGPATH
		  echo -n 'Backup Size:' >>$CHECKOSLOGPATH
		  du -sm $DUMPLOGPATH1* |awk '{ sum+=$1} END {print sum}'|awk '{ if (length($1) > 6) printf "%.2fG\n", $1/1024 ; else if (length($1) > 3) print $1/1024"G" ; else print $1"M"; } ' >> $CHECKOSLOGPATH
		  ##du -h $DUMPLOGPATH1 >>$CHECKOSLOGPATH
		  echo 'End of mongodump on path  '$DUMPLOGPATH1'   '>>$CHECKOSLOGPATH
		  # Zip the MongoDB dump directory
		  tar -czvf /$DUMPLOGPATH1.tar.gz $DUMPLOGPATH1

		else
		  echo "ERROR: Cannot find oplog.bson file! Exiting!" >>$DUMPLOGPATH1
		  exit 1
		fi
#############################################################################################################
		##Remove  old Files
      echo 'start primary delete file output'
      echo $CHECKOSLOGPATH_Rm
  # Clean up files in the defined paths
      cleanup_files "$CHECKOSLOGPATH_Rm"

  # Handle multiple paths found by find command
   for path in $DUMPLOGPATH1; do
      cleanup_files "$path"
   done	
#############################################################################################################		
		

		
		##Ftp Dump to tape server

		##########################################################################################################
		##ftp files
		#if [ "$DAYOFWEEK" != "Fri" or "$DAYOFWEEK" == "Fri"  ];  then
		cd /dbdata1/cronJobs/sh/
		cat /dev/null > ftpfiles.sh
		echo "lftp -u $FTPUSER,$FTPPASSWD $FTPSRV  <<end_script
		mkdir BackUp
		cd BackUp
		mkdir $CURRENTDATE
		cd $CURRENTDATE
		mkdir Mongo
		cd Mongo
		mkdir $IP
		cd $IP " >> $FTPFILES1
		echo "put "$DUMPLOGPATH1.tar.gz"" >> $FTPFILES1
		echo "quit
		end_script
		exit 0  " >> $FTPFILES1

		cd /dbdata1/cronJobs/sh/
		./ftpfiles.sh

		cd ~/.lftp/

		#OUTPUT1="(/usr/bin/less transfer_log | /bin/grep -iE $CURRENTDATE | /usr/bin/wc -l)"
		OUTPUT=$(/usr/bin/less transfer_log | /bin/grep -iE $CURRENTDATE | /usr/bin/wc -l)

		COUNTER=1
		echo " $OUTPUT as OUTPUT"

		echo " $COUNTER as COUNTER"

		   if [ $OUTPUT = 1 ]; then
		   echo "BACKUP DATABASE"  >> $CHECKOSLOGPATH
		   echo -n "FTP successful" >> $CHECKOSLOGPATH
       /usr/bin/rm $DUMPLOGPATH1.tar.gz -fr
		   echo " (number of successful FTPs : $OUTPUT ) " >> $CHECKOSLOGPATH
		   echo "BACKUP DATABASE  (End of File)" >> $CHECKOSLOGPATH

		   else
		   echo "BACKUP DATABASE"  >> $CHECKOSLOGPATH
		   echo -n "FTP unsuccessful" >> $CHECKOSLOGPATH
		   echo " (number of successful FTPs : $OUTPUT ) " >> $CHECKOSLOGPATH
		   echo "BACKUP DATABASE  (End of File)" >> $CHECKOSLOGPATH

		   fi

		#############################################################################################################
# Exit the loop
#        break
	else
        echo "$path does not exist." >> $CHECKOSLOGPATH
    fi
#############################################################################################################End Backup#############################################################################################################
#done
else
     echo "Not PRIMARY System" >>$CHECKOSLOGPATH
         echo "BACKUP DATABASE  (End of File)" >> $CHECKOSLOGPATH


#############################################################################################################
		##Remove  old Files

# Clean up files in the defined paths
  cleanup_files "$CHECKOSLOGPATH_Rm"

# Handle multiple paths found by find command
  for path in $DUMPLOGPATH1; do
    cleanup_files "$path"
  done	
#############################################################################################################		
		


ENDTIME="$(date +%H:%M:%S)"
echo "************************************************************************************************" >> $CHECKOSLOGPATH
echo "# Dumping oplogs end at " >>$CHECKOSLOGPATH
echo $ENDTIME >> $CHECKOSLOGPATH

#echo "*****************************************REMOVE OLD FILES****************************************" >> $CHECKOSLOGPATH

fi
