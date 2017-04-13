#!/bin/bash

/usr/sbin/rhn-satellite stop
/usr/bin/yum -y upgrade

# Re-assert config file size increase after upgrade
sed -i.`date +%Y%m%d%H%M%S` 's/^web.maximum_config_file_size.*/web.maximum_config_file_size = 1048576/' /usr/share/rhn/config-defaults/rhn_web.conf
sed -i.`date +%Y%m%d%H%M%S` 's/^maximum_config_file_size.*/maximum_config_file_size = 1048576/' /usr/share/rhn/config-defaults/rhn_server.conf

/sbin/reboot
