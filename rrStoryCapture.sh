#! /bin/bash

##### This is a script for copying the entirety of a freely-published work from the popular website RoyalRoad.com and saving it off to the local filesystem as a set of pdf files.
## Currently it only works for RoyalRoad pages, all of which are publicly available. This script is not intended for any ilicit purposes.
## The script relies on the freely-distributed tool wkhtmltopdf for the final conversion from html to pdf. If that step is not necessary then the dependency is unnecessary and those failed lines will not stop the rest of the script from running.
# @Author: bcavanaugh
# @Created: 9/18/19
# @LastModified: 9/5/21


### Planned improvements:
# Rename the "chapters" and "output" directories to be specific to the story's title, allowing multiple stories to be saved off in the same parent directory without overwriting.
# -q and -v modes, controlling the amount of logging.
# At that point, I would probably just default to a logging-level system.
# An option to skip the conversion to pdf.
# Reduce the URL and Id to one value (have the code pull out everything after the website name and generate the id...)
# Splitting the individual pieces into functions?
# Make the path to wkhtmltopdf a parameter.
# A param for changing the font-size style in the resulting HTML.

# Control flag use to handle logging.
quietMode="false"
logFilePath=""

# TODO: Convert the log method to append to a logging file instead!
# TODO: Make the logging actually include useful details, like if new files were found or if the user specified all chapters should be re-downloaded.

##### Helper functions: #####

# TODO: make different versions of logging? One for info, one for debug, one for trace, etc.?
log () {
	#if [[ $quietMode != "true" ]]; then
	#	echo $1
	#fi
	echo $1 >> $logFilePath
}

logError () {
	# TODO: Put this into std_err?
	#echo $1
	echo $1 >> $logFilePath
}

logInfo () {
	if [[ $quietMode != "true" ]]; then
		echo $1 >> $logFilePath
	fi
}

logTrace () {
	if [[ $verboseMode -eq "true" ]]; then
		echo $1 >> $logFilePath
	fi
}

# TODO: Expand on this to also list the names of the new chapters found! Also the pdfs?
# FIXME: In the event that no new chapters are found, chaptersFound is a negative number. This doesn't seem to support that.
outputResults () {
	printf '%s\n' '{' "chaptersFound=$1" '}';
}

# Returns the greater of two numbers provided.
max () {
	a=$1
	b=$2
	output=$(( a > b ? a : b ))
	echo $output
	return $output
}

# Simulates decimal division between two numbers
decimal_divide () {
	numerator=$1
	denominator=$2
	RESULT=$((${numerator}00/$denominator))
	echo "${RESULT:0:-2}.${RESULT: -2}"
}

# Uses sed to replace characters that wkhtmltopdf can't translate with ones that it can.
replace_invalid_chars () {
	fileName=$1

	# Replace the the text "title>" with "h1>" in the previous volume
	sed -i 's/title>/h1>/g' "${fileName}"

	#TODO: Make this sed work on either (make a character set?)
	# Replace all left-side quotation marks (“) with vertical quotes.
	sed -i 's/“/"/g' "${fileName}"
	# Replace all right-side quotation marks (”) with vertical quotes.
	sed -i 's/”/"/g' "${fileName}"

	# Replaces all left-side single-quote marks (‘) with a vertical single-quote.
	sed -i 's/‘/'"'"'/g' "${fileName}"
	# Replaces all right-side single-quote marks (’) with a vertical single-quote.
	sed -i 's/’/'"'"'/g' "${fileName}"

	# Replaces all elipse marks (…) with three period marks.
	sed -i 's/…/.../g' "${fileName}"
}

