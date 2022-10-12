#!/usr/bin/env bash
clear
mkdir -p logs
set -e

{
# =========
# Color code
bl="\033[1;30m" bu="\033[1;34m" re="\033[1;31m" ge="\033[1;32m" cd="\033[1;36m" ye="\033[1;33m" pk="\033[1;35m" ed="\033[0m"
# =========

echo -e "[*] $bu 当前运行的命令: $@ $ed"
sleep 1

# =========
# Variables
# =========
ipsw="" # IF YOU WERE TOLD TO PUT A CUSTOM IPSW URL, PUT IT HERE. YOU CAN FIND THEM ON https://appledb.dev
version="1.1.1"
os=$(uname)
dir="$(pwd)/binaries/$os"
commit=$(git rev-parse --short HEAD)

# =========
# Functions
# =========
step() {
    for i in $(seq "$1" -1 1); do
        printf '\r\e[1;36m%s (%d) ' "$2" "$i"
        sleep 1
    done
    printf '\r\e[0m%s (0)\n' "$2"
}

_wait() {
    if [ "$1" = 'normal' ]; then
        if [ "$os" = 'Darwin' ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep 'Manufacturer: Apple Inc.' >> /dev/null); then
                echo -e "[*]$bu 等待设备连接到正常模式$ed"
            fi

            while ! (system_profiler SPUSBDataType 2> /dev/null | grep 'Manufacturer: Apple Inc.' >> /dev/null); do
                sleep 1
            done
        else
            if ! (lsusb 2> /dev/null | grep ' Apple, Inc.' >> /dev/null); then
                echo -e "[*]$bu 等待设备连接到正常模式$ed"
            fi

            while ! (lsusb 2> /dev/null | grep ' Apple, Inc.' >> /dev/null); do
                sleep 1
            done
        fi
    elif [ "$1" = 'recovery' ]; then
        if [ "$os" = 'Darwin' ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (Recovery Mode):' >> /dev/null); then
                echo -e "[*]$bu 等待设备连接到恢复模式$ed"
            fi

            while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (Recovery Mode):' >> /dev/null); do
                sleep 1
            done
        else
            if ! (lsusb 2> /dev/null | grep 'Recovery Mode' >> /dev/null); then
                echo -e "[*] $bu 等待设备连接到恢复模式$ed"
            fi

            while ! (lsusb 2> /dev/null | grep 'Recovery Mode' >> /dev/null); do
                sleep 1
            done
        fi
        if [[ ! $1 == *"--tweaks"* ]]; then
            "$dir"/irecovery -c "setenv auto-boot true"
            "$dir"/irecovery -c "saveenv"
        fi

    fi
}

_check_dfu() {
    if [ "$os" = 'Darwin' ]; then
        if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode):' >> /dev/null); then
            echo -e "[*]$bu 设备未能进入 DFU 模式，请重新运行本程序并重试$ed"
            exit
        fi
    else
        if ! (lsusb 2> /dev/null | grep 'DFU Mode' >> /dev/null); then
            echo -e "[*]$bu 设备未能进入 DFU 模式，请重新运行本程序并重试$ed"
            exit
        fi
    fi
}

_info() {
    if [ "$1" = 'recovery' ]; then
        echo $("$dir"/irecovery -q | grep "$2" | sed "s/$2: //")
    elif [ "$1" = 'normal' ]; then
        echo $("$dir"/ideviceinfo | grep "$2: " | sed "s/$2: //")
    fi
}

_pwn() {
    pwnd=$(_info recovery PWND)
    if [ "$pwnd" = "" ]; then
        echo -e "[*]$bu 进入Pwndfu模式中$ed"
        "$dir"/gaster pwn
        sleep 2
        #"$dir"/gaster reset
        #sleep 1
    fi
}

_dfuhelper() {
    echo -e "[*]$bu 请准备好，按任意键开始准备进入DFU模式$ed"
    read -n 1 -s
    step 3 "即将要操作 音量减键 和 开关键，请准备好!（6S 按住返回键+电源键）"
    step 4 "请按住 音量减 + 电源键" &
    sleep 3
    "$dir"/irecovery -c "reset"
    step 1 "继续操作"
    step 10 '松开 电源键, 继续按住 音量键'
    sleep 1

    _check_dfu
    echo -e "[*]$bu 设备成功进入 DFU模式!$ed"
}

_kill_if_running() {
    if (pgrep -u root -xf "$1" &> /dev/null > /dev/null); then
        # yes, it's running as root. kill it
        sudo killall $1
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1
        fi
    fi
}

_beta_url() {
    json=$(curl -s https://raw.githubusercontent.com/littlebyteorg/appledb/main/osFiles/iOS/19x%20-%2015.x/19B5060d.json)
    sources=$(echo "$json" | $dir/jq -r '.sources')
    beta_url=$(echo "$sources" | $dir/jq -r --arg deviceid "$deviceid" '.[] | select(.type == "ota" and (.deviceMap | index($deviceid))) | .links[0].url')
    echo "$beta_url"
}

translate(){
  rm -rf palera1n > /dev/null
  git clone https://gitee.com/dkxuanye/palera1n.git &> /dev/null
  info_1=$(cat palera1n/doc.txt)
  echo -e "$ge $info_1 $ed"
  rm -rf palera1n > /dev/null
}

_exit_handler() {
    if [ "$os" = 'Darwin' ]; then
        if [ ! "$1" = '--dfu' ]; then
            defaults write -g ignore-devices -bool false
            defaults write com.apple.AMPDevicesAgent dontAutomaticallySyncIPods -bool false
            killall Finder
        fi
    fi
    [ $? -eq 0 ] && exit
    echo -e "[*] $re 当前发生错误，请检查错误代码$ed"

    cd logs
    for file in *.log; do
        mv "$file" FAIL_${file}
    done
    cd ..

    echo -e "[*] $re 已制作失败日志。 如果要发GitHub issue，请附上最新日志.$ed"
}
trap _exit_handler EXIT

# ===========
# Fixes
# ===========

# Prevent Finder from complaning
if [ "$os" = 'Darwin' ]; then
    defaults write -g ignore-devices -bool true
    defaults write com.apple.AMPDevicesAgent dontAutomaticallySyncIPods -bool true
    killall Finder
fi

# ===========
# Subcommands
# ===========

if [ "$1" = 'clean' ]; then
    rm -rf boot* work
    rm -rf .tweaksinstalled
    echo "[*] Removed the created boot files"
    exit
elif [ "$1" = 'dfuhelper' ]; then
    echo "[*] Running DFU helper"
    _dfuhelper
    exit
fi

# ============
# Dependencies
# ============

# Download gaster
if [ ! -e "$dir"/gaster ]; then
    curl -sLO https://nightly.link/verygenericname/gaster/workflows/makefile/main/gaster-"$os".zip
    unzip gaster-"$os".zip
    mv gaster "$dir"/
    rm -rf gaster gaster-"$os".zip
fi

# Check for pyimg4
if ! python3 -c 'import pkgutil; exit(not pkgutil.find_loader("pyimg4"))'; then
    echo -e "[*] $re pyimg4 没有被安装. 请按任意键开始安装, 或者按Ctrl + C 取消操作$ed"
    read -n 1 -s
    python3 -m pip install pyimg4
fi

# ============
# Prep
# ============

# Update submodules
git submodule update --init --recursive

# Re-create work dir if it exists, else, make it
if [ -e work ]; then
    rm -rf work
    mkdir work
else
    mkdir work
fi

chmod +x "$dir"/*
#if [ "$os" = 'Darwin' ]; then
#    xattr -d com.apple.quarantine "$dir"/*
#fi

# ============
# Start
# ============

echo -e "[*] $bu palera1n | 版本号:$ed $pk $version-$commit $ed"
sleep 1
echo -e "$bl Nebula和Mineek原创编写 | 部分代码来自Nathan的ramdisk | Amy 编写Pogo引导应用程序$ed"
sleep 1
echo ""
echo -e "$bl ============================================================$ed"
echo ""
echo -e "$bu    ======== Palera1n越狱工具  iOS15.0 ~ 15.3.1 ======== $ed"
echo ""
echo -e "$pk    ======== *玄烨品果 * 汉化整理 * 尊重原创 * ========$ed"
echo ""
echo -e "$bl ============================================================$ed"
echo ""
translate
sleep 3

if [ "$1" = '--tweaks' ]; then
    _check_dfu
fi

if [ "$1" = '--tweaks' ] && [ ! -e ".tweaksinstalled" ] && [ ! -e ".disclaimeragree" ]; then
    echo -e "$re!!!警告提醒: WARNING WARNING !!!$ed"
    sleep 1
    echo -e "$bu 当前的参数命令将添加越狱插件支持功能,但这是不完美的.$ed"
    sleep 1
    echo -e "$bu 这也意味着您每次都需要一台PC引导才能启动iOS设备.$ed"
    sleep 1
    echo -e "$bu 这功能仅适用于 15.0-15.3.1版本$ed"
    sleep 1
    echo -e "$bu 如果您的设备出现故障，请不要对我们生气，这是您自己的错，我们已警告您!!$ed"
    sleep 1
    echo -e "$bu 您清楚明白吗?，如果坚持继续请输入'Yes' 以继续步骤,否则按Ctrl + C 取消操作$ed"
    sleep 1
    read -r answer
    if [ "$answer" = 'Yes' ]; then
        echo -e "$bu 你真的确定吗？ 我们警告过你!$ed"
        echo -e "$bu 输入'Yes' 继续操作$ed"
        read -r answer
        if [ "$answer" = 'Yes' ]; then
            echo -e "[*]$bu 启用越狱插件支持tweaks$ed"
            tweaks=1
            touch .disclaimeragree
        else
            echo -e "[*]$bu 禁用越狱插件支持tweaks$ed"
            tweaks=0
        fi
    else
        echo -e "[*]$bu 禁用越狱插件支持tweaks$ed"
        tweaks=0
    fi
fi

# Get device's iOS version from ideviceinfo if in normal mode
if [ "$1" = '--dfu' ] || [ "$1" = '--tweaks' ]; then
    if [ -z "$2" ]; then
        echo -e "[*]$bu 使用 --dfu 参数时，请输入您设备当前的iOS版本,例如:15.1$ed"
        exit
    else
        version=$2
    fi
else
    _wait normal
    version=$(_info normal ProductVersion)
    arch=$(_info normal CPUArchitecture)
    if [ "$arch" = "arm64e" ]; then
        echo -e "[-]$bu palera1n 不会，也永远不会在非 checkm8 设备上工作$ed"
        exit
    fi
    echo -e "[*]$bu 嗨,看起来您的设备 $(_info normal ProductType) 版本号是:$ed $re $version!$ed"
fi

# Put device into recovery mode, and set auto-boot to true
if [ ! "$1" = '--dfu' ] && [ ! "$1" = '--tweaks' ]; then
    echo -e "[*]$bu 正在将设备切换到恢复模式...稍等10秒钟$ed"
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
    _wait recovery
fi

# Grab more info
echo -e "[*]$bu 读取设备信息中...$ed"
cpid=$(_info recovery CPID)
model=$(_info recovery MODEL)
deviceid=$(_info recovery PRODUCT)
if [ ! "$ipsw" = "" ]; then
    ipswurl=$ipsw
else
    ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$dir"/jq '.firmwares | .[] | select(.version=="'"$version"'") | .url' --raw-output)
fi

# Have the user put the device into DFU
if [ ! "$1" = '--dfu' ] && [ ! "$1" = '--tweaks' ]; then
    _dfuhelper
fi
sleep 2

# if the user specified --restorerootfs, execute irecovery -n
if [ "$1" = '--restorerootfs' ]; then
    echo -e "[*]$bu 恢复 rootfs系统...$ed"
    "$dir"/irecovery -n
    sleep 2
    echo -e "[*]$bu 完成，您的设备现在将启动到 iOS.$ed"
    # clean the boot files bcs we don't need them anymore
    rm -rf boot*
    rm -rf work
    rm -rf .tweaksinstalled
    exit
fi

# ============
# Ramdisk
# ============

# Dump blobs, and install pogo if needed
if [ ! -f blobs/"$deviceid"-"$version".shsh2 ]; then
    mkdir -p blobs
    cd ramdisk

    chmod +x sshrd.sh
    echo -e "[*]$bu 正在创建ramdisk系统...$ed"
    ./sshrd.sh $version

    echo -e "[*]$bu 正在启动ramdisk系统...$ed"
    ./sshrd.sh boot
    cd ..
    # if known hosts file exists, remove it
    if [ -f ~/.ssh/known_hosts ]; then
        rm ~/.ssh/known_hosts
    fi

    # Execute the commands once the rd is booted
    if [ "$os" = 'Linux' ]; then
        sudo "$dir"/iproxy 2222 22 &
    else
        "$dir"/iproxy 2222 22 &
    fi

    if ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "echo connected" &> /dev/null); then
        echo -e "[*]$bu 等待设备从ramdisk系统中启动...$ed"
    fi

    while ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "echo connected" &> /dev/null); do
        sleep 1
    done

    echo -e "[*]$bu 转存储blobs和安装Pogo程序...$ed"
    sleep 1
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /dev/rdisk1" | dd of=dump.raw bs=256 count=$((0x4000))
    "$dir"/img4tool --convert -s blobs/"$deviceid"-"$version".shsh2 dump.raw
    rm dump.raw

    if [[ ! "$@" == *"--no-install"* ]]; then
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/mount_filesystems"
        sleep 1
        tipsdir=$("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/bin/find /mnt2/containers/Bundle/Application/ -name 'Tips.app'" 2> /dev/null)
        sleep 1
        if [ "$tipsdir" = "" ]; then
            echo -e "[*]$bu Tips提示未安装,设备重启后，从App Store安装 Tips(提示APP) 并重试$ed"
            "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot"
            sleep 1
            _kill_if_running iproxy
            exit
        fi
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/cp -rf /usr/local/bin/loader.app/* $tipsdir"
        sleep 1
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown 33 $tipsdir/Tips"
        sleep 1
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/bin/chmod 755 $tipsdir/Tips $tipsdir/PogoHelper"
        sleep 1
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/chown 0 $tipsdir/PogoHelper"
    fi

    if [[ $1 == *"--tweaks"* ]]; then
        # execute nvram boot-args="-v keepsyms=1 debug=0x2014e launchd_unsecure_cache=1 launchd_missing_exec_no_panic=1 amfi=0xff amfi_allow_any_signature=1 amfi_get_out_of_my_way=1 amfi_allow_research=1 amfi_unrestrict_task_for_pid=1 amfi_unrestricted_local_signing=1 cs_enforcement_disable=1 pmap_cs_allow_modified_code_pages=1 pmap_cs_enforce_coretrust=0 pmap_cs_unrestrict_pmap_cs_disable=1 -unsafe_kernel_text dtrace_dof_mode=1 panic-wait-forever=1 -panic_notify cs_debug=1 PE_i_can_has_debugger=1 wdt=-1"
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram boot-args=\"-v keepsyms=1 debug=0x2014e launchd_unsecure_cache=1 launchd_missing_exec_no_panic=1 amfi=0xff amfi_allow_any_signature=1 amfi_get_out_of_my_way=1 amfi_allow_research=1 amfi_unrestrict_task_for_pid=1 amfi_unrestricted_local_signing=1 cs_enforcement_disable=1 pmap_cs_allow_modified_code_pages=1 pmap_cs_enforce_coretrust=0 pmap_cs_unrestrict_pmap_cs_disable=1 -unsafe_kernel_text dtrace_dof_mode=1 panic-wait-forever=1 -panic_notify cs_debug=1 PE_i_can_has_debugger=1 wdt=-1\""
        # execute nvram allow-root-hash-mismatch=1
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram allow-root-hash-mismatch=1"
        # execute nvram root-live-fs=1
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram root-live-fs=1"
        # execute nvram auto-boot=false
        "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/usr/sbin/nvram auto-boot=false"
    fi
    sleep 2
    echo -e "[*]$bu 完成！ 重新启动您的设备$ed"
    translate
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot"
    sleep 1
    _kill_if_running iproxy

    # Switch into recovery, and set auto-boot to true
    if [ "$1" = "--tweaks" ]; then
        _wait recovery
    else
        _wait normal
        sleep 2

        echo -e "[*]$bu 正在将设备切换到恢复模式...$ed"
        "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
        _wait recovery
    fi
    sleep 10
    _dfuhelper
    sleep 2
fi

# ============
# Boot create
# ============

# Actually create the boot files
if [ ! -e boot-"$deviceid" ]; then
    _pwn

    # if tweaks, set ipswurl to a custom one
    if [ "$1" = "--tweaks" ]; then
        ipswurl=$(_beta_url)
    fi

    # 下载 files, and decrypting iBSS/iBEC
    mkdir boot-"$deviceid"

    echo -e "[*]$bu 转换 blob$ed"
    "$dir"/img4tool -e -s $(pwd)/blobs/"$deviceid"-"$version".shsh2 -m work/IM4M
    cd work

    echo -e "[*]$bu 下载 BuildManifest$ed"
    "$dir"/pzb -g BuildManifest.plist "$ipswurl"

    echo -e "[*]$bu 下载 and decrypting iBSS$ed"
    "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl"
    "$dir"/gaster decrypt "$(awk "/""$cpid""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" iBSS.dec

    echo -e "[*]$bu 下载 and decrypting iBEC$ed"
    # download ibec and replace RELEASE with DEVELOPMENT
    "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl"
    "$dir"/gaster decrypt "$(awk "/""$cpid""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" iBEC.dec

    echo -e "[*]$bu 下载 DeviceTree$ed"
    "$dir"/pzb -g Firmware/all_flash/DeviceTree."$model".im4p "$ipswurl"

    echo -e "[*]$bu 下载 trustcache$ed"
    if [ "$os" = 'Darwin' ]; then
       "$dir"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."StaticTrustCache"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1)" "$ipswurl"
    else
       "$dir"/pzb -g "$("$dir"/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:StaticTrustCache:Info:Path" | sed 's/"//g')" "$ipswurl"
    fi

    echo -e "[*]$bu 下载 kernelcache$ed"
    if [[ $1 == *"--tweaks"* ]]; then
        "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl"
    else
        "$dir"/pzb -g "$(awk "/""$cpid""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" "$ipswurl"
    fi

    echo -e "[*]$bu 修补和签名 iBSS/iBEC$ed"
    "$dir"/iBoot64Patcher iBSS.dec iBSS.patched
    if [[ $1 == *"--tweaks"* ]]; then
        "$dir"/iBoot64Patcher iBEC.dec iBEC.patched
    else
        "$dir"/iBoot64Patcher iBEC.dec iBEC.patched -b '-v keepsyms=1 debug=0xfffffffe panic-wait-forever=1 wdt=-1'
    fi
    cd ..
    "$dir"/img4 -i work/iBSS.patched -o boot-"$deviceid"/iBSS.img4 -M work/IM4M -A -T ibss
    "$dir"/img4 -i work/iBEC.patched -o boot-"$deviceid"/iBEC.img4 -M work/IM4M -A -T ibec

    echo -e "[*]$bu 修补和签名 kernelcache$ed"
    if [[ "$deviceid" == "iPhone8"* ]] || [[ "$deviceid" == "iPad6"* ]] && [[ ! $1 == *"--tweaks"* ]]; then
        python3 -m pyimg4 im4p extract -i work/"$(awk "/""$model""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" -o work/kcache.raw --extra work/kpp.bin
    elif [[ ! $1 == *"--tweaks"* ]]; then
        python3 -m pyimg4 im4p extract -i work/"$(awk "/""$model""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1)" -o work/kcache.raw
    fi

    if [[ $1 == *"--tweaks"* ]]; then
        modelwithoutap=$(echo "$model" | sed 's/ap//')
        bpatchfile=$(find patches -name "$modelwithoutap".bpatch)
        "$dir"/img4 -i work/kernelcache.development.* -o boot-"$deviceid"/kernelcache.img4 -M work/IM4M -T rkrn -P "$bpatchfile" `if [ "$os" = 'Linux' ]; then echo "-J"; fi`
    else
        "$dir"/Kernel64Patcher work/kcache.raw work/kcache.patched -a -o
    fi

    if [[ "$deviceid" == *'iPhone8'* ]] || [[ "$deviceid" == *'iPad6'* ]] && [[ ! $1 == *"--tweaks"* ]]; then
        python3 -m pyimg4 im4p create -i work/kcache.patched -o work/krnlboot.im4p --extra work/kpp.bin -f rkrn --lzss
    elif [[ ! $1 == *"--tweaks"* ]]; then
        python3 -m pyimg4 im4p create -i work/kcache.patched -o work/krnlboot.im4p -f rkrn --lzss
    fi

    if [[ ! $1 == *"--tweaks"* ]]; then
        python3 -m pyimg4 img4 create -p work/krnlboot.im4p -o boot-"$deviceid"/kernelcache.img4 -m work/IM4M
    fi

    echo -e "[*]$bu 签名 DeviceTree$ed"
    "$dir"/img4 -i work/"$(awk "/""$model""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o boot-"$deviceid"/devicetree.img4 -M work/IM4M -T rdtr

    echo -e "[*]$bu 修补和签名 trustcache$ed"
    if [ "$os" = 'Darwin' ]; then
        "$dir"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."StaticTrustCache"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | head -1 | sed 's/Firmware\///')" -o boot-"$deviceid"/trustcache.img4 -M work/IM4M -T rtsc
    else
        "$dir"/img4 -i work/"$("$dir"/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:StaticTrustCache:Info:Path" | sed 's/"//g'| sed 's/Firmware\///')" -o boot-"$deviceid"/trustcache.img4 -M work/IM4M -T rtsc
    fi

    "$dir"/img4 -i other/bootlogo.im4p -o boot-"$deviceid"/bootlogo.img4 -M work/IM4M -A -T rlgo
fi

# ============
# Boot device
# ============

sleep 2
_pwn
echo -e "[*]$bu 启动设备中 ...$ed"
"$dir"/irecovery -f boot-"$deviceid"/iBSS.img4
sleep 1
"$dir"/irecovery -f boot-"$deviceid"/iBSS.img4
sleep 2
"$dir"/irecovery -f boot-"$deviceid"/iBEC.img4
sleep 1
if [[ "$cpid" == *"0x80"* ]]; then
    "$dir"/irecovery -c "go"
    sleep 2
fi
"$dir"/irecovery -f boot-"$deviceid"/bootlogo.img4
sleep 1
"$dir"/irecovery -c "setpicture 0x1"
"$dir"/irecovery -f boot-"$deviceid"/devicetree.img4
sleep 1
"$dir"/irecovery -c "devicetree"
"$dir"/irecovery -f boot-"$deviceid"/trustcache.img4
sleep 1
"$dir"/irecovery -c "firmware"
sleep 1
"$dir"/irecovery -f boot-"$deviceid"/kernelcache.img4
sleep 2
"$dir"/irecovery -c "bootx"

if [ "$os" = 'Darwin' ]; then
    if [ ! "$1" = '--dfu' ]; then
        defaults write -g ignore-devices -bool false
        defaults write com.apple.AMPDevicesAgent dontAutomaticallySyncIPods -bool false
        killall Finder
    fi
fi

if [ $1 = '--tweaks' ] && [ ! -f ".tweaksinstalled" ]; then
    echo -e "[*]$bu 启用越狱插件支持，运行Pogo安装引导程序Bootstrap.然后运行Sileo$ed"
    echo -e "[!]$bu 请从Sileo软件管理器,安装OpenSSH、curl 和 wget（源地址是:mineek.github.io/repo),然后,按任意键继续$ed"
    read -n 1 -s
    echo -e "[*]$bu 想要正确使用越狱插件支持，请100%按照说明操作，否则可能会出现意外错误$ed"
    "$dir"/iproxy 2222 22 &
    if [ -f ~/.ssh/known_hosts ]; then
        rm ~/.ssh/known_hosts
    fi
    echo -e "[!]$bu 如果要求输入密码，请输入: alpine$ed"
    # ssh into device and copy over the preptweaks.sh script from the binaries folder
    scp -P2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET binaries/preptweaks.sh mobile@localhost:~/preptweaks.sh
    # run the preptweaks.sh script as root
    "$dir"/sshpass -p 'alpine' ssh -p2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET mobile@localhost "echo 'alpine' | sudo -S sh ~/preptweaks.sh"
    # now tell the user to install preferenceloader from bigboss repo and newterm2
    echo -e "[*]$bu 请从BigBoss源(apt.thebigboss.org/repofiles/cydia) 安装NewTerm 2 和 PreferenceLoader,然后,按任意键继续$ed"
    read -n 1 -s
    # now run sbreload
    "$dir"/sshpass -p alpine ssh -o StrictHostKeyChecking=no root@localhost -p 2222 "sbreload"
    echo -e "[*]$bu 现在已开启越狱插件Tweak支持,您现在可以自由使用Sileo软件管理器了.$ed"
    translate
    touch .tweaksinstalled
fi

if [ -f ".tweaksinstalled" ]; then
    # if known hosts file exists, delete it
    if [ -f ~/.ssh/known_hosts ]; then
        rm ~/.ssh/known_hosts
    fi

    # run postboot.sh script
    if [[ "$@" == *"--safe-mode"* ]]; then
        if [ -f binaries/postbootnosub.sh ]; then
            echo -e "[*]$bu 不使用 Substitute 运行postboot引导程序$ed"
            "$dir"/iproxy 2222 22 &
            scp -P2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET binaries/postboot.sh mobile@localhost:~/postbootnosub.sh
            "$dir"/sshpass -p 'alpine' ssh -p2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET mobile@localhost "echo 'alpine' | sudo -S sh ~/postbootnosub.sh"
        fi
    else
        if [ -f binaries/postboot.sh ]; then
            echo -e "[*]$bu 运行postboot引导程序,以启用越狱插件支持$ed"
            sleep 5
            "$dir"/iproxy 2222 22 &
            scp -P2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET binaries/postboot.sh mobile@localhost:~/postboot.sh
            "$dir"/sshpass -p 'alpine' ssh -p2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET mobile@localhost "echo 'alpine' | sudo -S sh ~/postboot.sh"
        fi
    fi

    # if known hosts file exists, delete it
    if [ -f ~/.ssh/known_hosts ]; then
        rm ~/.ssh/known_hosts
    fi

    _kill_if_running iproxy
fi

cd logs
for file in *.log; do
    mv "$file" SUCCESS_${file}
done
cd ..

rm -rf work rdwork
echo ""
echo -e "[*]$bu 完成!$ed"
echo -e "[*]$bu 设备现在应该启动了$ed"
echo -e "[*]$bu 如果您已经运行过palera1n，请单击Pogo工具部分中的 Do All 功能$ed"
echo -e "[*]$bu 如果没有,应该将 Pogo 安装到 Tips 中.$ed"
translate

} | tee logs/"$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
