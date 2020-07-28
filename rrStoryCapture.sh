#! /bin/bash

##### This is a script for copying the entirety of a freely-published work from the popular website RoyalRoad.com and saving it off to the local filesystem as a set of pdf files.
## Currently it only works for RoyalRoad pages, all of which are publicly available. This script is not intended for any ilicit purposes.
## The script relies on the freely-distributed tool wkhtmltopdf for the final conversion from html to pdf. If that step is not necessary then the dependency is unnecessary and those failed lines will not stop the rest of the script from running.
# @Author: bcavanaugh
# @Created: 9/18/19
# @LastModified: 9/20/19


### Planned improvements:
# -q and -v modes, controlling the amount of logging.
# options for skipping the curling and controls for only curling new chapters (along with code to determine which volumes need to be recreated so the new chapters can be included).
# An option to skip the conversion to pdf.
# Reduce the URL and Id to one value (have the code pull out everything after the website name and generate the id...)
# Splitting the individual pieces into functions?
# Make the path to wkhtmltopdf a parameter.
# Params for overwriting the root url and search strings?
# A param for changing the font-size style in the resulting HTML.

let index=1;

# example toc_URL: https://www.royalroad.com/fiction/14167/metaworld-chronicles
# example toc_Id: /fiction/14167/metaworld-chronicles/

toc_URL=$1
toc_Id=$2
toc_LinkRoot="https://www.royalroad.com"

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
uniq toc_working/toBeTrimmed > toc_working/final

chapterCount=0

echo "Copying chapters from site to local directory."
if [ ! -d "chapters" ]; then
	mkdir chapters;

	while read line; do
		url=$toc_LinkRoot$line
		echo "Curling chapter #" $index "from url: $url"
		
		curl $url > "chapters/chapter_"$index".html"
		index=$((index+1))
		chapterCount=$index
	done < toc_working/final
fi

# TODO: Make this a value users can overwrite
let chaptersPerFile=50;
let volumeNumber=1;
let counter=0;

mkdir output

#Appends the opening HTML tags to the first volume file.
HTML_OPENING_TAGS="<!DOCTYPE html> <html> <head> </head> <body>"
HTML_CLOSING_TAGS="</body></html>"

echo "Combining chapter contents into logical html volumes and then converting them to pdf files."

echo $HTML_OPENING_TAGS > ./output/volume_$volumeNumber.html

for file in ./chapters/chapter_{1..$chapterCount}.html;
do
	if (( $counter > $chaptersPerFile)); then
		#Appends the ending HTML tags to the previous volume file.
		echo $HTML_CLOSING_TAGS >> ./output/volume_$volumeNumber.html

		# Replace the the text "title>" with "h1>" in the previous volume
		sed -i 's/title>/h1>/g' ./output/volume_$volumeNumber.html

		#TODO: Make this sed work on either (make a character set?)
		# Replace all left-side quotation marks (“) with vertical quotes.
		sed -i 's/“/"/g' ./output/volume_$volumeNumber.html
		# Replace all right-side quotation marks (”) with vertical quotes.
		sed -i 's/”/"/g' ./output/volume_$volumeNumber.html

		# Replaces all left-side single-quote marks (‘) with a vertical single-quote.
		sed -i 's/‘/'"'"'/g' ./output/volume_$volumeNumber.html
		# Replaces all right-side single-quote marks (’) with a vertical single-quote.
		sed -i 's/’/'"'"'/g' ./output/volume_$volumeNumber.html

		# Replaces all elipse marks (…) with three period marks.
		sed -i 's/…/.../g' ./output/volume_$volumeNumber.html

		#Convert the previous html file to a pdf.
		echo "Creating pdf from volume #"$volumeNumber
		# TODO: Make this a relative path, an actual command, or just a parameter...
		# TODO: Make this an optional step, controlled by a user-parameter
		/c/Program\ Files/wkhtmltopdf/bin/wkhtmltopdf.exe ./output/volume_$volumeNumber.html volume_$volumeNumber.pdf

		volumeNumber=$((volumeNumber+1));
		counter=0;

		#Appends the opening HTML tags to the new volume file.
		echo $HTML_OPENING_TAGS > ./output/volume_$volumeNumber.html
	fi
	
	echo "Parsing $file and piping it into ./output/volume_$volumeNumber.html"
	
	grep "<title>Chapter [0-9]" $file >> ./output/volume_$volumeNumber.html

	# line1 corresponds to the div that contains the chapter's content.
	line1=$(grep -n "chapter-inner chapter-content" $file | cut -f1 -d:)
	# line2 corresponds to an Advertisement that shows up immediately after the chapter-content element ends.
	line2=$(grep -n "bold uppercase text-center" $file | cut -f1 -d:)

	# Notice: this is a non-inclusive match (at least as far as line2 goes). This means we're successfully snipping out the advertisements element on line2!
	# We are appending the found text to the current volume file
	cat $file | tail -n +$line1 | head -n $((line2-line1)) >> ./output/volume_$volumeNumber.html

	# Appending a horizontal rule after the end of the current volume.
	echo "<hr>"  >> ./output/volume_$volumeNumber.html
	counter=$((counter+1));
done

# Appends the ending HTML tags to the last volume file.
echo $HTML_CLOSING_TAGS >> ./output/volume_$volumeNumber.html

# Replace the the text "title>" with "h1>" in the last volume
sed -i 's/title>/h1>/g' ./output/volume_$volumeNumber.html

# Convert the last html file to a pdf.
echo "Creating pdf from volume #"$volumeNumber
# TODO: Make this a relative path, an actual command, or just a parameter...
# TODO: Make this an optional step, controlled by a user-parameter
/c/Program\ Files/wkhtmltopdf/bin/wkhtmltopdf.exe ./output/volume_$volumeNumber.html volume_$volumeNumber.pdf