capture_table_of_contents_royalroad () {
	toc_URL=$1
	#TODO: Check the first and last characters of toc_Id for a /. If they aren't there then add them.

	mkdir toc_working
	#TODO: remove this directory when we are done?
	
	# TODO: rm toc_working/tocInProgress

	logInfo "curling $toc_URL to access table of contents for story."
	httpStatusCode=$(curl $toc_URL -o toc_working/tocInProgress -w "%{http_code}")

	if [[ ! -f toc_working/tocInProgress ]] || [[ ! "$httpStatusCode" =~ \s*^2[0-9][0-9]\s* ]]; then
		# toc_working/tocInProgress doesn't exist or the curl for the table of contents returned a non-200 series status code.
		logError "Failed to download table of contents page for the story: [${storyName}] from the url: [${toc_URL}]. Please check the URL and network connection and try again."
		# In theory it could also be an issue with creating the table of contents files in that directory...
		echo $TOC_DOWNLOAD_FAILURE_MESSAGE
		exit 1;
	fi
	
	## TODO: replace everything from this grep statement all the way down to that uniq statement with a call to extractMatchesByPattern(). TODO: automatically make a regex based on $toc_Id for this.
	## Alternatively, ask the user for a regex?

	grep $toc_Id toc_working/tocInProgress > toc_working/toBeTrimmed

	logInfo "Stripping out illegal characters from ToC file."

	# Strips out html tags from the document.
	sed -i 's/<tr style="cursor: pointer" data-url="//g' toc_working/toBeTrimmed
	sed -i 's/<a href="//g' toc_working/toBeTrimmed
	sed -i 's/<a class="//g' toc_working/toBeTrimmed
	sed -i 's/">//g' toc_working/toBeTrimmed

	# Strips out all spaces.
	sed -i 's/ //g' toc_working/toBeTrimmed

	# Trims off the first 2 lines. These are usually present, always garbage when they show up, and the good links always come in sets of threes, so we're safe to trim of them.
	sed -i 1,2d toc_working/toBeTrimmed

	# Trims off the last line. This is the always-present "reviews" link. Also, usable links always show up in sets of threes, so we're safe to remove it.
	sed -i '$ d' toc_working/toBeTrimmed

	logInfo "De-duplicate filtering ToC"
	uniq toc_working/toBeTrimmed > $tocFileName
}

capture_table_of_contents_wanderinginn () {
	#toc_URL="https://wanderinginn.com/"
	toc_URL=$1
	listStartText="<aside id=\"text-7\""
	#listStartText=$2
	listEndText="</aside"
	#listEndText=$3

	# FIXME: Currently this is getting $2 and $3 in reverse order. I don't know why. Until that's been fixed we need to just hard-code these fields.


	initialFileName="toc_working/toBeTrimmed"
	wipFileName="toc_working/inProgress"
	finalFileName=$tocFileName

	curl $toc_URL > $initialFileName
	logTrace "The full content from [${toc_URL}] was copied into a new file at [${initialFileName}]"

	line1=$(grep -n "$listStartText" toc_working/toBeTrimmed | head -n 1 | cut -f1 -d:)
	line1=$(($line1 + 1))
	logTrace "The listStartText of: [${listStartText}] was found on line: [${line1}] of that file. Everything on and after that line will be copied into the new file: [${wipFileName}]"

	cat toc_working/toBeTrimmed | tail -n +$line1 > $wipFileName

	line2=$(grep -n "$listEndText" -m2 $wipFileName | tail -n1 | head -n 1 | cut -f1 -d:)
	line2=$(($line2 - 1))
	logTrace "The listEndText of: [${listEndText}] was found on line: [${line2}] of that file. Everything before that line will be copied into the new file: [${finalFileName}]"

	cat $wipFileName | head -n $line2 | grep "<a href=" > $finalFileName

	# Filter out every </a>
	sed -i 's/<\/a>//g' $finalFileName

	sed -i 's/<p><strong>Volume [0-9]\+//g' $finalFileName
	sed -i 's/<\/strong><\/p>//g' $finalFileName

	# Filter out every <br />
	sed -i 's/<br\s*\/>//g' $finalFileName

	sed -i 's/<p style="padding-left:30px;">//g' $finalFileName
	sed -i 's/<a href=//g' $finalFileName
	sed -i 's/<\/p>//g' $finalFileName

	sed -i 's/>/ /g' $finalFileName
	
	logTrace "The final toc file: [${finalFileName}] has been stripped of its html tags and is ready for parsing."
}

# This is used to extract links from a page, either chapter links from a TOC or image links from a regular page.
extractMatchesByPattern () {
	linkPattern=$1
	input=$2

	for word in $(cat $input); do
		# Check to see if the current word matches the linkPattern.
		[[ $word =~ $linkPattern ]]

		# If a match to the linkPattern has been found...
		if [[ ${BASH_REMATCH[0]} ]]; then
			# Echo the text of the match to std_out.
			echo ${BASH_REMATCH[0]}
		fi
	done
}

# List return values and error messages here.

TOC_DOWNLOAD_FAILURE_MESSAGE="Failed to downlaod toc"

##### Parameters #####

