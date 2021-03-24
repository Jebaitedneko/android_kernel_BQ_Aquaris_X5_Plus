#!/bin/bash
BUILD_START=$(date +"%s")
tcdir=${HOME}/android/TOOLS/GCC
ak_dir=anykernel/anykernel3
CFGNAME=gohan_defconfig

[ -d "KERNEL_OUT" ] && rm -rf KERNEL_OUT && mkdir -p KERNEL_OUT || mkdir -p KERNEL_OUT

[ -d $tcdir ] && \
	echo "ARM64 TC Present." || \
	echo "ARM64 TC Not Present. Downloading..." | \
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $tcdir/los-4.9-64

[ -d $tcdir ] && \
	echo "ARM32 TC Present." || \
	echo "ARM32 TC Not Present. Downloading..." | \
	git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 $tcdir/los-4.9-32

build_32() {
	echo -e "Building 32-Bit Kernel...\n"
	PATH="$tcdir/los-4.9-32/bin:${PATH}" \
	make    O=KERNEL_OUT \
			ARCH=arm \
			CC="ccache $tcdir/los-4.9-32/bin/arm-linux-androideabi-gcc" \
			CROSS_COMPILE=arm-linux-androideabi- \
			CONFIG_NO_ERROR_ON_MISMATCH=y \
			CONFIG_DEBUG_SECTION_MISMATCH=y \
			-j$(nproc --all) || exit
}

build_64() {
	echo -e "Building 32-Bit Kernel...\n"
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

post() {
	[ -d $ak_dir ] && echo -e "\nAnykernel 3 Present.\n" \
	|| mkdir -p $ak_dir \
	| git clone --depth=1 https://github.com/osm0sis/AnyKernel3 $ak_dir
	rm $ak_dir/anykernel.sh
	cp $ak_dir/../anykernel.sh $ak_dir

	[ -f KERNEL_OUT/arch/arm/boot/zImage-dtb ] && cp KERNEL_OUT/arch/arm/boot/zImage-dtb $ak_dir
	[ -f KERNEL_OUT/arch/arm64/boot/zImage-dtb ] && cp KERNEL_OUT/arch/arm64/boot/zImage-dtb $ak_dir

	( cd $ak_dir; zip -r9 ../../KERNEL_OUT/${CFGNAME/_defconfig/}_`date +%d\.%m\.%Y_%H\:%M\:%S`.zip . -x '*.git*' '*modules*' '*patch*' '*ramdisk*' 'LICENSE' 'README.md' )

	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))
	echo -e "\nBuild completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

[[ $1 != '' && $1 != "64" && $1 = "32" ]] && \
	echo -e "Setting Config...\n" && make O=KERNEL_OUT ARCH=arm $CFGNAME && \
	build_32 && post || echo -e "Specify an arch (32 or 64) as parameter\n" && exit
[[ $1 != '' && $1 != "32" && $1 = "64" ]] && \
	echo -e "Setting Config...\n" && make O=KERNEL_OUT ARCH=arm64 $CFGNAME && \
	build_64 && post || echo -e "Specify an arch (32 or 64) as parameter\n" && exit
