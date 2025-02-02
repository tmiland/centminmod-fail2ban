# fail2ban for Debian 10 with Virtualmin

Forked from: [centminmod-fail2ban](https://github.com/centminmod/centminmod-fail2ban)

## fail2ban for centminmod.com LEMP stacks

[fail2ban](https://github.com/fail2ban/fail2ban) 0.10+ setup for [centminmod.com LEMP stacks](https://centminmod.com) with [CSF Firewall](https://centminmod.com/csf_firewall.html). CentOS EPEL Yum repo fail2ban version is using older fail2ban 0.9.6+, while below instructions are for fail2ban 0.10+ which now supports IPv6 addresses and improved performance. Suggestions, corrections and bug fixes are welcomed

**Info & Manuals**

* https://github.com/fail2ban/fail2ban
* https://github.com/fail2ban/fail2ban/wiki/Proper-fail2ban-configuration
* https://github.com/fail2ban/fail2ban/wiki/Troubleshooting
* [fail2ban 0.10 change log](https://github.com/fail2ban/fail2ban/blob/0.10/ChangeLog)

**Contents**

* [fail2ban installation for CentOS 7 Only](#fail2ban-installation-for-centos-7-only)
* [notes](#notes)
* [customising fail2ban](#customising-fail2ban)
* [examples](#examples) - [wordpress-auth filter action](#wordpress-auth-filter-action) & [nginx-req-limit filter action](#nginx-req-limit-filter-action)
* [fail2ban.sh](#fail2bansh)
* [Cloudflare v4 API](#cloudflare-v4-api)
* [troubleshooting fail2ban](#troubleshoot)

**fail2ban.sh status output**

![](/screenshots/fail2bansh/fail2bansh-status-02.png)

## manual fail2ban installation for CentOS 7 Only

    USERIP=$(last -i | grep "still logged in" | awk '{print $3}' | uniq)
    SERVERIPS=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
    IGNOREIP=$(echo "ignoreip = 127.0.0.1/8 ::1 $USERIP $SERVERIPS")
    cd /svr-setup/
    git clone -b 0.10 https://github.com/fail2ban/fail2ban
    cd fail2ban
    python setup.py install
    cp /svr-setup/fail2ban/files/fail2ban.service /usr/lib/systemd/system/fail2ban.service
    cp /svr-setup/fail2ban/files/fail2ban-tmpfiles.conf /usr/lib/tmpfiles.d/fail2ban.conf
    cp /svr-setup/fail2ban/files/fail2ban-logrotate /etc/logrotate.d/fail2ban
    echo "[DEFAULT]" > /etc/fail2ban/jail.local
    echo "ignoreip = 127.0.0.1/8 ::1 $USERIP $SERVERIPS" >> /etc/fail2ban/jail.local
    systemctl daemon-reload
    systemctl start fail2ban
    systemctl enable fail2ban
    systemctl status fail2ban

Then 

* populate your `/etc/fail2ban/jail.local` with the [jail.local](/jail.local) contents
* copy [action.d](/action.d) files to `/etc/fail2ban/action.d`
* copy [filter.d](/filter.d) files to `/etc/fail2ban/filter.d`
* restart fail2ban `systemctl restart fail2ban` or `fail2ban-client reload`

## automated fail2ban install via fail2ban.sh

    mkdir -p /root/tools
    cd /root/tools
    git clone https://github.com/centminmod/centminmod-fail2ban
    cd centminmod-fail2ban
    ./fail2ban.sh install

## notes

* currently this configuration is a work in progress, so not fully tested. Use at your own risk
* centmin mod buffers access log writes to Nginx in memory with directives `main_ext buffer=256k flush=60m` and custom log format called `main_ext`, so for fail2ban to work optimally, you would need to disable access log memory buffering and revert to nginx default log format by removing those three directives from your Nginx vhost config file's `access_log` line. So `access_log /home/nginx/domains/domain.com/log/access.log main_ext buffer=256k flush=60m;` becomes `access_log /home/nginx/domains/domain.com/log/access.log;` and restart Nginx
* if switching from CSF Firewall to Cloudflare API action from `action.d/cloudflare.conf`. Ensure Centmin Mod 123.09beta01 branch Nginx vhosts are setup with proper real IP detection and Cloudflare IP whitelisting. You can use [tools/csfcf.sh](https://community.centminmod.com/threads/csfcf-sh-automate-cloudflare-nginx-csf-firewall-setups.6241/) script to automate the Cloudflare Nginx configuration and Cloudflare IP whitelisting management outlined [here](https://community.centminmod.com/threads/csfcf-sh-automate-cloudflare-nginx-csf-firewall-setups.6241/). You can setup a cronjob to run the script in auto mode `/usr/local/src/centminmod/tools/csfcf.sh auto`.This ensures visitor's real IP address is passed on in your server logs which fail2ban reads.
* default `action.d/csfdeny.conf` ban option is to use `csf -d` to permanentaly block ip. Though temp block would be more appropriate:
* this fail2ban configuration can also work with my [bad bot blocking and rate limiting setup](https://community.centminmod.com/threads/blocking-bad-or-aggressive-bots.6433/). Particularly, for the rate limiting part as it would be detected by fail2ban configuration and/or if you are returning 444 status code for blocked bots.

```
-td, --tempdeny ip ttl [-p port] [-d direction] [comment]
       Add an IP to the temp IP ban list. ttl is how long to blocks for
       (default:seconds, can use one suffix of h/m/d).  Optional  port.
       Optional  direction  of  block  can  be one of: in, out or inout
       (default:in)
```

## customising fail2ban

If you need to modify the default created fail2ban filters located at `/etc/fail2ban/filter.d`, indead of editing the `/etc/fail2ban/filter.d/filtername.conf` you should create an override file at `/etc/fail2ban/filter.d/filtername.local` with the modified settings to override the defaults. This ensures your changes survive update changes to the `/etc/fail2ban/filter.d/filtername.conf`.

## examples

```
fail2ban-client status
Status
|- Number of jail:      16
`- Jail list:   nginx-auth, nginx-auth-main, nginx-botsearch, nginx-common, nginx-conn-limit, nginx-get-f5, nginx-req-limit, nginx-req-limit-main, nginx-req-limit-repeat, nginx-xmlrpc, vbulletin, wordpress-auth, wordpress-comment, wordpress-fail2ban-plugin, wordpress-pingback, wordpress-pingback-repeat
```

### wordpress-auth filter action

Lets test Wordpress failed login filter `wordpress-auth` with fail2ban and CSF Firewall. The default `jail.local` config for `wordpress-auth`

    [wordpress-auth]
    enabled = true
    filter = wordpress-auth
    action = csfdeny[name=wordpress-auth]
    #action   = cloudflare
    logpath = /home/nginx/domains/*/log/access.log
    port = http,https
    maxretry = 3
    findtime = 60

Launching a Siege run with POST request for dummy username and passwords.

```
siege -b -c1 -r5 "http://domain.com/wp-login.php POST user_login=admintest&user_pass=passtest" 
** SIEGE 4.0.2
** Preparing 1 concurrent users for battle.
The server is now under siege...
HTTP/1.1 200     0.53 secs:    7066 bytes ==> POST http://domain.com/wp-login.php
HTTP/1.1 200     0.71 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 200     0.50 secs:    7066 bytes ==> POST http://domain.com/wp-login.php
HTTP/1.1 200     0.73 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 200     0.50 secs:    7066 bytes ==> POST http://domain.com/wp-login.php
HTTP/1.1 200     0.72 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 200     0.50 secs:    7066 bytes ==> POST http://domain.com/wp-login.php
HTTP/1.1 200     1.16 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 200     0.27 secs:    7066 bytes ==> POST http://domain.com/wp-login.php
HTTP/1.1 200     0.73 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4

Transactions:                     10 hits
Availability:                 100.00 %
Elapsed time:                   6.35 secs
Data transferred:               0.51 MB
Response time:                  0.63 secs
Transaction rate:               1.57 trans/sec
Throughput:                     0.08 MB/sec
Concurrency:                    1.00
Successful transactions:          10
Failed transactions:               0
Longest transaction:            1.16
Shortest transaction:           0.27
```

check fail2ban log for `wordpress-auth` entries

```
tail -50 /var/log/fail2ban.log | grep wordpress-auth
2017-05-13 06:14:14,216 fail2ban.jail           [12969]: INFO    Jail 'wordpress-auth' started
2017-05-13 07:07:16,433 fail2ban.filter         [12969]: INFO    [wordpress-auth] Found 149.xxx.xxx.xxx - 2017-05-13 07:07:16
2017-05-13 07:08:06,916 fail2ban.filter         [12969]: INFO    [wordpress-auth] Found 149.xxx.xxx.xxx - 2017-05-13 07:08:06
2017-05-13 07:08:08,127 fail2ban.filter         [12969]: INFO    [wordpress-auth] Found 149.xxx.xxx.xxx - 2017-05-13 07:08:08
2017-05-13 07:08:08,459 fail2ban.actions        [12969]: NOTICE  [wordpress-auth] Ban 149.xxx.xxx.xxx
2017-05-13 07:08:09,365 fail2ban.filter         [12969]: INFO    [wordpress-auth] Found 149.xxx.xxx.xxx - 2017-05-13 07:08:09
2017-05-13 07:08:10,578 fail2ban.filter         [12969]: INFO    [wordpress-auth] Found 149.xxx.xxx.xxx - 2017-05-13 07:08:10
2017-05-13 07:08:12,005 fail2ban.filter         [12969]: INFO    [wordpress-auth] Found 149.xxx.xxx.xxx - 2017-05-13 07:08:11
2017-05-13 07:08:12,132 fail2ban.actions        [12969]: NOTICE  [wordpress-auth] 149.xxx.xxx.xxx already banned
```

check CSF Firewall grep the banned ip 149.xxx.xxx.xxx - notice the note for `Added by Fail2Ban for wordpress-auth`

```
csf -g 149.xxx.xxx.xxx                                         

Chain            num   pkts bytes target     prot opt in     out     source               destination         
No matches found for 149.xxx.xxx.xxx in iptables


IPSET: Set:chain_DENY Match:149.xxx.xxx.xxx Setting: File:/etc/csf/csf.deny

csf.deny: 149.xxx.xxx.xxx # Added by Fail2Ban for wordpress-auth - Sat May 13 07:08:08 2017
```

check the `wordpress-auth` jail status

```
fail2ban-client status wordpress-auth
Status for the jail: wordpress-auth
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     7
|  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
`- Actions
   |- Currently banned: 1
   |- Total banned:     1
   `- Banned IP list:   149.xxx.xxx.xxx
```

### nginx-req-limit filter action

`nginx-req-limit` filter action

testing Centmin Mod's `centmin.sh menu option 22` auto installed and configured Wordpress Nginx vhost which auto configures nginx level rate limiting on wp-login.php pages. Connection limit is disabled by default but can be enabled.

`/usr/local/nginx/conf/nginx.conf` level

    limit_req_zone $binary_remote_addr zone=xwplogin:16m rate=40r/m;
    #limit_conn_zone $binary_remote_addr zone=xwpconlimit:16m;

vhost level `/usr/local/nginx/conf/conf.d/domain.com.conf`

    location ~* /(wp-login\.php) {
        limit_req zone=xwplogin burst=1 nodelay;
        #limit_conn xwpconlimit 30;

use Siege benchmark tool (auto installed with Centmin Mod LEMP stacks) connection timed out entries are when CSF Firewall banned the IP via `csfdeny.conf` action profile:

```
siege -b -c3 -r10 http://domain.com/wp-login.php
** SIEGE 4.0.2
** Preparing 3 concurrent users for battle.
The server is now under siege...
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.57 secs:    7066 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.62 secs:    7066 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.94 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 200     0.93 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 503     0.61 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.45 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.49 secs:    7066 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.44 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.94 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 503     0.56 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.51 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.46 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.46 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.50 secs:    7066 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 200     0.91 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
HTTP/1.1 503     0.48 secs:    1665 bytes ==> GET  /wp-login.php
HTTP/1.1 503     0.48 secs:    1665 bytes ==> GET  /wp-login.php
[error] socket: -1555597568 connection timed out.: Connection timed out
[error] socket: -1538812160 connection timed out.: Connection timed out
[error] socket: -1538812160 connection timed out.: Connection timed out
[error] socket: -1555597568 connection timed out.: Connection timed out
[error] socket: -1555597568 connection timed out.: Connection timed out
[error] socket: -1538812160 connection timed out.: Connection timed out
[error] socket: -1555597568 connection timed out.: Connection timed out
[error] socket: -1538812160 connection timed out.: Connection timed out

Transactions:                      8 hits
Availability:                  23.53 %
Elapsed time:                  64.99 secs
Data transferred:               0.44 MB
Response time:                  1.82 secs
Transaction rate:               0.12 trans/sec
Throughput:                     0.01 MB/sec
Concurrency:                    0.22
Successful transactions:           8
Failed transactions:              26
Longest transaction:            0.94
Shortest transaction:           0.44
```

Centmin Mod Nginx error log entries at `/home/nginx/domains/domain.com/log/error.log`

    tail -3 error.log                                                  
    2017/05/12 06:32:07 [error] 30167#30167: *104 limiting requests, excess: 1.068 by zone "xwplogin", client: IPADDR, server: domain.com, request: "GET /wp-login.php HTTP/1.1", host: "domain.com"
    2017/05/12 06:32:07 [error] 30167#30167: *105 limiting requests, excess: 1.001 by zone "xwplogin", client: IPADDR, server: domain.com, request: "GET /wp-login.php HTTP/1.1", host: "domain.com"
    2017/05/12 06:32:07 [error] 30167#30167: *108 limiting requests, excess: 1.735 by zone "xwplogin", client: IPADDR, server: domain.com, request: "GET /wp-login.php HTTP/1.1", host: "domain.com"

CSF Firewall blocked IP note the `Added by Fail2Ban for nginx-req-limit` comment in csf.deny entry

    csf -g IPADDR                                                
    
    Chain            num   pkts bytes target     prot opt in     out     source               destination         
    No matches found for IPADDR in iptables
    
    
    IPSET: Set:chain_DENY Match:IPADDR Setting: File:/etc/csf/csf.deny
    
    csf.deny: IPADDR # Added by Fail2Ban for nginx-req-limit - Fri May 12 07:09:21 2017

nginx-req-limit filter status and regex test

```
fail2ban-client status nginx-req-limit                       
Status for the jail: nginx-req-limit
|- Filter
|  |- Currently failed: 1
|  |- Total failed:     21
|  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
`- Actions
   |- Currently banned: 1
   |- Total banned:     1
   `- Banned IP list:   IPADDR
```

```
fail2ban-regex error.log /etc/fail2ban/filter.d/nginx-req-limit.conf

Running tests
=============

Use   failregex filter file : nginx-req-limit, basedir: /etc/fail2ban
Use      datepattern : Default Detectors
Use         log file : error.log
Use         encoding : UTF-8


Results
=======

Failregex: 21 total
|-  #) [# of hits] regular expression
|   1) [21] ^\s*\[error\] \d+#\d+: \*\d+ limiting requests, excess: [\d\.]+ by zone "(?:[^"]+)", client: <HOST>,
`-

Ignoreregex: 0 total

Date template hits:
|- [# of hits] date format
|  [21] {^LN-BEG}ExYear(?P<_sep>[-/.])Month(?P=_sep)Day[T ]24hour:Minute:Second(?:[.,]Microseconds)?(?:\s*Zone offset)?
`-

Lines: 21 lines, 0 ignored, 21 matched, 0 missed
[processed in 0.01 sec]

```

Wordpress pingback filter in action

```
fail2ban-client status wordpress-pingback
Status for the jail: wordpress-pingback
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
`- Actions
   |- Currently banned: 1
   |- Total banned:     1
   `- Banned IP list:   104.237.xxx.xxx
```

filter search the fail2ban log for banned ip address = /var/log/fail2ban.log

```
grep '104.237.xxx.xxx' /var/log/fail2ban.log                       
2017-05-12 08:02:56,303 fail2ban.filter         [31920]: INFO    [wordpress-pingback] Found 104.237.xxx.xxx - 2017-05-12 08:02:56
2017-05-12 08:02:56,695 fail2ban.actions        [31920]: NOTICE  [wordpress-pingback] Ban 104.237.xxx.xxx
2017-05-12 11:50:39,167 fail2ban.actions        [31920]: NOTICE  [wordpress-pingback] Unban 104.237.xxx.xxx
2017-05-12 11:50:40,339 fail2ban.actions        [1528]: NOTICE  [wordpress-pingback] Restore Ban 104.237.xxx.xxx
2017-05-12 12:22:33,533 fail2ban.actions        [1528]: NOTICE  [wordpress-pingback] Unban 104.237.xxx.xxx
2017-05-12 12:22:34,613 fail2ban.actions        [1902]: NOTICE  [wordpress-pingback] Restore Ban 104.237.xxx.xxx
2017-05-12 12:23:19,039 fail2ban.actions        [1902]: NOTICE  [wordpress-pingback] Unban 104.237.xxx.xxx
2017-05-12 12:23:20,123 fail2ban.actions        [1991]: NOTICE  [wordpress-pingback] Restore Ban 104.237.xxx.xxx
2017-05-12 14:38:28,392 fail2ban.actions        [1991]: NOTICE  [wordpress-pingback] Unban 104.237.xxx.xxx
2017-05-12 14:38:29,482 fail2ban.actions        [3662]: NOTICE  [wordpress-pingback] Restore Ban 104.237.xxx.xxx
```

Unbanning the IP via fail2ban-client

    fail2ban-client unban IPADDR

## fail2ban.sh

fail2ban.sh is a script to automate fail2ban install for CentOS 7 based Centmin Mod LEMP stack based servers. The install routine also installs pyinotify as a fail2ban backend instead of the default polling backend for better performance when there's many log files. If you installed as per above instructions for automated install via `fail2ban.sh`, you would run `fail2ban.sh` from `/root/tools/fail2ban/fail2ban.sh`.

Usage options

    ./fail2ban.sh
    ./fail2ban.sh {install|status}

fail2ban.sh status output now includes each jail's parameters for maxretry, findtime, bantime as well as calculated per day hit rate allowed based on those parameters.

    ./fail2ban.sh status
    ---------------------------------------
    nginx-auth parameters: 
    maxretry: 3 findtime: 600 bantime: 3600
    allow rate: 288 hits/day
    Status for the jail: nginx-auth
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-auth-main parameters: 
    maxretry: 3 findtime: 600 bantime: 3600
    allow rate: 288 hits/day
    Status for the jail: nginx-auth-main
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /usr/local/nginx/logs/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-botsearch parameters: 
    maxretry: 2 findtime: 600 bantime: 600
    allow rate: 144 hits/day
    Status for the jail: nginx-botsearch
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-common parameters: 
    maxretry: 1 findtime: 600 bantime: 604800
    allow rate: 144 hits/day
    Status for the jail: nginx-common
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /var/log/nginx/localhost_ssl.access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-conn-limit parameters: 
    maxretry: 5 findtime: 600 bantime: 7200
    allow rate: 576 hits/day
    Status for the jail: nginx-conn-limit
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-get-f5 parameters: 
    maxretry: 15 findtime: 1 bantime: 600
    allow rate: 1209600 hits/day
    Status for the jail: nginx-get-f5
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-req-limit parameters: 
    maxretry: 5 findtime: 600 bantime: 7200
    allow rate: 576 hits/day
    Status for the jail: nginx-req-limit
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-req-limit-main parameters: 
    maxretry: 5 findtime: 600 bantime: 7200
    allow rate: 576 hits/day
    Status for the jail: nginx-req-limit-main
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /usr/local/nginx/logs/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-req-limit-repeat parameters: 
    maxretry: 5 findtime: 21600 bantime: 259200
    allow rate: 16 hits/day
    Status for the jail: nginx-req-limit-repeat
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /var/log/fail2ban.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    nginx-xmlrpc parameters: 
    maxretry: 6 findtime: 60 bantime: 600
    allow rate: 7200 hits/day
    Status for the jail: nginx-xmlrpc
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    vbulletin parameters: 
    maxretry: 3 findtime: 60 bantime: 28800
    allow rate: 2880 hits/day
    Status for the jail: vbulletin
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    wordpress-auth parameters: 
    maxretry: 3 findtime: 60 bantime: 600
    allow rate: 2880 hits/day
    Status for the jail: wordpress-auth
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    wordpress-comment parameters: 
    maxretry: 5 findtime: 60 bantime: 3600
    allow rate: 5760 hits/day
    Status for the jail: wordpress-comment
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    wordpress-fail2ban-plugin parameters: 
    maxretry: 1 findtime: 7200 bantime: 259200
    allow rate: 12 hits/day
    Status for the jail: wordpress-fail2ban-plugin
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /var/log/secure
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    wordpress-pingback parameters: 
    maxretry: 1 findtime: 1 bantime: 86400
    allow rate: 1 hits/day
    Status for the jail: wordpress-pingback
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     1
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 1
      |- Total banned:     1
      `- Banned IP list:   104.237.xxx.xxx
    ---------------------------------------
    wordpress-pingback-repeat parameters: 
    maxretry: 5 findtime: 21600 bantime: 259200
    allow rate: 16 hits/day
    Status for the jail: wordpress-pingback-repeat
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /var/log/fail2ban.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    All Time: Top 10 Banned IP Addresses:
          4 149.xxx.xxx.xxx [nginx-req-limit]
          3 104.237.xxx.xxx [wordpress-pingback]
          2 149.xxx.xxx.xxx [wordpress-auth]
          2 149.xxx.xxx.xxx [http-xensec]
    ---------------------------------------
    All Time: Top 10 Restored Banned IP Addresses:
         25 104.237.xxx.xxx [wordpress-pingback]
          2 149.xxx.xxx.xxx [nginx-req-limit]
    ---------------------------------------
    Yesterday: Top 10 Banned IP Addresses:
          4 149.xxx.xxx.xxx [nginx-req-limit]
          2 149.xxx.xxx.xxx [wordpress-auth]
          2 149.xxx.xxx.xxx [http-xensec]
          2 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------
    Yesterday: Top 10 Restored Banned IP Addresses:
         12 104.237.xxx.xxx [wordpress-pingback]
          2 149.xxx.xxx.xxx [nginx-req-limit]
    ---------------------------------------
    Today: Top 10 Banned IP Addresses:
    ---------------------------------------
    Today: Top 10 Restored Banned IP Addresses:
          8 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------
    1 hr ago: Top 10 Banned IP Addresses:
    ---------------------------------------
    1 hr ago: Top 10 Restored Banned IP Addresses:
    ---------------------------------------

## Cloudflare v4 API

Switching from local CSF Firewall action bans to Cloudflare v4 API based action bans for sites behind Cloudflare requires using the `action.d/cloudflare.conf` profile. Ensure Centmin Mod 123.09beta01 branch Nginx vhosts are setup with proper real IP detection and Cloudflare IP whitelisting. You can use [tools/csfcf.sh](https://community.centminmod.com/threads/csfcf-sh-automate-cloudflare-nginx-csf-firewall-setups.6241/) script to automate the Cloudflare Nginx configuration and Cloudflare IP whitelisting management outlined [here](https://community.centminmod.com/threads/csfcf-sh-automate-cloudflare-nginx-csf-firewall-setups.6241/). You can setup a cronjob to run the script in auto mode `/usr/local/src/centminmod/tools/csfcf.sh auto`.This ensures visitor's real IP address is passed on in your server logs which fail2ban reads.

**Cloudflare Firewall Rule Limits**

* Note, Cloudflare Firewall has Rule limits of 50,0000 IPs per CF Account as outlined [here](https://support.cloudflare.com/hc/en-us/articles/217074967). So you may need to drastically lower the failban jails' relative bantime durations if you intend to use Cloudflare Firewall with fail2ban.


**Cloudflare Firewall API Usage**

Below example is testing Nginx rate limiting with Centmin Mod 123.09beta01's auto installed Wordpress install ([centmin.sh menu option 22](https://centminmod.com/nginx-wordpress-installer.html)) which out of box uses Nginx level rate limiting for access to commonly targeted urls like `wp-login.php`

`/usr/local/nginx/conf/nginx.conf` level

    limit_req_zone $binary_remote_addr zone=xwplogin:16m rate=40r/m;
    #limit_conn_zone $binary_remote_addr zone=xwpconlimit:16m;

vhost level `/usr/local/nginx/conf/conf.d/domain.com.conf`

    location ~* /(wp-login\.php) {
        limit_req zone=xwplogin burst=1 nodelay;
        #limit_conn xwpconlimit 30;

I edited `/etc/fail2ban/jail.local` jail for `nginx-req-limit` and commented out the default `csfdeny` action and uncommented the `cloudflare` action and restarted fail2ban service.

    [nginx-req-limit]
    enabled = true
    filter = nginx-req-limit
    #action = csfdeny[name=nginx-req-limit]
    action   = cloudflare
    logpath = /home/nginx/domains/*/log/error.log
    findtime = 600
    bantime = 7200
    maxretry = 5

Then edited `action.d/cloudflare.conf` and filled in `cfuser` and `cftoken` variables with Cloudflare account email and API Key which you can find in your [My Account](https://www.cloudflare.com/a/profile) area. Restart fail2ban service for good measure.

    [Init]
    # Option: cfuser
    # Notes.: Replaces <cfuser> in actionban and actionunban with cfuser value below
    # Values: Your CloudFlare user account
    
    cfuser = put-your-cloudflare-email-here
    
    # Option: cftoken
    # Notes.: Replaces <cftoken> in actionban and actionunban with cftoken value below
    # Values: Your CloudFlare API key can be found here https://www.cloudflare.com/a/profile
    cftoken = put-your-API-key-here

Ran Siege load testing again from separate server against `wp-login.php` to trigger a fail2ban action to Cloudflare's v4 API

    siege -b -c3 -r10 http://domain.com/wp-login.php
    ** SIEGE 4.0.2
    ** Preparing 3 concurrent users for battle.
    The server is now under siege...
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.58 secs:    7067 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.66 secs:    7066 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.94 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
    HTTP/1.1 200     0.93 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
    HTTP/1.1 503     0.65 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.46 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.53 secs:    7066 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.93 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
    HTTP/1.1 503     0.60 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.52 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.45 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.45 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.48 secs:    7066 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.94 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
    HTTP/1.1 503     0.93 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.48 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.46 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.51 secs:    7066 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.45 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.45 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.94 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
    HTTP/1.1 503     0.54 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.53 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 503     0.47 secs:    1665 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.51 secs:    7066 bytes ==> GET  /wp-login.php
    HTTP/1.1 200     0.94 secs:  100250 bytes ==> GET  /wp-admin/load-styles.php?c=0&dir=ltr&load%5B%5D=dashicons,buttons,forms,l10n,login&ver=4.7.4
    
    Transactions:                     12 hits
    Availability:                  33.33 %
    Elapsed time:                   7.82 secs
    Data transferred:               0.65 MB
    Response time:                  1.75 secs
    Transaction rate:               1.53 trans/sec
    Throughput:                     0.08 MB/sec
    Concurrency:                    2.69
    Successful transactions:          12
    Failed transactions:              24
    Longest transaction:            0.94
    Shortest transaction:           0.45

Checking fail2ban log for `149.xxx.xxx.xxx`

    grep '149.xxx.xxx.xxx' /var/log/fail2ban.log | grep ' Ban '
    2017-05-13 03:59:42,227 fail2ban.actions        [11201]: NOTICE  [nginx-req-limit] Ban 149.xxx.xxx.xxx
    2017-05-13 04:02:04,713 fail2ban.actions        [11393]: NOTICE  [nginx-req-limit] Ban 149.xxx.xxx.xxx
    2017-05-13 04:03:46,051 fail2ban.actions        [11524]: NOTICE  [nginx-req-limit] Restore Ban 149.xxx.xxx.xxx
    2017-05-13 04:05:30,268 fail2ban.actions        [11665]: NOTICE  [nginx-req-limit] Restore Ban 149.xxx.xxx.xxx
    2017-05-13 05:14:03,388 fail2ban.actions        [11665]: NOTICE  [nginx-req-limit] Ban 149.xxx.xxx.xxx

Checking the `nginx-req-limit` filter status and regex

filter status

    fail2ban-client status nginx-req-limit                                                                             
    Status for the jail: nginx-req-limit
    |- Filter
    |  |- Currently failed: 1
    |  |- Total failed:     24
    |  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
    `- Actions
      |- Currently banned: 1
      |- Total banned:     1
      `- Banned IP list:   IPADDR

regex

    fail2ban-regex /home/nginx/domains/domain.com/log/error.log /etc/fail2ban/filter.d/nginx-req-limit.conf
    
    Running tests
    =============
    
    Use   failregex filter file : nginx-req-limit, basedir: /etc/fail2ban
    Use      datepattern : Default Detectors
    Use         log file : /home/nginx/domains/domain.com/log/error.log
    Use         encoding : UTF-8
    
    
    Results
    =======
    
    Failregex: 92 total
    |-  #) [# of hits] regular expression
    |   1) [92] ^\s*\[error\] \d+#\d+: \*\d+ limiting requests, excess: [\d\.]+ by zone "(?:[^"]+)", client: <HOST>,
    `-
    
    Ignoreregex: 0 total
    
    Date template hits:
    |- [# of hits] date format
    |  [92] {^LN-BEG}ExYear(?P<_sep>[-/.])Month(?P=_sep)Day[T ]24hour:Minute:Second(?:[.,]Microseconds)?(?:\s*Zone offset)?
    `-
    
    Lines: 92 lines, 0 ignored, 92 matched, 0 missed
    [processed in 0.02 sec]

Checking Cloudflare's Firewall Access Rules for fail2ban inserted IP address starting with 149.xxx.xxx.xxx which is remote server I launced the Siege load test from

![](/screenshots/cloudflare-api/cloudflare-firewall-access-rules-01.png)

Test curl access from blocked server for `wp-login.php` url link gives 403 forbidden meaning access is blocked at Cloudflare Firewall level

    curl -I http://domain.com/wp-login.php 
    HTTP/1.1 403 Forbidden
    Date: Sat, 13 May 2017 05:22:01 GMT
    Content-Type: text/html; charset=UTF-8
    Connection: keep-alive
    Set-Cookie: __cfduid=d34a309e3527a91971491fc853424dbca1494652921; expires=Sun, 13-May-18 05:22:01 GMT; path=/; domain=.domain.com; HttpOnly
    Cache-Control: max-age=15
    Expires: Sat, 13 May 2017 05:22:16 GMT
    X-Frame-Options: SAMEORIGIN
    Server: cloudflare-nginx
    CF-RAY: 35e32d7813e63f95-YUL

Unbanning the ip from Cloudflare's Firewall Access Rules is same as before

    fail2ban-client unban 149.xxx.xxx.xxx

fail2ban.sh status after latest test

    ./fail2ban.sh status
    ---------------------------------------
    Status for the jail: http-xensec
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     21
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 1
      |- Total banned:     2
      `- Banned IP list:   149.xxx.xxx.xxx
    ---------------------------------------
    Status for the jail: nginx-auth
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /var/log/nginx/localhost.error.log /var/log/nginx/localhost_ssl.error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-auth-main
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /usr/local/nginx/logs/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-botsearch
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-conn-limit
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-get-f5
    |- Filter
    |  |- Currently failed: 1
    |  |- Total failed:     42
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-req-limit
    |- Filter
    |  |- Currently failed: 1
    |  |- Total failed:     31
    |  `- File list:        /home/nginx/domains/domain.com/log/error.log /home/nginx/domains/demodomain.com/log/error.log
    `- Actions
      |- Currently banned: 1
      |- Total banned:     1
      `- Banned IP list:   149.xxx.xxx.xxx
    ---------------------------------------
    Status for the jail: nginx-req-limit-main
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /usr/local/nginx/logs/error.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-req-limit-repeat
    |- Filter
    |  |- Currently failed: 1
    |  |- Total failed:     1
    |  `- File list:        /var/log/fail2ban.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: nginx-xmlrpc
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: vbulletin
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: wordpress-auth
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     5
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 1
      |- Total banned:     1
      `- Banned IP list:   149.xxx.xxx.xxx
    ---------------------------------------
    Status for the jail: wordpress-comment
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: wordpress-pingback
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /home/nginx/domains/demodomain.com/log/access.log /home/nginx/domains/domain.com/log/access.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     1
      `- Banned IP list:
    ---------------------------------------
    Status for the jail: wordpress-pingback-repeat
    |- Filter
    |  |- Currently failed: 0
    |  |- Total failed:     0
    |  `- File list:        /var/log/fail2ban.log
    `- Actions
      |- Currently banned: 0
      |- Total banned:     0
      `- Banned IP list:
    ---------------------------------------
    All Time: Top 10 Banned IP Addresses:
          4 149.xxx.xxx.xxx [nginx-req-limit]
          2 149.xxx.xxx.xxx [wordpress-auth]
          2 149.xxx.xxx.xxx [http-xensec]
          2 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------
    All Time: Top 10 Restored Banned IP Addresses:
         16 104.237.xxx.xxx [wordpress-pingback]
          2 149.xxx.xxx.xxx [nginx-req-limit]
    ---------------------------------------
    Yesterday: Top 10 Banned IP Addresses:
          1 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------
    Yesterday: Top 10 Restored Banned IP Addresses:
          5 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------
    Today: Top 10 Banned IP Addresses:
          4 149.xxx.xxx.xxx [nginx-req-limit]
          2 149.xxx.xxx.xxx [wordpress-auth]
          2 149.xxx.xxx.xxx [http-xensec]
          1 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------
    Today: Top 10 Restored Banned IP Addresses:
         11 104.237.xxx.xxx [wordpress-pingback]
          2 149.xxx.xxx.xxx [nginx-req-limit]
    ---------------------------------------
    1 hr ago: Top 10 Banned IP Addresses:
          1 149.xxx.xxx.xxx [http-xensec]
    ---------------------------------------
    1 hr ago: Top 10 Restored Banned IP Addresses:
          5 104.237.xxx.xxx [wordpress-pingback]
    ---------------------------------------

The `fail2ban.sh status` command lists each fail2ban jail's status as well as the top 10 IP address occurences in banned IPs or restored banned IPs for All Time, Yesterday, Today and the past 1hr.

## troubleshoot

For some simple troubleshooting steps for fail2ban jail testing, you can do the following:

`1.` Enable debug logging instead of default info log level

    fail2ban-client get loglevel
    fail2ban-client set loglevel debug

`2.` Then do test attacks against your fail2ban server for the jail config you want to test

`3.` Then search the /var/log/fail2ban.log log and grep filter on the IP address of attacking server for clues escaping dots . with backslashes

    grep '149\.xxx\.xxx\.xxx' /var/log/fail2ban.log

example output

    2017-08-21 15:02:10,728 fail2ban.filter         [2351]: INFO    [nginx-req-limit] Found 149.xxx.xxx.xxx - 2017-08-21 15:02:10
    2017-08-21 15:02:10,728 fail2ban.failmanager    [2351]: DEBUG   Total # of detected failures: 5. Current failures from 1 IPs (IP:count): 149.xxx.xxx.xxx:5
    2017-08-21 15:02:11,264 fail2ban.actions        [2351]: NOTICE  [nginx-req-limit] Ban 149.xxx.xxx.xxx
    2017-08-21 15:02:11,264 fail2ban.action         [2351]: DEBUG   csf -d 149.xxx.xxx.xxx Added by Fail2Ban for nginx-req-limit
    2017-08-21 15:02:11,269 fail2ban.filter         [2351]: DEBUG   Processing line with time:1503327731.0 and ip:149.xxx.xxx.xxx
    2017-08-21 15:02:11,269 fail2ban.filter         [2351]: INFO    [nginx-req-limit-repeat] Found 149.xxx.xxx.xxx - 2017-08-21 15:02:11
    2017-08-21 15:02:11,272 fail2ban.failmanager    [2351]: DEBUG   Total # of detected failures: 1. Current failures from 1 IPs (IP:count): 149.xxx.xxx.xxx:1
    2017-08-21 15:02:12,249 fail2ban.utils          [2351]: DEBUG   25fee10 -- stdout: 'deny failed: 149.xxx.xxx.xxx is in the allow file /etc/csf/csf.allow'

Then set log level back to info

    fail2ban-client get loglevel
    fail2ban-client set loglevel info
