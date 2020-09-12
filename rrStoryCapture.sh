#! /bin/bash

##### This is a script for copying the entirety of a freely-published work from the popular website RoyalRoad.com and saving it off to the local filesystem as a set of pdf files.
## Currently it only works for RoyalRoad pages, all of which are publicly available. This script is not intended for any ilicit purposes.
## The script relies on the freely-distributed tool wkhtmltopdf for the final conversion from html to pdf. If that step is not necessary then the dependency is unnecessary and those failed lines will not stop the rest of the script from running.
# @Author: bcavanaugh
# @Created: 9/18/19
# @LastModified: 9/12/20


### Planned improvements:
# Rename the "chapters" and "output" directories to be specific to the story's title, allowing multiple stories to be saved off in the same parent directory without overwriting.
# -q and -v modes, controlling the amount of logging.
# options for skipping the curling and controls for only curling new chapters (along with code to determine which volumes need to be recreated so the new chapters can be included).
# An option to skip the conversion to pdf.
# Reduce the URL and Id to one value (have the code pull out everything after the website name and generate the id...)
# Splitting the individual pieces into functions?
# Make the path to wkhtmltopdf a parameter.
# Params for overwriting the root url and search strings?
# A param for changing the font-size style in the resulting HTML.

# Returns the greater of two numbers provided.
max () {
	a=$1
	b=$2
	output=$(( a > b ? a : b ))
	echo $output
	return $output
}

decimal_divide () {
	numerator=$1
	denominator=$2
	RESULT=$((${numerator}00/$denominator))
	echo "${RESULT:0:-2}.${RESULT: -2}"
}

# This normally starts at zero.
# TODO: Make a step that counts the number of files in "chapters" and sets this value to the result...
startChapter=0
# This normally starts at zero.
# TODO: Make a step that counts the number of files in "output" and sets this value to the result...
let startVolumeNumber=1
tocFileName="final-latest";

let index=$startChapter+1;
chapterCount=$startChapter;

# The first new chapter found that doesn't already exist within a story's chapters directory. Usually set to 0 when the first chapter is downloaded, but on subsequent runs this will be a higher number. Used to prevent unnecessary work when generating volumes.
let firstNewChapter=0
((firstNewChapter = 0 - 1))

toc_LinkRoot="https://www.royalroad.com"
toc_Id=$1
toc_URL=$toc_LinkRoot$toc_Id

let storyName
## TODO: Check $2. If it is populated then set storyName="$2-"
if [[ ! -z "$2" ]]; then 
  storyName=${2}"_"
fi

outputDir="./${storyName}output"

# example toc_Id: /fiction/14167/metaworld-chronicles/
# example toc_URL: https://www.royalroad.com/fiction/14167/metaworld-chronicles

#TODO: Check the first and last characters of toc_Id for a /. If they aren't there then add them.


mkdir toc_working
#TODO: remove this directory when we are done...

echo "curling $toc_URL to access table of contents for story."
curl $toc_URL > toc_working/tocInProgress

grep $toc_Id toc_working/tocInProgress > toc_working/toBeTrimmed

echo "Stripping out illegal characters from ToC file."

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

echo "De-duplicate filtering ToC"
uniq toc_working/toBeTrimmed > toc_working/$tocFileName

#TODO: Preface the chapters, toc_working, and output directories with a title param passed in by the user-parameter
# to identifiy the story.
echo "Copying chapters from site to local directory: [${storyName}chapters]."
if [ ! -d "${storyName}chapters" ]; then
	mkdir "${storyName}chapters";
fi

while read line; do
	nextChapterName="${storyName}chapters/chapter_${index}.html"
	# TODO: Add a check to see if the whole file is less than 50 characters?
	# TODO: Try and extract the chapter name?
	# And do what with it?
	# TODO: Add a flag that ignores this check and re-downloads all of the chapters regardless.
	if [ -f $nextChapterName ]; then
		# Echoing a blank line for clarity when logging...
		echo "\n"
		echo "Chapter number ${index} already exists and is saved under the file name ${nextChapterName}. It will not be re-downloaded."
	else
		if [ $firstNewChapter -lt 0 ]; then
			#echo "The first new chapter found was: $firstNewChapter, and it is now being set to $index"
			firstNewChapter=$index
		fi
		# TODO: Make a listing of all of the exclusively new chapters. If they all exist at the end of the TOC, then we know they're all new. New chapters all get bundled into a single new volume.
		# TODO: Make a command-line flag that controls whether the latest volume is completely recreated with the new chapters added or if a new volume is produced instead.
			# Ex: If only 24 chapters were originally produced and now 35 exist the default behavior would be to completely recreate volume_1, however this flag would change the behavior so that chapters 25-35 would instead go into a new volume named volume_1.2

		url=$toc_LinkRoot$line
		# Echoing a blank line for clarity when logging...
		echo "\n"
		echo "Downloading chapter #${index} from the url: ${url} and saving it under the name ${nextChapterName}"

		curl $url > $nextChapterName
	fi

	index=$((index+1))
	chapterCount=$index
