#!/bin/bash

#######################################################################
# IPFire network object creator for IPv4 addresses based on ASN information
# Creates 'customnetworks' objects in /var/ipfire/fwhosts/customnetworks
# Creates 'customgroups' objects in /var/ipfire/fwhosts/customgroups
#######################################################################

#######################################################################
  revision="asn_ipfire.sh v0.7.3"                  # do not comment out
# Last updated: November 25 2017 by maloe
# Author: Mike Kuketz, maloe
# Visit: www.kuketz-blog.de
#######################################################################

#######################################################################
# Constants, Filenames, Enable/Disable Sources

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
file_asn="asn_list.txt"				# output file for ASNs only

temppath="."					# path to store temporary source file (default: ".")
temp1="asn_cidrreport.tmp"			# Define temp file
temp2="asn_bglooking.tmp"			# Define temp file

# Local files can be used as ASN and/or network sources. To be activated by enabling "gather_ASN0" and/or "gather_NET0" into following arrays.
local_asn_file="local_asn.list"			# Note: Each ASN must be in the same line as the corresponding company, e.g. 'AS1234 CompanyA' or 'CompanyA AS1234'
local_net_file="local_net.list"			# Note: Each network must be in the same line as the corresponding ASN, e.g. '1.2.3.4/24 AS5678' or 'AS5678 1.2.3.4/24'

# Enable/disable ASN sources: Remove leading hashes (#) to enable ASN_sources. 
getASNfromCOMPANY=( \
  ASN_local \					# local source (local_asn_file)
  ASN_cidrreport \				# cidr-report.org
# ASN_ultratools \				# ultratools.com
# ASN_bglookingglass \				# bgplookingglass.com
)

# Enable/disable network sources: Remove leading hash (#) to enable NET_sources. 
getNETfromASN=( \
  NET_local \					# local source (local_net_file)
  NET_ripe \					# stat.ripe.net
# NET_ipinfo \					# ipinfo.io
# NET_radb \					# whois.radb.net
)										

