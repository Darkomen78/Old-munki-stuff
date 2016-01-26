#!/bin/bash

echo 'Munki Tools install packager'
echo 'Version 1.3.4 by Sylvain La Gravière'
echo 'Twitter : @darkomen78'
echo 'Mail : darkomen@me.com'
echo ''

# Current dir
ROOTDIR="`pwd`"
# Source base URL
GITMUNKI="https://github.com/munki/munki/releases/latest"
LATESTVER=$(curl -L -s "$GITMUNKI" | egrep releases.*pkg | sed -ne 's/.*\(\/munki\/[^"]*\).*/\1/p')
MUNKISRC="https://github.com/munki"$LATESTVER
PACKAGESSRC="http://s.sudre.free.fr/Software/files/Packages.dmg"
GITSRC="https://raw.github.com/Darkomen78/Munki/master/"

# CocoaDialog path
POPUP="$(dirname "$0")"/Munki2_source/cocoaDialog.app/Contents/MacOS/cocoaDialog

# Options for cocoaDialog Manifest
RUNMODE="inputbox"
TITLE="Manifest"
TEXT="standard"
TEXTB="Enter manifest file name"
OTHEROPTS="--float --string-output --no-cancel"
ICON="gear"

# Options for cocoaDialog Munki Server
TITLE2="Munki server"
TEXT2="munki.mydomain.lan"
TEXTB2="Enter adress without http://"
OTHEROPTS2="--float --string-output --no-cancel"
ICON2="fileserver"

# Options for cocoaDialog Reposado Server
TITLE3="Reposado or Apple update server"
TEXT3="reposado.mydomain.lan"
TEXT3B="Enter adress without http:// and without index.sucatalog, leave blank for Apple Server"
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
  sudo /usr/sbin/installer -dumplog -verbose -pkg "/Volumes/Packages/packages/Packages.pkg" -target / && echo "Install Packages" && hdiutil unmount /Volumes/Packages/ && echo "Unmount Packages install"
  cd "$ROOTDIR"
fi

# Prepare sources
if [ -d "$ROOTDIR"/Munki2_source ]; then
  read -p "----------------> Use current source files ? [Y] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "...remove source files"
    rm -R "$ROOTDIR"/Munki2_source/
    rm "$ROOTDIR"/Munki2.pkgproj
    echo "Download latest version of pkg source..."
    curl -O -s -L "$GITSRC"Munki2prepkg.zip
    unzip -q "Munki2prepkg.zip" && rm "Munki2prepkg.zip"
    echo "Download latest version of Munki..."
    curl -s -L "$MUNKISRC" -o "$ROOTDIR"/Munki2_source/munkitools2.pkg && pkgutil --expand "$ROOTDIR"/Munki2_source/munkitools2.pkg "$ROOTDIR"/Munki2_source/src
  else
    echo "...skip update source files"
  fi
else
  echo "Download latest version of pkg source..."
  curl -O -s -L "$GITSRC"Munki2prepkg.zip
  unzip -q "Munki2prepkg.zip" && rm "Munki2prepkg.zip"
  echo "Download latest version of Munki..."
  curl -s -L "$MUNKISRC" -o "$ROOTDIR"/Munki2_source/munkitools2.pkg && pkgutil --expand "$ROOTDIR"/Munki2_source/munkitools2.pkg "$ROOTDIR"/Munki2_source/src
fi

# Get core version
MUNKIVER=$(ls -la "$ROOTDIR"/Munki2_source/src/ | grep core | sed 's/.*-//' | sed 's/.pkg//')
echo "...update version on pkgproj file to" $MUNKIVER
packagesutil --file Munki2.pkgproj set package-1 version $MUNKIVER

# Duplicate default file for sed
cp "$ROOTDIR"/Munki2_source/intro.txt "$ROOTDIR"/Munki2_source/intro.default
cp "$ROOTDIR"/Munki2_source/CLIENT.configure "$ROOTDIR"/Munki2_source/CLIENT.default

# Add version in Package Intro text
sed -i .temp "s/myversion/$MUNKIVER/g" "$ROOTDIR"/Munki2_source/intro.txt

dialog=$($POPUP checkbox --title "Configure options" \
--label "Choose :" \
--icon preferences \
--items `#box0` "Munki Server" `#box1` "Manifest" `#box2` "Apple Software Update" `#box3` "No notifications" `#box4` "Update on first boot" `#box5` "Update at every boot" \
--rows 10 \
--disabled 0 \
--checked 0 1 4 \
--value-required \
--button1 "Ok" \
--resize);

checkboxes=($(echo "${dialog}" | awk 'NR>1{print $0}'));