done < toc_working/$tocFileName

# TODO: Make this a value users can overwrite
# WARNING: When using --update mode take care to always use the same value for chaptersPerFile. If an update is being made this tool assumes existing volumes already have the specified number of files. If, for example, 800 chapters were saved with each volume holding 50 chapters, and update is run with a new setting for 60 chapters per file, the tool will believe chapter 801 should go into volume 13, not 17. As a result every volume from 1 to 12 will have 50 sequential chapters, for with volume 12 ending at chapter 600. Then volume 13 will skip ahead to chapter 780. Also, depending on the number of new chapters, later volumes may or may not be overwritten at all. Such as if only chapters 801 to 810 were newly available. In that instance volume 13 would contain chapters 780 to 810, and then volumes 14 to 16 would still contain chapters 651 to 800.
	# Note to self "--update mode" is a planned feature, one that will preserve existing volumes when new chapters are found and only update the ones missing them/generate new volumes as needed.
let chaptersPerFile=50;

echo "/n"
echo "The first new chapter found was $firstNewChapter"

## TODO: Add a command-line flag to this script that, when provided, sets firstNewChapter to 1. That will force the recreation of all volumes.

# If the variable firstNewChapter has not been set then no new chapters were found.
if [ $firstNewChapter -lt 0 ]; then
	echo "No new chapters were found. Therefore, no volumes need to be created."
	exit 0;
else
	chaptersPerFile=$(max $chaptersPerFile 1)

	# Divide the new chapter by the number of chapters per volume and preserve the decimal places.
	startVolumeNumber=$(decimal_divide $firstNewChapter $chaptersPerFile)

	# Round that number up to the nearest value.
	startVolumeNumber=$(echo $startVolumeNumber | awk '{print int($1+0.5)}')

	# Ensure that value is at least 1.
	startVolumeNumber=$(max $startVolumeNumber 1)
	echo "The first volume that contains new chapters will be $startVolumeNumber"

	((startChapter = (startVolumeNumber - 1) * 50 + 1))
	#startChapter=$(max $startChapter 1)
	echo "The first chapter to include in that volume is $startChapter"
fi

let volumeNumber=$startVolumeNumber;
let counter=1;

mkdir $outputDir

#Appends the opening HTML tags to the first volume file.
HTML_OPENING_TAGS="<!DOCTYPE html> <html> <head> </head> <body>"
# TODO: Make a param for controlling this value.
HTML_FONT_SIZE_VALUE=400
HTML_STYLE_TAG="<style>p { font-size: "$HTML_FONT_SIZE_VALUE"%}</style>"
HTML_CHAPTER_TITLE_OPENING_TAG="<h1>"
HTML_CHAPTER_TITLE_CLOSING_TAG="</h1>"
HTML_CLOSING_TAGS="</body></html>"

echo "Combining chapter contents into logical html volumes and then converting them to pdf files."

echo $HTML_OPENING_TAGS $HTML_STYLE_TAG > "${outputDir}/${storyName}volume_${volumeNumber}.html"

## Setting chapter count here, unfortunately as a string...
chapterCount=$(ls ${storyName}chapters | wc -l)
## Converting chapterCount back into an integer here...
chapterCount=$(($chapterCount + 0))

