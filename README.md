# afwall_easy

Last update: 22/18/2017

https://github.com/mglinux/afwall_easy


Simple script for generating ASN Block lists and DNS Server entry for Android AFWall.


It generates AFWall scripts for blocking connections to google, facebook, whatever you want.
This gets achieved through setting the corressponding iptables rules.

Following Packages are required to fetch and set the corressponding rules:

Awk, printf, curl

_______________________________________________________________________________________________

Open a terminal window

git clone https://github.com/mglinux/afwall_easy.git

cd afwall_easy

Make the script executable with "chmod +x afwall.sh"

Run the script with ./afwall.sh

===============================================================================================

In Afwall app:

Set the DNS proxy to -Disable DNS via netd- (preferences->Binaries->DNS proxy)
You must allow (Android 5+) -[0] (root) - Apps running as root- in afwall else dns resolving won´t work!


_______________________________________________________________________________________________
Maybe not all IPs get banned through the ASN block, but at least it's a beginning :-)


Thx ukanth, Mike and maloe for all your hard work!

https://github.com/ukanth/afwall (GPLv3)

https://www.kuketz-blog.de/

https://notabug.org/maloe/ASN_IPFire_Script (GPLv3)