# This normally starts at zero.
# TODO: Make a step that counts the number of files in "chapters" and sets this value to the result...
startChapter=0
# This normally starts at zero.
# TODO: Make a step that counts the number of files in "output" and sets this value to the result...
let startVolumeNumber=1
# TODO: Determine if I want to preserve the toc in with the chapters. Since I can make HashMaps, keeping this around might let me determine if chapters ever disappear. Ex: When the author decides they want to publish book 1, but starts putting chapters from book 2 onto the same RoyalRoad fiction.
tocFileName="toc_working/final-latest";

let index=$startChapter+1;
chapterCount=$startChapter;

# The first new chapter found that doesn't already exist within a story's chapters directory. Usually set to 0 when the first chapter is downloaded, but on subsequent runs this will be a higher number. Used to prevent unnecessary work when generating volumes.
let firstNewChapter=0
((firstNewChapter = 0 - 1))

# example toc_URL: https://www.royalroad.com/fiction/14167/metaworld-chronicles
toc_LinkRoot="https://www.royalroad.com"

skipToc="false"
skipChapters="false"
skipVolumes="false"

recreateVolumes="false"
redownloadChapters="false"

firstLineInclusive="false"
lastLineInclusive="false"

#Controls whether or not to run in the mode dedicated to capturing chapters from www.wanderininn.com
wanderinginnMode="false"

# In RoyalRoad stories this text corresponds to the div that contains the chapter's content.
chapterStartText="chapter-inner chapter-content"

# In RoyalRoad stories this text corresponds to an Advertisement that shows up immediately after the chapter-content element ends.
chapterEndText="bold uppercase text-center"

# In the event that chapterEndText can't be found, this value is used instead.
# This (totally not a hack) solution was added because some sites (Reign of Hunters) change their formatting midway through...
# Overwrites the text used for finding the end of a filechapterEndText
backupEndText="Previous Chapter"

# TODO: Add comments explaining these two values...
# Also mention that they overwrite --lastLineInclusive and --firstLineInclusive if they are set.
firstLineOffset=0
lastLineOffset=0
backupEndLineOffset=0

fontSize=400

let storyName

# TODO: Add a help option...

# Loop through arguments and process them
for arg in "$@"
do
	case $arg in
		-h|--help)
		echo "Sorry, I haven't written the help message yet."
		outputResults 0
		exit 0;
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
		storyName="${arg#*=}_"
		shift
		;;
		-r|--recreate-volumes)
		# recreates volume files regardless of whether or not their chapter files were found
		# Defaults to false if not set here.
		recreateVolumes="true"
		shift
		;;
		-a|--redownload-all)
		# recreates chapter files regardless of whether or not they already exist in the chapters directory, and then recreates the resulting volumes with the new chapters.
		redownloadChapters="true"
		shift
		;;
		-t=*|--toc=*)
		# A user-provided table-of-contents. Skips the step to download the TOC.
		skipToc="true"
		tocFileName="${arg#*=}"
		shift
		;;
		-s|--skip-chapters)
		# skip the toc-download and chapter-download steps. This uses an existing chapters directory for generating volumes.
		skipToc="true"
		skipChapters="true"
		shift
		;;
		-o|--only-chapters)
		# run the toc-download and chapter-download steps but not the volume step.
		skipVolumes="true"
		shift
		;;
		-f|--font-size=*)
		# Overwrites the font size applied in the pdfs.
		# Warning: this is still buggy.
		fontSize="${arg#*=}"
		shift
		;;
		--start-text=*)
		# Overwrites the text used for finding the end of a filechapterEndText
		chapterStartText="${arg#*=}"
		shift
		;;
		--first-line-inclusive)
		# causes the scritp to treat chapterStartText as the first line of the chapter instead of the line one before it starts.
		firstLineInclusive="true"
		shift
		;;
		--last-line-inclusive)
		# causes the scritp to treat filechapterEndText as the last line of the chapter instead of the line one after it ends.
		lastLineInclusive="true"
		shift
		;;
		--first-line-offset=*)
		# TODO: Documentation
		firstLineOffset="${arg#*=}"
		shift
		;;
		--last-line-offset=*)
		# TODO: Documentation
		lastLineOffset="${arg#*=}"
		shift
		;;
		--backup-end-line-offset=*)
		# TODO: Documentation
		backupEndLineOffset="${arg#*=}"
		shift
		;;
		--end-text=*)
		# Overwrites the text used for finding the end of a filechapterEndText
		chapterEndText="${arg#*=}"
		shift
		;;
		--backup-end-text=*)
		# Overwrites the text used for finding the end of a backupEndText
		backupEndText="${arg#*=}"
		shift
		;;
		-q|--quiet)
		# Suppresses some of the logging to limit what appears in log files.
		# Not compatible with --verbose.
		quietMode="true"
		verboseMode="false"
		shift
		;;
		-v|--verbose)
		# Adds more detail to log files where possible.
		# Not compatible with --quiet.
		verboseMode="true"
		quietMode="false"
		shift
		;;
		-w|--wandering-inn)
		# Adds more detail to log files where possible.
		# Not compatible with --quiet.
		wanderinginnMode="true"
		toc_Id="https://wanderinginn.com/"

		## TODO: Set the chapterStartText and chapterEndText here!
		## Remember, it needs to work on both the original wordpress pages and the new ones directly on www.wanderinginn.com
		## It might work to use chapterStartText, chapterEndText, and backupEndText
		chapterStartText="<div class=\"entry-content\">"
		#chapterEndText="<p>(<span.*>)?<a href=.*>Previous Chapter"
		chapterEndText="<a href=.*>Previous Chapter"
		#backupEndText="<p>(<span.*>)?<a href=.*>Next Chapter"
		backupEndText="<a href=.*>Next Chapter"
		lastLineOffset=2;
		shift
		;;
		*)
		OTHER_ARGUMENTS+=("$1")
		shift # Remove generic argument from processing
		;;
	esac
