#!/bin/bash

if [ ! -d /home/runner/work ]; then NTHREADS=$(nproc); else NTHREADS=$(($(nproc)*4)); fi

kernels=$(ls -d ./kernels/* | sed 's#./kernels/##g')
for kernel in $kernels; do
	if [ ! -f "./kernels/$kernel/out/arch/x86/boot/bzImage" ]; then echo "The kernel $kernel has to be built first"; exit 1; fi
done

if ( ! test -z {,} ); then echo "Must be ran with \"sudo bash\""; exit 1; fi
if [ $(whoami) != "root" ]; then echo "Please run with sudo"; exit 1; fi

if [ -d ./packages ]; then rm -r ./packages; fi

mkdir packages

chmod 0777 ./packages || { echo "Failed to fix output directory permissions"; exit 1; }

cwd="$(pwd)"

for kernel in $kernels; do

mkdir -p ./kernel || { echo "Failed to create directory for kernel $kernel"; exit 1; }
cd ./kernel || { echo "Failed to enter source directory for kernel $kernel"; exit 1; }
kernel_version="$(file ./out/arch/x86/boot/bzImage | cut -d' ' -f9)"
[ ! "$kernel_version" == "" ] || { echo "Failed to read version for kernel $kernel"; exit 1; }
cp ./out/arch/x86/boot/bzImage ${cwd}/kernel-"$kernel" || { echo "Failed to copy the kernel $kernel"; exit 1; }
make -j"$NTHREADS" O=out INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${cwd}/kernel modules_install || { echo "Failed to install modules for kernel $kernel"; exit 1; }
rm -f ${cwd}/kernel/lib/modules/"$kernel_version"/build || { echo "Failed to remove the build directory for kernel $kernel"; exit 1; }
rm -f ${cwd}/kernel/lib/modules/"$kernel_version"/source || { echo "Failed to remove the source directory for kernel $kernel"; exit 1; }

cd ${cwd}/kernel || { echo "Failed to enter directory for kernel $kernel"; exit 1; }
tar zcf ${cwd}/packages/kernel-"$kernel_version".tar.gz * --owner=0 --group=0 || { echo "Failed to create archive for kernel $kernel"; exit 1; }
rm -rf ${cwd}/kernel || { echo "Failed to cleanup for kernel $kernel"; exit 1; }

done

cd ${cwd}

if [ -d ./out ]; then rm -r ./out; fi
if [ -d ./firmware ]; then rm -r ./firmware; fi

git clone --depth=1 -b main https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git || { echo "Failed to clone the linux firmware git"; exit 1; }
cd ./linux-firmware || { echo "Failed to enter the linux firmware directory"; exit 1; }
make -j"$NTHREADS" DESTDIR=./tmp ZSTD_CLEVEL=19 FIRMWAREDIR=/lib/firmware install-zst || { echo "Failed to install firmwares in temporary directory"; exit 1; }
mv ./tmp/lib/firmware ./out || { echo "Failed to move the firmwares temporary directory"; exit 1; }
rm -rf ./out/bnx2x*
rm -rf ./out/dpaa2*
rm -rf ./out/liquidio*
rm -rf ./out/mellanox*
rm -rf ./out/mrvl/prestera*
rm -rf ./out/netronome*
rm -rf ./out/qcom*
rm -rf ./out/qed*
rm -rf ./out/ti-connectivity*
curl -L https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/regulatory.db -o ./out/regulatory.db || { echo "Failed to download the regulatory db"; exit 1; }
curl -L https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/plain/regulatory.db.p7s -o ./out/regulatory.db.p7s || { echo "Failed to download the regulatory db"; exit 1; }
curl -L https://archlinux.org/packages/core/any/amd-ucode/download/ -o /tmp/amd-ucode.tar.zst || { echo "Failed to download amd ucode"; exit 1; }
tar -C ${cwd}/out -xf /tmp/amd-ucode.tar.zst boot/amd-ucode.img --strip 1 || { echo "Failed to extract amd ucode"; exit 1; }
rm /tmp/amd-ucode.tar.zst || { echo "Failed to cleanup amd ucode"; exit 1; }
curl -L https://archlinux.org/packages/extra/any/intel-ucode/download/ -o /tmp/intel-ucode.tar.zst || { echo "Failed to download intel ucode"; exit 1; }
tar -C ${cwd}/out -xf /tmp/intel-ucode.tar.zst boot/intel-ucode.img --strip 1 || { echo "Failed to extract intel ucode"; exit 1; }
rm /tmp/intel-ucode.tar.zst || { echo "Failed to cleanup intel ucode"; exit 1; }
mv ./out ./firmware
tar zcf ${cwd}/packages/firmwares.tar.gz firmware --owner=0 --group=0 || { echo "Failed to create the firmwares archive"; exit 1; }
cd ${cwd}
rm -r ./linux-firmware || { echo "Failed to cleanup firmwares directory"; exit 1; }

tar zcf packages.tar.gz packages --owner=0 --group=0
