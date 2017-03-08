## Determine the appropriate openssl source path to use
## Introduced by michaeltyson, adapted to account for OPENSSL_SRC build path

echo "Ditto /Users/dweston/Library/Developer/Xcode/DerivedData/Netopsy-frdwfkwtnprvpodaxeqecabaxytg/Build/Products/Debug/Proxying.framework/Versions/A/Headers/Proxying-Swift.h /Users/dweston/Library/Developer/Xcode/DerivedData/Netopsy-frdwfkwtnprvpodaxeqecabaxytg/Build/Intermediates/Netopsy.build/Debug/Proxying.build/Objects-normal/x86_64/Proxying-Swift.h
    (running because there is no record of having run this command since the last clean)
    cd /Users/dweston/src/Netopsy/Netopsy
    /usr/bin/ditto -rsrc /Users/dweston/Library/Developer/Xcode/DerivedData/Netopsy-frdwfkwtnprvpodaxeqecabaxytg/Build/Intermediates/Netopsy.build/Debug/Proxying.build/Objects-normal/x86_64/Proxying-Swift.h /Users/dweston/Library/Developer/Xcode/DerivedData/Netopsy-frdwfkwtnprvpodaxeqecabaxytg/Build/Products/Debug/Proxying.framework/Versions/A/Headers/Proxying-Swift.h"
echo "progress: Doing the thing!"

# locate src archive file if present
SRC_ARCHIVE=`ls openssl*tar.gz 2>/dev/null`

# if there is an openssl directory immediately under the openssl.xcode source 
# folder then build there
if [ -d "$SRCROOT/openssl" ]; then
OPENSSL_SRC="$SRCROOT/openssl"
# else, if there is a openssl.tar.gz in the directory, expand it to openssl
# and use it
elif [ -f "$SRC_ARCHIVE" ]; then
OPENSSL_SRC="$PROJECT_TEMP_DIR/openssl"
if [ ! -d "$OPENSSL_SRC" ]; then
echo "note: extracting $SRC_ARCHIVE..."
mkdir "$OPENSSL_SRC"
tar -C "$OPENSSL_SRC" --strip-components=1 -zxf "$SRC_ARCHIVE" || exit 1
cp -RL "$OPENSSL_SRC/include" "$TARGET_BUILD_DIR"
fi
# else, if $OPENSSL_SRC is not already defined (i.e. by prerequisites for SQLCipher XCode config)
# then assume openssl is in the current directory
elif [ ! -d "$OPENSSL_SRC" ]; then
OPENSSL_SRC="$SRCROOT"
fi

echo "note: using $OPENSSL_SRC for openssl source code  *****"

# check whether libcrypto.a already exists - we'll only build if it does not
if [ -f  "$TARGET_BUILD_DIR/libcrypto.a" ]; then
echo "Touch $TARGET_BUILD_DIR/libcrypto.a"
echo "note: To force a rebuild clean project and clean dependencies *****"
exit 0;
else
echo "note: No previously-built libary present at $TARGET_BUILD_DIR/libcrypto.a - performing build *****"
fi

# figure out the right set of build architectures for this run
BUILDARCHS="$ARCHS"

echo "note: creating universal binary for architectures: $BUILDARCHS *****"

if [ "$SDKROOT" != "" ]; then
ISYSROOT="-isysroot $SDKROOT"
fi

echo "note: using ISYSROOT $ISYSROOT *****"

OPENSSL_OPTIONS=""

echo "note: using OPENSSL_OPTIONS $OPENSSL_OPTIONS *****"

cd "$OPENSSL_SRC"

for BUILDARCH in $BUILDARCHS
do
echo "note: BUILDING UNIVERSAL ARCH $BUILDARCH ******"
make clean

# disable assembler
echo "note: configuring WITHOUT assembler optimizations based on architecture $BUILDARCH and build style $BUILD_STYLE *****"
./config no-asm $OPENSSL_OPTIONS -openssldir="$BUILD_DIR"
ASM_DEF="-UOPENSSL_BN_ASM_PART_WORDS"

make CFLAG="-D_DARWIN_C_SOURCE $ASM_DEF -arch $BUILDARCH $ISYSROOT -Wno-unused-value -Wno-parentheses" SHARED_LDFLAGS="-arch $BUILDARCH -dynamiclib"

echo "note: copying intermediate libraries to $CONFIGURATION_TEMP_DIR/$BUILDARCH-*.a *****"
cp libcrypto.a "$CONFIGURATION_TEMP_DIR"/$BUILDARCH-libcrypto.a
cp libssl.a "$CONFIGURATION_TEMP_DIR"/$BUILDARCH-libssl.a
done

echo "note: creating universallibraries in $TARGET_BUILD_DIR *****"
mkdir -p "$TARGET_BUILD_DIR"
lipo -create "$CONFIGURATION_TEMP_DIR/"*-libcrypto.a -output "$TARGET_BUILD_DIR/libcrypto.a"
lipo -create "$CONFIGURATION_TEMP_DIR/"*-libssl.a -output "$TARGET_BUILD_DIR/libssl.a"

echo "note: removing temporary files from $CONFIGURATION_TEMP_DIR *****"
rm -f "$CONFIGURATION_TEMP_DIR/"*-libcrypto.a
rm -f "$CONFIGURATION_TEMP_DIR/"*-libssl.a
                                       
echo "note: executing ranlib on libraries in $TARGET_BUILD_DIR *****"
ranlib "$TARGET_BUILD_DIR/libcrypto.a"
ranlib "$TARGET_BUILD_DIR/libssl.a"

