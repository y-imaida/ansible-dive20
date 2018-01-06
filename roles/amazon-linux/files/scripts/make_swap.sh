#! /bin/bash

FSTAB_ENTRY='/swapfile               swap                    swap    defaults        0 0'

dd if=/dev/zero of=/swapfile bs=1M count=1024
mkswap /swapfile
swapon /swapfile

cp -p /etc/fstab /etc/fstab.$(date +%Y%m%d_%H%M%S)
echo "$FSTAB_ENTRY" >> /etc/fstab
