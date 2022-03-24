#!/usr/bin/env bash
export LANG=en_US.UTF-8
echoContent() {
	case $1 in
	# 红色
	"red")
		# shellcheck disable=SC2154
		echo -e "\033[31m${printN}$2 \033[0m"
		;;
		# 天蓝色
	"skyBlue")
		echo -e "\033[1;36m${printN}$2 \033[0m"
		;;
		# 绿色
	"green")
		echo -e "\033[32m${printN}$2 \033[0m"
		;;
		# 白色
	"white")
		echo -e "\033[37m${printN}$2 \033[0m"
		;;
	"magenta")
		echo -e "\033[31m${printN}$2 \033[0m"
		;;
		# 黄色
	"yellow")
		echo -e "\033[33m${printN}$2 \033[0m"
		;;
	esac
}
updateDependents(){
    cp -f go.mod.latest ~/gobuild/xray-core/go.mod
    cd ~/gobuild/xray-core/
    go mod tidy
    echoContent green "更新依赖成功！"
}
updateRepository(){
    cd ~/gobuild/
    rm -rf xray-core
    git clone https://github.com/xtls/xray-core
    echoContent green "更新仓库成功！"
}
updateBinaries(){
    cp -f xray.linux /etc/v2ray-agent/xray/xray
    chmod +x /etc/v2ray-agent/xray/xray
    mv xray.* /usr/share/nginx/html/xray-core/
    echoContent green "更新二进制成功！"
}
buildBinaries(){
    GOARCH=arm64 GOOS=darwin go build -a -o xray.mac -trimpath -ldflags "-s -w -buildid=" ./main
    if [[ -f "xray.mac" ]]; then
        
        echoContent green "$(ls -lh xray.mac)  \n ----> mac编译完成!"
    else
        echoContent red "mac二进制编译失败!"
        exit 0
    fi
    GOARCH=amd64 GOOS=linux go build -a  -o xray.linux -trimpath -ldflags "-s -w -buildid=" ./main
    if [[ -f "xray.linux" ]]; then
        echoContent green "$(ls -lh xray.linux) \n ----> linux编译完成!"
    else
        echoContent red "linux二进制编译失败!"
        exit 0
    fi
    GOARCH=amd64 GOOS=windows go build -a  -o xray.exe -trimpath -ldflags "-s -w -buildid=" ./main
    if [[ -f "xray.exe" ]]; then
        echoContent green "$(ls -lh xray.exe) \n ----> windows编译完成!"
    else
        echoContent red "windows二进制编译失败!"
        exit 0
    fi
}
reloadcore() {
    handleXray stop
    handleXray start
}
handleXray() {
	if [[ -n $(find /bin /usr/bin -name "systemctl") ]] && [[ -n $(find /etc/systemd/system/ -name "xray.service") ]]; then
		if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
			systemctl start xray.service
		elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
			systemctl stop xray.service
		fi
	fi

	sleep 0.8

	if [[ "$1" == "start" ]]; then
		if [[ -n $(pgrep -f "xray/xray") ]]; then
			echoContent green " ---> Xray启动成功"
		else
			echoContent red "xray启动失败"
			echoContent red "请手动执行【/etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf】，查看错误日志"
			exit 0
		fi
	elif [[ "$1" == "stop" ]]; then
		if [[ -z $(pgrep -f "xray/xray") ]]; then
			echoContent green " ---> Xray关闭成功"
		else
			echoContent red "xray关闭失败"
			echoContent red "请手动执行【ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9】"
			exit 0
		fi
	fi
}

installCronUpdate(){
    crontab -l > ~/gobuild/xraybuild.cron
    echo "0 12 * * * /bin/bash ~/gobuild/update.sh >> ~/gobuild/buildlog.log 2>&1" >> ~/gobuild/xraybuild.cron
    crontab ~/gobuild/xraybuild.cron
    rm ~/gobuild/xraybuild.cron
    echoContent green "添加定时升级脚本成功!"
}

installScript(){
    mkdir ~/gobuild/
    if [[ -f ~/update.sh]]; then
        mv update.sh ~/gobuild/
    fi
}

main () {
    installScript
    updateRepository
    updateDependents
    buildBinaries
    updateBinaries
    reloadcore
    installCronUpdate
}

main
