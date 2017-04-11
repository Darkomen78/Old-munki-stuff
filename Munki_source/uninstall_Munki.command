#!/bin/bash

# Admin user shortname
ADMUSR="admin"
if [ "$USER" = "root" ]; then
		echo "Run as root"
		launchctl unload /Library/LaunchDaemons/*.munki.*
		# remove all Munki files
		rm -Rf '/usr/local/munki'
		rm -Rf '/Library/Managed Installs'
		rm -Rf '/Library/Preferences/'*[Mm]unki*
		rm -f '/Library/Preferences/'*ManagedInstalls*
		rm -f '/Library/LaunchAgents/'*munki*
		rm -f '/Library/LaunchDaemons/'*munki*
		rm -f '/var/db/receipts/'*[Mm]unki*
		rm -rf "/Applications/Utilities/Managed Software Center.app"
		rm -rf "/Applications/Managed Software Center.app"
		pkgutil --forget com.googlecode.munki.core
		pkgutil --forget com.googlecode.munki.admin
		pkgutil --forget com.googlecode.munki.app
		pkgutil --forget com.googlecode.munki.launchd
		pkgutil --forget com.googlecode.munki
		pkgutil --forget com.github.munkireport
		rm -f "$0"
		echo "All Munki files was removed"
		exit 0
fi		
if [ "$USER" = "$ADMUSR" ]; then
	echo "Enter $ADMUSR password"
	sudo "$0" "$@"
	exit 0
else
	echo "Enter $ADMUSR password"
	su "$ADMUSR" -c "sudo "$0" "$@""
	exit 0
fi		
echo "You need admin privileges to uninstall Munki"
exit 0