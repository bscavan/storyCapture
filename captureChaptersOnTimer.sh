#! /bin/bash

## Experimental script for pinging a site once per hour until success, and then waiting 24 hours before repeating.

quietMode="false"

# Set originalDirectory before changing directories into the directory for the current story.
originalDirectory=$(pwd)

# TODO: Write up some documentation stating this environmental variable needs to be manually set...
homeDirectory="${STORY_CAPTURE_HOME_DIR}"
# This is where the new chapters found by rrStoryCapture.sh are recorded. It is assumed to exist within homeDirectory unless the user overwrites it with an absolute path.
# TODO: Determine how this can be handled. Present this information to the user somehow and let them view it at their leisure. When they "dismiss" the information, the results file should be cleared out.
# TODO: Also timestamp the update messages to let the user know when we found each new group of chapters.
resultsFile="results.txt"

# TODO: Rewrite these to record their logs in files
log () {
	if [[ $quietMode != "true" ]]; then
		echo $1
	fi
}

logError () {
	# TODO: Put this into std_err?
	echo $1
}

recordResults () {
	echo $1 >> $resultsFile
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

defaultStatusFileName="status"

# Measured in seconds
defaultWaitTimeBetweenRuns="3600"

runWithoutId="false"
wanderinginnModeFlag=""

# TODO: Convert these into line-options.
#toc_LinkRoot="https://www.royalroad.com"
toc_LinkRoot="www.royalroad.com"
toc_Id=""
storyName=""

# TODO: Eventually bundle these scripts together with the executables for bash.exe from git-bash and the scripts for wkhtmltopdf

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
		-r=*|--results-file=*)
		resultsFile="${arg#*=}"
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
		--wandering-inn)
		wanderinginnModeFlag=' --wandering-inn'
		runWithoutId="true"
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

resultsFile="${homeDirectory}/${resultsFile}"

cd $homeDirectory

storyCaptureScript="${homeDirectory}/rrStoryCapture.sh"

if [[ ! -f $storyCaptureScript ]]; then
	log "Failed to find the story capture script at: [${storyCaptureScript}]. Cannot continue. Exiting now."
	exitMethod 6
fi

if [[ ! "$toc_Id" ]] && [[ ! $runWithoutId = "true"  ]]; then
	logError "An Id for the desired story is required and one was not provided. Cannot continue."
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

# Run the storyCapture.sh script here.
storyCaptureOutput=$($storyCaptureScript --toc_LinkRoot=$toc_LinkRoot --name=$storyName --id=$toc_Id ${wanderinginnModeFlag})

# Get the successCode of the script just ran.
storyCaptureSuccessCode=$?

# TODO: Adjust this script so it can report that info back to the user.
if [[ $storyCaptureSuccessCode -eq 0 ]]; then
	chaptersFound=$(echo "$storyCaptureOutput" | grep "chaptersFound" | cut -d '=' -f2)
	log "Successfully storyCapture script on [${targetURL}]. It downloaded: [${chaptersFound}] chapters."

	## TODO: Check $storyCaptureOutput here to determine if chapters were actually retrieved.
	if [[ $chaptersFound -gt -0 ]]; then
		## Add a statement about how many files were found to the log file!
		recordResults "$(date +"%m-%d-%y %T"): story: [${storyName}], captured [${chaptersFound}] new chapters."
	fi

	# Update the status document with the last successful capture time
	printf '%s\n' '{' "timeStamp=$(date +%s)" '}' > $statusFileName
	exitMethod 0;
else
	log "Failed to capture chapters from [${targetURL}]. Exiting now."
	exitMethod 1;
fi

# This secton should be unreachable.
# Return to the original directory before terminating.
exitMethod 0;