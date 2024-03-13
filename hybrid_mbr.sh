#!/bin/bash
# 安装gdisk，用于操作GPT
apt-get install -y gdisk
# 假设/dev/vda是目标磁盘
# 转换GPT为Hybrid MBR
sgdisk -h 1:2:3 /dev/vda
# 更新系统以识别新分区表
partprobe /dev/vda