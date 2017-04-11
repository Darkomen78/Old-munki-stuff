#!/bin/bash

echo 'Munki Tools install packager'
echo 'Version 2.0 by Sylvain La Gravière'
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
GITSRC="https://github.com/Darkomen78/Munki/trunk/"

# CocoaDialog path
POPUP="$(dirname "$0")"/Munki_source/cocoaDialog.app/Contents/MacOS/cocoaDialog

# Options for cocoaDialog Manifest
RUNMODE="inputbox"
TITLE="Manifest"
TEXT="standard"
TEXTB="Enter manifest file name"
OTHEROPTS="--float --string-output --no-cancel"
ICON="gear"

# Options for cocoaDialog Munki Server
TITLE2="Munki server"
TEXT2="munki"
TEXTB2="Adress without http://"
OTHEROPTS2="--float --string-output --no-cancel"
ICON2="fileserver"

# Options for cocoaDialog Notifications
TITLE3="Time between each user notifications"
TEXT3="Number of days :"
OTHEROPTS3="--float --string-output --no-cancel"
ICON3="sync"

if [ ! -d /Applications/Packages.app ]; then
  echo "No Packages install found, install it..."
  cd /tmp/
  curl -O -L $PACKAGESSRC && echo "Download Stéphane Sudre's Packages install"
  hdiutil mount /tmp/Packages.dmg && echo "Mount Packages install"
  sudo /usr/sbin/installer -dumplog -verbose -pkg "/Volumes/Packages/packages/Packages.pkg" -target / && echo "Install Packages" && hdiutil unmount /Volumes/Packages/ && echo "Unmount Packages install"
  cd "$ROOTDIR"
fi

# Prepare sources
if [ -d "$ROOTDIR"/Munki_source ]; then
  read -p "----------------> Use current source files ? [Y] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "...remove source files"
    rm -R "$ROOTDIR"/Munki_source/
    rm "$ROOTDIR"/Munki.pkgproj
    echo "Download latest version of pkgproj and source..."
    svn -q export "$GITSRC/Munki_source"
    svn -q export "$GITSRC/Munki.pkgproj"
    echo "Download latest version of Munki..."
    curl -s -L "$MUNKISRC" -o "$ROOTDIR"/Munki_source/munkitools.pkg && pkgutil --expand "$ROOTDIR"/Munki_source/munkitools.pkg "$ROOTDIR"/Munki_source/src
  else
    echo "...skip update source files"
  fi
else
  echo "Download latest version of pkgproj and source..."
  svn -q export "$GITSRC/Munki_source"
  svn -q export "$GITSRC/Munki.pkgproj"
  echo "Download latest version of Munki..."
  curl -s -L "$MUNKISRC" -o "$ROOTDIR"/Munki_source/munkitools.pkg && pkgutil --expand "$ROOTDIR"/Munki_source/munkitools.pkg "$ROOTDIR"/Munki_source/src
fi

# Get core version
MUNKIVER=$(ls -la "$ROOTDIR"/Munki_source/src/ | grep core | sed 's/.*-//' | sed 's/.pkg//')
echo "...update version on pkgproj file to" $MUNKIVER
packagesutil --file Munki.pkgproj set package-1 version $MUNKIVER

# Duplicate default file for sed
cp "$ROOTDIR"/Munki_source/intro.txt "$ROOTDIR"/Munki_source/intro.default
cp "$ROOTDIR"/Munki_source/CLIENT.configure "$ROOTDIR"/Munki_source/CLIENT.default

# Add version in Package Intro text
sed -i .temp "s/myversion/$MUNKIVER/g" "$ROOTDIR"/Munki_source/intro.txt

dialog=$($POPUP checkbox --title "Configure options" \
      --label "Choose :" \
      --icon preferences \
      --items `#box0` "Munki Server" `#box1` "Manifest" `#box2` "Apple Software Update" `#box3` "No notifications" `#box4` "Update on first boot" `#box5` "Update at every boot" \
      --rows 10 \
      --disabled 0 \
      --checked 0 2 4 \
      --value-required \
      --button1 "Ok" \
      --resize);

checkboxes=($(echo "${dialog}" | awk 'NR>1{print $0}'));

