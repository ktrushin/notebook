# Network tools

## Show sockets
```shell
$ sudo ss -lpt
$ sudo ss -lpu
$ sudo ss -lp
$ sudo ss -lptn 'sport = :80'
$ sudo ss -nat4 | grep '10\.1\.0\.10' | grep CLOSE-WAIT | \
  python3 -c "from fileinput import input
for line in input():
    print(line.split()[4])
" | sort | uniq -c | sort -rh | head
```

## Tcpdump
```shell
$ sudo tcpdump -A -s 0 -i eth0 -w my_host.my_domain.pcap \
    'host my_host.my_domain.com and tcp port 443'
$ sudo tcpdump -A -s 0 -i lo -w test.pcap 'host 127.0.0.1 and tcp'
$ sudo tcpdump -A -s0 -i any -w test.pcap 'tcp and (port 80 or port 443)'
$ sudo tcpdump -A -s 0 -i lo -w ~/jira/psmdb-1241/lo.pcap \
    '(host 127.0.0.1 or 127.0.0.2) and tcp'
```

## DNS queries
```shell
$ dig @8.8.8.8 -p 53 debian.org
$ nslookup -port=53 debian.org 8.8.8.8
$ named -f -c named.conf
$ sudo tcpdump -A -s0 -i lo host 127.0.0.1 -w ns_lookup.pcap
$ dig @127.0.0.1 -p 8853 +bufsize=2048 foo.movie.edu
```

## QNAP NFS
```shell
$ tail /etc/auto.master
+auto.master

/depot/qnap /etc/auto.qnap --timeout=60

$ cat /etc/auto.qnap
disk1 -rw 192.168.1.113:/disk1
```

## curl
Upgrade to websocket
```shell
$ curl -vk -H 'Connection: Upgrade' -H 'Upgrade: websocket'  \
  -H 'Sec-WebSocket-Key: q4xkcO32u266gldTuKaSOw==' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'X-Upgrade: websocket' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'Referer: www.example.com' \
  'https://example.com:8443'
```

Gather timing stats:
```shell
$ cat curl-format.txt
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
   time_pretransfer:  %{time_pretransfer}\n
      time_redirect:  %{time_redirect}\n
 time_starttransfer:  %{time_starttransfer}\n
                    ----------\n
         time_total:  %{time_total}\n

$ for i in `seq 1 150`; do curl -w "@curl-format.txt" -o /dev/null -s "https://example.com"; done
    time_namelookup:  0,003343
       time_connect:  0,009590
    time_appconnect:  0,044986
   time_pretransfer:  0,045019
      time_redirect:  0,000000
 time_starttransfer:  0,055655
                    ----------
         time_total:  0,166693
    time_namelookup:  0,003534
       time_connect:  0,006849
    time_appconnect:  0,039217
   time_pretransfer:  0,039251
      time_redirect:  0,000000
 time_starttransfer:  0,047996
                    ----------
         time_total:  0,161126
```


## Decode secure traffic in Wireshark
Start capturing traffic as usual:
```shell
$ sudo /usr/sbin/tcpdump -A -s 0 -i eth0 host my_host.my_domain.com and \
  tcp port 443 -w my_host_my_domain.pcap
```

Log pre master secrets:
```shell
$ rm /tmp/sslkey.log; SSLKEYLOGFILE=/tmp/sslkey.log firefox https://example.com &
```
or
```shell
$ rm /tmp/sslkey.log; SSLKEYLOGFILE=/tmp/sslkey.log curl -v https://example.com &
```

When requests have been handled, stop `tcpdump` with `Ctrl+c` and
open `my_host_my_domain.pcap` in Wireshark.
Right-click on a packet whose `Info` field equals to `Application Data`,
choose `Protocol Preferences`->`(Pre)-Master-Secret log Filename`.
In the opened dialog window, browse to `/tmp/sslkey.log` in the
`(Pre)-Master-Secret log filename` field. The field is placed at the very
bottom of the window.