done

# If firstLineInclusive was set and firstLineOffset was not set then set firstLineOffset to -1.
if [[ $firstLineOffset -eq 0 && $firstLineInclusive = "true" ]]; then
	# If the pattern for the "start text" is actually the first line and not the line one before the first, we want to decrease $line1 by 1 so the last line will be kept.
	firstLineOffset=-1
	logInfo "firstLineInclusive was true. New value for the starting line of the chapter is: [$line2]"
fi

# Commented-out while trying to work-in handling for backupEndText... (It needs a different offset)
# If lastLineInclusive was set and lastLineOffset was not set then set lastLineOffset to 1.
if [[ $lastLineOffset -eq 0 && $lastLineInclusive = "true" ]]; then
	# If the pattern for the "end text" is actually the last line and not the line one after the end, we want to increase $line2 by 1 so the last line will be kept.
	lastLineOffset=1
	logInfo "lastLineInclusive was true. New value for the ending line of the chapter is: [$line2]"
fi

##### Main: ####

outputDir="./${storyName}output"
logFilePath="${storyName}log.txt"
# TODO: add a means of rotating logs?

############### Section for downloading TOC. 
if [[ $skipToc = "false" ]]; then
	if [[ $wanderinginnMode = "false" ]]; then
		# call the method for creating the standard toc here and put it into $tocFileName
		toc_URL=${toc_LinkRoot}${toc_Id}
		capture_table_of_contents_royalroad $toc_URL
	else
		# call the method for creating the wanderinginn.com-specific toc here and put it into $tocFileName
		toc_LinkRoot=""
		toc_URL=${toc_Id}
		tocStartText="<aside id=\"text-7\""
		tocEndText="</aside"
		
		logTrace "The tocStartText is: [${tocStartText}]"
		logTrace "The tocEndText is: [${tocEndText}]"
		
		capture_table_of_contents_wanderinginn $toc_URL $tocStartText $tocEndText
	fi
fi

################ Section for downloading chapter files:

if [[ $skipChapters = "true" ]]; then
	firstNewChapter=1