if [ "${checkboxes[0]}" = "1" ]; then
  # Do the dialog Munki Server, add result in CONFIGURE and Intro file
  RESPONSE2=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS2  --icon $ICON2 --title "${TITLE2}" --text "${TEXT2}" --label "$TEXTB2"`
  MUNKISRV=`echo $RESPONSE2 | sed 's/Ok//g' | sed 's/ //g'`
  sed -i .temp "s/mymunki/$MUNKISRV/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  sed -i .temp "s/mymunki/$MUNKISRV/g" "$ROOTDIR"/Munki_source/intro.txt
fi

if [ "${checkboxes[1]}" = "1" ]; then
  # Do the dialog Manifest, add result in CONFIGURE and Intro file
  RESPONSE=`$POPUP $RUNMODE --button1 "Ok" $OTHEROPTS  --icon $ICON --title "${TITLE}" --text "${TEXT}" --label "$TEXTB"`
  MANIFEST=`echo $RESPONSE | sed 's/Ok//g' | sed 's/ //g'`
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• Le fichier $MANIFEST est le manifest par défaut sur le serveur $MUNKISRV" >> "$ROOTDIR"/Munki_source/intro.txt
  sed -i .temp "s/mymanifest/$MANIFEST/g" "$ROOTDIR"/Munki_source/CLIENT.configure
else
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• Il n'y a pas de manifest par défaut pour ce client" >> "$ROOTDIR"/Munki_source/intro.txt
  sed -i .temp "s/mymanifest//g" "$ROOTDIR"/Munki_source/CLIENT.configure
  MANIFEST="No_manifest"
fi

if [ "${checkboxes[2]}" = "1" ]; then
  sed -i .temp "s/myASUS/true/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  sed -i .temp "s/FORCEAPPLEUPDATES=false/FORCEAPPLEUPDATES=true/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• Les mises à jour Apple sont gérées par Munki" >> "$ROOTDIR"/Munki_source/intro.txt
else
  sed -i .temp "s/myASUS/false/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• Les mises à jour Apple ne sont pas gérées par Munki" >> "$ROOTDIR"/Munki_source/intro.txt
fi

if [ "${checkboxes[3]}" = "1" ]; then
  # Do the dialog Notifications, add result in CONFIGURE and Intro file
  sed -i .temp "s/SUPPRESSUSERNOTIFICATION=false/SUPPRESSUSERNOTIFICATION=true/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• Aucune notification des mises à jour à l'utilisateur" >> "$ROOTDIR"/Munki_source/intro.txt
else
  RESPONSE3=`$POPUP dropdown --button1 "Ok" $OTHEROPTS3  --icon $ICON3 --title "${TITLE3}" --text "${TEXT3}" --items "2" "3" "4" "5" "7" "15" "30"`
  XDAYS=`echo $RESPONSE3 | sed 's/Ok//g' | sed 's/ //g'`
  sed -i .temp "s/=xdays/=$XDAYS/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• Les notifications des mises à jour à l'utilisateur se font tout les $XDAYS jours" >> "$ROOTDIR"/Munki_source/intro.txt
fi

if [ "${checkboxes[4]}" = "1" ]; then
  sed -i .temp "s/myboot/true/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• L'agent lancera une mise à jour automatique au redémarrage après l'installation" >> "$ROOTDIR"/Munki_source/intro.txt
else
  sed -i .temp "s/myboot/false/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• L'agent ne lancera pas de mise à jour automatique après l'installation" >> "$ROOTDIR"/Munki_source/intro.txt
fi
if [ "${checkboxes[5]}" = "1" ]; then
  sed -i .temp "s/myallboot/true/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• L'agent lancera une mise à jour à chaque démarrage" >> "$ROOTDIR"/Munki_source/intro.txt
else
  sed -i .temp "s/myallboot/false/g" "$ROOTDIR"/Munki_source/CLIENT.configure
  echo "" >> "$ROOTDIR"/Munki_source/intro.txt
  echo "• L'agent ne lancera pas de mise à jour à chaque démarrage" >> "$ROOTDIR"/Munki_source/intro.txt
fi

# Remove temp files
rm "$ROOTDIR"/Munki_source/*.temp

# Remove old package file
if [[ -d "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER"_"$MANIFEST".mpkg ]]; then
  rm -Rf "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER"_"$MANIFEST".mpkg
fi

# Build new package file
/usr/local/bin/packagesbuild -v "$ROOTDIR/Munki.pkgproj" && mv "$ROOTDIR/build/Munki.mpkg" "$ROOTDIR"/build/"$MUNKISRV"_"$MUNKIVER"_"$MANIFEST".mpkg

read -p "----------------> Delete source files ? [N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "...remove source files"
  rm -R "$ROOTDIR"/Munki_source/
  rm "$ROOTDIR"/Munki.pkgproj
else
  echo "...keep source files"
  rm "$ROOTDIR"/Munki_source/intro.txt && rm "$ROOTDIR"/Munki_source/CLIENT.configure
  mv "$ROOTDIR"/Munki_source/intro.default "$ROOTDIR"/Munki_source/intro.txt
  mv "$ROOTDIR"/Munki_source/CLIENT.default "$ROOTDIR"/Munki_source/CLIENT.configure
fi
open "$ROOTDIR"/build