echo "About to loop over all of the files in ./${storyName}chapters/, from chapter_ ${startChapter}.html to ${chapterCount}.html"
for (( currentChapter=$startChapter; currentChapter<=$chapterCount; currentChapter++ ))
do
	file="./${storyName}chapters/chapter_${currentChapter}.html"
	if (( $counter >= $chaptersPerFile)); then
		echo "Reached chapter ${counter} out of ${chaptersPerFile} for volume number ${volumeNumber}. Finalizing volume now."

		#Appends the ending HTML tags to the previous volume file.
		echo $HTML_CLOSING_TAGS >> "${outputDir}/${storyName}volume_${volumeNumber}.html"

		# Replace the the text "title>" with "h1>" in the previous volume
		sed -i 's/title>/h1>/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

		#TODO: Make this sed work on either (make a character set?)
		# Replace all left-side quotation marks (“) with vertical quotes.
		sed -i 's/“/"/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"
		# Replace all right-side quotation marks (”) with vertical quotes.
		sed -i 's/”/"/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

		# Replaces all left-side single-quote marks (‘) with a vertical single-quote.
		sed -i 's/‘/'"'"'/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"
		# Replaces all right-side single-quote marks (’) with a vertical single-quote.
		sed -i 's/’/'"'"'/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

		# Replaces all elipse marks (…) with three period marks.
		sed -i 's/…/.../g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

		#Convert the previous html file to a pdf.
		echo "Creating pdf from volume #"$volumeNumber
		# TODO: Make this a relative path, an actual command, or just a parameter...
		# TODO: Make this an optional step, controlled by a user-parameter
		/c/Program\ Files/wkhtmltopdf/bin/wkhtmltopdf.exe "${outputDir}/${storyName}volume_${volumeNumber}.html" volume_$volumeNumber.pdf

		volumeNumber=$((volumeNumber+1));
		# FIXME: Make counter start at 1, make this loop run while counter <= chaptersPerFile and remove the places where I'm logging counter + 1
		counter=1;

		#Appends the opening HTML tags to the new volume file.
		echo $HTML_OPENING_TAGS $HTML_STYLE_TAG > "${outputDir}/${storyName}volume_${volumeNumber}.html"

		echo "Resetting counter to ${counter} and beginning volume number ${volumeNumber}"
	else 
		echo "parsing content from chapter ${counter} out of ${chaptersPerFile} for volume number ${volumeNumber}"
	fi
	
	echo "Parsing $file and piping it into "${outputDir}/${storyName}volume_${volumeNumber}.html""
	
	echo "${HTML_CHAPTER_TITLE_OPENING_TAG}Chapter ${counter}/${chaptersPerFile} ${HTML_CHAPTER_TITLE_CLOSING_TAG}" >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
	
	grep "<title>Chapter [0-9]" $file >> "${outputDir}/${storyName}volume_${volumeNumber}.html"

	# line1 corresponds to the div that contains the chapter's content.
	line1=$(grep -n "chapter-inner chapter-content" $file | cut -f1 -d:)
	# line2 corresponds to an Advertisement that shows up immediately after the chapter-content element ends.
	line2=$(grep -n "bold uppercase text-center" $file | cut -f1 -d:)

	# Notice: this is a non-inclusive match (at least as far as line2 goes). This means we're successfully snipping out the advertisements element on line2!
	# We are appending the found text to the current volume file
	if [ -z $line1 ] || [ -z $line2 ]; then 
		echo "failed to parse content of chapter number $counter."  >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
	else
		cat $file | tail -n +$line1 | head -n $((line2-line1)) >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
	fi

	# Appending a horizontal rule after the end of the current volume.
	echo "<hr>"  >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
	counter=$((counter+1));
done

# Appends the ending HTML tags to the last volume file.
echo $HTML_CLOSING_TAGS >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
#Appends the ending HTML tags to the previous volume file.

# Replace the the text "title>" with "h1>" in the previous volume
sed -i 's/title>/h1>/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

#TODO: Make this sed work on either (make a character set?)
# Replace all left-side quotation marks (“) with vertical quotes.
sed -i 's/“/"/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"
# Replace all right-side quotation marks (”) with vertical quotes.
sed -i 's/”/"/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

# Replaces all left-side single-quote marks (‘) with a vertical single-quote.
sed -i 's/‘/'"'"'/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"
# Replaces all right-side single-quote marks (’) with a vertical single-quote.
sed -i 's/’/'"'"'/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

# Replaces all elipse marks (…) with three period marks.
sed -i 's/…/.../g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

# Replace the the text "title>" with "h1>" in the last volume
sed -i 's/title>/h1>/g' "${outputDir}/${storyName}volume_${volumeNumber}.html"

# Convert the last html file to a pdf.
echo "Creating pdf from volume #"$volumeNumber
# TODO: Make this a relative path, an actual command, or just a parameter...
# TODO: Make this an optional step, controlled by a user-parameter
/c/Program\ Files/wkhtmltopdf/bin/wkhtmltopdf.exe "${outputDir}/${storyName}volume_${volumeNumber}.html" "${storyName}volume_${volumeNumber}.pdf"
