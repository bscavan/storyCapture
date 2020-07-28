#! /bin/bash

##### This is a script for copying the entirety of a freely-published work from the popular website RoyalRoad.com and saving it off to the local filesystem as a set of pdf files.
## Currently it only works for RoyalRoad pages, all of which are publicly available. This script is not intended for any ilicit purposes.
## The script relies on the freely-distributed tool wkhtmltopdf for the final conversion from html to pdf. If that step is not necessary then the dependency is unnecessary and those failed lines will not stop the rest of the script from running.
# @Author: bcavanaugh
# @Created: 9/18/19
# @LastModified: 6/24/20


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


# This normally starts at zero.
# TODO: Make a step that counts the number of files in "chapters" and sets this value to the result...
startChapter=0
# This normally starts at zero.
# TODO: Make a step that counts the number of files in "output" and sets this value to the result...
let startVolumeNumber=1
tocFileName="final-latest";

let index=$startChapter+1;
chapterCount=$startChapter;

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

echo "De-duplicate filtering ToC"
uniq toc_working/toBeTrimmed > toc_working/$tocFileName

#TODO: Preface the chapters, toc_working, and output directories with a title param passed in by the user-parameter
# to identifiy the story.
echo "Copying chapters from site to local directory: [${storyName}chapters]."
if [ ! -d "${storyName}chapters" ]; then
	mkdir "${storyName}chapters";

	while read line; do
		url=$toc_LinkRoot$line
		# Echoing a blank line for clarity when logging...
		echo "\n"
		echo "Curling chapter #" $index "from url: $url"
		
		curl $url > "${storyName}chapters/chapter_${index}.html"
		index=$((index+1))
		chapterCount=$index
	done < toc_working/$tocFileName
fi

# TODO: Make this a value users can overwrite
let chaptersPerFile=50;
let volumeNumber=$startVolumeNumber;
let counter=0;

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

if [ $startChapter -eq 0 ]; then
	startChapter=1
fi

## TODO: Once the following loop is confirmed to work with the "ls | wc -l" command, cut out the previous solution for counting the chapters...

echo "About to loop over all of the files in ./${storyName}chapters/, from chapter_ ${startChapter}.html to ${chapterCount}.html"
for (( currentChapter=$startChapter; currentChapter<=$chapterCount; currentChapter++ ))
do
	file="./${storyName}chapters/chapter_${currentChapter}.html"
	if (( $counter > $chaptersPerFile)); then
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
		counter=0;

		#Appends the opening HTML tags to the new volume file.
		echo $HTML_OPENING_TAGS $HTML_STYLE_TAG > "${outputDir}/${storyName}volume_${volumeNumber}.html"

		echo "Resetting counter to ${counter} and beginning volume number ${volumeNumber}"
	else 
		echo "parsing content from chapter ${counter} out of ${chaptersPerFile} for volume number ${volumeNumber}"
	fi
	
	echo "Parsing $file and piping it into "${outputDir}/${storyName}volume_${volumeNumber}.html""
	
	echo "${HTML_CHAPTER_TITLE_OPENING_TAG}Chapter $((counter+1))${HTML_CHAPTER_TITLE_CLOSING_TAG}" >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
	
	grep "<title>Chapter [0-9]" $file >> "${outputDir}/${storyName}volume_${volumeNumber}.html"

	# line1 corresponds to the div that contains the chapter's content.
	line1=$(grep -n "chapter-inner chapter-content" $file | cut -f1 -d:)
	# line2 corresponds to an Advertisement that shows up immediately after the chapter-content element ends.
	line2=$(grep -n "bold uppercase text-center" $file | cut -f1 -d:)

	# Notice: this is a non-inclusive match (at least as far as line2 goes). This means we're successfully snipping out the advertisements element on line2!
	# We are appending the found text to the current volume file
	if [ -z $line1 ] || [ -z $line2 ]; then 
		echo "failed to parse content of chapter number $((counter+1))."  >> "${outputDir}/${storyName}volume_${volumeNumber}.html"
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