if [ "${checkboxes[0]}" = "1" ]; then
  # Do the dialog Munki Server, add result in CONFIGURE and Intro file
  RESPONSE2=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS2  --icon $ICON2 --title "${TITLE2}" --text "${TEXT2}" --label "$TEXTB2"`
  MUNKISRV=`echo $RESPONSE2 | sed 's/Ok//g' | sed 's/ //g'`
  sed -i .temp "s/mymunki/$MUNKISRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  sed -i .temp "s/mymunki/$MUNKISRV/g" "$ROOTDIR"/Munki2_source/intro.txt
fi

if [ "${checkboxes[1]}" = "1" ]; then
  # Do the dialog Manifest, add result in CONFIGURE and Intro file
  RESPONSE=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS  --icon $ICON --title "${TITLE}" --text "${TEXT}" --label "$TEXTB"`
  MANIFEST=`echo $RESPONSE | sed 's/Ok//g' | sed 's/ //g'`
  echo "• Le fichier $MANIFEST est le manifest par défaut sur le serveur $MUNKISRV" >> "$ROOTDIR"/Munki2_source/intro.txt
  sed -i .temp "s/mymanifest/$MANIFEST/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
else
  echo "• Il n'y a pas de manifest par défaut pour ce client" >> "$ROOTDIR"/Munki2_source/intro.txt
  sed -i .temp "s/mymanifest//g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  MANIFEST="No_manifest"
fi

if [ "${checkboxes[2]}" = "1" ]; then
  sed -i .temp "s/myASUS/true/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  # Do the dialog Reposado Server, add result in CONFIGURE and Intro file
  RESPONSE3=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS3  --icon $ICON3 --title "${TITLE3}" --text "${TEXT3}" --label "$TEXT3B"`
  REPOSADOSRV=`echo $RESPONSE3 | sed 's/Ok//g' | sed 's/ //g'`
  if [ "$REPOSADOSRV" != '' ]; then
    sed -i .temp "s/myreposado/$REPOSADOSRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
    echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
    echo "• Les mises à jour Apple sont configurées vers le serveur $REPOSADOSRV" >> "$ROOTDIR"/Munki2_source/intro.txt
  else
    sed -i .temp "s/http\:\/\/myreposado\/index.sucatalog/$REPOSADOSRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
    echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
    echo "• Les mises à jour Apple sont configurées vers le serveur par défaut" >> "$ROOTDIR"/Munki2_source/intro.txt
  fi
else
  REPOSADOSRV=''
  sed -i .temp "s/http\:\/\/myreposado\/index.sucatalog/$REPOSADOSRV/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  sed -i .temp "s/myASUS/false/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• Les mises à jour Apple ne sont pas gérées par Munki" >> "$ROOTDIR"/Munki2_source/intro.txt
fi

if [ "${checkboxes[3]}" = "1" ]; then
  # Do the dialog Notifications, add result in CONFIGURE and Intro file
  sed -i .temp "s/SUPPRESSUSERNOTIFICATION=false/SUPPRESSUSERNOTIFICATION=true/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• Aucune notification des mises à jour à l'utilisateur" >> "$ROOTDIR"/Munki2_source/intro.txt
else
  RESPONSE4=`$POPUP dropdown --button1 "Ok" $OTHEROPTS4  --icon $ICON4 --title "${TITLE4}" --text "${TEXT4}" --items "2" "3" "4" "5" "7" "15" "30" `
  XDAYS=`echo $RESPONSE4 | sed 's/Ok//g' | sed 's/ //g'`
  sed -i .temp "s/=xdays/=$XDAYS/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• Les notifications des mises à jour se font tout les $XDAYS jours" >> "$ROOTDIR"/Munki2_source/intro.txt
fi
if [ "${checkboxes[4]}" = "1" ]; then
  sed -i .temp "s/myboot/true/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• L'agent lancera une mise à jour au prochain démarrage" >> "$ROOTDIR"/Munki2_source/intro.txt
else
  sed -i .temp "s/myboot/false/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• L'agent ne lancera pas de mise à jour au prochain démarrage" >> "$ROOTDIR"/Munki2_source/intro.txt
fi
if [ "${checkboxes[5]}" = "1" ]; then
  sed -i .temp "s/myallboot/true/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• L'agent lancera une mise à jour à chaque démarrage" >> "$ROOTDIR"/Munki2_source/intro.txt
else
  sed -i .temp "s/myallboot/false/g" "$ROOTDIR"/Munki2_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki2_source/intro.txt
  echo "• L'agent ne lancera pas de mise à jour à chaque démarrage" >> "$ROOTDIR"/Munki2_source/intro.txt
fi

# Remove temp files
rm "$ROOTDIR"/Munki2_source/*.temp

# Remove old package file
if [[ -d "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER"_"$MANIFEST".mpkg ]]; then
  rm -Rf "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER"_"$MANIFEST".mpkg
fi

# Build new package file
/usr/local/bin/packagesbuild -v "$ROOTDIR/Munki2.pkgproj" && mv "$ROOTDIR/build/Munki2.mpkg" "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER"_"$MANIFEST".mpkg

read -p "----------------> Delete source files ? [N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "...remove source files"
  rm -R "$ROOTDIR"/Munki2_source/
  rm "$ROOTDIR"/Munki2.pkgproj
else
  echo "...keep source files"
  rm "$ROOTDIR"/Munki2_source/intro.txt && rm "$ROOTDIR"/Munki2_source/CLIENT.configure
  mv "$ROOTDIR"/Munki2_source/intro.default "$ROOTDIR"/Munki2_source/intro.txt
  mv "$ROOTDIR"/Munki2_source/CLIENT.default "$ROOTDIR"/Munki2_source/CLIENT.configure
fi
open "$ROOTDIR"/build
