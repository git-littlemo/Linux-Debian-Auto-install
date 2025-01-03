#!/bin/bash

# 检测分区表类型
partition_table_type=$(fdisk -l $boot_device 2>/dev/null | grep 'Disklabel type' | awk '{print $3}')

if [ "$partition_table_type" = "gpt" ]; then
  # 对于GPT分区表的处理
  if [ $boot_partition_number -eq 0 ]; then
    partition="hd$boot_disk_number"
  else
    partition="hd$boot_disk_number,gpt$boot_partition_number"
  fi
  
  # 判断是否是UEFI引导
  if [ -d "/sys/firmware/efi/efivars" ]; then
    read -r -d '' partman <<'EOF'
# d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-partitioning/choose_label select gpt
d-i partman-partitioning/default_label string gpt
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select boot-root
d-i partman-auto/expert_recipe string                         \
      boot-root ::                                            \
              512 512 1024 free                               \
                      $iflabel{ gpt }                         \
                      $reusemethod{ }                         \
                      method{ efi }                           \
                      format{ }                               \
              .                                               \
              512 512 1024 ext4                               \
                      $primary{ } $bootable{ }                \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ /boot }                     \
              .                                               \
              1000 10000 1000000000 ext4                      \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ / }                         \
              .                                               \
              512 1024 200% linux-swap                        \
                      method{ swap } format{ }                \
              .
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
EOF

  else
    read -r -d '' partman <<'EOF'
d-i partman-auto/method string regular
d-i partman-partitioning/choose_label select gpt
d-i partman-partitioning/default_label string gpt
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select boot-root
d-i partman-auto/expert_recipe string                         \
      boot-root ::                                            \
              1 1 1 free                                      \
                      method{ bios_grub }                    \
              .                                               \
              512 512 1024 ext4                               \
                      $primary{ } $bootable{ }                \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ /boot }                     \
              .                                               \
              1000 10000 1000000000 ext4                      \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ / }                         \
              .                                               \
              512 1024 200% linux-swap                        \
                      method{ swap } format{ }                \
              .
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
EOF
  fi
  
else
  # 对于MBR分区表的原有处理
  if [ $boot_partition_number -eq 0 ]; then
    partition="hd$boot_disk_number"
  else
    partition="hd$boot_disk_number,msdos$boot_partition_number"
  fi
  
  read -r -d '' partman <<'EOF'
# d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select boot-root
d-i partman-auto/expert_recipe string                         \
      boot-root ::                                            \
              512 512 1024 ext4                               \
                      $primary{ } $bootable{ }                \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ /boot }                     \
              .                                               \
              1000 10000 1000000000 ext4                      \
                      $primary{ }                             \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ / }                         \
              .                                               \
              512 1024 200% linux-swap                        \
                      $primary{ }                             \
                      method{ swap } format{ }                \
              .
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
EOF

fi

preseed="""
# 预配置文件
# 低内存模式
d-i lowmem/low boolean true
d-i lowmem/insufficient boolean true
# 语言和地区
d-i debian-installer/locale string en_US.UTF-8
d-i debian-installer/country string US
d-i debian-installer/language string en
d-i keyboard-configuration/xkb-keymap select us
# 网络设置
d-i netcfg/choose_interface select ${interface}
d-i netcfg/get_hostname string debian
d-i netcfg/get_nameservers string 8.8.8.8
# 设置镜像源
d-i mirror/country string manual
d-i mirror/http/hostname string ${mirror_domain}
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
# 设置时区
d-i clock-setup/utc boolean true
d-i time/zone string Asia/Hong_Kong
# 分区设置
${partman}
# 设置root用户密码
d-i passwd/root-login boolean true
d-i passwd/root-password-crypted password ${root_pass}
d-i passwd/make-user boolean false
# 配置apt和软件选择
tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server build-essential
d-i apt-setup/non-free boolean true
d-i apt-setup/contrib boolean true
d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/cdrom/set-next boolean false   
d-i apt-setup/cdrom/set-failed boolean false

popularity-contest popularity-contest/participate boolean false

# 安装GRUB引导加载程序
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

# 安装完成后执行命令
d-i preseed/late_command string \
  in-target sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config ; \
  in-target systemctl restart ssh.service

# 重启通知
d-i finish-install/reboot_in_progress note

"""
