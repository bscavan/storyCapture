#! /bin/bash
let index=1;


## This is commented-out because I don't want to re-create the chapter files every time.
## TODO: make this section only run when the chapters directory doesn't exist or is empty.
if [ ! -d "chapters" ]; then
	mkdir chapters;

	while read line; do
		echo "Curling chapter #" $index
		curl $line > "chapters/chapter_"$index".html"
		index=$((index+1))
	done
fi

let chaptersPerFile=50;
let counter=0;

mkdir output
let volumeNumber=1;

#Appends the opening HTML tags to the first volume file.
echo "<!DOCTYPE html> <html> <head> </head> <body>" > ./output/volume_$volumeNumber.html

# TODO: Make this work without needing to manually count the files. Perhaps using that "wc -1 | ls -l" command?
# lineNumber=$(ls -1 chapters | wc -l)
for file in ./chapters/chapter_{1..297}.html;
do
	if (( $counter > $chaptersPerFile)); then
		#Appends the ending HTML tags to the previous volume file.
		echo "</body></html>" >> ./output/volume_$volumeNumber.html

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
		wkhtmltopdf.exe ./output/volume_$volumeNumber.html volume_$volumeNumber.pdf
		
		volumeNumber=$((volumeNumber+1));
		counter=0;
		
		#Appends the opening HTML tags to the new volume file.
		echo "<!DOCTYPE html> <html> <head> </head> <body>" > ./output/volume_$volumeNumber.html
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
echo "</body></html>" >> ./output/volume_$volumeNumber.html

# Replace the the text "title>" with "h1>" in the last volume
sed -i 's/title>/h1>/g' ./output/volume_$volumeNumber.html

# Convert the last html file to a pdf.
wkhtmltopdf.exe ./output/volume_$volumeNumber.html volume_$volumeNumber.pdf