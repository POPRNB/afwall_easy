#!/bin/bash
clear
echo "=================================================="
echo -e "\033[3;34m BLOCK ASNs SCRIPT AND SET DNS FOR ANDROID AFWALL\033[0m"
echo "=================================================="
echo
echo
echo "--------------------------------------------------"
echo "Thx ukanth for the great AFWall app!" 
echo
echo "Visit https://github.com/ukanth/afwall"
echo
echo
echo "Script is based on infos and python scripts from Mike Kuketz,"
echo "https://www.kuketz-blog.de/"
echo
echo "and was further enhanced by maloe"
echo "https://notabug.org/maloe/ASN_IPFire_Script"
echo 
echo
echo "Great job guys!"
echo
echo "--------------------------------------------------"
echo
echo
read -n 1 -s -p "Press any key to continue"
clear
chmod +x asn_ipfire_beta.sh
rm -R -f afwscripts
mkdir afwscripts
cp default ./afwscripts/aafwall.sh
cp iptables_off.sh ./afwscripts
echo "Set DNS Server? Press key [1-4]"
echo
echo
echo "[1] Don't change DNS Server"
echo "[2] 84.200.69.80 DNS Watch"
echo "[3] 91.239.100.100 Censurfridns Denmark"
echo "[4] Other DNS Server (ipfire wiki list)"
echo
echo "See http://wiki.ipfire.org/en/dns/public-servers"
echo "It´s only an overview, not all listed servers are censorship-free!"
echo "At least you should prefer dnssec validating servers."
echo
echo "--------------------------------------------------"
echo "Important!!!!!"
echo 
echo "Set the DNS proxy to -Disable DNS via netd- (preferences->Binaries->DNS proxy)"
echo "You must allow (Android 5+) -[0] (root) - Apps running as root- in afwall else dns resolving won´t work!"
echo "--------------------------------------------------"
echo
echo -n ":"
while read Option
do
case $Option in
1)
echo "Don't touch DNS Server"
break
;;
2)
echo "Setting DNS Watch"
echo "$""IPTABLES -t nat -I OUTPUT -p tcp --dport 53 -j DNAT --to-destination 84.200.69.80:53" >> ./afwscripts/aafwall.sh
echo "$""IPTABLES -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to-destination 84.200.69.80:53" >> ./afwscripts/aafwall.sh
break
;;
3)
echo "Setting Censurfridns Denmark"
echo "$""IPTABLES -t nat -I OUTPUT -p tcp --dport 53 -j DNAT --to-destination 91.239.100.100:53" >>  ./afwscripts/aafwall.sh
echo "$""IPTABLES -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to-destination 91.239.100.100:53" >> ./afwscripts/aafwall.sh
break
;;
4)
echo "Please enter IPv4:"
echo "e.g. 84.200.69.80"
read ip
echo
echo $ip "will be set for dns"
echo
echo
read -n 1 -s -p "Press any key to continue"
echo "$""IPTABLES -t nat -I OUTPUT -p udp --dport 53 -j DNAT --to-destination $ip" >> ./afwscripts/aafwall.sh
echo "$""IPTABLES -t nat -I OUTPUT -p tcp --dport 53 -j DNAT --to-destination $ip" >> ./afwscripts/aafwall.sh
clear
break
esac
done
echo
echo "Now choose the companys you want to be blocked!"
echo "Seperate them by comma or space"
echo "e.g. Google, Facebook, Samsung or Google Facebook ..."
read companys
echo $companys "will be blocked"
echo
read -n 1 -s -p "Press any key to continue"
echo
./asn_ipfire_beta.sh --afwall "$companys"
mv afwall_rules.txt ./afwscripts/afwall_rules
clear
echo "End of script..."
echo
echo "Now copy the whole afwscripts folder to /system on your device."
echo "Additionally transfer afwscripts.txt onto the device."
echo
echo "Device: Open afwscripts.txt and copy all to the clipboard."
echo
echo "Open AFWall and press the three dots in the top right corner and select"
echo "<Set custom script>. Paste the contents of the clipboard to user defined script."
echo 
echo
echo "Now you must set the shutdown script path (user defined shutdown script)."
echo
echo "Enter this:   . /system/afwscripts/iptables_off.sh"
echo
echo "IMPORTANT: Don't forget the ". /" point-space-slash!!"
echo
echo 
echo "Hint: See attached screenshot how it should look like!"
echo
echo "Afterwards press OK and wait until AFWall applied the rules!"
echo 
echo "Finally block IPv6 in AFWall preferences->Rules/Connectivity"
echo "Only IPv4 is working right now"
echo
echo
echo "--------------------------------------------------------------------------"
echo -e "\033[1;31mAFTER UPDATING YOUR SYSTEM CHECK IF /system/afwscripts IS STILL AVAILABLE."
echo -e "ELSE YOU HAVE TO COPY OVER THE FOLDER TO /SYSTEM AGAIN!\033[0m"
echo "--------------------------------------------------------------------------"
echo
echo
echo
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo "Have fun and enjoy a bit more privacy!"
echo
echo "https://github.com/mglinux/afwall_easy"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo
