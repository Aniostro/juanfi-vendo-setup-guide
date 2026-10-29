# hotspot-login-logic.example.rsc
# The official JuanFi on-login / on-logout script (release-4.4), unmodified except for
# the two placeholders below. This is what talks to the NodeMCU's voucher signal (the
# new@gmail.com / extend@gmail.com marker emails) and sends the 'New Sales' Telegram
# message. Do not rewrite the logic unless you understand the comment-field and
# email-field conventions documented in the README -- the NodeMCU firmware depends on
# them exactly as they are.
#
# Telegram is OFF by default (isTelegram 0). To enable it: set isTelegram to 1, and
# replace iTBotToken / iTGrChatID below with your own bot token and chat ID (see
# README step 6). Import this AFTER network-and-hotspot.example.rsc.

/ip hotspot user profile
/ip hotspot user profile
set [ find default=yes ] on-login=":put (\",ntfc,10,31d,12,,Disable,\");\r\
    \n:do {/system logging enable 0; :log info \">>> Hotspot INFO Login||Vouch\
    er: \$user ||Server: \$interface  ||ENTER: \$[/system clock get date] - \$\
    [/system clock get time]\"; / console clear-history;\r\
    \n\r\
    \n### hotspot folder for HEX put flash/hotspot for haplite put hotspot onl\
    y\r\
    \n:local HSFilePath \"hotspot\";\r\
    \n### enable telegram notification, change from 0 to 1 if you want to enab\
    le telegram\r\
    \n:local isTelegram 0;\r\
    \n###replace telegram token\r\
    \n:local iTBotToken \"xxxxxxxxxx:xxxxxxxxxxxxx-xxxxxxxxxxxxxxx-xxxxx\";\r\
    \n###replace telegram chat id / group id\r\
    \n:local iTGrChatID \"xxxxxxxxxxxxxx\";\r\
    \n### enable Random MAC synchronizer\r\
    \n:local isRandomMacSyncFix 1;\r\
    \n#\r\
    \n####### DONT EDIT BEYOND THIS LINE unless you know what your doing! ####\
    ###\r\
    \n#\r\
    \n# Get User Data\r\
    \n:local aUsrNote [/ip hotspot user get \$user comment];\r\
    \n:local aUsrNote [:toarray \$aUsrNote];\r\
    \n:local iUsrTime [:totime (\$aUsrNote->0)];\r\
    \n:local iSaleAmt [:tonum (\$aUsrNote->1)];\r\
    \n:local iExtCode (\$aUsrNote->2);\r\
    \n:local iVdoName (\$aUsrNote->3);\r\
    \n:local iTimeMin [/ip hotspot user get \$user limit-uptime];\r\
    \n:local iUserReg [/system scheduler find name=\$user];\r\
    \n:local mac \$\"mac-address\";\r\
    \n:local sobre [/ip hotspot user get \$user email];\r\
    \n:local komehtap [/ip hotspot user get \$user comment];\r\
    \n:local devSerialSN [/system routerboard get serial-number];\r\
    \n:local iFileMac; :local hsHSprofile; :local htmlFolder;\r\
    \n  :for i from=0 to=([:len \$mac] - 1) do={\r\
    \n    :local chr [:pick \$mac \$i];\r\
    \n    :if (\$chr = \":\") do={ :set \$chr \"\" };\r\
    \n    :set \$iFileMac (\$iFileMac . \$chr);\r\
    \n  }\r\
    \n/system logging disable 0; :local HSemailadd \"bots@juanfi.local\"; /ip \
    hotspot user set \$user email=\"\$HSemailadd\";\r\
    \n:do {:set \$hsHSprofile [/ip hotspot get [/ip hotspot find interface=\$i\
    nterface] profile];} on-error={ };\r\
    \n:do {:set \$htmlFolder [/ip hotspot profile get [ /ip hotspot profile fi\
    nd name=\$hsHSprofile] html-directory];} on-error={:set \$htmlFolder \"\$H\
    SFilePath\";};\r\
    \n:if ([:len \$htmlFolder] != 0) do={:set \$HSFilePath \"\$htmlFolder\";}\
    \r\
    \n# LOGIN PROFILE STATUS \r\
    \n:if (\$sobre=\"\$HSemailadd\") do={:do { :local iValidUntil [/system sch\
    eduler get \$user next-run];\r\
    \n  :if ([/system scheduler find name=\$user]!=\"\") do={\r\
    \n    /file print file=\"\$HSFilePath/data/\$iFileMac.txt\" where name=\"d\
    ummyfile\";\r\
    \n    :local x 10;:while ((\$x>0) and ([/file find name=\"\$HSFilePath/dat\
    a/\$iFileMac.txt\"]=\"\")) do={:set \$x (\$x-1);:delay 1s};\r\
    \n    :do {/file set \"\$HSFilePath/data/\$iFileMac\" contents=\"\$user#\$\
    iValidUntil\";:delay 1s;} on-error={ }; \r\
    \n    :do {/file set [find name~\"\$iFileMac\"] contents=\"\$user#\$iValid\
    Until\";:delay 1s;} on-error={ }; \r\
    \n  } \r\
    \n} on-error={ };}\r\
    \n# Check User Data \r\
    \n:if (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\") do={\r\
    \n/ip hotspot user set \$user comment=\"\" email=\"\$HSemailadd\";\r\
    \n:local iDateBeg [/system clock get date]; :local iTimeBeg [/system clock\
    \_get time];\r\
    \n# Extend User\r\
    \n  :if (\$sobre=\"extend@gmail.com\") do={:log info \"OLD Account\";\r\
    \n    :local iTimeInt [/system scheduler get \$user interval];\r\
    \n    :set \$iTimeInt (\$iTimeInt+\$iUsrTime);\r\
    \n    :if (\$iTimeMin>\$iTimeInt) do={ :set iTimeInt (\$iTimeMin+\$iUsrTim\
    e) };\r\
    \n    #UserExtend with failsafe routine for HS-Scheduler\r\
    \n    :do {/system scheduler set \$user interval=\$iTimeInt;} on-error={\r\
    \n            :do { /system scheduler add name=\"\$user\" interval=\$iTime\
    Int \\\r\
    \n                start-date=\$iDateBeg start-time=\$iTimeBeg disable=no \
    \\\r\
    \n                policy=ftp,reboot,read,write,policy,test,password,sniff,\
    sensitive,romon \\\r\
    \n                on-event=(\":do {/ip hotspot user remove [find name=\$us\
    er];} on-error={};\\r\\n\".\\\r\
    \n                \":do {/ip hotspot active remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\r\
    \n                \":do {/ip hotspot cookie remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\r\
    \n                \":do {/system scheduler remove [find name=\$user];} on-\
    error={};\\r\\n\".\\\r\
    \n                \":do {/file remove \\\"\$HSFilePath/data/\$iFileMac.txt\
    \\\"} on-error={};\\r\\n\")\r\
    \n            } on-error={ log error \"( \$user ) /system scheduler add =>\
    \_ERROR ADD!\" };\r\
    \n    };\r\
    \n  }\r\
    \n# ADD User\r\
    \n  :if (\$sobre=\"new@gmail.com\") do={:log info \"NEW Account\";\r\
    \n    :local iTimeInt \$iUsrTime;\r\
    \n    :if (\$iTimeMin>\$iUsrTime) do={ :set \$iTimeInt (\$iTimeMin+\$iUsrT\
    ime) };\r\
    \n    :do { /system scheduler add name=\"\$user\" interval=\$iTimeInt \\\r\
    \n      start-date=\$iDateBeg start-time=\$iTimeBeg disable=no \\\r\
    \n      policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,\
    romon \\\r\
    \n      on-event=(\":do {/ip hotspot user remove [find name=\$user];} on-e\
    rror={};\\r\\n\".\\\r\
    \n                \":do {/ip hotspot active remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\r\
    \n                \":do {/ip hotspot cookie remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\r\
    \n                \":do {/system scheduler remove [find name=\$user];} on-\
    error={};\\r\\n\".\\\r\
    \n                \":do {/file remove \\\"\$HSFilePath/data/\$iFileMac.txt\
    \\\"} on-error={};\\r\\n\")\r\
    \n    } on-error={ log error \"( \$user ) /system scheduler add => ERROR A\
    DD!\" };\r\
    \n    :local x 10;:while ((\$x>0) and ([/system scheduler find name=\"\$us\
    er\"]=\"\")) do={:set \$x (\$x-1);:delay 1s};\r\
    \n  };\r\
    \n:if (([:len [/sys sched find name=\"\$user\" and !disabled]]) != 0) do={\
    /sys sch; :local osDate [/system clock get date]; :local osTime [/system c\
    lock get time]; \r\
    \n    :local lenNextRun 0; :local StartDate; :local StartTime;:local Sched\
    Date; :local SchedTime; :local nxtSchedDate; :local nxtSchedTime; \r\
    \n    :local CurrentSchedDate; :local CurrentSchedTime; :local CurrentNext\
    Run; :local CurrentSchedInterval; \r\
    \n    :local hsSchedevent; :local iTemName; :local logEvent; :local SchedR\
    emarks; \r\
    \n    :local devSerial \"\$devSerialSN\$user\"; :do {/sys sch remo \$devSe\
    rial;} on-error={ };\r\
    \n:do {/sys sch add name=\"\$devSerial\" on-event=(\":do {/system schedule\
    r remove [find name=\$devSerial];} on-error={};\") disable=no interval=[(2\
    d)]; :delay 3s; /sys sch set \$devSerial start-time=\"00:00:00\" comment=\
    \$devSerialSN;} on-error={ };\r\
    \n:if (([:len [/sys sched find name=\"\$user\" and !disabled]]) != 0) do={\
    :set \$SchedDate [:put [/sys sch get \$devSerial next-run]]; :set \$SchedT\
    ime [:put [/sys sch get \$devSerial start-time]]; :set \$nxtSchedDate [:pu\
    t [:pick [/sys sch get \$devSerial next-run] 0 6]];\r\
    \n    :set \$CurrentNextRun [:put [/sys sch get \$user next-run]]; :set \$\
    lenNextRun [:put [:len [/sys sch get \$user next-run]]]; :delay 1s;\r\
    \n    :set \$CurrentSchedDate [:put [/sys sch get \$user start-date]]; :se\
    t \$CurrentSchedTime [:put [/sys sch get \$user start-time]];\r\
    \n    :set \$hsSchedevent [:put [/sys sch get \$user on-event]]; :set \$iT\
    emName [:put [/sys sch get \$user name]]; :set \$SchedRemarks [:put [/sys \
    sch get \$user comment]];\r\
    \n    :set \$CurrentSchedInterval [:put [/sys sch get \$user interval]];:d\
    o {/sys sch remo \$devSerial;} on-error={ }; :local toTimeInterval [:totim\
    e (\"5m\")];\r\
    \n        :if (([:put [:len [/system clock get date]]])=10) do={:set \$log\
    Event \"\$iTemName Debug Event Date 10\";:set \$StartDate [:put [:pick [/s\
    ys sch get \$user next-run] 0 10]];:set \$StartTime [:put [:pick [/sys sch\
    \_get \$user next-run] 11 19]];:set \$StartTime [(([:totime (\"\$StartTime\
    \")])+([:totime (\"\$toTimeInterval\")]))];};\r\
    \n        :if (([:put [:len [/system clock get date]]])=11) do={:if (\$len\
    NextRun=8) do={ :set \$logEvent \"\$iTemName Debug Event Date 8\";:set \$S\
    tartDate [:put [(\"\$nxtSchedDate\$[:pick [/system clock get date] 6 11]\"\
    )]];:set \$StartTime [:put [/sys sch get \$user next-run]];:set \$StartTim\
    e [(([:totime (\"\$StartTime\")])+([:totime (\"\$toTimeInterval\")]))];};\
    \r\
    \n          :if (\$lenNextRun=15) do={ :set \$logEvent \"\$iTemName Debug \
    Event Date 15\";\r\
    \n            :set \$StartDate [:put [:pick [/sys sch get \$user next-run]\
    \_0 6]];:set \$StartDate [:put (\"\$StartDate\$[:pick [/system clock get d\
    ate] 6 11]\")];\r\
    \n            :set \$StartTime [:put [:pick [/sys sch get \$user next-run]\
    \_7 15]];:set \$StartTime [(([:totime (\"\$StartTime\")])+([:totime (\"\$t\
    oTimeInterval\")]))];};\r\
    \n          :if (\$lenNextRun=20) do={ :set \$logEvent \"\$iTemName Debug \
    Event Date 20\";:set \$StartDate [:put [:pick [/sys sch get \$user next-ru\
    n] 0 11]];:set \$StartTime [:put [:pick [/sys sch get \$user next-run] 12 \
    20]];};};\r\
    \n        :if (([:len [/sys sched find name=\"\$devSerial\" and !disabled]\
    ]) = 0) do={:do {/system sche set \$user start-date=\$StartDate start-time\
    =\$StartTime interval=\$toTimeInterval comment=\"\$devSerialSN, [<<||User|\
    |Voucher|| CODE: \$user ||>>],  <<***>> \$komehtap <<***>>\"; :delay 1s; :\
    do {/sys sch remo \$devSerial;} on-error={ };} on-error={/system logging e\
    nable 0; :log info  \"\$logEvent\";};}\r\
    \n}; :log info \"Sched TIME and Date\";};\r\
    \n# Save Data File\r\
    \n  :if ([/file find name=\"\$HSFilePath/data\"]=\"\") do={ :do {/tool fet\
    ch dst-path=(\"\$HSFilePath/data/.\") url=\"https://127.0.0.1/\"} on-error\
    ={ };}\r\
    \n  :local iValidUntil [/system scheduler get \$user next-run];\r\
    \n  :if ([/system scheduler find name=\$user]!=\"\") do={:log info \"TXT A\
    ccount\";\r\
    \n    /file print file=\"\$HSFilePath/data/\$iFileMac.txt\" where name=\"d\
    ummyfile\";\r\
    \n    :local x 10;:while ((\$x>0) and ([/file find name=\"\$HSFilePath/dat\
    a/\$iFileMac.txt\"]=\"\")) do={:set x (\$x-1);:delay 1s};\r\
    \n    :do {/file set \"\$HSFilePath/data/\$iFileMac\" contents=\"\$user#\$\
    iValidUntil\"; :delay 1s;} on-error={ }; \r\
    \n    :do {/file set [find name~\"\$iFileMac\"] contents=\"\$user#\$iValid\
    Until\";:delay 1s;} on-error={ }; \r\
    \n  }\r\
    \n#### SALES RECORDING\r\
    \n:if (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\") do={:log\
    \_info \"Sales Module\";\r\
    \n# Update Today Income\r\
    \n  :local iSaveAmt [:tonum [/system script get todayincome source]];\r\
    \n  :local iDailySales (\$iSaleAmt + \$iSaveAmt);\r\
    \n  :do {/system script set todayincome source=\"\$iDailySales\";} on-erro\
    r={ };\r\
    \n# Update Monthly Income\r\
    \n  :local iSaveAmt [:tonum [/system script get monthlyincome source]];\r\
    \n  :local iMonthSales ( \$iSaleAmt + \$iSaveAmt );\r\
    \n  :do {/system script set monthlyincome source=\"\$iMonthSales\";} on-er\
    ror={ };\r\
    \n# Telegram\r\
    \n  :if (\$isTelegram=1) do={:log info \"Telegram Module\"; :local xVendo;\
    \r\
    \n    :for i from=0 to=([:len \$iVdoName] - 1) do={ :local chr [:pick \$iV\
    doName \$i];\r\
    \n      :if (\$chr = \" \") do={ :set \$chr \"%20\" }; :set \$xVendo (\$xV\
    endo . \$chr);\r\
    \n    }\r\
    \n    :local iUActive [/ip hotspot active print count-only];\r\
    \n    :local iMessage (\"<<======New Sales======>>%0A\".\\\r\
    \n                     \"Vendo: \$xVendo %0A\".\\\r\
    \n                     \"Voucher: \$user %0A\".\\\r\
    \n                     \"IP: \$address %0A\".\\\r\
    \n                     \"MAC: \$mac %0A\".\\\r\
    \n                     \"Amount: \$iSaleAmt %0A\".\\\r\
    \n                     \"Extended: \$iExtCode %0A\".\\\r\
    \n                     \"Total Time: \$iTimeMin %0A %0A\".\\\r\
    \n                     \"Today Sales: \$iDailySales %0A\".\\\r\
    \n                     \"Monthly Sales: \$iMonthSales %0A\".\\\r\
    \n                     \"Active Users: \$iUActive %0A\".\\\r\
    \n                     \"Valid Until: \$iValidUntil %0A\".\\\r\
    \n                     \"<<=====================>>\");\r\
    \n    :do {/tool fetch url=\"https://api.telegram.org/bot\$iTBotToken/send\
    message\\\?chat_id=\$iTGrChatID&text=\$iMessage\" keep-result=no;} on-erro\
    r={/system logging enable 0;:log warning \"Skip Sending Telegram Message\"\
    ;/system logging disable 0;};\r\
    \n  }\r\
    \n}\r\
    \n#### SALES RECORDING\r\
    \n#  \r\
    \n};\r\
    \n# Random Mac\r\
    \n:if (\$isRandomMacSyncFix=1) do={ :local ActiveMacAdd \$\"mac-address\";\
    \_:local ActiveUser \"\$user\"; :log info \"Multiple Login Module\";\r\
    \n/ip hotspot active {\r\
    \n   :local o [/ip hotspot active find where mac-address!=\"\$ActiveMacAdd\
    \" and user=\"\$ActiveUser\"];\r\
    \n   :if ([:len \$o] != 0) do={/system logging enable 0;:log warning \"REM\
    OVE Multiple Account using Login|Voucher: \$user \";/system logging disabl\
    e 0; /ip hotspot active remove \$o;};\r\
    \n } }\r\
    \n:do {:delay 1s;/ip hotspot user set \$user comment=\"LastUsed_LOG_IN,\$[\
    /system clock get date],\$[/system clock get time]\";:delay 1s;} on-error=\
    { };\r\
    \n/system logging enable 0; :log info \"<<< Hotspot INFO Login||Voucher: \
    \$user ||Server: \$interface  ||EXIT: \$[/system clock get date] - \$[/sys\
    tem clock get time]\"; / console clear-history;} on-error={/system logging\
    \_enable 0; :log error \"HOTSPOT LOGIN SCRIPT FAILED \$user\";/ console cl\
    ear-history;};\r\
    \n" on-logout="####################################\r\
    \n### ON-LOGOUT\r\
    \n#####################################\r\
    \n/ console clear-history;/system logging enable 0; :log info \"#|LOGOUT| \
    Hotspot INFO ||Voucher|UserCode: \$user ||Server: \$interface  ||ENTER: \$\
    [/system clock get date] - \$[/system clock get time]\"; /system logging d\
    isable 0;\r\
    \n:do {:local HSuser \$user; :local mac \$\"mac-address\"; :local hsIfaceN\
    ame \$interface;\r\
    \n### hotspot folder for HEX put flash/hotspot for haplite put hotspot onl\
    y\r\
    \n:local hotspotFolder \"hotspot\";\r\
    \n### IF VoucherCode NO Uptime Limit \r\
    \n:local NewUPtime \"1d\";\r\
    \n#\r\
    \n:local macNoCol; :local hsHSprofile; :local htmlFolder; :local hsValidCo\
    de 1; :local sobre [/ip hotspot user get \$user email];\r\
    \n:do {:set \$hsHSprofile [/ip hotspot get [/ip hotspot find interface=\$h\
    sIfaceName] profile];} on-error={ };\r\
    \n:do {:set \$htmlFolder [/ip hotspot profile get [ /ip hotspot profile fi\
    nd name=\$hsHSprofile] html-directory];} on-error={:set \$htmlFolder \"\$h\
    otspotFolder\";};\r\
    \n:local Limituptime ([/ip hotspot user get \"\$HSuser\" limit-uptime]);:l\
    ocal Uptime ([/ip hotspot user get \"\$HSuser\" uptime]);\r\
    \n:local macadd ([/ip hotspot user get \"\$HSuser\" mac-address]);:local H\
    Semailadd \"bots@juanfi.local\";\r\
    \n:if ([:len \$htmlFolder] != 0) do={:set \$hotspotFolder \"\$htmlFolder\"\
    ;}\r\
    \n:for i from=0 to=([:len \$mac] - 1) do={ :local char [:pick \$mac \$i];:\
    if (\$char = \":\") do={:set \$char \"\";};:set \$macNoCol (\$macNoCol . \
    \$char);}\r\
    \n:do {:delay 1s;/ip hotspot user set \$user comment=\"LastUsed_LOGOUT,\$[\
    /system clock get date],\$[/system clock get time]\";:delay 1s;} on-error=\
    { };\r\
    \n:do {/ file remove \"\$hotspotFolder/data/\$macNoCol.txt\";} on-error={ \
    }\r\
    \n:if (\$Uptime>=\$Limituptime) do={:set \$hsValidCode 0;\r\
    \n    :do {/ip hotspot active remove [find where user=\"\$HSuser\"]} on-er\
    ror={ };\r\
    \n    :do {/ip hotspot user remove [find where name=\"\$HSuser\"]} on-erro\
    r={ };\r\
    \n    :do {/ip hotspot cookie remove [find user=\"\$HSuser\"];} on-error={\
    \_}; \r\
    \n    :do {/system sche remove [find name=\$user];} on-error={ };\r\
    \n    /system logging enable 0;:log warning \"\$HSuser Uptime Limit Expire\
    d\"; /system logging disable 0;\r\
    \n}\r\
    \n:if (\$hsValidCode != 0) do={\r\
    \n    :if (([:len [/ip hotspot user get \$user email]]) = 0) do={\r\
    \n        :do {:delay 1s;/ip hotspot user set \$user email=\$HSemailadd;:d\
    elay 1s;} on-error={ };\r\
    \n    }\r\
    \n    :if  (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\") do=\
    {\r\
    \n        :do {:delay 1s;/ip hotspot user set \$user email=\$HSemailadd;:d\
    elay 1s;} on-error={ };\r\
    \n    }\r\
    \n    :if  (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\" or \
    \$sobre=\"\$HSemailadd\") do={\r\
    \n        :if ([:len [/ip hotspot user get [/ip hotspot user find where na\
    me=\"\$HSuser\"] limit-uptime]] = 0) do={\r\
    \n            :do {:delay 1s;/ip hotspot user set \$user limit-uptime=\"\$\
    NewUPtime\";:delay 1s;} on-error={ };\r\
    \n        } \r\
    \n    }\r\
    \n}\r\
    \n} on-error={ };\r\
    \n/ console clear-history; /system logging enable 0;\r\
    \n\r\
    \n/sys sch set [find where name=\$user] comment=\"\";" rate-limit=8M/8M
