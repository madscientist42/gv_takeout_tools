#!/bin/bash
#
# gv_call_stats.sh is a bash script to parse Google Voice call history files
# generated from Google Takeout, and then output them into a CSV format
# that can be human readable, but is intended to actually be read by 
# something like LibreOffice or Excel.  It grabs all FOUR classes of call 
# events from Google Voice's Takeout format and processes them appropriately.
#
# For detailed instructions, please see: 
# https://blog.ls20.com/calculating-your-google-voice-minutes-usage-with-ease/
#
# (The blog covers the original script- but the operation's the SAME for this one)
#
# Copyright (C) 2014 Lin Song
# Copyright (C) 2014 Frank Earl - Adjustments to original script to do missed
#        calls and to actually put out a CSV that can be read by any CSV aware
#        spreadsheet.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.

command -v sed >/dev/null 2>&1 || { echo >&2 "I require \"sed\" but it's not installed.  Aborting."; exit 1; }
command -v stat >/dev/null 2>&1 || { echo >&2 "I require \"stat\" but it's not installed.  Aborting."; exit 1; }
command -v grep >/dev/null 2>&1 || { echo >&2 "I require \"grep\" but it's not installed.  Aborting."; exit 1; }
command -v paste >/dev/null 2>&1 || { echo >&2 "I require \"paste\" but it's not installed.  Aborting."; exit 1; }
command -v column >/dev/null 2>&1 || { echo >&2 "I require \"column\" but it's not installed.  Aborting."; exit 1; }

sw=0
if ls -- *Received*.html &> /dev/null; then sw=1; fi
if ls -- *Placed*.html &> /dev/null; then sw=1; fi
[ "$sw" = "0" ] && { echo "Please double check your current folder is \"Calls\". Aborting."; exit 1; }

mkdir -p mytempdir
\rm -f mytempdir/*
\cp -f -- *Received*.html mytempdir/
\cp -f -- *Placed*.html mytempdir/
\cp -f -- *Missed*.html mytempdir/
\cp -f -- *Voicemail*.html mytempdir/

cd mytempdir
[ ! "${PWD##*/}" = "mytempdir" ] && { echo "Failed to change working directory to mytempdir. Aborting."; exit 1; }

for file in *.html; do 
	\mv -- "$file" "`stat -c %n -- "$file" | sed -e 's/.*- Received/Received/' -e 's/.*- Placed/Placed/' -e 's/.*- Missed/Missed/'  -e 's/.*- Voicemail/Voicemail/'`"	
done

for DR in Placed Received Missed Voicemail; do

  echo "Contact_Name" > 1.txt
  echo "Phone_Number" > 2.txt
  echo "Start_Date,Start_Time_UTC" > 3.txt    
  echo "Call_Duration" > 4.txt
  # Contact Name
  cat -- *${DR}* | grep "tel:" | sed -e "s/<a.*\"fn\">//" -e "s/<\/span.*//" -e "s/^$/_EMPTY_/" >> 1.txt

  # Telephone Number
  cat -- *${DR}* | grep "tel:" | sed -e "s/<a.*tel://" -e "s/\"><span.*//" -e "s/^$/_EMPTY_/" >> 2.txt

  # Date and Time
  cat -- *${DR}* | grep "\"published" | sed -e "s/<abbr.*title=\"//" -e "s/\.000Z\">.*//" -e "s/T/,/" >> 3.txt

  # Call Duration
  cat -- *${DR}* | grep "duration" | sed -e "s/<abbr.*(//" -e "s/).*//" >> 4.txt

  # Assemble the results for the processing into the appropriate Recieved/Missed/Placed bucket...
  paste -d ',' 1.txt 2.txt 3.txt 4.txt | cat > ${DR}_calls.csv
  \rm -f 1.txt 2.txt 3.txt 4.txt

  # Handle the no-tollfree entries efficiently...
  grep -E -v -e "+1(800|888|877|866|855)[[:digit:]]{7}" ${DR}_calls.csv > ${DR}_calls_no_tollfree.csv

done


cd ..
mkdir -p GV_CSV_Files
\rm -f GV_CSV_Files/*
\cp -f mytempdir/*calls*.csv GV_CSV_Files/
if [ $? -eq 0 ]; then
  echo "Results successfully generated into GV_CSV_Files."
  echo " "
  echo "This script currently processes Placed, Recieved, Missed, and Voicemail"
  echo "entries with the naming of <Foo>_calls.csv and toll-free being removed"
  echo "from the list with the naming of <Foo>_calls_no_tollfree.csv, where <Foo>"
  echo "is the name from the above mentioned call event type list."
  echo " "
  echo "All date and time in results are in UTC."
else
  echo "Oops... Something went wrong. No result is generated."
fi 

echo " "
echo -n "Removing temp directory..."
\rm -f mytempdir/*
rmdir mytempdir
echo " Done."
