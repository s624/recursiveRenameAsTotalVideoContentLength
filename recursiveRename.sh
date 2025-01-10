#!/usr/bin/env bash

#############################
# The program has to run from the directory which is to be renamed recursively.
#############################

function contentDurationExtraction() { #{{{
	contentName="$1"
	if [[ "$(printf '%s' "$contentName" | grep -E "^.*____[0-9][0-9]?:[0-9][0-9]?:[0-9][0-9]?\.[a-zA-Z0-9_]+$")" ]]; then
		hHh="$(printf '%s' "$contentName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)\.[a-zA-Z0-9_]+$%\2%g")"
		mMm="$(printf '%s' "$contentName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)\.[a-zA-Z0-9_]+$%\3%g")"
		sSs="$(printf '%s' "$contentName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)\.[a-zA-Z0-9_]+$%\4%g")"
		contentDuration="${hHh}:${mMm}:${sSs}"
		returnValue=2
	#c# this elif is because some of the contents in first few attemts were renamed wrongly.
	elif [[ "$(printf '%s' "$contentName" | grep -E "^.*____[0-9][0-9]?:[0-9][0-9]?:[0-9][0-9]?$")" ]]; then
		hHh="$(printf '%s' "$contentName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)$%\2%g")"
		mMm="$(printf '%s' "$contentName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)$%\3%g")"
		sSs="$(printf '%s' "$contentName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)$%\4%g")"
		contentDuration="${hHh}:${mMm}:${sSs}"
		returnValue=1
	else
		returnValue=0
	fi
	extractionReturn[0]=$returnValue
	extractionReturn[1]=$hHh
	extractionReturn[2]=$mMm
	extractionReturn[3]=$sSs
} #}}}

function fileRename() { #{{{
	local namE="$1"
	fileDirectoryName="$(dirname "$namE")"
	fileBaseName="$(basename "$namE")"
	duration="$(exiftool "$namE" | grep 'Track Duration' | awk '{print $(NF)}' )" #c# this line is very important because exiftool shows the duration in different ways. So you may need to add some more ways.
	#printf 'duration=%s\n' "$duration"
	newFileBaseName="$(printf '%s' "$fileBaseName" | sed -E "s%____[0-9]+:[0-9]+:[0-9]+%%g")"
	newFileBaseName="$(printf '%s' "$newFileBaseName" | sed -E "s%^(.*)\.([a-zA-Z0-9_]+)$%\1____${duration}.\2%g")"
	newFileName="${fileDirectoryName}/${newFileBaseName}"
	printf "oldfilName=%s\tnewfileName=%s\n" "$namE" "$newFileName"
	mv "$namE" "$newFileName"
} #}}}

function directoryRename() { #{{{
	directoryName=$1
	contentsUnderLevel1="$(ls "${directoryName}")"
	oldIFS="$(printf '%q' "$IFS")"
	IFS=$'\n'
	hours=0; minutes=0; seconds=0; count=0
	for content in $contentsUnderLevel1; do
		count="$(($count+1))"
		hHh=0; mMm=0; sSs=0;
		declare -a extractionReturn
		contentDurationExtraction "$content"
		if [[ "${extractionReturn[0]}" -eq 1 || "${extractionReturn[0]}" -eq 2 ]]; then
			hHh="$(printf '%s' "$hHh" | sed -E "s%^0{,1}([0-9]+)$%\1%g")"
			mMm="$(printf '%s' "$mMm" | sed -E "s%^0{,1}([0-9]+)$%\1%g")"
			sSs="$(printf '%s' "$sSs" | sed -E "s%^0{,1}([0-9]+)$%\1%g")"
			#-------
			secondsT="$(( "$seconds" + "$sSs" ))"
			seconds="$(( "$secondsT" % 60 ))"
			minutesT="$(( "$minutes" + "$mMm" + ("$secondsT"/60) ))"
			minutes="$(( "$minutesT" % 60 ))"
			hours="$(( "$hours" + "$hHh" + ("$minutesT"/60) ))"
		fi
	done
	#------ #c# if a number has 0 prepended then bash takes it in octal number system. So it's important to omit the prepended 0 befor handling any arithmatics.
	if [[ "${seconds}" -ne 0 || "${minutes}" -ne 0 || "${hours}" -ne 0 ]]; then
		[[ "${#seconds}" -eq 1 ]] && seconds="$(printf '%02d' "$seconds")"
		[[ "${#minutes}" -eq 1 ]] && minutes="$(printf '%02d' "$minutes")"
		duration="${hours}:${minutes}:${seconds}"
		directoryDirectoryName="$(dirname  "$directoryName")"
		directoryBasename="$(basename "$directoryName")"
		newDirectoryBasename="$(printf '%s' "$directoryBasename" | sed -E "s%____[0-9]+:[0-9]+:[0-9]+%%g")"
		newDirectoryBasename="$(printf '%s' "$newDirectoryBasename" | sed -E "s%^(.*)$%\1____${duration}%g")"
		if [[ "$directoryDirectoryName" != "." ]] then
			newDirectoryName="${directoryDirectoryName}/${newDirectoryBasename}"
		else
			newDirectoryName="${newDirectoryBasename}"
		fi
		#echo -e "oldDirName = $directoryName \n\tnewDirectoryBasename=$newDirectoryBasename \n\tdirectoryDirectoryName=$directoryDirectoryName \n\tnewDirName=$newDirectoryName\n"
		mv "$directoryName" "$newDirectoryName"
	fi
} #}}}


