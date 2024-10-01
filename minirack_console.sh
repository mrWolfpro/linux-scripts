#!/bin/bash

### TO-DO
#
# 1. Add strict check for case clause
# 2. Port script to Python (???)
#

SGM1=ttyUSB0	# gw-8beb71
SGM2=ttyUSB1	# gw-8be33d
SGM3=ttyUSB2	# gw-8bed5b
SGM4=ttyUSB3	# gw-8bf873
SGM5=ttyUSB4	# gw-8c840d
SGM6=ttyUSB5	# gw-8c810b
MHO1=ttyUSB6    # gw-8d7ff0
MHO2=ttyUSB7    # gw-8d7ff8

#function print_usage {
#	printf "Usage: $(basename $0) [ <DEVICE_ID> ]"
#	exit 63
#}

function choose_device {
	printf "Welcome to Maestro Minirack console server. Choose device:\n\n"
	printf "    1) SGM1 - Check Point Security Appliance 6500 #1\n"
	printf "    2) SGM2 - Check Point Security Appliance 6500 #2\n"
	printf "    3) SGM3 - Check Point Security Appliance 6500 #3\n"
	printf "    4) SGM4 - Check Point Security Appliance 6500 #4\n"
	printf "    5) SGM5 - Check Point Security Appliance 6800 #1\n"
	printf "    6) SGM6 - Check Point Security Appliance 6800 #2\n"
  printf "    7) MHO1 - Check Point Maestro Orchestrator 140 #1\n"
  printf "    8) MHO2 - Check Point Maestro Orchestrator 140 #2\n"
	printf "    0) Disconnect from console server\n\n"

	read -p "Enter your choice: " CHOICE

	case $CHOICE in
		1)
			DEV=SGM1
			TTY=$SGM1
			;;
		2)
			DEV=SGM2
			TTY=$SGM2
			;;
		3)
			DEV=SGM3
			TTY=$SGM3
			;;
		4)
			DEV=SGM4
			TTY=$SGM4
			;;
		5)
			DEV=SGM5
			TTY=$SGM5
			;;
		6)
			DEV=SGM6
			TTY=$SGM6
			;;
    7)
      DEV=MHO1
      TTY=$MHO1
      ;;
    8)
      DEV=MHO2
      TTY=$MHO2
      ;;
		0)
			exit 0
			;;
#		*)
#			print_usage
#			;;
	esac
}

function connect {
	CU_CMD="cu -s 9600 -l /dev"
	CU_PID=`lsof /dev/$TTY | grep -v COMMAND | head -1 | grep ^cu | awk '{print $2}'`

	if [ $CU_PID ]; then
		read -p "Console connection to $DEV is already opened. Terminate? (y/N): " CU_TERM

		if [[ $CU_TERM =~ [yY] || $CU_TERM =~ [yY][eE][sS] ]]; then
			printf "Terminating existing connection to $DEV... "
			kill $CU_PID && sleep 4; printf "Done!\n"

			printf "Connecting to $DEV console line... "
			sleep 1 && $CU_CMD/$TTY
			echo " "
		else
			printf "Connection to $DEV cancelled: line in use\n\n"
		fi
	else
		printf "Connecting to $DEV console line... "
		sleep 1 && $CU_CMD/$TTY
	fi

	read FOOBAR
}

while [ 1 ]; do
	clear
	choose_device
	connect
done
