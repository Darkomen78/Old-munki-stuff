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

# CocoaDialog path
POPUP="$(dirname "$0")"/Munki2_source/cocoaDialog.app/Contents/MacOS/cocoaDialog
  
# Options for cocoaDialog Manifest
RUNMODE="inputbox"
TITLE="Manifest name"
TEXT="standard"
OTHEROPTS="--float --string-output --no-cancel"
ICON="gear"

# Options for cocoaDialog Munki Server
TITLE2="Munki Server adress (without http)"
TEXT2="munki.mydomain.lan"
OTHEROPTS2="--float --string-output --no-cancel"
ICON2="fileserver"

# Options for cocoaDialog Reposado Server
TITLE3="Reposado Server adress (without http and index.sucatalog)"
TEXT3="reposado.mydomain.lan"
OTHEROPTS3="--float --string-output --no-cancel"
ICON3="fileserver"

# Options for cocoaDialog Notifications
TITLE4="Days between notifications"
TEXT4="Number of days :"
OTHEROPTS4="--float --string-output --no-cancel"
ICON4="sync"

if [ ! -d /Applications/Packages.app ]; then
      echo "No Packages install found, install it..."
      cd /tmp/
      curl -O -L $PACKAGESSRC && echo "Download Stéphane Sudre's Packages install"
      hdiutil mount /tmp/Packages.dmg && echo "Mount Packages install"
      /usr/sbin/installer -dumplog -verbose -pkg "/Volumes/Packages/packages/Packages.pkg" -target / && echo "Install Packages" && hdiutil unmount /Volumes/Packages/ && echo "Unmount Packages install"
      cd "$ROOTDIR"
fi

if [ ! -d "$ROOTDIR"/Munki2_source ]; then
	echo "Download latest version of pkg source"
	curl -O -L "$GITSRC"Munki2prepkg.zip
	unzip "Munki2prepkg.zip" && rm "Munki2prepkg.zip" && rm -R "__MACOSX" && mv Munki2prepkg/* $ROOTDIR/ && rm -R Munki2prepkg
fi
cp "$ROOTDIR"/Munki2_source/intro.txt "$ROOTDIR"/Munki2_source/intro.default
cp "$ROOTDIR"/Munki2_source/CLIENT.configure "$ROOTDIR"/Munki2_source/CLIENT.default

echo "Download latest version of Munki"
if [ -f "$ROOTDIR"/Munki2_source/munkitools2.pkg ]; then 
	rm -f "$ROOTDIR"/Munki2_source/munkitools2.pkg
fi	
curl -s "$MUNKISRC" -o "$ROOTDIR"/Munki2_source/munkitools2.pkg
pkgutil --expand "$ROOTDIR"/Munki2_source/munkitools2.pkg "$ROOTDIR"/temp
MUNKIVER=$(ls -la "$ROOTDIR"/temp/ | grep core | sed 's/.*-//' | sed 's/.pkg//')
rm -R "$ROOTDIR"/temp/

echo "met à jour la version du .pkgproj à " $MUNKIVER
packagesutil --file Munki2.pkgproj set package-1 version $MUNKIVER

dialog=$($POPUP checkbox --title "Configure options" \
      --label "Choose :" \
      --icon preferences \
      --items `#box0` "Manifest" `#box1` "Munki Adress" `#box2` "Reposado Adress" \
      --rows 10 \
      --checked 1 1 0 \
      --value-required \
      --button1 "Ok" \
      --resize);

checkboxes=($(echo "${dialog}" | awk 'NR>1{print $0}'));

if [ "${checkboxes[0]}" = "1" ]; then
#Do the dialog Manifest, get the result and strip the Ok button code
RESPONSE=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS  --icon $ICON --title "${TITLE}" --text "${TEXT}"`
MANIFEST=`echo $RESPONSE | sed 's/Ok//g' | sed 's/^[ \t]*//'`
fi
if [ "${checkboxes[1]}" = "1" ]; then
#Do the dialog Munki Server, get the result and strip the Ok button code
RESPONSE2=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS2  --icon $ICON2 --title "${TITLE2}" --text "${TEXT2}"`
MUNKISRV=`echo $RESPONSE2 | sed 's/Ok//g' | sed 's/^[ \t]*//'`
fi
if [ "${checkboxes[2]}" = "1" ]; then
#Do the dialog Reposado Server, get the result and strip the Ok button code
RESPONSE3=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS3  --icon $ICON3 --title "${TITLE3}" --text "${TEXT3}"`
REPOSADOSRV=`echo $RESPONSE3 | sed 's/Ok//g' | sed 's/^[ \t]*//'`
sed -i .temp "s/myreposado/$REPOSADOSRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
echo "• Les mise à jour Apple sont configurer vers le serveur $REPOSADOSRV" >> "$ROOTDIR"/Munki2_source/intro.txt
else 
REPOSADOSRV=''
sed -i .temp "s/http\:\/\/myreposado\/index.sucatalog/$REPOSADOSRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
fi

#Do the dialog Notifications, get the result and strip the Ok button code
RESPONSE4=`$POPUP dropdown --button1 "Ok" $OTHEROPTS4  --icon $ICON4 --title "${TITLE4}" --text "${TEXT4}" --items "1" "2" "3" "4" "5" "7" "30" `
XDAYS=`echo $RESPONSE4 | sed 's/Ok//g' | sed 's/^[ \t]*//'`

sed -i .temp "s/mymanifest/$MANIFEST/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
sed -i .temp "s/mymunki/$MUNKISRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
sed -i .temp "s/xdays/$XDAYS/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
sed -i .temp "s/mymanifest/$MANIFEST/g" "$ROOTDIR"/Munki2_source/intro.txt
sed -i .temp "s/mymunki/$MUNKISRV/g" "$ROOTDIR"/Munki2_source/intro.txt
sed -i .temp "s/xdays/$XDAYS/g" "$ROOTDIR"/Munki2_source/intro.txt
sed -i .temp "s/myversion/$MUNKIVER/g" "$ROOTDIR"/Munki2_source/intro.txt
rm "$ROOTDIR"/Munki2_source/*.temp

/usr/local/bin/packagesbuild -v "$ROOTDIR/Munki2.pkgproj" && mv "$ROOTDIR/build/Munki2.mpkg" "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER".mpkg

read -p "----------------> Delete source files ? [N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo "...remove source files"
	rm -Rf "$ROOTDIR"/Munki2_source/
else
	echo "...keep source files"
      mv "$ROOTDIR"/Munki2_source/intro.default "$ROOTDIR"/Munki2_source/intro.txt  
      mv "$ROOTDIR"/Munki2_source/CLIENT.default "$ROOTDIR"/Munki2_source/CLIENT.configure
fi	