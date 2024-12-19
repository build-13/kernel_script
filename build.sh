#! /bin/bash

#
# Script for building Android arm64 Kernel
#
# Copyright (c) 2021 Fiqri Ardyansyah <fiqri15072019@gmail.com>
# Based on Panchajanya1999 script.
#

# Set environment for directory
KERNEL_DIR=$PWD
IMG_DIR="$KERNEL_DIR"/out/arch/arm64/boot

# Get defconfig file
DEFCONFIG=vendor/mojito_defconfig

# Set common environment
export KBUILD_BUILD_USER="Clang"

#
# Set if do you use GCC or clang compiler
# Default is clang compiler
#
COMPILER=clang

# Get distro name
DISTRO=$(source /etc/os-release && echo ${NAME})

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Set date and time
DATE=$(TZ=Asia/Jakarta date)

# Set date and time for zip name
ZIP_DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M")

# Get branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
export BRANCH

# Check kernel version
KERVER=$(make kernelversion)

# Get last commit
COMMIT_HEAD=$(git log --oneline -1)

# Check directory path
if [[ -d "/drone/src" || -d "/root/project" ]]; then
	echo -e "Detected Continous Integration dir"
	export LOCALBUILD=0
	export KBUILD_BUILD_VERSION="1"
	# Get CPU name
	export CPU_NAME="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"
else
	echo -e "Detected local dir"
	export LOCALBUILD=1
fi

# Setup and apply patch KernelSU in root dir
if ! [ -d "$KERNEL_DIR"/KernelSU ]; then
	curl -kLSs "https://raw.githubusercontent.com/rifsxd/KernelSU/refs/heads/next/kernel/setup.sh" | bash -s main
	if [ -d "$KERNEL_DIR"/KernelSU ]; then
		git apply KernelSU-hook.patch
	fi
fi

# Check for CI
if [ $LOCALBUILD == "0" ]; then
	if [ -d "/drone/src" ]; then
		export KBUILD_BUILD_HOST=$DRONE_SYSTEM_HOST
	elif [ -d "/root/project" ]; then
		export KBUILD_BUILD_HOST="CircleCI"
	fi
elif [ $LOCALBUILD == "1" ]; then
	export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
fi

# Set function for defconfig changes
cfg_changes() {
	if [ $COMPILER == "clang" ]; then
		sed -i 's/CONFIG_LTO_GCC=y/# CONFIG_LTO_GCC is not set/g' arch/arm64/configs/vendor/mojito_defconfig
		sed -i 's/CONFIG_GCC_GRAPHITE=y/# CONFIG_GCC_GRAPHITE is not set/g' arch/arm64/configs/vendor/mojito_defconfig
	elif [ $COMPILER == "gcc" ]; then
		sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/g' arch/arm64/configs/vendor/mojito_defconfig
		sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/g' arch/arm64/configs/vendor/mojito_defconfig
		sed -i 's/# CONFIG_LTO_NONE is not set/CONFIG_LTO_NONE=y/g' arch/arm64/configs/vendor/mojito_defconfig
		sed -i 's/CONFIG_INIT_STACK_ALL_ZERO=y/# CONFIG_INIT_STACK_ALL_ZERO is not set/g' arch/arm64/configs/vendor/mojito_defconfig
		sed -i 's/# CONFIG_INIT_STACK_NONE is not set/CONFIG_INIT_STACK_NONE=y/g' arch/arm64/configs/vendor/mojito_defconfig
	fi

	if [ $LOCALBUILD == "1" ]; then
		if [ $COMPILER == "clang" ]; then
			sed -i 's/# CONFIG_THINLTO is not set/CONFIG_THINLTO=y/g' arch/arm64/configs/vendor/mojito_defconfig
		elif [ $COMPILER == "gcc" ]; then
			sed -i 's/CONFIG_LTO_GCC=y/# CONFIG_LTO_GCC is not set/g' arch/arm64/configs/vendor/mojito_defconfig
		fi
	fi
}

# Set function for enable boot clock timestamp buffer
enable_boot_clock() {	
	# Enable boot clock timestamp buffer support for MIUI ROMs and MIUI Camera
	sed -i 's/# CONFIG_MSM_CAMERA_BOOTCLOCK_TIMESTAMP is not set/CONFIG_MSM_CAMERA_BOOTCLOCK_TIMESTAMP=y/g' arch/arm64/configs/vendor/mojito_defconfig
}

