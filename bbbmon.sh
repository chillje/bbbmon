#!/bin/bash
# vim:et:ai:sw=2:tw=0
#
# bbb-mon.sh
# copyright (c) 2020 chris <christoph.hillje@gmail.com>, GPL version 3

#set -vx; set -o functrace


IAM="$(basename "${0}")"


# Help function.
help() {
  echo -e "\e[1;31mATTENTION: You have to use this on your BBB server.\e[0m"
  echo
  echo "usage ${IAM}: [OPTION...]"
  cat << EOF
OPTIONs:
 -f|--file         path to the outputfile (default is stdout).
 -i|--iface        interface stats to be shown (depends on \"-s\").
 -l|--log          start logging of meeting informations in simple log-format.
 -m|--members      show also the members of a meeting.
 -s|--stats        show the performance monitor (depends on \"-w\") .
 -w|--watch        start watch mode (best use with external tool \"watch\", see examples.)
 -h|--help         print this help, then exit.

examples:
 * watch --color -n3 "bbbmon.sh -w -i eth0"
 * watch --color -n3 "bbbmon.sh -w -m"
 * bbb-mon.sh -l -f bbb-meetings.log
EOF
}

setVars() {
    # Get secret informations about the running BBB instance.
    secretdata=$(bbb-conf --secret)
    # Extract secret key from $secretdata.
    secret=$(echo "$secretdata" | grep "Secret:" | cut -d':' -f 2 | sed 's/^ *//g' | sed 's/ *$//g')
    
    # Generate BBB URL.
    url=$(echo "$secretdata" | grep "URL:" | sed -e s/\ //g -e s/URL:// -e s/\\/bigbluebutton\\///)
    # Generate checksum (see: https://docs.bigbluebutton.org/dev/api.html#api-security-model)
    ccc=$(echo -n "getMeetings$secret" | sha1sum | cut -d' ' -f 1)
    # Generate URI from checksum.
    uri="$url/bigbluebutton/api/getMeetings?checksum=$ccc"
    
    # Get XML informations from URI.
    data=$(curl --silent "$uri")
    
    # Declare array of meetingNames
    IFS=$'\n' read -r -d '' -a meetingName < <( echo $data | xmlstarlet sel -t -v 'response/meetings/meeting/meetingName' -n && printf '\0' )
    # Count of running meetings.
    #meetings=$(echo $data | grep -o "<meeting>" | wc -l)
    meetings=${#meetingName[@]}
}

# This function defines the used date format.
isodate() {
  date "${@}" +%Y-%m-%dT%H:%M:%S%z
}


# Function to check for dependencys.
depCheck() {
    local deps=(sha1sum curl xmlstarlet mpstat ifstat)
    for (( i=0; i<${#deps[@]}; i++))
    do
        [ -z $(command -v ${deps[$i]}) ] && {
            if [ ${deps[$i]} = "mpstat" ]
            then
                echo "${deps[$i]} is missing, do \"sudo apt install sysstat\""
            else
                echo "${deps[$i]} is missing, do \"sudo apt install ${deps[$i]}\""
            fi
        }
    done
}


# This function generates the performance usage output.
cpuMemoryUsage() {
    cpuIdle=$(mpstat 1 1 | awk 'END{print}' | cut -d' ' -f 42-)
    mem=$(free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n",$3,$2,$3*100/$2 }' | cut -d' ' -f 3-)
    disk=$(df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n",$3,$2,$5}' | cut -d' ' -f 3-)
    # If an interface is given, we see the input and output traffic
    [ -n "${PRM_IFACE}" ] && {
        IFS=$'\n' read -r -d '' -a ifstats < <( ifstat -i ens32 -b -n 1 1 | awk 'END{print}' | tr -s ' ' | sed -e s/^\ //g -e s/\ /\\n/g )
        kbpsIn=${ifstats[0]}
        kbpsOut=${ifstats[1]}
    }
}


# This function checks the bbb-server for running meetings
# return: true if a min. of one meeting is running, otherwise false.
runningMeetings() {
    local emptyText=$(echo ${data} | xmlstarlet sel -t -v "response/messageKey" -n -)
    if [ -z ${emptyText} ]
    then
        echo true
    else
        echo false
    fi
}


# This function gets a value ($2) from a sepcific meeting ($1) of the xml data.
# $1: the meeting number counted by first "meeting"-value in xml data.
# $2: the xml value in the given meeting cage.
# return: the value
getXmlMettingInfos() {
    echo $(echo $data | xmlstarlet sel -t -v "response/meetings/meeting[$1]/$2" -n -)
}


# This function gets a attendee value ($2) from a sepcific meeting ($1) of the xml data.
# $1: the meeting number counted by first "meeting"-value in xml data.
# $2: the xml value in the given attendee cage from the given meeting ($1) cage.
# return: the value
getXmlAttendeeInfos() {
    IFS=$'\n' read -r -d '' -a attendees < <( echo $data | xmlstarlet sel -t -v "response/meetings/meeting[$1]/attendees/attendee/$2" -n && printf '\0' )
}


# This function defines relevant meeting informations as variables.
getTotalMettingInfos() {
    for (( i=1; i<${#meetingName[@]}+1; i++))
    do
        participantCount=$(getXmlMettingInfos "${i}" "participantCount")
        listenerCount=$(getXmlMettingInfos "${i}" "listenerCount")
        voiceParticipantCount=$(getXmlMettingInfos "${i}" "voiceParticipantCount")
        videoCount=$(getXmlMettingInfos "${i}" "videoCount")

        ((participantTotal+=$participantCount))
        ((listenerTotal+=$listenerCount))
        ((voiceTotal+=$voiceParticipantCount))
        ((videoTotal+=$videoCount))
    done

}


# This function prints the neccesary informations of all running meetings (--watch option).
printMeetingInfos() {
    for (( i=1; i<${#meetingName[@]}+1; i++))
    do
        echo -e "\e[1;34mRoom Name:\\t\\t ${meetingName[$(( $i-1 ))]}\e[0m"
        echo -e "Meeting ID:\\t\\t" $(getXmlMettingInfos "${i}" "meetingID")
        echo -e "Creation Date:\\t\\t"  $(getXmlMettingInfos "${i}" "createDate")
        echo -e "Room max Participants:\\t"  $(getXmlMettingInfos "${i}" "maxUsers")
        echo -e "Participants total:\\t"  $(getXmlMettingInfos "${i}" "participantCount")
        echo -e "Participants listener:\\t"  $(getXmlMettingInfos "${i}" "listenerCount")
        echo -e "Participants voice:\\t"  $(getXmlMettingInfos "${i}" "voiceParticipantCount")
        echo -e "Participants with video:"  $(getXmlMettingInfos "${i}" "videoCount")

        # Get the attendee "fullName" infos in the specific meeting room.
        [ -n "${PRM_MEMBERS}" ] && {
            echo -e "Members (by Name): \033[1;32m"
            getXmlAttendeeInfos "${i}" "fullName"
            for (( k=0; k<${#attendees[@]}; k++))
            do
                echo -e "\\t${attendees[${k}]}"
            done
        }
        echo
    done
}


# This function prints the neccesary informations as a "log line" (--log option).
logMeetingInfos() {
    for (( i=1; i<${#meetingName[@]}+1; i++))
    do
        local roomName=${meetingName[$(( $i-1 ))]}
        local meetingID=$(getXmlMettingInfos "${i}" "meetingID")
        local createDate=$(getXmlMettingInfos "${i}" "createDate" | sed s/\ /-/g)
        local maxUsers=$(getXmlMettingInfos "${i}" "maxUsers")
        local participantCount=$(getXmlMettingInfos "${i}" "participantCount")
        local listenerCount=$(getXmlMettingInfos "${i}" "listenerCount")
        local voiceParticipantCount=$(getXmlMettingInfos "${i}" "voiceParticipantCount")
        local videoCount=$(getXmlMettingInfos "${i}" "videoCount")
        local logmsg="MeetingName=${roomName} MeetingID=${meetingID} CreateDate=${createDate} \
RoomMaxUsers=${maxUsers} Participants=${participantCount} ListenerCount=${listenerCount} \
VoiceCount=${voiceParticipantCount} VideoCount=${videoCount}"

        # Get the attendee "fullName" infos in the specific meeting room.
        [ -n "${PRM_MEMBERS}" ] && {
            getXmlAttendeeInfos "${i}" "fullName"
            logmsg="${logmsg} Members="

            for (( k=0; k<${#attendees[@]}; k++))
            do
                logmsg="${logmsg}${attendees[k]// /};"
            done
        }

        meetingLog+=( "${logmsg}")
    done
}


# This is the main function.
main() {
    # Proof for missing dependencys.
    [ -n "$(depCheck)" ] && {
        depCheck
        echo "$IAM: Missing dependencys, exiting.."
        exit 1
    }

# Load needed vars
# FIXME
setVars

    # Show performance stats if "watch" and "stats" is checked.
    [ -n "${PRM_WATCH}" ] && [ -n "${PRM_STATS}" ] && {
        echo -e "\e[0;31mPerformance data:\e[0m"
        cpuMemoryUsage
        echo -e "CPU Idle:\\t ${cpuIdle} (avg.)"
        echo -e "Memory Usage:\\t ${mem}"
        echo -e "Disk Usage:\\t ${disk}"
        # If an interface is given, we see the input and output traffic
        [ -n "${PRM_IFACE}" ] && {
            echo -e "${PRM_IFACE} In:\\t ${kbpsIn} Kbit/s"
            echo -e "${PRM_IFACE} Out:\\t ${kbpsOut} Kbit/s"
            echo -e "${PRM_IFACE}-Total:\\t $( echo "scale=2;${kbpsIn}+${kbpsOut}" | bc ) Kbit/s"
        }
        echo "--------------------------------------------"
        echo -e "\e[0;31mBigBlueButton meeting informations for \"$url\":\e[0m" 
    }

    # Proof for running meetings.
    if [ "$(runningMeetings)" == "true" ]
    then
        # Watch mode is started.
        [ -n "${PRM_WATCH}" ] && {
            getTotalMettingInfos
            echo -e "Meetings: \e[1;31m${meetings}\e[0m, Participants Total: \e[1;31m${participantTotal}\e[0m, VideoCount Total: \e[1;31m${videoTotal}\e[0m"
            echo
            printMeetingInfos
        }

        # Log mode is started.
        [ -n "${PRM_LOG}" ] && {
            # Log-file not specified.
            [ -z "${PRM_FILE}" ] && {
                # Show log-msg as "echo" with all meetings seperated per lines.
                logMeetingInfos
                for (( i=0; i<${#meetingLog[@]}; i++))
                do
                    echo -e  $(isodate) ${IAM}: ${meetingLog[$i]}
                done

                # Show log-msg as "echo" with total, total and cpu or total, cpu and if-infos.
                getTotalMettingInfos
                if [ -n "${PRM_STATS}" ] && [ -z "${PRM_IFACE}" ]
                then
                    cpuMemoryUsage
                    totalLogMsg="meetingsTotal=${meetings} participantsTotal=${participantTotal} videoTotal=${videoTotal} cpuIdle=${cpuIdle}%" 
                elif [ -n "${PRM_STATS}" ] && [ -n "${PRM_IFACE}" ]
                then
                    cpuMemoryUsage
                    totalLogMsg="meetingsTotal=${meetings} participantsTotal=${participantTotal} videoTotal=${videoTotal} cpuIdle=${cpuIdle}% ${PRM_IFACE}-In=${kbpsIn}Kbps ${PRM_IFACE}-Out=${kbpsOut}Kbps ${PRM_IFACE}-Total=$( echo "scale=2;${kbpsIn}+${kbpsOut}" | bc )Kbps"
                else
                    totalLogMsg="meetingsTotal=${meetings} participantsTotal=${participantTotal} videoTotal=${videoTotal}"
                fi
                echo -e $(isodate) ${IAM}: "${totalLogMsg}"
            }

            # Log-file is given.
            [ -n "${PRM_FILE}" ] && {
                # Get the last informations from the given ${PRM_FILE}. It loads the same lines
                # (from behind) as meetings are currently running.
                [ -s "${PRM_FILE}" ] && {
                    lastLog=$( tail -n ${#meetingName[@]} ${PRM_FILE} | cut -d' ' -f 3- )
                }
                logMeetingInfos
                # Save the currently running meetings and the loaded meetings from ${PRM_FILE} as
                # separated files.
                echo -e "${meetingLog[@]}" > meetingLog.tmp
                echo -e $lastLog > lastLog.tmp

                ## Only save new line in log-file with new informations if the two files are differ.
                if [[ ! -z $(diff meetingLog.tmp lastLog.tmp) ]] || [ ! -s "${PRM_FILE}" ]
                then
                    for (( i=0; i<${#meetingName[@]}; i++))
                    do
                        echo -e $(isodate) ${IAM}: ${meetingLog[$i]} >> ${PRM_FILE}
                    done
                fi

                # Remove the ugly tmp-files for comparison...
                rm -rf meetingLog.tmp lastLog.tmp

                ####################
                #FIXME -> Dies soll auf dauer den Mist mit den tmp-Files abloesen!
                ####################
                #if [[ "${meetingLog[*]}" != "${lastLog}" ]] || [ ! -s "${PRM_FILE}" ]
                #then
                #    for (( i=0; i<${#meetingName[@]}; i++))
                #    do
                #        echo -e $(isodate) ${IAM}: ${meetingLog[$i]} >> ${PRM_FILE}
                #    done
                #    echo Daten sind nicht identisch neues log.
                #else
                #    echo Daten sind identisch, kein log!
                #fi


                # Einfache Variante alles konkatiniert.
                ## Get last log from log-file.
                #lastlog=$( tail -n 1 ${PRM_FILE} | cut -d' ' -f 3- )
                ## Generate new meeting logs.
                #logMeetingInfos
                ## Only save new line in log-file with new informations.
                #[[ "${lastLog}" != "${meetingLog[@]}" ]] && {
                #    echo -e  $(isodate) ${IAM}: "${meetingLog[@]}" >> ${PRM_FILE}
                #}

                ##############################################################################
                # Log "total" informations to another logfile called "${PRM_FILE}.total".
                ##############################################################################

                # Log "total" informations to another logfile.
                [ -s "${PRM_FILE}.total" ] && {
                    # We want to compare the first 3 informations only. Not the iface or cpu.
                    lastLogTotal=$( tail -n 1 ${PRM_FILE}.total | cut -d' ' -f 3-5 )
                }
                # Define totalLogMsg with total, total and cpu or total, cpu and if-infos.
                getTotalMettingInfos
                if [ -n "${PRM_STATS}" ] && [ -z "${PRM_IFACE}" ]
                then
                    cpuMemoryUsage
                    totalLogMsg="meetingsTotal=${meetings} participantsTotal=${participantTotal} videoTotal=${videoTotal} cpuIdle=${cpuIdle}%" 
                elif [ -n "${PRM_STATS}" ] && [ -n "${PRM_IFACE}" ]
                then
                    cpuMemoryUsage
                    totalLogMsg="meetingsTotal=${meetings} participantsTotal=${participantTotal} videoTotal=${videoTotal} cpuIdle=${cpuIdle}% ${PRM_IFACE}-In=${kbpsIn}Kbps ${PRM_IFACE}-Out=${kbpsOut}Kbps ${PRM_IFACE}-Total=$( echo "scale=2;${kbpsIn}+${kbpsOut}" | bc )Kbps"
                else
                    totalLogMsg="meetingsTotal=${meetings} participantsTotal=${participantTotal} videoTotal=${videoTotal}"
                fi
                ## Only save new line in log-file".total" with new informations about total counts (not stats or iface).
                if [[ "${lastLogTotal}" != "$(echo -e "${totalLogMsg}" | cut -d' ' -f 1-3)" ]] || [ ! -s "${PRM_FILE}.total" ]
                then
                    echo -e $(isodate) ${IAM}: "${totalLogMsg}" >> ${PRM_FILE}.total
                fi
            }
        }
    else # No meeting is active.
        # Watch mode is started.
        [ -n "${PRM_WATCH}" ] && {
            echo "currently no meetings" 
        }

        # Log mode is started.
        [ -n "${PRM_LOG}" ] && {
            # Log-file not specified.
            [ -z "${PRM_FILE}" ] && {
                echo -e  $(isodate) ${IAM}: "currently no meetings"
            }

            # Log-file is given.
            [ -n "${PRM_FILE}" ] && {
                # Only save new line in log-file with new informations.
                lastlog=$( tail -n 1 ${PRM_FILE} | cut -d' ' -f 3- )
                [ "${lastlog}" != "currently no meetings" ] && {
                    echo -e $(isodate) ${IAM}: "currently no meetings" >> ${PRM_FILE}
                    echo -e $(isodate) ${IAM}: "currently no meetings" >> ${PRM_FILE}.total
                }
            }
        }
    fi
}


# If this script starts without a parameter, it will show the help message and exit
[ -n "${1}" ] || { help >&2; exit 1; }


# The option declarations.
unset PRM_LOG PRM_FILE PRM_IFACE PRM_WATCH PRM_STATS PRM_MEMBERS
while [ "${#}" -gt '0' ]; do case "${1}" in
  '-l'|'--log') PRM_LOG='true';;
  '-f'|'--file') PRM_FILE="${2}"; shift;;
  '-i'|'--iface') PRM_IFACE="${2}"; shift;;
  '-w'|'--watch') PRM_WATCH='true';;
  '-m'|'--members') PRM_MEMBERS='true';;
  '-s'|'--stats') PRM_STATS='true';;
  '-h'|'--help') help >&2; exit;;
  '--') shift; break;;
  -*) echo "${IAM}: don't know about '${1}'." >&2; help >&2; exit 1;;
  *) break;;
esac; shift; done


# Start main function (if an parameter is given)
main "${@}"