extList="$(cat /etc/mime.types | grep -E '^video/\S*\s+\w' | sed -E 's:^video/\S*\s+::' | tr '\n' ' ')"
extPartOfCommand="$(printf '%s' "$extList" | sed -E 's:(\w+):-e \1:g')"
videoFileFindingCommand="$(printf '%s' "$extPartOfCommand" | sed -E 's:^(.*)$:fd -tf \1:g')"
fileList="$(eval "$videoFileFindingCommand")"
noOfFiles="$(echo "$fileList" | wc -l)"

oldIFS="$(printf '%q\n' "$IFS")"
IFS=$'\n'
for name in $fileList; do
	fileRename "$name"
done

for (( i_correction = 1; i_correction <= 8; i_correction++ )); do
	dirList="$(fd -td )"
	echo "correction level $i_correction"
	for dir in $dirList; do
		directoryRename "$dir"
	done
done







#
#function fileRename_old() { #{{{
#	local namE="$1"
#	fileDirectoryName="$(dirname "$namE")"
#	fileBaseName="$(basename "$namE")"
#	duration="$(exiftool "$namE" | grep 'Track Duration' | awk '{print $(NF)}' )"
#	printf 'duration=%s\n' "$duration"
#	if [[ "$(printf '%s' "$fileBaseName" | grep -E "^.*____[0-9][0-9]?:[0-9][0-9]?:[0-9][0-9]?\.[a-zA-Z0-9_]+$")" ]]; then
#		hHh="$(printf '%s' "$fileBaseName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)\.[a-zA-Z0-9_]+$%\2%g")"
#		mMm="$(printf '%s' "$fileBaseName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)\.[a-zA-Z0-9_]+$%\3%g")"
#		sSs="$(printf '%s' "$fileBaseName" | sed -E "s%^(.*____)([0-9]+):([0-9]+):([0-9]+)\.[a-zA-Z0-9_]+$%\4%g")"
#		hH="$(printf '%s' "$duration" | sed -E "s%^([0-9]+):([0-9]+):([0-9]+)$%\1%g")"
#		mM="$(printf '%s' "$duration" | sed -E "s%^([0-9]+):([0-9]+):([0-9]+)$%\2%g")"
#		sS="$(printf '%s' "$duration" | sed -E "s%^([0-9]+):([0-9]+):([0-9]+)$%\3%g")"
#		if [[ "$hHh" == "$hH" && "$mMm" == "$mM" && "$sSs" == "$sS" ]]; then
#			#printf 'Already renamed & the file name matches with its duration\n'
#			#The ':' is for noop.
#			:
#		else
#			newBaseName="$(printf '%s' "$fileBaseName" | sed -E "s%____[0-9]+:[0-9]+:[0-9]+%%g")"
#			newBaseName="$(printf '%s' "$newBaseName" | sed -E "s%^(.*)\.([a-zA-Z0-9_]+)$%\1____${duration}.\2%g")"
#			newName="${fileDirectoryName}/${fileBaseName}"
#			printf "Renamed but the file name doesn't match with its duration, so I am renaming the file correctly\n\t oldName=$namE newName=$newName\n"
#			mv "$namE" "$newName"
#		fi
#	else
#		newBaseName="$(printf '%s' "$fileBaseName" | sed -E "s%^(.*)\.([a-zA-Z0-9_]+)$%\1____${duration}.\2%g")"
#		newName="${fileDirectoryName}/${fileBaseName}"
#		printf "file is not renamed with duration, so renaming\n\t oldName=$namE newName=$newName\n"
#		#printf 'count = %s; name = %s; newName = %s\n' "$count" "$namE" "$newName"
#		mv "$namE" "$newName"
#	fi
#	
#} #}}}
#

#function tst() { #{{{
#	dirname="$1"
#	contentLevel1="$(fd -d1)"
#	fileLevel1="$(fd -tf -d1)"
#	directoryLevel1="$(fd -td -d1)"
#	for content in $contentLevel1; do
#		tst content
#	done
#} #}}}








