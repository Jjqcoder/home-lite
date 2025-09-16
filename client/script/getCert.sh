#!/bin/bash

# 本脚本用于在 CentOS 上申请 Let's Encrypt 证书
# 注意：请先确保 80 端口已开放，且防火墙已放行 80/443 端口

# 配置变量
DOMAIN="www.wbeishangw.top"
EMAIL="1810422805@qq.com"
WEB_ROOT="/var/www/html"  # Web 根目录（如果使用 --webroot 模式）

# 日志文件
LOG_FILE="/var/log/get-cert.log"
echo "[$(date)] 开始执行证书申请脚本" > $LOG_FILE

# 函数：错误处理
handle_error() {
    echo "[$(date)] 错误：$1" | tee -a $LOG_FILE
    exit 1
}

# 检查网络连接
echo "[0/5] 检查网络连接..." | tee -a $LOG_FILE
ping -c 3 www.baidu.com > /dev/null 2>&1
if [ $? -ne 0 ]; then
    handle_error "无法连接到互联网，请检查网络设置！"
fi
echo "[0/5] 网络连接正常" | tee -a $LOG_FILE

# 替换 CentOS 7 镜像源为阿里云镜像源
echo "[1/5] 替换 CentOS 7 镜像源为阿里云镜像源..." | tee -a $LOG_FILE
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup 2>/dev/null
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
if [ $? -ne 0 ]; then
    handle_error "下载阿里云镜像源配置失败！"
fi

# 修改镜像源配置
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/#baseurl=http:\/\/mirror.centos.org\/centos\//baseurl=https:\/\/mirrors.aliyun.com\/centos\//g' /etc/yum.repos.d/CentOS-Base.repo

# 替换 EPEL 镜像源为阿里云镜像源
mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup 2>/dev/null
mv /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.backup 2>/dev/null
curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo
if [ $? -ne 0 ]; then
    handle_error "下载阿里云 EPEL 镜像源配置失败！"
fi

# 禁用 CentOS SCLo 仓库（已停止维护）
echo "[2/5] 禁用 CentOS SCLo 仓库..." | tee -a $LOG_FILE
if [ -f /etc/yum.repos.d/CentOS-SCLo-scl.repo ]; then
    sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/CentOS-SCLo-scl.repo
fi
if [ -f /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo ]; then
    sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
fi

# 清理并生成缓存
echo "[3/5] 清理并生成 yum 缓存..." | tee -a $LOG_FILE
yum clean all > /dev/null 2>&1
yum makecache > /dev/null 2>&1
if [ $? -ne 0 ]; then
    handle_error "生成 yum 缓存失败！"
fi

# 安装必要的依赖
echo "[4/5] 安装 Certbot..." | tee -a $LOG_FILE
yum install -y certbot python2-certbot-nginx > /dev/null 2>&1
if [ $? -ne 0 ]; then
    # 尝试使用 snap 安装
    echo "常规方式安装失败，尝试使用 snap 安装..." | tee -a $LOG_FILE
    yum install -y snapd > /dev/null 2>&1
    systemctl enable --now snapd.socket > /dev/null 2>&1
    ln -s /var/lib/snapd/snap /snap 2>/dev/null
    snap install core > /dev/null 2>&1
    snap refresh core > /dev/null 2>&1
    snap install --classic certbot > /dev/null 2>&1
    ln -s /snap/bin/certbot /usr/bin/certbot 2>/dev/null
    
    # 检查 Certbot 是否安装成功
    if ! command -v certbot &> /dev/null; then
        handle_error "Certbot 安装失败！"
    fi
fi
echo "[4/5] Certbot 安装成功！" | tee -a $LOG_FILE

# 申请证书（使用 standalone 模式，自动绑定 80/443 端口）
echo "[5/5] 申请 Let's Encrypt 证书..." | tee -a $LOG_FILE
certbot certonly --standalone \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --preferred-challenges http \
    --debug-challenges

# 检查是否成功
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "[5/5] 证书申请成功！" | tee -a $LOG_FILE
    echo "证书文件: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    echo "私钥文件: /etc/letsencrypt/live/$DOMAIN/privkey.pem"
else
    echo "证书申请失败，请检查日志：$LOG_FILE" | tee -a $LOG_FILE
    exit 1
fi