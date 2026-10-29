# base-income-and-uptime.example.rsc
# Required companions to hotspot-login-logic.example.rsc, also from the official
# release: the 'todayincome' / 'monthlyincome' running-total scripts that the on-login
# sales block writes to (without these, that block fails silently via its own
# on-error handler and nothing breaks, but no totals are kept), their scheduled
# resets, and the two schedulers that make a voucher's remaining time survive a
# router reboot.
#
# Fix applied vs. the official file: the 'uptime restore' scheduler used
# "hsolduptime" without its "$" sigil, so RouterOS would read it as literal text
# instead of the stored variable. Confirmed present in JuanFi's own release-4.4, not
# something introduced here. The '$' is added back in below. Not confirmed on real
# hardware -- verify by rebooting the router mid-voucher and checking
# /ip hotspot user get <voucher> limit-uptime before and after.
#
# Import this AFTER hotspot-login-logic.example.rsc.

/system scheduler
/system scheduler
add interval=5s name="uptime backup" on-event=":local hsactiveuptime;\r\
    \n:local hsuser;\r\
    \n:local hslimit;\r\
    \n\r\
    \n:if ([/ip hotspot active print count-only] > 0) do={\r\
    \n:foreach i in=[/ip hotspot active find] do={\r\
    \n:set hsactiveuptime [/ip hotspot active get \$i uptime];\r\
    \n:set hsuser [/ip hotspot active get \$i user];\r\
    \n:set hslimit [/ip hotspot user get \$hsuser limit-uptime];\r\
    \n/system scheduler set [find where name=\$hsuser] comment=\"temp \$hsacti\
    veuptime\";\r\
    \n\t\t}\r\
    \n\t}\r\
    \n" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
add name="uptime restore" on-event=":local ucom;\r\
    \n:local hsolduptime;\r\
    \n:local hsnewuptime;\r\
    \n:local hsactiveuptime;\r\
    \n:local hsuser;\r\
    \n:local temp; \r\
    \n:foreach ie in=[/sys sch find] do={\r\
    \n :set \$ucom [/sys sch get \$ie comment]; \r\
    \n:if (\$ucom != \"\") do={ \r\
    \n:set \$temp [:pick \$ucom 0 4];\r\
    \n:if (\$temp = \"temp\") do={\r\
    \n   :set \$hsuser [/sys sch get \$ie name]; \r\
    \n:if ([/ip hotspot user find name=\$hsuser]) do={\r\
    \n:set \$hsolduptime [/ip hotspot user get [find where name=\$hsuser] limi\
    t-uptime];\r\
    \n:set \$hsactiveuptime [:pick \$ucom 5 ([:len \$ucom] + 1)]; \r\
    \n:set \$hsnewuptime (\$hsolduptime - \$hsactiveuptime);\r\
    \n/ip hotspot user set [find where name=\$hsuser] limit-uptime=\$hsnewupti\
    me;\r\
    \n/sys sch set [find where name=\$hsuser] comment=\"\";} else={ /sys sch r\
    emove \$ie;}\r\
    \n}}}" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup

/system scheduler add interval=1d name="Reset Daily Income" on-event="/system script set source=\"0\" todayincome " policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=Sep/28/2021 start-time=00:00:00;
/system scheduler add interval=30d name="Reset Monthly Income" on-event="/system script set source=\"0\" monthlyincome " policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=Sep/28/2021 start-time=00:00:00;
/system script add dont-require-permissions=no name=todayincome owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="0";
/system script add dont-require-permissions=no name= monthlyincome owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="0";