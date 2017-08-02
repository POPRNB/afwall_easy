# afwall_easy
https://github.com/mglinux/afwall_easy


Stopped from further development! A much better script ist available here: https://notabug.org/maloe/ASN_IPFire_Script


Bash script for generating AS Block lists and setting DNS Server for Android AFWall.

It generates AFWall scripts for blocking connections to google, facebook, microsoft and a few others.
This gets achieved through setting the corressponding iptables rules.


Note:   Python2 and python2-ipaddr are required! 
        Be sure to install the right one for python2! There is another one (ipaddress).


*Extract afwall_easy.zip
*Open a terminal window
*Make the script executable with "chmod +x afwall.sh"
*Run the script with ./afwall.sh


Maybe not all IPs get banned through the ASN block, but at least it's a beginning :-)


Thx ukanth and Mike for all your hard work!

https://github.com/ukanth/afwall

https://www.kuketz-blog.de/

