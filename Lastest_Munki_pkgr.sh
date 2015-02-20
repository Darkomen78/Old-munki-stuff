#!/bin/bash

# Version 0.1 by Sylvain La Gravière
# Twitter : @darkomen78
# Mail : darkomen@me.com

# Current dir
ROOTDIR="`pwd`"
# Source base URL
MUNKISRC="https://munkibuilds.org/munkitools2-latest.pkg"
PACKAGESSRC="http://s.sudre.free.fr/Software/files/Packages.dmg"
GITSRC="https://raw.github.com/Darkomen78/Munki/master/"


echo "Download latest version of pkg source"
curl -s "$GITSRC"Munki2prepkg.zip -o /tmp/Munki2prepkg.zip

echo "Download latest version of Munki"
curl -s "$MUNKISRC" -o "$ROOTDIR"/Munki2_source/munkitools2.pkg






echo "Move files to source folder for packages..."
if [ ! -d $SRCDST ]; then
	mkdir $SRCDST
else 
	if [ -d "$SRCDST""_previous" ]; then
		rm -Rf "$SRCDST""_previous"
	fi
	mv "$SRCDST" "$SRCDST""_previous"
	mkdir $SRCDST
fi
cd $SRCDST
mkdir -p ."$CONFDIR_PATH"
mkdir -p ."$INSTALL_PATH"
read -p "----------------> Delete temporary files ? [N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo "...remove temporary files"
	rm -Rf /tmp/$FI_DIR
	cp -R "$CONFDIR_PATH/"* ."$CONFDIR_PATH/" && rm -Rf "$CONFDIR_PATH"
	cp -R "$INSTALL_PATH/"* ."$INSTALL_PATH/" && rm -Rf "$INSTALL_PATH"
else
	cp -R "$CONFDIR_PATH/"* ."$CONFDIR_PATH/"
	cp -R "$INSTALL_PATH/"* ."$INSTALL_PATH/"
fi
chmod -R 775 "$SRCDST"

# Remove heavy useless files
rm -Rf .$PERLBREW_ROOT/build
rm -Rf .$PERLBREW_ROOT/dists
rm -Rf .$PERLBREW_ROOT"/perls/perl-"$OSXPERLVER/man

chmod -R 775 "$ROOTDIR"
cd "$ROOTDIR"
echo "Files copied in $SRCDST"
echo
read -p "----------------> Create standard package ? [Y] " -n 1 -r PKG
echo
if [[ $PKG =~ ^[Nn]$ ]]; then
	echo "...skip create standard package"
else	
	if [ ! -d /Applications/Packages.app ]; then
		echo "No Packages install found, install it..."
		cd /tmp/
		curl -O -L $PACKAGESSRC && echo "Download Stéphane Sudre's Packages install"
		hdiutil mount /tmp/Packages.dmg && echo "Mount Packages install"
		/usr/sbin/installer -dumplog -verbose -pkg "/Volumes/Packages/packages/Packages.pkg" -target / && echo "Install Packages" && hdiutil unmount /Volumes/Packages/ && echo "Unmount Packages install"
		cd "$ROOTDIR"
	fi
	if [ ! -f "FusionInventory_$FI_VERSION.pkgproj" ]; then	
		echo "FusionInventory_$FI_VERSION.pkgproj not found, download it..."
		curl -O -L "$GITSRC$PROJ"
		unzip "$PROJ" && rm "$PROJ"
	fi
/usr/local/bin/packagesbuild -v "FusionInventory_$FI_VERSION.pkgproj" && rm "FusionInventory_$FI_VERSION.pkgproj"
chmod -R 775 ./build
open ./build
fi
read -p "----------------> Create vanilla deployment package ? [Y] " -n 1 -r DEPLOY
echo
if [[ $DEPLOY =~ ^[Nn]$ ]]; then
	echo "...skip create deployment package"
	echo
	exit 0
else	
	if [ ! -d /Applications/Packages.app ]; then
		echo "No Packages install found, install it..."
		cd /tmp/
		curl -O -L $PACKAGESSRC && echo "Download Stéphane Sudre's Packages install"
		hdiutil mount /tmp/Packages.dmg && echo "Mount Packages install"
		/usr/sbin/installer -dumplog -verbose -pkg "/Volumes/Packages/packages/Packages.pkg" -target / && echo "Install Packages" && hdiutil unmount /Volumes/Packages/ && echo "Unmount Packages install"
		cd "$ROOTDIR"
	fi
	if [ ! -f "FusionInventory_deploy_$FI_VERSION.pkgproj" ]; then	
		echo "FusionInventory_deploy_$FI_VERSION.pkgproj not found, download it..."
		curl -O -L "$GITSRC$DEPLOYPROJ"
		unzip "$DEPLOYPROJ" && rm "$DEPLOYPROJ"
	fi
	if [ ! -d "./Deploy" ]; then
		curl -O -L "$GITSRC"Deploy.zip
		unzip "Deploy.zip" && rm "Deploy.zip"
	fi
	if [ ! -d "./source_deploy" ]; then
		curl -O -L "$GITSRC"source_deploy.zip
		unzip "source_deploy.zip" && rm "source_deploy.zip"
	fi
	rm -R ./__MACOSX
	/usr/local/bin/packagesbuild -v "FusionInventory_deploy_$FI_VERSION.pkgproj" && rm "FusionInventory_deploy_$FI_VERSION.pkgproj" && rm -R ./source_deploy
	chown -R root:staff ./Deploy && chmod -R 775 ./Deploy && open ./Deploy
	read -p "----------------> Configure your first deployment package ? [Y] " -n 1 -r CONF
	echo
	if [[ $CONF =~ ^[Nn]$ ]]; then
		echo "...skip configure deployment package"
		echo	
		exit 0
	else
		open ./Deploy/"Configure.command"	
	fi
fi
echo
exit 0	