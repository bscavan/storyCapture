#! /bin/bash

## Experimental script for pinging a site once per hour until success, and then waiting 24 hours before repeating.

quietMode="false"

# Set originalDirectory before changing directories into the directory for the current story.
originalDirectory=$(pwd)

log () {
	if [[ $quietMode != "true" ]]; then
		echo $1
	fi
}

logError () {
	# TODO: Put this into std_err?
	echo $1
}

exitMethod() {
	cd $originalDirectory
	exit $1
}

exitCodes="0: A successful result\
1: General errors\
2: Failure to connect to the provided URL\
3: statusFileName did not correspond with a valid path\
4: The status file was found and not enough time has passed since the last successful run.\
5: Parameters were missing.\
6: Story capture script was missing."

# TODO: Make this less fragile
homeDirectory='/c/Users/bcavanaugh/Documents/sharedGitRepo/storyCapture'

defaultStatusFileName="status"

# Measured in seconds
defaultWaitTimeBetweenRuns="3600"

# TODO: Convert these into line-options.
#toc_LinkRoot="https://www.royalroad.com"
toc_LinkRoot="www.royalroad.com"
toc_Id=""
storyName=""

# Loop through arguments and process them
for arg in "$@"
do
	case $arg in
		-h|--help)
		echo "Sorry, I haven't written the help message yet."
		exitMethod 0;
		;;
		-m=*|--home-directory=*)
		homeDirectory="${arg#*=}"
		shift
		;;
		-l=*|--link-root=*)
		toc_LinkRoot="${arg#*=}"
		shift
		;;
		-i=*|--id=*)
		# example toc_Id: /fiction/14167/metaworld-chronicles/
		toc_Id="${arg#*=}"
		shift
		;;
		-n=*|--name=*)
		storyName="${arg#*=}"
		shift
		;;
		-s=*|--status-file-name=*)
		statusFileName="${arg#*=}"
		shift
		;;
		-w=*|--wait-time=*)
		waitTimeBetweenRuns="${arg#*=}"
		shift
		;;
		*)
		OTHER_ARGUMENTS+=("$1")
		## TODO: Put $OTHER_ARGUMENTS into the call to ./rrStoryCapture.sh?
		shift # Remove generic argument from processing
		;;
	esac
done

if [[ ! -d $homeDirectory ]]; then
	log "Home directory for the script did not exist at: [${homeDirectory}], meaning the story capture script cannot exist within it. Cannot continue. Exiting now."
	exitMethod 6
fi

cd $homeDirectory

storyCaptureScript="${homeDirectory}/rrStoryCapture.sh"

if [[ ! -f $storyCaptureScript ]]; then
	log "Failed to find the story capture script at: [${storyCaptureScript}]. Cannot continue. Exiting now."
	exitMethod 6
fi

if [[ ! "$toc_Id" ]]; then
	logError "An Id for the desired was not provided. Cannot continue."
	exitMethod 5;
fi

if [[ ! "$storyName" ]]; then
	logError "An name for the desired was not provided. Cannot continue."
	exitMethod 5;
fi

# If the directory for this story does not exist, create it.
if [[ ! -d $storyName ]]; then
	mkdir $storyName
fi

cd $storyName

targetURL=${toc_LinkRoot}${toc_Id}
shouldRun="true";

if [[ ! "$statusFileName" ]]; then
	statusFileName="${defaultStatusFileName}_${storyName}.txt"
	log "statusFileName was not set. Using default value of [${statusFileName}]."
fi

if [[ ! "$waitTimeBetweenRuns" ]]; then
	log "waitTimeBetweenRuns was not set. Using default value of [${defaultWaitTimeBetweenRuns}]."
	waitTimeBetweenRuns=$defaultWaitTimeBetweenRuns
fi

if [[ ! -f "$statusFileName" ]]; then
	log "${statusFileName} does not exist."
	# leave shouldRun set to "true"
else
	if grep -q "timeStamp" $statusFileName ; then
		# If the timeStamp can be found in the status file.
		timeStampLine=$(grep "timeStamp" $statusFileName)
		
		if grep -q '=' $statusFileName ; then
			# Grab the status files timeStamp value here.
			timeStamp=$(grep "timeStamp" $statusFileName | cut -d '=' -f2)
			log "timestamp found in status file: [${timeStamp}]"

			# TODO: Check to see if timeStamp has any content.

			currentTime=$(date +%s)
			log "current time is [${currentTime}]"

			timeSinceLastRun=$(($currentTime-$timeStamp))
			log "timeSinceLastRun: [${timeSinceLastRun}] seconds."

			if [[ $timeSinceLastRun -lt $waitTimeBetweenRuns ]]; then
				log "Not enough time has passed since the last run. Overwrite waitTimeBetweenRuns to allow the script to run more frequently. Exiting now."
				shouldRun="false";
			fi
		else
			# Either the timestamp was missing or malformed.
			log "${statusFileName} was found but no valid value for a timeStamp was found."
			# leave shouldRun set to "true"
		fi
	else
		# Either the timestamp was missing or malformed.
		log "${statusFileName} was found but no valid value for a timeStamp was found."
		# leave shouldRun set to "true"
	fi
fi

if [[ $shouldRun != "true" ]]; then
	exitMethod 4;
fi

#ping -n 1 $targetURL 2>&1 >/dev/null

#pingSuccessCode=$?
pingSuccessCode=0
# Artificially setting pingSuccessCode to 0 here because RoyalRoad blocks pings.
# TODO: Determine if I can just replace ping with curl here...

#log "Success code of pinging [${targetURL}] was [${pingSuccessCode}]"

if [[ $pingSuccessCode -ne 0 ]]; then
	log "Failed to connect to the URL [${targetURL}]; Cannot proceed.";
	exitMethod 2;
else
	# Run the storyCapture.sh script here.
	$storyCaptureScript --toc_LinkRoot=$toc_LinkRoot --name=$storyName --id=$toc_Id

	# Get the successCode of the script just ran.
	storyCaptureSuccessCode=$?

	# TODO: change the storyCapture.sh script so it reports whether new chapters were found.
	# Adjust this script so it can report that info back to the user.

	if [[ $pingSuccessCode -eq 0 ]]; then
		log "Successfully captured chapters from [${targetURL}]. Exiting now."

		# Update the status document with the last successful ping time?
		printf '%s\n' '{' "timeStamp=$(date +%s)" '}' > $statusFileName
		exitMethod 0;
	else
		log "Failed to capture chapters from [${targetURL}]. Exiting now."
		exitMethod 1;
	fi
fi

# Return to the original directory before terminating.
exitMethod 0;