#######################################################################
# Gather-Functions: add further sources here and activate them in above arrays getASNfromCOMPANY() and getNETfromASN()
# ASN sources: function must return a list of ASNs
	ASN_local() 	# Get ASN from local file
	{	
		if [[ -f $local_asn_file ]]; then 
			cname=`echo $1 | sed 's/~/ /g; s/*/.*/g'` 										# Replace ~ with space
			asn_array=`cat $local_asn_file | grep -i "$cname" | grep -Eo 'AS[0-9]+'`
		fi; 
	}
	ASN_cidrreport() 	# Get ASN from cidr-report.org
	{	
		if [[ $dl != "local" ]]; then													# wget or curl available?
			if [[ ! -f $temp1 ]] && [[ ${#company_array[@]} -gt 1 || $keeptemp ]]; then						# Temp file not exist and more than one company names or option keeptemp is enabled
				touch $temp1 2> /dev/null											# Temp file writable?
				if [[ -w $temp1 ]]; then											# Write temp file
					echo "---[Downloading ASN Source List from www.cidr-report.org]---"
					$dl "https://www.cidr-report.org/as2.0/autnums.html" | grep -Eo '>AS[0-9]+.*' | sed 's/^>//; s/[ ]*<\/a>[ ]*/ /' >> $temp1
				fi
			fi
			cname=`echo $1 | sed 's/~/ /g; s/*/.*/g'` 										# Replace ~ with space and * with expression .*
			if [[ -f $temp1 ]]; then 												# Read from temp file
				asn_array=`cat $temp1 | grep -i "$cname" | grep -Eo '^AS[0-9]+'`
			else															# Read from source
				echo "---[Downloading ASN Source List from www.cidr-report.org]---"
				asn_array=`$dl "https://www.cidr-report.org/as2.0/autnums.html" | grep -i "$cname" | grep -Eo '>AS[0-9]+' | grep -Eo 'AS[0-9]+'`
			fi; 
		fi
	}
	ASN_ultratools() 	# Get ASN from ultratools.org
	{	
		if [[ $dl != "local" ]]; then													# wget or curl available?
			cname=`echo $1 | sed 's/~/ /g; s/+/%2B/g'`  										# Replace ~ with space and "+" with %2B
			asn_array=(`$dl "https://www.ultratools.com/tools/asnInfoResult?domainName=$cname" | grep -Eo 'AS[0-9]+' | uniq`)
		fi
	}
	ASN_bglookingglass() 	# Get ASN from bgplookingglass.com
	{ 
		if [[ $dl != "local" ]]; then													# wget or curl available?
			if [[ ! -f $temp2 ]] && [[ ${#company_array[@]} -gt 1 || $keeptemp ]]; then						# Temp file not exist and more than one company names or option keeptemp is enabled
				touch $temp2 2> /dev/null											# Check if writable?
				if [[ -w $temp2 ]]; then
					echo "---[Downloading ASN Source List from www.bgplookingglass.com]---"
					$dl "http://www.bgplookingglass.com/list-of-autonomous-system-numbers" | sed -n '/AS[0-9]/ p' | sed 's/<br \/>/\n/g; s/^[[:space:]]*<pre>//; s/[ ]\+/ /g' >> $temp2
					$dl "http://www.bgplookingglass.com/list-of-autonomous-system-numbers-2" | sed -n '/AS[0-9]/ p' | sed 's/<br \/>/\n/g; s/^[[:space:]]*<pre>//; s/[ ]\+/ /g' >> $temp2
					$dl "http://www.bgplookingglass.com/4-byte-asn-names-list" | sed -n '/AS[0-9]/ p' | sed 's/<br \/>/\n/g; s/^[[:space:]]*<pre>//; s/[ ]\+/ /g' >> $temp2
				fi
			fi
			cname=`echo $1 | sed 's/~/ /g; s/*/.*/g'` 										# Replace ~ with space and * with expression .*
			if [[ -f $temp2 ]]; then 												# Read from temp file
				asn_array=`cat $temp2 | grep -i "$cname" | grep -Eo '^AS[0-9]+'`
			else															# Temp file not writable
				echo "---[Downloading ASN Source List from www.bgplookingglass.com]---"
				asn_array=(`$dl "http://www.bgplookingglass.com/list-of-autonomous-system-numbers" | sed -n '/AS[0-9]/ p' | sed 's/<br \/>/\n/g' | grep -i "$cname" | sed 's/^[[:space:]]*<pre>//' | grep -Eo '^AS[0-9]+'`)
				asn_array=(${asn_array[@]} `$dl "http://www.bgplookingglass.com/list-of-autonomous-system-numbers-2" | sed -n '/AS[0-9]/ p' | sed 's/<br \/>/\n/g' | grep -i "$cname" | sed 's/^[[:space:]]*<pre>//' | grep -Eo '^AS[0-9]+'`)
				asn_array=(${asn_array[@]} `$dl "http://www.bgplookingglass.com/4-byte-asn-names-list" | sed -n '/AS[0-9]/ p' | sed 's/<br \/>/\n/g' | grep -i "$cname" | sed 's/^[[:space:]]*<pre>//' | grep -Eo '^AS[0-9]+'`)
			fi
		fi
	}

# Network sources: function must return a list of CIDR networks
	NET_local()	# Get networks from local file, pre-sorting
	{	
		if [[ -f $local_net_file ]]; then
			cat $local_net_file | grep -i "$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | sort -u
		fi 
	}				
	NET_ripe()	# Get networks from stat.ripe.net, pre-sorting
	{ 
		if [[ $dl != "local" ]]; then													# wget or curl available?
			$dl "https://stat.ripe.net/data/announced-prefixes/data.json?preferred_version=1.1&resource=$1" | grep -Eo '([0-9.]+){4}/[0-9]+' | sort -u
		fi
	}	
	NET_ipinfo()	# Get networks from ipinfo.io, pre-sorting
	{ 
		if [[ $dl != "local" ]]; then													# wget or curl available?
			$dl "https://ipinfo.io/$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' | sort -u
		fi
	}														
	NET_radb()	# Get networks from whois, pre-sorting
	{ 
		if [[ -x `which whois 2>/dev/null` ]]; then											# whois available?
			whois -h whois.radb.net -i origin $1 | grep -w "route:" | awk '{print $NF}' | sort -n | sort -u 
		fi 
	}														


#######################################################################
# NO  NEED TO EDIT ANYTHING BELOW
#######################################################################
# Functions
	# Function: check existence of wget or curl
	chkSystem()
	{
		if [[ -d /var/ipfire ]] && [[ -f /etc/init.d/firewall ]]; then 					# Running on ipfire sytem?
			is_ipfire=1
		else
			is_ipfire=""
		fi
		
		if [[ -x `which wget 2>/dev/null` ]]; then 
			dl="wget --quiet -O - --https-only"							# Use wget if existent
		elif [[ -x `which curl 2>/dev/null` ]]; then
			dl="curl --silent"									# Use curl if existent and wget is missing
		else
			echo "Warning: did not found wget nor curl. Only local sources usable."			# Neither wget nor curl was found
			dl=local
		fi
	}

	# Function: get network mask
	cdr2mask()
	{
		# Number of args to shift, 255..255, first non-255 byte, zeroes
		set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
		[ $1 -gt 1 ] && shift $1 || shift
		echo ${1-0}.${2-0}.${3-0}.${4-0}
	}

	# Functions: get decimal IP values
	get_firstIP() {	echo ${1/\//.} | awk -F"." '{ printf "%.0f", $1*2^24+$2*2^16+$3*2^8+$4 }'; }		# First IP of network
	get_IPrange() { echo $1 | awk -F"/" '{ printf "%.0f", 2^(32-$2)}'; }					# IP range of network
	get_lastIP() { echo ${1/\//.} | awk -F"." '{ printf "%.0f", $1*2^24+$2*2^16+$3*2^8+$4+2^(32-$5)}'; }	# Last IP +1 of network

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
		declare -a array1=("${!1}") 									# Put $1 into new array
		declare -a array2=() 										# Create second array
		declare maxIP=0 										# Initial IP for comparison
		declare n=0											# Counter for array
		for net in ${array1[@]}; do
			lastIP=`get_lastIP $net`								# Get last IP(+1) of actual network 
			if [[ `echo $lastIP $maxIP | awk '$1>$2 {printf 1}'` ]]; then				# Comparing big integer. Only keep network if last IP is not covered by previous network
				array2[$n]=$net									# Write actual network into second array 
				maxIP=$lastIP									# Update maximum IP(+1)
				n=$[n+1]
			fi
		done

		for net in ${array2[@]}; do									# Return result
			if [ $net ]; then echo ${net}; fi							# Skip empty lines
		done
	}

	# Function: consolidate adjacent networks
	rm_adjacentIP() {
		declare -a array1=("${!1}")									# Put $1 into new array1
		declare -a array2=() 										# Create working array2
		declare oldlastIP=0										# Initial IP for comparison
		declare n=0											# Counter for array2
		declare d=1											# Initial counter for adjacents
		declare range=0											# IP range

		for net in ${array1[@]}; do									# Loop through network list
			firstIP=`get_firstIP $net`								# Get decimal first IP from actual network
			netmask=`get_IPrange $net`								# Get decimal IP range from actual network
			lastIP=`get_lastIP $net`								# Get decimal last IP(+1) from actual network

			if [[ `echo $firstIP $oldlastIP | awk '$1==$2 {printf 1}'` ]]; then			# Check if adjacent network, then count adjacent series
				d=$[d+1]									# Count adjacent series
				if [ $d -eq 2 ]; then								# If 1 or more adjacents
					range=`get_IPrange ${array2[$[n-1]]}`					# Get range from network
				fi
                range=`echo $range $netmask | awk '{printf "%.0f\n", $1+$2;}'` 					# Calculate total range of adjacent networks
			elif [ $d -gt 1 ]; then									# Consolidate adjacent networks
				newfirstIP=`get_firstIP ${array2[$[n-d]]}`					# Get first IP from new consolidated network
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

				for suffix in $suffix_list; do							# Create new CIDR
					array2[$[n-d]]=`dec2ip $newfirstIP`"/"$suffix				# Write new network into array
					newfirstIP=`get_lastIP ${array2[$[n-d]]}`				# Get first IP from new consolidated network
					d=$[d-1]								# Decrease adjacent series counter
				done
				while [ $d -gt 0 ]; do								# Empty excessive entries
					array2[$[n-d]]=""							# Empty excessive array
					d=$[d-1]								# Decrease adjacent series counter
				done
				d=1 										# Initial counter for adjacent series
			fi
			array2[$n]=$net										# Keep "normal" network
			oldlastIP=$lastIP									# Update highest IP(+1)
			n=$[n+1]										# Increase counter for array2
		done

		for net in ${array2[@]} ; do									# Return result
			if [ $net ]; then echo ${net}; fi							# Skip empty lines
		done
	}

	# Function: print statistics
	show_stats() {												# Requires arguments: asn_array net_array, company
		declare -a asn_array=("${!1}") 									# Put $1 (asn_list) into new array
		declare -a net_array=("${!2}") 									# Put $2 (net_list) into new array
		declare countASN=0										# Counter for ASN
		declare countNet=0										# Counter for networks
		declare countIP=0										# Counter for IP
		for asn in ${asn_array[@]}; do
			countASN=$[countASN + 1]								# Count ASN
		done
		for net in ${net_array[@]}; do
			countNet=$[countNet + 1]								# Count networks
			netmask=`get_IPrange $net`								# Get decimal IP range from actual network
			countIP=`echo $countIP $netmask | awk '{printf "%.0f", $1+$2}'`				# Count IP
			#countIP=$[countIP + $netmask]								# Count IP
		done
		countIP=`printf "%'i\n" $countIP`								# Point separated format
		echo "    $countNet networks with $countIP IPs found in $countASN ASNs for $3"
	}


#######################################################################
# Main procedures
	addNetworks() {
		if [ ! $1 ]; then 										# Default ipfire mode
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
			prnt_company=`echo $company | sed 's/~/ /g; s/,//g'`									# Printable company name with space (and no commas)
			echo "---[Get all $prnt_company ASNs]---"
			for asn_gather in ${getASNfromCOMPANY[@]}; do										# Loop through ASN sources
				$asn_gather $company
				asn_list=(`echo ${asn_list[@]} ${asn_array[@]} | sed 's/ /\n/g' | sort -u -tS -n -k2,2`)			# Append to list, rough sorting
			done
			if [ ! $asn_list ]; then
				echo "---[No ASN found for $prnt_company]---"
			else
				# Loop through all ASN
				declare net_array=()
				declare net_list=()
				for asn in ${asn_list[@]}; do
					# Store networks from ASN in file
					echo "---[Get $prnt_company networks for $asn]---"
					for net_gather in ${getNETfromASN[@]}; do								# Loop through NET webservices
						net_array=(`$net_gather $asn`)
						net_list=(`echo ${net_list[@]} ${net_array[@]} | sed 's/ /\n/g' | sort -u`)			# Append to list, rough sorting
					done
				done
				if [[ $verbose ]]; then echo "---[Removing invalid networks]---"; fi
				net_list=(`echo ${net_list[@]} | sed 's/\([0-9]\{1,3\}.\)\{3\}[0-9]\{1,3\}\/0[0-9]\?[ ]\?//g'`)			# Remove possible x.x.x.x/0x
				if [ ! $net_list ]; then
					echo "---[No networks found for $prnt_company]---"
				else
					# Consolidate adjacent and overlapping netblocks
					before=${#net_list[@]}											# Number of network entries before consolidate
					if [[ $verbose ]]; then show_stats asn_list[@] net_list[@] $company; fi
					# Sort network list
					IFS=$'\n'
					net_list=($(echo "${net_list[*]//\//.}" | sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 | awk -F"." '{ printf "%d.%d.%d.%d/%d\n", $1, $2, $3, $4, $5 }'))
					unset IFS
					if [ "$1" != "--network_raw" ]; then
						echo "---[Remove adjacent and overlapping netblocks]---"
						net_list=(`rm_redundantIP net_list[@]`)								# Remove redundant networks
						net_list=(`rm_adjacentIP net_list[@]`)								# Consolidate adjacent networks
					fi
					after=${#net_list[@]} 											# Number of network entries after consolidate
					if [[ $verbose ]]; then echo "    $[$before - $after] of $before networks removed"; fi

					# Write objects to files
					echo "---[Creating objects for $prnt_company networks]---"
					case "$1" in												# Check Mode
						"--asn") {
							printf "### Company: ${prnt_company} ###\n" >> $output_file				# Write company remark to file
							for net in ${asn_list[@]}; do
								printf "$net\n" >> $output_file							# Write new objects to files
							done
						};;
						--network|--network_raw) {
							printf "### Company: ${prnt_company} ###\n" >> $output_file				# Write company remark to file
							for net in ${net_list[@]}; do
								printf "$net\n" >> $output_file							# Write new objects to files
							done
						};;
						--iptable) {
							printf "### Company: ${prnt_company}\n" >> $output_file					# Write company remark to file
							for net in ${net_list[@]}; do
								printf "$iptable_path -A OUTPUT -d $net -j REJECT\n" >> $output_file		# Write new objects to files
							done
						};;
						--afwall) {
							printf "### Company: ${prnt_company}\n" >> $output_file					# Write company remark to file
							for net in ${net_list[@]}; do
								# Write new objects to files	
								printf "$afwall_path -A \"afwall\" -d $net -j REJECT\n" >> $output_file		# Write new objects to files
							done
						};;
						*) {												# Default ipfire mode
							counter=1
							for net in ${net_list[@]}; do
								# Separate IP and netmask
								ip=${net%/*}
								if [ "$ip" != "0.0.0.0" ]; then 						# Double check for no empty lines
									netmask=${net#*/}
									# Write new objects to files [customnetworks|customgroups]                
									printf "$network_object_number,$company-Network Nr.$counter,$ip,$(cdr2mask $netmask),$auto_remark\n" >> $customnetworks
									printf "$group_object_number,$prnt_company,$auto_remark,$company-Network Nr.$counter,Custom Network\n" >> $customgroups
									# Increase counter
									network_object_number=$[$network_object_number +1]
									group_object_number=$[$group_object_number +1]
									counter=$[$counter +1]
								fi
							done
						};;
					esac
					if [[ $verbose ]]; then show_stats asn_list[@] net_list[@] $company; fi
					echo "---[Result for ${prnt_company} written to $output_file]---"					# Resutfile info
				fi
			fi
		done
		
		# remove temp files
		if [[ ! $keeptemp ]]; then
			echo "---[Removing temporary source files]---"
			if [[ -f $temp1 ]]; then rm $temp1; fi
			if [[ -f $temp2 ]]; then rm $temp2; fi
		fi
	}

	cleanupNetworks() {											# Remove entries from ipfire files
		for ipfire_file in $customnetworks $customgroups; do
			if [[ -w $ipfire_file ]]; then
				if [[ $backup ]]; then 
					if [[ $verbose ]]; then echo "---[Backing up $ipfire_file.bak ]---"; fi
					cp -f $ipfire_file $ipfire_file.bak					# Create ipfire backup files
				fi
				if [[ ${company_array[0]} == "ALL" ]]; then					# Remove all entries made by asn_ipfire.sh
					echo "---[Removing all objects from $ipfire_file ]---"
					sed -i "/,$auto_remark/Id" $ipfire_file;
				else
					for company in ${company_array[@]}; do
					prnt_company=`echo $company | sed 's/~/ /g;'`				# Company name with space and "+"
					echo "---[Removing $prnt_company objects from $ipfire_file ]---"
						sed -i "/$company.*$auto_remark/Id" $ipfire_file;		# Remove company entries made by asn_ipfire.sh
					done
				fi
			elif [[ -f $ipfire_file ]]; then
				echo -e "File $ipfire_file write protected.\nCheck your IPFire installation."
			fi
		done
	}

	removeBackup() {											# Remove ipfire backup files
		for ipfire_file in $customnetworks $customgroups; do
			if [[ -w $ipfire_file.bak ]]; then
				if [[ $verbose ]]; then echo "---[Removing backup $ipfire_file.bak ]---"; fi
				rm -f $ipfire_file.bak
			fi
		done
	}
	
	renumberIpfireFiles() {											# Remove entries from ipfire files
		for ipfire_file in $customnetworks $customgroups; do
			if [[ -w $ipfire_file ]]; then
				if [[ $verbose ]]; then echo "---[Renumbering $ipfire_file ]---"; fi
				sed -i '/^$/d;=' $ipfire_file							# Delete empty lines and add numbered lines
				sed -i 'N;s/\n[0-9]\+//' $ipfire_file						# Renumber lines by consolidation
			else
				echo -e "File $ipfire_file not found or write protected.\nCheck your IPFire installation."
			fi
		done
	}

	restoreIpfireFiles() {											# Restore ipfire file
		for ipfire_file in $customnetworks $customgroups; do
			if [[ -w $ipfire_file ]]; then
				if [[ -f "$ipfire_file.bak" ]]; then 
					cp -f $ipfire_file.bak $ipfire_file
					echo "File $ipfire_file restored."
				else
					echo "No backup file $ipfire_file.bak found."
				fi
			else
				echo -e "File $ipfire_file not found or write protected.\nCheck your IPFire installation."
			fi
		done
	}

	listIpfireFiles () {											# Show companies from ipfire files
		for ipfire_file in $customnetworks $customgroups; do
			if [[ -f $ipfire_file ]]; then
				echo "Company names in "$ipfire_file":"
				cat $ipfire_file | grep "$auto_remark" | grep -Eo '[a-Z]*-Network Nr' | sort -u | sed 's/-Network Nr//'
			else
				echo -e "File $ipfire_file not found.\nCheck your IPFire installation."
			fi
		done
	}
	
	print_help() {												# Help info
		echo "Usage: asn_ipfire.sh [OPTION] [COMPANYs | -f FILE]"
		echo "Add or remove networks to IPFire firewall Groups: Networks & Host Groups"
		echo
		echo "Options:"
		echo "  -a, --add         Add new company networks"
		echo "  -r, --remove      Remove company networks from customnetworks & customgroups"
		echo "  -f, --file FILE   Get company list from FILE"
		echo "  -l, --list        List of companies already added by this script"
		echo "  -k, --keep        Keep temporary source files after finish"
		echo "      --renumber    Renumber lines of customnetworks & customgroups"
		echo "      --backup      Backup customnetworks & customgroups before change"
		echo "      --rmbackup    Remove backup files of customnetworks & customgroups"
		echo "      --restore     Restore customnetworks & customgroups from backup"
		echo "  -v, --verbose     Verbose mode"
		echo "  -V, --version     Show this script version and exit"
		echo "  -h, --help        Show this help and exit"
		echo
		echo "Create special output files (Non-IPFire-Mode):"
		echo "  --network        Create FILE '$file_network' with networks"
		echo "  --network_raw    dito, but networks not consolidated"
		echo "  --asn            Create FILE '$file_asn' with ASNs only"
		echo "  --iptable        Create FILE '$file_iptable' with iptable rules"
		echo "  --afwall         Create FILE '$file_afwall' with afwall rules"
		echo
		echo "COMPANY to be one or more company names, put into double quotes (\"...\")"
		echo "  Multi company names must be comma separated"
		echo "  Substitute spaces with tilde (~)"
		echo "  Restrict to exact matches with tilde (~) before and after the name"
		echo "  Company names are handled case insensitive."
		echo "  example: asn_ipfire.sh --add \"CompanyA,Company~NameB,~CompanyC~\" "
		echo
		echo "FILE to be a name of a file, containing one or more company names."
		echo "  Company names to be separated by comma or line feed."
		echo "  examples: asn_ipfire.sh -a -f company.list "
		echo "            asn_ipfire.sh --network -f company.list "
		echo
		echo "Option --remove only affects entries made by asn_ipfire.sh itself."
		echo "  These entries are recognized by the 'Remark'-column in IPFire."
		echo "  To remove all entries done by this script, use COMPANY='ALL' "
		echo "  examples: asn_ipfire.sh -r \"CompanyA, CompanyB\" "
		echo "            asn_ipfire.sh -r ALL "
		echo
	}

#######################################################################
# Main program

company_array=()												# Create empty company array
mode=""														# Initial mode
verbose=""													# Default verbose = OFF
backup=""													# Default backup of ipfire files = OFF
keeptemp=""													# Default Keep source temp file after finish = OFF
temp1="$temppath/$temp1"											# Source temp file
temp2="$temppath/$temp2"											# Source temp file
helptext="Usage: asn_ipfire.sh [OPTION] [COMPANYs | -f FILE] \nTry 'asn_ipfire.sh --help' for more information."

chkSystem													# ipfire system? wget or curl available?

# Check arguments and get company array
if [[ $# -eq 0 ]]; then echo -e $helptext; exit 0; fi								# No arguments --> exit
if [[ $# -gt 4 ]]; then echo -e "Too many arguments.\n"$helptext; exit 0; fi					# Too many arguments --> exit

while [[ $# > 0 ]] ; do
	case $1 in
		-f | --file) {
			if [[ -f $2 ]]; then												# File exist
				company_array_from_file=(`sed 's/[ ]*//g; s/,\+/ /g; s/\[//g; s/\]//g; s/[.\]*//g' <<< cat $2`)		# Substitute space,comma,slash
				shift
			else											# File not exist --> exit
				echo "Company file not found."
				echo -e $helptext
				exit 0
			fi
		};;
		-a|--add | -r|--remove | --asn | --network | --network_raw | --iptable | --afwall) {
			if [[ $mode ]]; then 									# Mode already set
				echo -e "Too many arguments.\n"$helptext
				exit 0
			else
				mode=$1
				if [[ ! $2 ]]; then 
					echo -e "No COMPANY names given.\n"$helptext
					exit 0
				elif [[ ${2:0:1} == "-" ]]; then 	# followed by argument instead of company names
					if [[ "$2" != "-f" && "$2" != "--file" ]]; then 	# followed by argument instead of company names
						echo -e "Wrong order of arguments.\n"$helptext			# Wrong order of arguments --> exit
						exit 0
					fi
				else
					company_array_from_arg=(`sed 's/[ ]*//g; s/,\+/ /g; s/\[//g; s/\]//g; s/[.\]*//g' <<< $2`)	# Trim empty entries
					shift
				fi
			fi
		};;
		-l|--list | --renumber | --restore | --rmbackup | -h|--help | -V|--version) {
			if [[ $mode ]] || [[ $2 ]]; then							# No more arguments allowed for this option
				echo -e "Too many arguments.\n"$helptext					# Too many parameter --> exit
				exit 0
			else
				mode=$1
			fi
		};;
		--backup ) {											# Don't write backup Ipfire files
			if [[ ! $mode ]] && [[ ! $2 ]]; then 
				echo -e "Missing arguments.\n"$helptext
				exit 0
			else
				backup=1
			fi
		};;
		-k|--keep ) {											# Keep temporary source files
			if [[ ! $mode ]] && [[ ! $2 ]]; then 
				echo -e "Missing arguments.\n"$helptext
				exit 0
			else
				keeptemp=1
			fi
		};;
		-v|--verbose ) {										# Verbose mode shows stats
			if [[ ! $mode ]] && [[ ! $2 ]]; then 
				echo -e "Missing arguments.\n"$helptext
				exit 0
			else
				verbose=1
			fi
		};;

		*) {
			echo -e "Unknown argument.\n"$helptext							# Unknown arguments --> exit
			exit 0
		};;
	esac
	shift
done

company_array=(`echo ${company_array_from_file[@]} ${company_array_from_arg[@]} | sort -uf`)
case $mode in

	-a|--add | -r|--remove) {										# Add objects to ipfire files
		if [[ $is_ipfire ]]; then
			if [ ! $company_array ]; then
				echo "No company names found. Nothing done!"
				echo "Try 'asn_ipfire.sh --help' for more information."
				exit 0
			fi
			cleanupNetworks										# Remove existing entries
			renumberIpfireFiles									# Renumbering
			if [[ $mode == "-a" || $mode == "--add" ]]; then
				addNetworks									# Get networks and write to file
			fi
			echo "---[Restarting firewall]---"
			/etc/init.d/firewall restart 1> /dev/null						# Restart firewall
			echo "---[All done!]---"
		else
			echo -e "IPFire not found.\nCheck your IPFire installation."
		fi
	};;

	-l|--list) {												# Function: List all company names already there by asn_ipfire
		if [[ $is_ipfire ]]; then 
			listIpfireFiles 
		else
			echo -e "IPFire not found.\nCheck your IPFire installation."
		fi
	};;

	--renumber) {
		if [[ $is_ipfire ]]; then 
			verbose=1
			renumberIpfireFiles 
		else
			echo -e "IPFire not found.\nCheck your IPFire installation."
		fi
	};;

	--rmbackup) {
		if [[ $is_ipfire ]]; then 
			verbose=1
			removeBackup 
		else
			echo -e "IPFire not found.\nCheck your IPFire installation."
		fi
	};;

	--restore) {
		if [[ $is_ipfire ]]; then 
			restoreIpfireFiles
		else
			echo -e "IPFire not found.\nCheck your IPFire installation."
		fi
	};;

	--asn | --network | --network_raw | --iptable | --afwall ) {						# Create special output files
		output_file="file_"${mode:2}									# Get output file
		output_file="${!output_file}"

		if [ $company_array ]; then
			touch $output_file > $output_file
			addNetworks $mode									# Get and add new networks
			echo "---[All done!]---"
		else
			echo "No company names found. Nothing done!"
			echo "Try 'asn_ipfire.sh --help' for more information."
		fi
	};;

	-V|--version ) {											# Show version and quit
		echo $revision;
	};;

	-h|--help) {
		print_help											# Show help and quit
	};;

	*) echo -e $helptext;;											# Wrong or unknown parameter

esac

exit 0
