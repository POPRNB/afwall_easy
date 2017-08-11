##
## iptables.sh	
## AFWall+ additional firewall rules
## Mike Kuketz
## www.kuketz-blog.de
## Changes: 25.08.2014
##

IPTABLES=/system/bin/iptables
IP6TABLES=/system/bin/ip6tables 

# All 'afwall' chains/rules gets flushed automatically, before the custom script is executed

# Flush/Purge all rules expect OUTPUT (quits with error)
$IPTABLES -F INPUT
$IPTABLES -F FORWARD
$IPTABLES -t nat -F
$IPTABLES -t mangle -F
$IP6TABLES -F INPUT
$IP6TABLES -F FORWARD
$IP6TABLES -t nat -F
$IP6TABLES -t mangle -F

# Flush/Purge all chains 
$IPTABLES -X 
$IPTABLES -t nat -X 
$IPTABLES -t mangle -X 
$IP6TABLES -X 
$IP6TABLES -t nat -X 
$IP6TABLES -t mangle -X

# Deny IPv6 connections  
$IP6TABLES -P INPUT DROP  
$IP6TABLES -P FORWARD DROP  
$IP6TABLES -P OUTPUT DROP

# DNS Server and custom rules generated from the script
 
