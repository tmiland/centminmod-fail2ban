#!/usr/bin/env bash
######################################################
# written by George Liu (eva2000) centminmod.com
# https://github.com/centminmod/centminmod-fail2ban
######################################################
# Modified for Debian 10 with virtualmin by @tmiland
# variables
#############
VER=0.8
DT=$(date +"%d%m%y-%H%M%S")
# branch version https://github.com/fail2ban/fail2ban/branches/active
FAILBAN_VER='0.10.2'
GITHUB_REPO='tmiland/centminmod-fail2ban'
USERIP=$(last -i | grep "still logged in" | awk '{print $3}' | uniq)
SERVERIPS=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
IGNOREIP=$(echo "ignoreip = 127.0.0.1/8 ::1 $USERIP $SERVERIPS")
DIR_TMP='/svr-setup'
FAIL2BAN_DIR='/etc/fail2ban'
######################################################
# functions
#############
# Create tmp dir since we aren't using Centminmod
if [ ! -d "$DIR_TMP" ]; then
  mkdir -p $DIR_TMP
fi
# Debian only
# shopt -s nocasematch
# if [[ -f /etc/debian_version ]]; then
#   DISTRO=$(cat /etc/issue.net)
# fi
# if [[ ! $DISTRO == 'Debian*' ]]; then
#   echo -e "Error: Sorry, your OS is not supported."
#   exit 1;
# fi
# Check if Virtualmin is installed
if [[ ! -f /usr/sbin/virtualmin ]]; then
  echo -e "Error: Virtualmin is not installed."
  exit 1;
fi
# required otherwise f2b doesn't start
if [ ! -f /var/log/nginx/access.log ]; then
  touch /var/log/nginx/access.log
fi
# required otherwise f2b doesn't start
if [ ! -f /var/log/auth.log ]; then
  touch /var/log/auth.log
fi
# Check if f2b is installed, install if not
if ! dpkg -s fail2ban >/dev/null 2>&1; then
  apt install fail2ban 2> /dev/null
fi
# Check if f2b folder exists, back it up if it does
if [ -d /etc/fail2ban ]; then
  cp -rp /etc/fail2ban /etc/fail2ban.bak
fi
######################################################