else
	#TODO: Preface the chapters, toc_working, and output directories with a title param passed in by the user-parameter
	# to identifiy the story.
	logInfo "Copying chapters from site to local directory: [${storyName}chapters]."
	if [ ! -d "${storyName}chapters" ]; then
		mkdir "${storyName}chapters";
	fi

	unformattedURL=$line

	while read line; do
		if [[ $wanderinginnMode = "true" ]]; then
			# This Regular Expression pattern splits the line into two portions and use the second half for nextChapterName
			newRegex="\"(.*)\" (.*)"
			if [[ $line =~ $newRegex ]]; then
				# Sets the chapter's url to the text between the quotation marks before the fist space and removes the text ".wordpress" from the url if it exists.
				unformattedURL="${BASH_REMATCH[1]//.wordpress/}"

				# Sets the chapter's fileName to the text after the first space outside a quote mark and replaces any spaces in it chapterTitle with underscores.
				chapterTitle="${BASH_REMATCH[2]// /_}"
				nextChapterName="${storyName}chapters/chapter_${index}_${chapterTitle}.html"
			else
				logInfo "The line [${line}] doesn't match the expected pattern for a url followed by a name. It will be skipped." >&2
				# TODO: put a "continue" statement here...
			fi
		else
			# The normal case of operations goes here.
			nextChapterName="${storyName}chapters/chapter_${index}.html"
		fi

		# If the current url does not contain a period, ensure it ends in exactly one slash mark
		#if [[ ! $unformattedURL =~ '/'$ ]] && [[ ! "$unformattedURL" == *"\."* ]]; then
		if [[ "$(basename $unformattedURL)" == *"."* ]]; then
			logTrace "Chapter URL contained a period. An additional slash mark will be added to the end."
			unformattedURL="${unformattedURL}/"
		else
			# Removes every slash mark from the end of the current url and then add one to the end.
			logTrace "The chapter name did not contain a period. Only one slash mark will be retained."

			# This uses weird bash pattern-matching voodoo to set and remove the suffix for the unformattedURL, but it does this by setting a prefix that is everything in the string except the trailing slashes.
			unformattedURL=${unformattedURL%"${unformattedURL##*[!/]}"}/;
		fi

		# TODO: Add a check to see if the whole file is less than 50 characters?
		# TODO: Try and extract the chapter name from the url?
		# And do what with it?
		if [[ $redownloadChapters = "false" ]] && [ -f $nextChapterName ]; then
			# Echoing a blank line for clarity when logging...
			logInfo "Chapter number ${index} already exists and is saved under the file name ${nextChapterName}. It will not be re-downloaded."
		else
			if [ $firstNewChapter -lt 0 ]; then
				logInfo "The first new chapter found was: $firstNewChapter, and it is now being set to $index"
				firstNewChapter=$index
			fi
			# TODO: Make a command-line flag that controls whether the latest volume is completely recreated with the new chapters added or if a new volume is produced instead.
				# Ex: If only 24 chapters were originally produced and now 35 exist the default behavior would be to completely recreate volume_1, however this flag would change the behavior so that chapters 25-35 would instead go into a new volume named volume_1.2

			# The url begins with the link root and ends with the first space in the current line. Anything after that is cut off.
			url=${toc_LinkRoot}$(echo $unformattedURL | cut -f1 -d' ')

			# Echoing a blank line for clarity when logging...
			logInfo "Downloading chapter #${index} from the url: ${url} and saving it under the name ${nextChapterName}"

			curl $url > $nextChapterName
		fi

		index=$((index+1))
		chapterCount=$index
	done < $tocFileName
fi

if [[ $skipVolumes = "true" ]]; then
	echo "Skipping the volume generation step. Exiting now."
	logInfo "Skipping the volume generation step. Exiting now."
	exit 0;
fi

# TODO: Make this a value users can overwrite
# WARNING: When using --update mode take care to always use the same value for chaptersPerFile. If an update is being made this tool assumes existing volumes already have the specified number of files. If, for example, 800 chapters were saved with each volume holding 50 chapters, and update is run with a new setting for 60 chapters per file, the tool will believe chapter 801 should go into volume 13, not 17. As a result every volume from 1 to 12 will have 50 sequential chapters, for with volume 12 ending at chapter 600. Then volume 13 will skip ahead to chapter 780. Also, depending on the number of new chapters, later volumes may or may not be overwritten at all. Such as if only chapters 801 to 810 were newly available. In that instance volume 13 would contain chapters 780 to 810, and then volumes 14 to 16 would still contain chapters 651 to 800.
	# Note to self "--update mode" is a planned feature, one that will preserve existing volumes when new chapters are found and only update the ones missing them/generate new volumes as needed.
		# Alternatively, whenever we allow users to specify a new volume size, force it to recreate the volumes.
let chaptersPerFile=50;

logInfo "/n"

if [[ $recreateVolumes = "true" ]]; then
	firstNewChapter=1
fi

logInfo "The first new chapter found was $firstNewChapter"

# If the variable firstNewChapter has not been set then no new chapters were found.
if [ $firstNewChapter -lt 0 ]; then
	log "No new chapters were found. Therefore, no volumes need to be created."
	outputResults 0
	exit 0;
