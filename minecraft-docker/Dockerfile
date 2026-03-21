# 使用较易获取的Debian镜像作为起点
FROM debian:bookworm-slim

# 配置国内软件源并安装OpenJDK 21
# 关键修改：先创建或确保源列表文件存在
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openjdk-21-jre-headless && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# 验证安装
RUN java -version