# asterisk-contact-id
asteriskcontactid.pl

A Contact ID processor for Asterisk's AlarmReceiver() application.

https://wiki.asterisk.org

Uses rcell-smsclient for direct SMS notifications

https://github.com/WillCodeForCats/rcell-smsclient

## Installation
* Copy asteriskcontactid.pl into /usr/local/bin
* chmod 755 /usr/local/bin/asteriskcontactid.pl

## Configuration
Configure the following settings for Asterisk.

asterisk.conf:
* mindtmfduration = 40

alarmreceiver.conf:
* eventcmd = /usr/local/bin/asteriskcontactid.pl
* eventspooldir = /var/spool/asterisk/alarmreceiver

## Recommended FXS Adapter
The Grandstream HT802 configured for DTMF inband and passthrough is recommended for connecting a Contact ID dialer to Asterisk.

* https://www.grandstream.com/products/gateways-and-atas/analog-telephone-adaptors/product/ht802
