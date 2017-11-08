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
####make ASN fetching script executable####
chmod +x asn_ipfire.sh
####delete and create folder to reset process####
rm -f copy_paste.txt
rm -R -f afwscripts
mkdir afwscripts
####copy common rules####
cp default ./afwscripts/aafwall.sh
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
echo -e "\e[3;91mImportant!!!!!"
echo 
echo "Set the DNS proxy to -Disable DNS via netd- (preferences->Binaries->DNS proxy)"
echo "You must allow (Android 5+) -[0] (root) - Apps running as root- in afwall else dns resolving won´t work!"
echo "--------------------------------------------------"
echo -e "\e[0m"
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
clear
path=/storage/emulated/0/
echo "Now we need to set the Path to your internal storage"
echo "Default used: /storage/emulated/0/"
echo
echo "Please check yourself what´s the right path for your device!"
echo
echo "[1] Keep default path /storage/emulated/0"
echo "[2] Set different path"
echo -n ":"
while read Option2
do
case $Option2 in
1)
echo
echo
path=/storage/emulated/0
echo "$path/afwscripts will be used"
echo
echo
read -n 1 -s -p "Press any key to continue"
break
;;
2) 
clear
ok=no
while
    echo "Please enter your path like /storage/sdcard"
    echo
    read -p 'New path:' pathinput
    path=$(echo "/"$pathinput | sed 's/^[/]\+/\//; s/[/]\+$//')
    echo "Used path: $path/afwscripts"
    read -p "Is this correct? [y/n] " yn
    case $yn in
        [Yy]* )  false;;
        * )  true;;
esac
do
    :
done
break
esac
done
clear
echo "Now choose the companies you want to be blocked!"
echo "Seperate them by comma or space"
echo "e.g. Google, Facebook, Samsung or Google Facebook ..."
read companies
echo $companies "will be blocked"
echo
read -n 1 -s -p "Press any key to continue"
echo
####start fetching ASNs####
./asn_ipfire.sh --afwall "$companies"
mv afwall_rules.txt ./afwscripts/afwall_rules
#### split rules at 100 lines. Else afwall could fail on some devices####
split -l 100 ./afwscripts/afwall_rules ./afwscripts/afwall_rules_
rm ./afwscripts/afwall_rules
ls -d ./afwscripts/* | xargs -n1 basename > ./afwscripts/cp.txt
nl -s ". $path/afwscripts/" ./afwscripts/cp.txt | cut -c7- > copy_paste.txt
rm ./afwscripts/cp.txt
cp iptables_off.sh ./afwscripts
clear
echo "End of script..."
echo
echo "Now copy the whole afwscripts folder to $path on your device."
echo "Additionally transfer copy_paste.txt onto the device."
echo
echo "Device: Open copy_paste.txt and copy all to the clipboard."
echo
echo "Open AFWall and press the three dots in the top right corner and select"
echo "<Set custom script>. Paste the contents of the clipboard to user defined script."
echo 
echo
echo "Set the shutdown script path (user defined shutdown script)."
echo
echo "Enter this:   . $path/afwscripts/iptables_off.sh"
echo
echo -e "\e[3;91mIMPORTANT: Don't forget the ". /" point-space-slash!!"
echo -e "\e[0m"
echo 
echo "Hint: See attached screenshot how it should look like!"
echo
echo "Afterwards press OK and wait until AFWall applied the rules!"
echo
echo
read -n 1 -s -p "Press any key to continue"
clear
echo
echo
echo "Finally block IPv6 in AFWall preferences->Rules/Connectivity."
echo "The afwall.sh script sets IPv6 to drop all too!"
echo
echo "Done!"
echo
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo
echo "Have fun and enjoy a bit more privacy!"
echo
echo "https://github.com/mglinux/afwall_easy"
echo "https://github.com/ukanth/afwall"
echo "https://www.kuketz-blog.de"
echo "https://notabug.org/maloe/ASN_IPFire_Script"
echo
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
echo
