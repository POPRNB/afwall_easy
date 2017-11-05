#!/bin/bash

#######################################################################
# IPFire network object creator for IPv4 addresses based on ASN information
# Creates 'customnetworks' objects in /var/ipfire/fwhosts/customnetworks
# Creates 'customgroups' objects in /var/ipfire/fwhosts/customgroups
#######################################################################

#######################################################################
  revision="asn_ipfire.sh v0.6.2"                    # do not comment out
# Last updated: August 25 2017 by maloe
# Author: Mike Kuketz, maloe
# Visit: www.kuketz-blog.de
#######################################################################

#######################################################################
# Constants, Filenames

# Path to IPFire customnetworks|customgroups
customnetworks=/var/ipfire/fwhosts/customnetworks
customgroups=/var/ipfire/fwhosts/customgroups

# Remark for IPFire customnetworks|customgroups. This is used to identify entries made by asn_ipfire.sh.
auto_remark="entry by asn_ipfire.sh"

# Define iptables path for iptable/afwall output file
iptable_path="/sbin/iptables"
afwall_path="/system/bin/iptables"

# Output files
file_network="network_list.txt"			# output file for network consolidated
file_network_raw="$file_network"		# output file for network not consolidated
file_iptable="iptable_rules.txt"		# output file in iptable format
file_afwall="afwall_rules.txt"			# output file in afwall format
file_asn="asn_list.txt"					# output file for ASNs only

#######################################################################
# Activate sources for ASN or network gathering by adding below defined "Gather_Functions" into the array (space separated).
getASNfromCOMPANY=(gather_ASN0 gather_ASN1 gather_ASN2)							# Default: (gather_ASN0 gather_ASN1)
getNETfromASN=(gather_NET0 gather_NET1)								# Default: (gather_NET0 gather_NET1)

# Local files can be used as ASN and/or network sources. To be activated by adding "gather_ASN0" or "gather_NET0" into above array.
local_asn_file="local_asn_list.txt"		# Note: Each ASN must be in the same row as the corresponding company, e.g. 'AS1234 CompanyA' or 'CompanyA AS1234'
local_net_file="local_net_list.txt"		# Note: Each network must be in the same row as the corresponding ASN, e.g. '1.2.3.4/24 AS5678' or 'AS5678 1.2.3.4/24'

# Gather Functions: add further sources here and activate them in above arrays getASNfromCOMPANY() and getNETfromCOMPANY()
# ASN sources, function must return a list of ASNs
	gather_ASN0() {	if [[ -f $local_asn_file ]]; then cat $local_asn_file | grep -i " $1 " | grep -Eo 'AS[0-9]+' ; fi; }														# Get ASN from local file
	gather_ASN1() {	wget -q -O - "https://www.ultratools.com/tools/asnInfoResult?domainName=$1" | grep -Eo 'AS[0-9]+' | uniq; }													# Get ASN from ultratools.org
	gather_ASN2() { wget -q -O - "http://www.cidr-report.org/as2.0/autnums.html" | grep -i " $1 " | grep -Eo 'AS[0-9]+'; }														# Get ASN from cidr-report.org
	gather_ASN3() 
	{ 
		wget -q -O - "http://www.bgplookingglass.com/list-of-autonomous-system-numbers" | sed 's/<br /\n/g' | grep -i " $1 " | grep -Eo 'AS[0-9]+'								# Get ASN from bgplookingglass.com (part1)
		wget -q -O - "http://www.bgplookingglass.com/list-of-autonomous-system-numbers-2" | sed 's/<br /\n/g' | grep -i " $1 " | grep -Eo 'AS[0-9]+'							# Get ASN from bgplookingglass.com (part2)
		wget -q -O - "http://www.bgplookingglass.com/4-byte-asn-names-list" | sed 's/<br /\n/g' | grep -i " $1 " | grep -Eo 'AS[0-9]+'											# Get ASN from bgplookingglass.com (part3)
	}
# Network sources, must return a list of CIDR networks
	gather_NET0() {	if [[ -f $local_net_file ]]; then cat $local_net_file | grep -i " $1 " | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | sort -u ; fi; }				# Get networks from local file
	gather_NET1() { wget -q -O - "https://stat.ripe.net/data/announced-prefixes/data.json?preferred_version=1.1&resource=$1" | grep -Eo '([0-9.]+){4}/[0-9]+' | sort -u ; }	# Get networks from stat.ripe.net, rough sorting
	gather_NET2() { wget -q -O - "https://ipinfo.io/$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | sort -u ; }														# Get networks from ipinfo.io, rough sorting


# Don't edit anything below
#######################################################################
# Functions
	# Function: get network mask
	cdr2mask()
	{
		# Number of args to shift, 255..255, first non-255 byte, zeroes
		set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
		[ $1 -gt 1 ] && shift $1 || shift
		echo ${1-0}.${2-0}.${3-0}.${4-0}
	}

	# Functions: get decimal IP values
	get_firstIP() {	echo ${1/\//.} | awk -F"." '{ printf "%.0f", $1*2^24+$2*2^16+$3*2^8+$4 }'; }				# first IP of network
	get_IPrange() { echo $1 | awk -F"/" '{ printf "%.0f", 2^(32-$2)}'; }										# IP range of network
	get_lastIP() { echo ${1/\//.} | awk -F"." '{ printf "%.0f", $1*2^24+$2*2^16+$3*2^8+$4+2^(32-$5)}'; }		# last IP +1 of network

	# Function: transform decimal IP into dot noted IP
	dec2ip() {
		ip1=`echo $1 | awk '{ printf "%i", $1 / (2^24) }'`
		ip2=`echo $1 $ip1 | awk '{ printf "%i", ($1-$2*(2^24)) / (2^16) }'`
		ip3=`echo $1 $ip1 $ip2 | awk '{ printf "%i", ($1-$2*(2^24)-$3*(2^16)) / (2^8) }'`
		ip4=`echo $1 $ip1 $ip2 $ip3 | awk '{ printf "%i", $1-$2*(2^24)-$3*(2^16)-$4*(2^8) }'`
		echo "$ip1.$ip2.$ip3.$ip4"
	}

	# Function: remove redundant networks
	rm_redundantIP() {
		declare -a array1=("${!1}") 												# Put $1 into new array
		declare -a array2=() 														# Create second array
		declare maxIP=0 															# Initial IP for comparison
		declare n=0																	# Counter for array
		for net in ${array1[@]}; do
			lastIP=`get_lastIP $net`												# Get last IP(+1) of actual network 
			if [[ `echo $lastIP $maxIP | awk '$1>$2 {printf 1}'` ]]; then			# Comparing big integer. Only keep network if last IP is not covered by previous network
				array2[$n]=$net														# Write actual network into second array 
				maxIP=$lastIP														# Update maximum IP(+1)
				n=$[n+1]
			fi
		done

		for net in ${array2[@]}; do					# Return result
			if [ $net ]; then echo ${net}; fi		# Skip empty lines
		done
	}

	# Function: consolidate adjacent networks
	rm_adjacentIP() {
		declare -a array1=("${!1}")													# Put $1 into new array1
		declare -a array2=() 														# Create working array2
		declare oldlastIP=0															# Initial IP for comparison
		declare n=0																	# Counter for array2
		declare d=1																	# Initial counter for adjacents
		declare range=0																# IP range

		for net in ${array1[@]}; do													# Loop through network list
			firstIP=`get_firstIP $net`												# Get decimal first IP from actual network
			netmask=`get_IPrange $net`												# Get decimal IP range from actual network
			lastIP=`get_lastIP $net`												# Get decimal last IP(+1) from actual network

			if [[ `echo $firstIP $oldlastIP | awk '$1==$2 {printf 1}'` ]]; then		# Check if adjacent network, then count adjacent series
				d=$[d+1]															# Count adjacent series
				if [ $d -eq 2 ]; then												# If 1 or more adjacents
					range=`get_IPrange ${array2[$[n-1]]}`							# Get range from network
				fi
                range=`echo $range $netmask | awk '{printf "%.0f\n", $1+$2;}'` 		# Calculate total range of adjacent networks
			elif [ $d -gt 1 ]; then													# Consolidate adjacent networks
				newfirstIP=`get_firstIP ${array2[$[n-d]]}`							# Get first IP from new consolidated network
																					# Calculate netmask from range:
				suffix_list=`echo $range | awk '
					{
						expo=$1;
						do {
							printf 32-int(log(expo)/log(2))" "
							expo=expo-2^int(log(expo)/log(2))
						} while (expo > 0) 
						printf "\n"
					}'`

				for suffix in $suffix_list; do										# Create new CIDR
					array2[$[n-d]]=`dec2ip $newfirstIP`"/"$suffix					# Write new network into array
					newfirstIP=`get_lastIP ${array2[$[n-d]]}`						# Get first IP from new consolidated network
					d=$[d-1]														# Decrease adjacent series counter
				done
				while [ $d -gt 0 ]; do												# Empty excessive entries
					array2[$[n-d]]=""												# Empty excessive array
					d=$[d-1]														# Decrease adjacent series counter
				done
				d=1 																# Initial counter for adjacent series
			fi
			array2[$n]=$net															# Keep "normal" network
			oldlastIP=$lastIP														# Update highest IP(+1)
			n=$[n+1]																# Increase counter for array2
		done

		for net in ${array2[@]} ; do												# Return result
			if [ $net ]; then echo ${net}; fi										# Skip empty lines
		done
	}

	# Function: print statistics
	show_stats() {
		declare -a array1=("${!1}") 												# Put $1 (asn_list) into new array
		declare -a array2=("${!2}") 												# Put $2 (net_list) into new array
		declare countASN=0															# Counter for ASN
		declare countNet=0															# Counter for networks
		declare countIP=0															# Counter for IP
		for asn in ${array1[@]}; do
			countASN=$[countASN + 1]												# Count ASN
		done
		for net in ${array2[@]}; do
			countNet=$[countNet + 1]												# Count networks
			netmask=`get_IPrange $net`												# Get decimal IP range from actual network
			countIP=`echo $countIP $netmask | awk '{printf "%.0f", $1+$2}'`			# Count IP
			#countIP=$[countIP + $netmask]											# Count IP
		done
		countIP=`printf "%'i\n" $countIP`											# Point separated format
		echo "    $countNet networks with $countIP IPs found in $countASN ASNs for $3"
	}


#######################################################################
# Main procedures
	addNetworks() {
		if [ ! $1 ]; then 															# Default ipfire mode
			# Get highest number from existing objects in [customnetworks|customgroups]
			if [[ -w $customnetworks ]]; then
				network_object_number=$(cat $customnetworks | cut -f1 -d',' | awk '{for(i=1;i<=NF;i++) if($i>maxval) maxval=$i;}; END { print maxval;}')
			else
				echo -e "File $customnetworks not found or write protected.\nCheck your IPFire installation."
				exit 0
			fi
			if [[ -w $customgroups ]]; then
				group_object_number=$(cat $customgroups | cut -f1 -d',' | awk '{for(i=1;i<=NF;i++) if($i>maxval) maxval=$i;}; END { print maxval;}')
			else
				echo -e "File $customgroups not found or write protected.\nCheck your IPFire installation."
				exit 0
			fi
			# Increase counter
			network_object_number=$[network_object_number +1]
			group_object_number=$[group_object_number +1]
		fi
		for company in ${company_array[@]}; do
			# Get all company ASNs
			declare asn_array=()
			declare asn_list=()
			echo "---[Get all $company ASNs]---"
			for asn_gather in ${getASNfromCOMPANY[@]}; do													# Loop through ASN sources
				asn_array=(`$asn_gather $company`)
				asn_list=(`echo ${asn_list[@]} ${asn_array[@]} | sed 's/ /\n/g' | sort -u -tS -n -k2,2`)	# Append to list, rough sorting
			done
			if [ ! $asn_list ]; then
				echo "---[No ASN found for $company]---"
			else
				# Loop through all ASN
				declare net_array=()
				declare net_list=()
				for asn in ${asn_list[@]}; do
					# Store networks from ASN in file
					echo "---[Get $company networks for $asn]---"
					for net_gather in ${getNETfromASN[@]}; do												# Loop through NET webservices
						net_array=(`$net_gather $asn`)
						net_list=(`echo ${net_list[@]} ${net_array[@]} | sed 's/ /\n/g' | sort -u`)			# Append to list, rough sorting
					done
				done
				if [ ! $net_list ]; then
					echo "---[No networks found for $company]---"
				else
					# Consolidate adjacent and overlapping netblocks
					before=${#net_list[@]}																	# Number of network entries before consolidate
					if [[ $verbose ]]; then show_stats asn_list[@] net_list[@] $company; fi
					# Sort network list
					IFS=$'\n'
					net_list=($(echo "${net_list[*]//\//.}" | sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 | awk -F"." '{ printf "%d.%d.%d.%d/%d\n", $1, $2, $3, $4, $5 }'))
					unset IFS
					if [ "$1" != "--network_raw" ]; then
						echo "---[Remove adjacent and overlapping netblocks]---"
						net_list=(`rm_redundantIP net_list[@]`)												# Remove redundant networks
						net_list=(`rm_adjacentIP net_list[@]`)												# Consolidate adjacent networks
					fi
					after=${#net_list[@]} 																	# Number of network entries after consolidate
					if [[ $verbose ]]; then echo "    $[$before - $after] of $before networks removed"; fi

					# Write objects to files
					echo "---[Creating objects for $company networks]---"
					case "$1" in																			# Check Mode
						"--asn") {
							printf "### Company: ${company} ###\n" >> $output_file							# Write company remark to file
							for net in ${asn_list[@]}; do
								printf "${net}\n" >> $output_file											# Write new objects to files
							done
						};;
						--network|--network_raw) {
							printf "### Company: ${company} ###\n" >> $output_file							# Write company remark to file
							for net in ${net_list[@]}; do
								printf "${net}\n" >> $output_file											# Write new objects to files
							done
						};;
						--iptable) {
							printf "## Company: ${company}\n" >> $output_file								# Write company remark to file
							for net in ${net_list[@]}; do
								printf "${iptable_path} -A OUTPUT -d ${net} -j REJECT\n" >> $output_file	# Write new objects to files
							done
						};;
						--afwall) {
							printf "## Company: ${company}\n" >> $output_file								# Write company remark to file
							for net in ${net_list[@]}; do
								# Write new objects to files	
								printf "${afwall_path} -A \"afwall\" -d ${net} -j REJECT\n" >> $output_file	# Write new objects to files
							done
						};;
						*) {																				# Default ipfire mode
							counter=1
							for net in ${net_list[@]}; do
								# Separate IP and netmask
								ip=${net%/*}
								if [ "$ip" != "0.0.0.0" ]; then 											# Double check for no empty lines
									netmask=${net#*/}
									# Write new objects to files [customnetworks|customgroups]                
									printf "$network_object_number,$company-Network Nr.$counter,$ip,$(cdr2mask $netmask),$auto_remark\n" >> $customnetworks
									printf "$group_object_number,$company,$auto_remark,$company-Network Nr.$counter,Custom Network\n" >> $customgroups
									# Increase counter
									network_object_number=$[$network_object_number +1]
									group_object_number=$[$group_object_number +1]
									counter=$[$counter +1]
								fi
							done
						};;
					esac
					if [[ $verbose ]]; then show_stats asn_list[@] net_list[@] $company; fi
				fi
			fi
		done
		if [ $1 ]; then echo "---[Result written to $output_file]---"; fi											# Resutfile info
	}

	cleanupNetworks() {																						# Remove entries from ipfire files
		for ipfire_file in $customnetworks $customgroups; do
			if [[ -w $ipfire_file ]]; then
				if [[ ${company_array[0]} == "ALL" ]]; then													# Remove all entries made by asn_ipfire.sh
					echo "---[Removing $company objects from $ipfire_file ]---"
					sed -i "/,$auto_remark/Id" $ipfire_file;
				else
					for company in ${company_array[@]}; do
					echo "---[Removing $company objects from $ipfire_file ]---"
						sed -i "/$company.*$auto_remark/Id" $ipfire_file;									# Remove company entries made by asn_ipfire.sh
					done
				fi
			elif [[ -f $ipfire_file ]]; then
				echo -e "File $ipfire_file write protected.\nCheck your IPFire installation."
			fi
		done
	}

	print_help() {																							# Help info
		echo "Usage: asn_ipfire.sh [OPTION] [COMPANYs | -f FILE]"
		echo "Add or remove networks to IPFire firewall Groups: Networks & Host Groups"
		echo
		echo "Options:"
		echo "  -a, --add         Add new company networks"
		echo "  -r, --remove      Remove company networks from customnetworks & customgroups"
		echo "                    COMPANY='ALL' to remove all entries done by this script"
		echo "  -f, --file FILE   Get company list from FILE"
		echo "      --verbose     Verbose mode"
		echo "  -l, --list        List entries done by this script"
		echo "      --renumber    Renumber lines of customnetworks & customgroups files"
		echo "  -v, --version     Show script version"
		echo "  -h, --help        Show this help"
		echo
		echo "Create special output files (Non-IPFire-Mode):"
		echo "  --network        Create FILE '$file_network' with networks"
		echo "  --network_raw    dito, but networks not consolidated"
		echo "  --asn            Create FILE '$file_asn' with ASNs only"
		echo "  --iptable        Create FILE '$file_iptable' with iptable rules"
		echo "  --afwall         Create FILE '$file_afwall' with afwall rules"
		echo
		echo "COMPANY to be one or more company names, put into double quotes ('\"')"
		echo "        Multi company names can be comma or space separated"
		echo "usage example: asn_ipfire.sh -a \"CompanyA CompanyB CompanyC\" "
		echo "               asn_ipfire.sh --asn \"CompanyA,CompanyB,CompanyC\" "
		echo
		echo "FILE = name of a file, containing one or more company names."
		echo "Company names to be separated by space or line feed."
		echo "usage example: asn_ipfire.sh -r -f company.lst "
		echo "               asn_ipfire.sh --network -f company.lst "
		echo
		echo "Notes:"
		echo "  Company names are handled case insensitive."
		echo "  Only entries made by asn_ipfire.sh can be removed."
		echo "  These entries are recognized by the 'Remark'-column in IPFire."
		echo
	}

#######################################################################
# Main program

company_array=()																	# Create empty company array
mode=""																				# Initial mode
verbose=""																			# Default verbose = OFF
helptext="Usage: asn_ipfire.sh [OPTION] [COMPANYs | -f FILE] \nTry 'asn_ipfire.sh --help' for more information."

# Check arguments and get company array
if [[ $# -eq 0 ]]; then echo -e $helptext; exit 0; fi								# No arguments --> exit
if [[ $# -gt 4 ]]; then echo -e "Too many arguments.\n"$helptext; exit 0; fi		# Too many arguments --> exit

while [[ $# > 0 ]] ; do
	case $1 in
		-f | --file) {
			if [[ -f $2 ]]; then													# File exist
				company_array_from_file=(`sed 's/[,]/ /g; s/[\/]//g' <<< cat $2`)	# Substitute commata, remove special chars like "/"
				shift
			else																	# File not exist --> exit
				echo "Company file not found."
				echo -e $helptext
				exit 0
			fi
		};;
		-a|--add | -r|--remove | --asn | --network | --network_raw | --iptable | --afwall) {
			if [[ $mode ]]; then 													# Mode already set
				echo -e "Too many arguments.\n"$helptext
				exit 0
			else
				mode=$1
			fi
			if [[ $2 && ${2:0:1} == "-" && "$2" != "-f" ]]; then 					# followed by argument instead of company names
				echo -e "Wrong order of arguments.\n"$helptext						# Wrong order of arguments --> exit
				exit 0
			fi
			if [[ $2 && "${2:0:1}" != "-" ]]; then 									# No company names given
				company_array_from_arg=(`sed 's/[,]/ /g; s/[\/]//g' <<< $2`)
				shift
			fi
		};;
		-l|--list | --renumber | -v|--version | -h|--help ) {
			if [[ $mode || $2 ]]; then												# No more arguments allowed for this option
				echo -e "Too many arguments.\n"$helptext							# Too many parameter --> exit
				exit 0
			else
				mode=$1
			fi
		};;
		--verbose ) {
			verbose=1																# Verbose mode shows stats
		};;
		*) {
			echo -e "Unknown argument.\n"$helptext									# Unknown arguments --> exit
			exit 0
		};;
	esac
	shift
done

company_array=(`echo ${company_array_from_file[@]} ${company_array_from_arg[@]} | sed 's/ /\n/g' | sort -uf`)

case $mode in

	-a|--add | -r|--remove) {														# Add objects to ipfire files
		if [[ ! -f /etc/init.d/firewall ]]; then
			echo -e "/etc/init.d/firewall not found.\nCheck your IPFire installation."
			exit 0
		fi
		if [ ! $company_array ]; then
			echo "No company names found. Nothing done!"
			echo "Try 'asn_ipfire.sh --help' for more information."
			exit 0
		fi
		cleanupNetworks																# Remove existing entries
		if [[ $mode == "-a" || $mode == "--add" ]]; then
			addNetworks																# Get networks and write to file
		fi
		/etc/init.d/firewall restart												# Restart firewall
		echo "---[All done!]---"
	};;

	-l|--list) {																	# Function: List all company names already there by asn_ipfire
		if [[ -f $customnetworks ]]; then
			# Show companies from customnetworks
			echo "Company names in "$customnetworks":"
			cat $customnetworks | grep "$auto_remark" | grep -Eo '[a-Z]*-Network Nr' | sort -u | sed 's/-Network Nr//'
		else
			echo -e "File $customnetworks not found.\nCheck your IPFire installation."
		fi
		if [[ -f $customgroups ]]; then
			# Show companies from customgroups
			echo "Company names in "$customgroups":"
			cat $customgroups | grep "$auto_remark" | grep -Eo '[a-Z]*-Network Nr' | sort -u | sed 's/-Network Nr//'
		else
			echo -e "File $customgroups not found.\nCheck your IPFire installation."
		fi
	};;

	--renumber) {																	# Function: Re-number lines
		if [[ -w $customnetworks ]]; then
			sed -i '/^$/d;=' $customnetworks										# Delete empty lines and add numbered lines
			sed -i 'N;s/\n[0-9]\+//' $customnetworks								# Renumber lines by consolidation
			echo "File $customnetworks renumbered."
		else
			echo -e "File $customnetworks not found or write protected.\nCheck your IPFire installation."
		fi
		if [[ -w $customgroups ]]; then
			sed -i '/^$/d;=' $customgroups											# Delete empty lines and add numbered line
			sed -i 'N;s/\n[0-9]\+//' $customgroups									# Renumber lines by consolidation
			echo "File $customgroups renumbered."
		else
			echo -e "File $customgroups not found or write protected.\nCheck your IPFire installation."
		fi
	};;

	--asn | --network | --network_raw | --iptable | --afwall ) {					# Create special output files
		output_file="file_"${mode:2}												# Get output file
		output_file="${!output_file}"

		if [ $company_array ]; then
			touch $output_file > $output_file
			addNetworks	$mode														# Get and add new networks
			echo "---[All done!]---"
		else
			echo "No company names found. Nothing done!"
			echo "Try 'asn_ipfire.sh --help' for more information."
		fi
	};;

	-v|--version) echo $revision;;													# Show version

	-h|--help) print_help;;															# Show help

	*) echo -e $helptext;;															# Wrong or unknown parameter

esac

exit 0
