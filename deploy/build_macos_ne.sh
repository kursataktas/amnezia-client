#!/bin/bash
echo "Build script started ..."

set -o errexit -o nounset

while getopts n flag
do
    case "${flag}" in
        n) NOTARIZE_APP=1;;
    esac
done

# Hold on to current directory
PROJECT_DIR=$(pwd)
DEPLOY_DIR=$PROJECT_DIR/deploy

mkdir -p $DEPLOY_DIR/build
BUILD_DIR=$DEPLOY_DIR/build

echo "Project dir: ${PROJECT_DIR}" 
echo "Build dir: ${BUILD_DIR}"

APP_NAME=AmneziaVPN
APP_FILENAME=$APP_NAME.app
APP_DOMAIN=org.amneziavpn.package
PLIST_NAME=$APP_NAME.plist

OUT_APP_DIR=$BUILD_DIR/client
BUNDLE_DIR=$OUT_APP_DIR/$APP_FILENAME

PREBUILT_DEPLOY_DATA_DIR=$PROJECT_DIR/deploy/data/deploy-prebuilt/macos
DEPLOY_DATA_DIR=$PROJECT_DIR/deploy/data/macos

INSTALLER_DATA_DIR=$BUILD_DIR/installer/packages/$APP_DOMAIN/data
INSTALLER_BUNDLE_DIR=$BUILD_DIR/installer/$APP_FILENAME
DMG_FILENAME=$PROJECT_DIR/${APP_NAME}.dmg

# Copy provisioning profiles
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles/"

echo $MACOS_APP_PROVISIONING_PROFILE | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/macos_app.mobileprovision
echo $MACOS_NE_PROVISIONING_PROFILE | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/macos_ne.mobileprovision

shasum -a 256 ~/Library/MobileDevice/Provisioning\ Profiles/macos_app.mobileprovision
shasum -a 256 ~/Library/MobileDevice/Provisioning\ Profiles/macos_ne.mobileprovision

macos_app_uuid=`grep UUID -A1 -a ~/Library/MobileDevice/Provisioning\ Profiles/macos_app.mobileprovision | grep -io "[-A-F0-9]\{36\}"`
macos_ne_uuid=`grep UUID -A1 -a ~/Library/MobileDevice/Provisioning\ Profiles/macos_ne.mobileprovision | grep -io "[-A-F0-9]\{36\}"`

mv ~/Library/MobileDevice/Provisioning\ Profiles/macos_app.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/$macos_app_uuid.mobileprovision
mv ~/Library/MobileDevice/Provisioning\ Profiles/macos_ne.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/$macos_ne_uuid.mobileprovision

# Check if QIF_VERSION is properly set, otherwise set a default
if [ -z "${QIF_VERSION+x}" ]; then
  echo "QIF_VERSION is not set, using default 4.6"
  QIF_VERSION=4.6
fi

QIF_BIN_DIR="$QT_BIN_DIR/../../../Tools/QtInstallerFramework/$QIF_VERSION/bin"

# Checking environment
$QT_BIN_DIR/qt-cmake --version || { echo "Error: qt-cmake not found in $QT_BIN_DIR"; exit 1; }
cmake --version || { echo "Error: cmake not found"; exit 1; }
clang -v || { echo "Error: clang not found"; exit 1; }

# Build the app
echo "Building App..."
mkdir -p build-macos
cd build-macos

$QT_BIN_DIR/qt-cmake .. -GXcode -DQT_HOST_PATH=$QT_MACOS_ROOT_DIR -DMACOS_NE=TRUE
# Xác định target hợp lệ và build
cmake --build . --config release --target AmneziaVPN  # Hoặc target chính xác của bạn

# Build and run tests here

echo "____________________________________"
echo "............Deploy.................."
echo "____________________________________"

# Package
echo "Packaging ..."