status() {
  GETJAILS=$(fail2ban-client status | grep "Jail list" | sed -E 's/^[^:]+:[ \t]+//' | sed 's/,//g')
  for j in $GETJAILS; do
    echo "---------------------------------------"
    MAXRETRY=$(fail2ban-client get $j maxretry)
    FINDTIME=$(fail2ban-client get $j findtime)
    BANTIME=$(fail2ban-client get $j bantime)
    if [ -f "$FAIL2BAN_DIR/filter.d/$j.local" ]; then
      LASTMOD=$(date -d @$(stat -c %Y $FAIL2BAN_DIR/filter.d/$j.local))
    else
      LASTMOD=$(date -d @$(stat -c %Y $FAIL2BAN_DIR/filter.d/$j.conf))
    fi
    if [[ "$MAXRETRY" -eq '1' && "$FINDTIME" -eq '1' ]]; then
      ALLOWRATE=1
    else
      if [[ "$MAXRETRY" -eq '1' ]]; then
        ALLOWMAX=1
      else
        ALLOWMAX=$(($MAXRETRY-1))
      fi
      ALLOWRATE=$(((86400/$FINDTIME) * $ALLOWMAX))
    fi
    echo "$j parameters: "
    echo -n "maxretry: $MAXRETRY "
    echo -n "findtime: $FINDTIME "
    echo "bantime: $BANTIME"
    echo "allow rate: $ALLOWRATE hits/day"
    echo "filter last modified: $LASTMOD"
    fail2ban-client status $j
  done
  echo "---------------------------------------"
  echo "All Time: Top 10 Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "] Ban " /var/log/fail2ban.log{-*,*} | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "] Ban " /var/log/fail2ban.log | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "All Time: Top 10 Restored Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "Restore Ban " /var/log/fail2ban.log{-*,*} | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "Restore Ban " /var/log/fail2ban.log | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "Yesterday: Top 10 Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "] Ban " /var/log/fail2ban.log{-*,*} | grep `date -d "1 day ago" +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "] Ban " /var/log/fail2ban.log | grep `date -d "1 day ago" +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "Yesterday: Top 10 Restored Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "Restore Ban " /var/log/fail2ban.log{-*,*} | grep `date -d "1 day ago" +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "Restore Ban " /var/log/fail2ban.log | grep `date -d "1 day ago" +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "Today: Top 10 Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "] Ban " /var/log/fail2ban.log{-*,*} | grep `date +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "] Ban " /var/log/fail2ban.log | grep `date +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "Today: Top 10 Restored Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "Restore Ban " /var/log/fail2ban.log{-*,*} | grep `date +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "Restore Ban " /var/log/fail2ban.log | grep `date +%Y-%m-%d` | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "1 hr ago: Top 10 Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "] Ban " /var/log/fail2ban.log{-*,*} | grep "$(date -d "1 hour ago" '+%Y-%m-%d %H:')" | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "] Ban " /var/log/fail2ban.log | grep "$(date -d "1 hour ago" '+%Y-%m-%d %H:')" | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
  echo "1 hr ago: Top 10 Restored Banned IP Addresses:"
  if [[ "$(ls -lah /var/log | grep -q "fail2ban.log-$(date "+%Y")"; echo $?)" -eq '0' ]]; then
    zgrep -h "Restore Ban " /var/log/fail2ban.log{-*,*} | grep "$(date -d "1 hour ago" '+%Y-%m-%d %H:')" | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  else
    zgrep -h "Restore Ban " /var/log/fail2ban.log | grep "$(date -d "1 hour ago" '+%Y-%m-%d %H:')" | awk '{print $NF, $6}' | sort | uniq -c | sort -rn | tail -10
  fi
  echo "---------------------------------------"
}

pipinstall() {
  if [ ! -f /usr/bin/pip ]; then
    apt install -qq python2-pip
    PYTHONWARNINGS=ignore:::pip._internal.cli.base_command pip install --upgrade pip
  fi
}

install() {
  echo "---------------------------------------"
  echo "install fail2ban $FAILBAN_VER"
  echo "---------------------------------------"
  echo
  cd "$DIR_TMP"
  pipinstall
  PYTHONWARNINGS=ignore:::pip._internal.cli.base_command pip install pyinotify
  git clone -b ${FAILBAN_VER} https://github.com/fail2ban/fail2ban
  cd fail2ban
  git pull
  PYTHONWARNINGS=ignore:::pip._internal.cli.base_command python setup.py install

  \cp -f build/fail2ban.service /usr/lib/systemd/system/fail2ban.service
  \cp -f files/fail2ban-tmpfiles.conf /usr/lib/tmpfiles.d/fail2ban.conf
  \cp -f files/fail2ban-logrotate /etc/logrotate.d/fail2ban

  rm -rf $FAIL2BAN_DIR/action.d/cloudflare.conf
  wget -cnv -O $FAIL2BAN_DIR/action.d/cloudflare.conf https://github.com/$GITHUB_REPO/raw/master/action.d/cloudflare.conf
  chmod 0640 $FAIL2BAN_DIR/action.d/cloudflare.conf

  rm -rf $FAIL2BAN_DIR/action.d/csfdeny.conf
  wget -cnv -O $FAIL2BAN_DIR/action.d/csfdeny.conf https://github.com/$GITHUB_REPO/raw/master/action.d/csfdeny.conf

  rm -rf $FAIL2BAN_DIR/filter.d/http-xensec-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/http-xensec-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/http-xensec-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/http-xensec.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/http-xensec.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/http-xensec.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-auth-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-auth-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-auth-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-auth.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-auth.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-auth.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-common-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-common-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-common-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-common.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-common.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-common.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-401-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-401-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-401-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-401.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-401.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-401.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-403-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-403-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-403-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-403.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-403.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-403.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-404-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-404-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-404-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-404.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-404.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-404.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-badrequests-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-badrequests-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-badrequests-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-badrequests.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-badrequests.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-badrequests.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-botsearch-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-botsearch-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-botsearch-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-botsearch.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-botsearch.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-botsearch.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-conn-limit-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-conn-limit-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-conn-limit-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-conn-limit.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-conn-limit.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-conn-limit.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-get-f5-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-get-f5-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-get-f5-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-get-f5.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-get-f5.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-get-f5.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-req-limit-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-req-limit-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-req-limit-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-req-limit.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-req-limit.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-req-limit.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-req-limit-repeat.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-req-limit-repeat.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-req-limit-repeat.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-w00tw00t-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-w00tw00t-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-w00tw00t-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-w00tw00t.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-w00tw00t.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-w00tw00t.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-xmlrpc-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-xmlrpc-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-xmlrpc-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nginx-xmlrpc.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nginx-xmlrpc.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nginx-xmlrpc.conf
  rm -rf $FAIL2BAN_DIR/filter.d/nsd.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/nsd.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/nsd.conf
  rm -rf $FAIL2BAN_DIR/filter.d/pure-ftpd.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/pure-ftpd.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/pure-ftpd.conf
  rm -rf $FAIL2BAN_DIR/filter.d/vbulletin-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/vbulletin-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/vbulletin-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/vbulletin.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/vbulletin.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/vbulletin.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-auth-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-auth-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-auth-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-auth.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-auth.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-auth.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-comment-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-comment-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-comment-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-comment.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-comment.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-comment.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-pingback-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-pingback-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-pingback-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-pingback.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-pingback.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-pingback.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-pingback-repeat.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-pingback-repeat.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-pingback-repeat.conf
  rm -rf $FAIL2BAN_DIR/filter.d/phpmyadmin-cmm.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/phpmyadmin-cmm.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/phpmyadmin-cmm.conf
  rm -rf $FAIL2BAN_DIR/filter.d/phpmyadmin-other.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/phpmyadmin-other.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/phpmyadmin-other.conf
  rm -rf $FAIL2BAN_DIR/filter.d/joomla-auth-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/joomla-auth-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/joomla-auth-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/joomla-auth.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/joomla-auth.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/joomla-auth.conf
  rm -rf $FAIL2BAN_DIR/filter.d/magento-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/magento-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/magento-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/magento.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/magento.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/magento.conf
  rm -rf $FAIL2BAN_DIR/filter.d/wordpress-fail2ban-plugin.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/wordpress-fail2ban-plugin.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/wordpress-fail2ban-plugin.conf
  rm -rf $FAIL2BAN_DIR/filter.d/shells-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/shells-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/shells-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/shells.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/shells.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/shells.conf
  rm -rf $FAIL2BAN_DIR/filter.d/adminer-main.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/adminer-main.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/adminer-main.conf
  rm -rf $FAIL2BAN_DIR/filter.d/adminer.conf
  wget -cnv -O $FAIL2BAN_DIR/filter.d/adminer.conf https://github.com/$GITHUB_REPO/raw/master/filter.d/adminer.conf

  echo "[DEFAULT]" > $FAIL2BAN_DIR/jail.local
  echo "ignoreip = 127.0.0.1/8 ::1 $USERIP $SERVERIPS" >> /etc/fail2ban/jail.local
  wget -cnv -O $FAIL2BAN_DIR/jail.local.download https://github.com/$GITHUB_REPO/raw/master/jail.local
  sed -i '/\[DEFAULT\]/d' $FAIL2BAN_DIR/jail.local.download
  sed -i '/ignoreip/d' $FAIL2BAN_DIR/jail.local.download
  cat $FAIL2BAN_DIR/jail.local.download >> $FAIL2BAN_DIR/jail.local
  rm -rf $FAIL2BAN_DIR/jail.local.download

  if [ ! -f /var/log/fail2ban.log ]; then
    touch /var/log/fail2ban.log
  fi

  systemctl daemon-reload
  systemctl stop fail2ban
  systemctl start fail2ban
  systemctl enable fail2ban
  echo
  systemctl status fail2ban

  echo
  sleep 5
  fail2ban-client status
  echo
  echo "---------------------------------------"
  echo "fail2ban $FAILBAN_VER installed"
  echo "---------------------------------------"
  echo
}

case "$1" in
  install )
    install
    ;;
  status )
    status
    ;;
  * )
    echo "$0 {install|status}"
    ;;
esac