# Set function for cloning repository
clone() {
	# Clone AnyKernel3
	git clone --depth=1 https://github.com/build-13/AnyKernel3.git -b mojito

	if [ $COMPILER == "clang" ]; then
                # Clone clang
                git clone https://gitlab.com/LeCmnGend/proton-clang -b clang-19 --depth=1 clang
                KBUILD_COMPILER_STRING="Proton clang 19.0"
		PATH="${PWD}/clang/bin:${PATH}"
	elif [ $COMPILER == "gcc" ]; then
		# Clone GCC ARM64 and ARM32
		git clone https://github.com/fiqri19102002/aarch64-gcc.git -b release/elf-12 --depth=1 gcc64
		git clone https://github.com/fiqri19102002/arm-gcc.git -b release/elf-12 --depth=1 gcc32
		# Set environment for GCC ARM64 and ARM32
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
		# Get path and compiler string
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi

	export PATH KBUILD_COMPILER_STRING
}

# Set function for naming zip file
set_naming_for_bc() {
	KERNEL_NAME="STRIX-mojito-ksu-$ZIP_DATE"
	export ZIP_NAME="$KERNEL_NAME.zip"
}

# Set function for starting compile
compile() {
	echo -e "Kernel compilation starting"
	if [ $LOCALBUILD == "0" ]; then
		tg_post_msg "<b>Docker OS: </b><code>$DISTRO</code>" \
		            "<b>Kernel Version : </b><code>$KERVER</code>" \
		            "<b>Date : </b><code>$DATE</code>" \
		            "<b>Device : </b><code>Redmi Note 10 (mojito)</code>" \
		            "<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>" \
		            "<b>Host CPU Name : </b><code>$CPU_NAME</code>" \
		            "<b>Host Core Count : </b><code>$PROCS</code>" \
		            "<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>" \
		            "<b>Branch : </b><code>$BRANCH</code>" \
		            "<b>Last Commit : </b><code>$COMMIT_HEAD</code>"
	fi
	make O=out "$DEFCONFIG"
	BUILD_START=$(date +"%s")
	if [ $COMPILER == "clang" ]; then
		make -j"$PROCS" O=out \
				CROSS_COMPILE=aarch64-linux-gnu- \
				LLVM=1 \
				LLVM_IAS=1
	elif [ $COMPILER == "gcc" ]; then
		export CROSS_COMPILE_COMPAT=$GCC32_DIR/bin/arm-eabi-
		make -j"$PROCS" O=out CROSS_COMPILE=aarch64-elf-
	fi
	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))
	if [ -f "$IMG_DIR"/Image ]; then
		echo -e "Kernel successfully compiled"
		if [ $LOCALBUILD == "1" ]; then
			git restore arch/arm64/configs/vendor/mojito_defconfig
		fi
	elif ! [ -f "$IMG_DIR"/Image ]; then
		echo -e "Kernel compilation failed"
		if [ $LOCALBUILD == "0" ]; then
			tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
		fi
		if [ $LOCALBUILD == "1" ]; then
			git restore arch/arm64/configs/vendor/mojito_defconfig
		fi
		exit 1
	fi
}

# Set function for zipping into a flashable zip
gen_zip_for_bc() {
	# Make sure there are no files like dtb, dtbo.img, Image, and .zip
	cd AnyKernel3 || exit
	rm -rf dtb dtbo.img Image *.zip
	cd ..

	# Move kernel image to AnyKernel3
	cat "$IMG_DIR"/dts/qcom/sm6150.dtb > AnyKernel3/dtb
	mv "$IMG_DIR"/dtbo.img AnyKernel3/dtbo.img
	mv "$IMG_DIR"/Image AnyKernel3/Image
	cd AnyKernel3 || exit

	# Archive to flashable zip
	zip -r9 "$ZIP_NAME" * -x .git README.md *.zip

	# Prepare a final zip variable
	ZIP_FINAL="$ZIP_NAME"

	if [ $LOCALBUILD == "0" ]; then
		tg_post_build "$ZIP_FINAL" "<b>Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)</b>"
	fi

	if ! [[ -d "/home/yuta" || -d "/drone/src" || "/root/project" ]]; then
		curl -i -T *.zip https://oshi.at
		curl bashupload.com -T *.zip
	fi
	cd ..
}

clone
cfg_changes
compile
set_naming_for_bc
gen_zip_for_bc
enable_boot_clock
cfg_changes
compile

