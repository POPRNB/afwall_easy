# [afwall_easy](https://github.com/mglinux/afwall_easy)

### **Last update: 12/02/2017**

Simple script for generating [ASN](https://en.wikipedia.org/wiki/Autonomous_system_(Internet)) Block lists and DNS Server entry for Android AFWall.

It generates AFWall scripts for blocking connections to google, facebook, whatever you want.
This gets achieved through setting the corressponding iptables rules.

Following **Packages** are **required** to fetch and set the corressponding rules:

**Awk, printf, wget**

_______________________________________________________________________________________________

## *How to use:*

Open a terminal window

git clone https://github.com/mglinux/afwall_easy.git

cd afwall_easy

Make the script executable with "chmod +x afwall.sh"

Run the script with ./afwall.sh

_______________________________________________________________________________________________

#### *In Afwall app:*

Set the DNS proxy to -Disable DNS via netd- (preferences->Binaries->DNS proxy)
You must allow (Android 5+) -[0] (root) - Apps running as root- in afwall else dns resolving won´t work!


_______________________________________________________________________________________________
*Since there isn't an update function yet, the script should be run regularly (e.g monthly) to fetch New ASNs for each company you wish to block. But well this happens not that often.*


***Thx ukanth, Mike and maloe for the amazing work! :+1:***


[ukanth AFWall](https://github.com/ukanth/afwall)  			  

[Mike Kuketz](https://www.kuketz-blog.de/)

[Maloe](https://notabug.org/maloe/ASN_IPFire_Script) 


**License:** AFWall and ASN_IPFire_Script are under [GPLv3](https://www.gnu.org/licenses/gpl.html). Afwall_easy script itself has none. Feel free to use any piece of the script itself!