else
	# FIXME: This section isn't working...
	chaptersPerFile=$(max $chaptersPerFile 1)

	if [ $firstNewChapter -lt $chaptersPerFile ]; then
		startVolumeNumber=1
	else
		# Divide the new chapter by the number of chapters per volume and preserve the decimal places.
		startVolumeNumber=$(decimal_divide $firstNewChapter $chaptersPerFile)

		# Round that number up to the nearest value.
		startVolumeNumber=$(echo $startVolumeNumber | awk '{print int($1+0.5)}')

		# Ensure that value is at least 1.
		startVolumeNumber=$(max $startVolumeNumber 1)
		logInfo "The first volume that contains new chapters will be $startVolumeNumber"
	fi

	((startChapter = (startVolumeNumber - 1) * 50 + 1))
	#startChapter=$(max $startChapter 1)
	logInfo "The first chapter to include in that volume is $startChapter"
fi

let volumeNumber=$startVolumeNumber;
let counter=1;

mkdir $outputDir

#Appends the opening HTML tags to the first volume file.
HTML_OPENING_TAGS="<!DOCTYPE html> <html> <head> </head> <body>"
HTML_FONT_SIZE_VALUE=$fontSize
HTML_STYLE_TAG="<style>p { font-size: "$HTML_FONT_SIZE_VALUE"%}</style>"
HTML_CHAPTER_TITLE_OPENING_TAG="<h1>"
HTML_CHAPTER_TITLE_CLOSING_TAG="</h1>"
HTML_CLOSING_TAGS="</body></html>"

logInfo "Combining chapter contents into logical html volumes and then converting them to pdf files."

echo $HTML_OPENING_TAGS $HTML_STYLE_TAG > "${outputDir}/${storyName}volume_${volumeNumber}.html"

## Setting chapter count here, unfortunately as a string...
chapterCount=$(ls ${storyName}chapters/chapter_*.html | wc -l)
## Converting chapterCount back into an integer here...
chapterCount=$(($chapterCount + 0))

# This line uses integer division to determine the last volume that will have $chaptersPerFile number of chapters. (Bash uses integer division, so the decimal value is stripped off here.).
lastCompleteVolume=$(($chapterCount / $chaptersPerFile))
# Now that the decimal value has been removed, re-multiplying by $chaptersPerFile produces the number of volumes that will be "complete" (they will have $chaptersPerFile number of chapters).
lastChapterInACompleteVolume=$(($lastCompleteVolume * $chaptersPerFile))
# This is the number of chapters that will appear in the last volume if it is an "incomplete" volume (one with fewer than $chapterCount chapters). If no chapters would be left to go into an "incomplete" volume then this value will be zero. 
# Note, mathematically speaking, $lastChapterInACompleteVolume cannot be greater than $chapterCount. It can only be fewer or equal. If it is fewer then $chapterCountOfIncompleteVolume will be used for the length of the last chapter. If it is equal then $chaptersPerFile will be used instead.
chapterCountOfIncompleteVolume=$(($chapterCount - $lastChapterInACompleteVolume))