cp -Rv $PREBUILT_DEPLOY_DATA_DIR/* $BUNDLE_DIR/Contents/macOS
$QT_BIN_DIR/macdeployqt $OUT_APP_DIR/$APP_FILENAME -always-overwrite -qmldir=$PROJECT_DIR
cp -av $BUILD_DIR/service/server/$APP_NAME-service $BUNDLE_DIR/Contents/macOS
cp -Rv $PROJECT_DIR/deploy/data/macos/* $BUNDLE_DIR/Contents/macOS
rm -f $BUNDLE_DIR/Contents/macOS/post_install.sh $BUNDLE_DIR/Contents/macOS/post_uninstall.sh

# Signing and notarizing the app
if [ "${MAC_CERT_PW+x}" ]; then

  CERTIFICATE_P12=$DEPLOY_DIR/PrivacyTechAppleCertDeveloperId.p12
  WWDRCA=$DEPLOY_DIR/WWDRCA.cer
  KEYCHAIN=amnezia.build.macos.keychain
  TEMP_PASS=tmp_pass

  security create-keychain -p $TEMP_PASS $KEYCHAIN || true
  security default-keychain -s $KEYCHAIN
  security unlock-keychain -p $TEMP_PASS $KEYCHAIN

  security default-keychain
  security list-keychains

  security import $WWDRCA -k $KEYCHAIN -T /usr/bin/codesign || true
  security import $CERTIFICATE_P12 -k $KEYCHAIN -P $MAC_CERT_PW -T /usr/bin/codesign || true

  security set-key-partition-list -S apple-tool:,apple: -k $TEMP_PASS $KEYCHAIN
  security find-identity -p codesigning

  echo "Signing App bundle..."
  /usr/bin/codesign --deep --force --verbose --timestamp -o runtime --sign "$MAC_SIGNER_ID" $BUNDLE_DIR
  /usr/bin/codesign --verify -vvvv $BUNDLE_DIR || true
  spctl -a -vvvv $BUNDLE_DIR || true

  if [ "${NOTARIZE_APP+x}" ]; then
    echo "Notarizing App bundle..."
    /usr/bin/ditto -c -k --keepParent $BUNDLE_DIR $PROJECT_DIR/Bundle_to_notarize.zip
    xcrun notarytool submit $PROJECT_DIR/Bundle_to_notarize.zip --apple-id $APPLE_DEV_EMAIL --team-id $MAC_TEAM_ID --password $APPLE_DEV_PASSWORD
    rm $PROJECT_DIR/Bundle_to_notarize.zip
    sleep 300
    xcrun stapler staple $BUNDLE_DIR
    xcrun stapler validate $BUNDLE_DIR
    spctl -a -vvvv $BUNDLE_DIR || true
  fi
fi

echo "Packaging installer..."
mkdir -p $INSTALLER_DATA_DIR
cp -av $PROJECT_DIR/deploy/installer $BUILD_DIR
cp -av $DEPLOY_DATA_DIR/post_install.sh $INSTALLER_DATA_DIR/post_install.sh
cp -av $DEPLOY_DATA_DIR/post_uninstall.sh $INSTALLER_DATA_DIR/post_uninstall.sh
cp -av $DEPLOY_DATA_DIR/$PLIST_NAME $INSTALLER_DATA_DIR/$PLIST_NAME

chmod a+x $INSTALLER_DATA_DIR/post_install.sh $INSTALLER_DATA_DIR/post_uninstall.sh

cd $BUNDLE_DIR 
tar czf $INSTALLER_DATA_DIR/$APP_NAME.tar.gz ./

echo "Building installer..."
$QIF_BIN_DIR/binarycreator --offline-only -v -c $BUILD_DIR/installer/config/macos.xml -p $BUILD_DIR/installer/packages -f $INSTALLER_BUNDLE_DIR

if [ "${MAC_CERT_PW+x}" ]; then
  echo "Signing installer bundle..."
  security unlock-keychain -p $TEMP_PASS $KEYCHAIN
  /usr/bin/codesign --deep --force --verbose --timestamp -o runtime --sign "$MAC_SIGNER_ID" $INSTALLER_BUNDLE_DIR
  /usr/bin/codesign --verify -vvvv $INSTALLER_BUNDLE_DIR || true

  if [ "${NOTARIZE_APP+x}" ]; then
    echo "Notarizing installer bundle..."
    /usr/bin/ditto -c -k --keepParent $INSTALLER_BUNDLE_DIR $PROJECT_DIR/Installer_bundle_to_notarize.zip
    xcrun notarytool submit $PROJECT_DIR/Installer_bundle_to_notarize.zip --apple-id $APPLE_DEV_EMAIL --team-id $MAC_TEAM_ID --password $APPLE_DEV_PASSWORD
    rm $PROJECT_DIR/Installer_bundle_to_notarize.zip
    sleep 300
    xcrun stapler staple $INSTALLER_BUNDLE_DIR
    xcrun stapler validate $INSTALLER_BUNDLE_DIR
    spctl -a -vvvv $INSTALLER_BUNDLE_DIR || true
  fi
fi

echo "Building DMG installer..."
hdiutil create -size 256mb -volname AmneziaVPN -srcfolder $BUILD_DIR/installer/$APP_NAME.app -ov -format UDZO $DMG_FILENAME

if [ "${MAC_CERT_PW+x}" ]; then
  echo "Signing DMG installer..."
  security unlock-keychain -p $TEMP_PASS $KEYCHAIN
  /usr/bin/codesign --deep --force --verbose --timestamp -o runtime --sign "$MAC_SIGNER_ID" $DMG_FILENAME
  /usr/bin/codesign --verify -vvvv $DMG_FILENAME || true

  if [ "${NOTARIZE_APP+x}" ]; then
    echo "Notarizing DMG installer..."
    xcrun notarytool submit $DMG_FILENAME --apple-id $APPLE_DEV_EMAIL --team-id $MAC_TEAM_ID --password $APPLE_DEV_PASSWORD
    sleep 300
    xcrun stapler staple $DMG_FILENAME
    xcrun stapler validate $DMG_FILENAME
  fi
fi

echo "Finished, artifact is $DMG_FILENAME"

# restore keychain
security default-keychain -s login.keychain