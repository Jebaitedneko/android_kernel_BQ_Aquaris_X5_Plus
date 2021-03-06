#!/bin/bash
BUILD_START=$(date +"%s")
tcdir=${HOME}/android/TOOLS/GCC
ak_dir=anykernel/anykernel3
CFGNAME=gohan-perf_defconfig

[ -d "KERNEL_OUT" ] && rm -rf KERNEL_OUT && mkdir -p KERNEL_OUT || mkdir -p KERNEL_OUT

[ -d $tcdir ] && \
	echo "ARM64 TC Present." || \
	echo "ARM64 TC Not Present. Downloading..." | \
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $tcdir/los-4.9-64

[ -d $tcdir ] && \
	echo "ARM32 TC Present." || \
	echo "ARM32 TC Not Present. Downloading..." | \
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 $tcdir/los-4.9-32

build_64() {
	echo -e "Building 64-Bit Kernel...\n"
	PATH="$tcdir/los-4.9-64/bin:$tcdir/los-4.9-32/bin:${PATH}" \
		make    O=KERNEL_OUT \
				ARCH=arm64 \
				CC="ccache $tcdir/los-4.9-64/bin/aarch64-linux-android-gcc" \
				CROSS_COMPILE=aarch64-linux-android- \
				CROSS_COMPILE_ARM32=arm-linux-androideabi- \
				CONFIG_NO_ERROR_ON_MISMATCH=y \
				CONFIG_DEBUG_SECTION_MISMATCH=y \
				-j$(nproc --all) || exit
}

mod() {
	echo -e "Building Modules...\n"
	[ -d "KERNEL_OUT/modules" ] && rm -rf KERNEL_OUT/modules || mkdir -p KERNEL_OUT/modules
	PATH="$tcdir/los-4.9-64/bin:$tcdir/los-4.9-32/bin:${PATH}" \
		make    O=KERNEL_OUT \
				ARCH=arm64 \
				CC="ccache $tcdir/los-4.9-64/bin/aarch64-linux-android-gcc" \
				CROSS_COMPILE=aarch64-linux-android- \
				CROSS_COMPILE_ARM32=arm-linux-androideabi- \
				CONFIG_NO_ERROR_ON_MISMATCH=y \
				CONFIG_DEBUG_SECTION_MISMATCH=y \
				INSTALL_MOD_PATH=modules \
				INSTALL_MOD_STRIP=1 \
				modules_install || exit
	find $ak_dir/modules/system/lib/modules -iname "*.ko" -delete
	find KERNEL_OUT/modules -iname "*.ko" -exec cp {} $ak_dir/modules/system/lib/modules/ \;
}

post() {
	[ -d $ak_dir ] && echo -e "\nAnykernel 3 Present.\n" \
	|| mkdir -p $ak_dir \
	| git clone --depth=1 https://github.com/osm0sis/AnyKernel3 $ak_dir
	rm $ak_dir/anykernel.sh
	cp $ak_dir/../anykernel.sh $ak_dir

	[ -f KERNEL_OUT/arch/arm64/boot/zImage-dtb ] && cp KERNEL_OUT/arch/arm64/boot/zImage-dtb $ak_dir

	( cd $ak_dir; zip -r9 ../../KERNEL_OUT/${CFGNAME/_defconfig/}_`date +%d\.%m\.%Y_%H\:%M\:%S`.zip . -x '*.git*' '*patch*' '*ramdisk*' 'LICENSE' 'README.md' )

	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))
	echo -e "\nBuild completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

echo -e "Setting Config...\n" && make O=KERNEL_OUT ARCH=arm64 $CFGNAME && build_64 && mod && post