logInfo "About to loop over all of the files in ./${storyName}chapters/, from chapter_ ${startChapter}.html to ${chapterCount}.html"
for (( currentChapter=$startChapter; currentChapter<=$chapterCount; currentChapter++ ))
do
	let chaptersInThisVolume=$chaptersPerFile

	if (( $currentChapter > $chapterCountOfIncompleteVolume )); then
		chaptersInThisFile=$chapterCountOfIncompleteVolume
	fi
	
	file="./${storyName}chapters/chapter_${currentChapter}_*.html"
	if (( $counter > $chaptersInThisVolume)); then
		logInfo "While constructing volume number [${volumeNumber}], [${chaptersInThisVolume}] out of [${chaptersInThisVolume}] chapters were included. The volume will now be finalized and chapter number [${counter}] will be included in the next volume."

		currentOutputFileName="${outputDir}/${storyName}volume_${volumeNumber}.html"

		#Appends the ending HTML tags to the previous volume file.
		echo $HTML_CLOSING_TAGS >> "${currentOutputFileName}"

		replace_invalid_chars "${currentOutputFileName}"

		#Convert the previous html file to a pdf.
		logInfo "Creating pdf from volume #${volumeNumber}"
		# TODO: Make this a relative path, an actual command, or just a parameter...
		# TODO: Make this an optional step, controlled by a user-parameter
		/c/Program\ Files/wkhtmltopdf/bin/wkhtmltopdf.exe "${currentOutputFileName}" ${storyName}volume_$volumeNumber.pdf

		volumeNumber=$((volumeNumber+1));
		counter=1;

		#Appends the opening HTML tags to the new volume file.
		echo $HTML_OPENING_TAGS $HTML_STYLE_TAG > "${outputDir}/${storyName}volume_${volumeNumber}.html"

		logInfo "Resetting internal counter to ${counter} and beginning volume number ${volumeNumber}"
	else 
		logInfo "Parsing content from chapter ${counter} out of ${chaptersInThisVolume} for volume number ${volumeNumber}"
	fi

	currentOutputFileName="${outputDir}/${storyName}volume_${volumeNumber}.html"
	logInfo "Parsing ${file} and piping it into ${currentOutputFileName}"

	currentChapterHeading="${HTML_CHAPTER_TITLE_OPENING_TAG}Chapter ${counter}/${chaptersInThisVolume} ${HTML_CHAPTER_TITLE_CLOSING_TAG}"
	logInfo "Current chapter heading: [${currentChapterHeading}]"
	echo $currentChapterHeading >> "${currentOutputFileName}"

	# If there is a title element in this file, append that whole line to the volume document.
	grep "<title>Chapter [0-9]" $file >> "${currentOutputFileName}"
	
	## FIXME: Replace the above grep with a better one that only puts in the title element, and nothing besides that.

	# line1 is where the chapter's content starts.
	line1=$(grep -n "$chapterStartText" $file | head -n 1 | cut -f1 -d:)
	logTrace "Chapter ${counter} begins at line: [$line1]"

	line1=$(($line1 - $firstLineOffset))

	# If chapterEndText exists within the file, set line2 to the line number where it first appears.
	if [[ $(grep -n "$chapterEndText" $file) ]]; then
		# line2 is where the chapter's content ends.
		line2=$(grep -n "$chapterEndText" $file | head -n 1 | cut -f1 -d:)
		line2=$(($line2 - $lastLineOffset))
		logTrace "Chapter ${counter} ends at line: [$line2]"
	else
		# If chapterEndText does not exist within the file, use backupEndText instead of chapterEndText to determine where the chapter text ends.
		line2=$(grep -n "$backupEndText" $file | head -n 1 | cut -f1 -d:)
		line2=$(($line2 - $backupEndLineOffset))
		logTrace "Chapter ${counter} ends at line: [$line2]"
	fi

	#line2=$(($line2 - $lastLineOffset))

	# Notice: this is a non-inclusive match (at least as far as line2 goes). This means we're successfully snipping out the advertisements element on line2!
	# We are appending the found text to the current volume file
	if [ -z $line1 ] || [ -z $line2 ]; then 
		echo "failed to parse content of chapter number $counter." >> "${currentOutputFileName}"
		logError "failed to parse content of chapter number $counter."
	else
		cat $file | tail -n +$line1 | head -n $((line2-line1)) >> "${currentOutputFileName}"
	fi
	
	# tr -s '\n' ' ' < chapter_1.html | tr -s '\r\n' ' ' > altered.html
	# grep -oP "$shortPattern" ./altered.html
	
	# tr -s '\n' ' ' < chapter_1.html | tr -s '\r\n' ' ' | grep -oP "$pattern" >>  "${currentOutputFileName}"

	# Appending a horizontal rule after the end of the current volume.
	echo "<hr>"  >> "${currentOutputFileName}"
	counter=$((counter+1));
done

# TODO: This one shouldn't be necessary. Confirm it isn't and then remove it.
#currentOutputFileName="${outputDir}/${storyName}volume_${volumeNumber}.html"

#Appends the ending HTML tags to the previous volume file.
echo $HTML_CLOSING_TAGS >> "${currentOutputFileName}"

replace_invalid_chars "${currentOutputFileName}"

# Convert the last html file to a pdf.
logInfo "Creating pdf from volume #${volumeNumber}"

# TODO: Make this a relative path, an actual command, or just a parameter...
# TODO: Make this an optional step, controlled by a user-parameter
/c/Program\ Files/wkhtmltopdf/bin/wkhtmltopdf.exe "${currentOutputFileName}" "${storyName}volume_${volumeNumber}.pdf"
