# hotspot-login-logic.example.rsc
# The core JuanFi on-login / on-logout script, taken from a working hAP lite
# install and sanitized. This is what talks to the NodeMCU's voucher signal
# (the special new@gmail.com / extend@gmail.com marker emails) and sends the
# 'New Sales' Telegram message. Do not rewrite the logic unless you understand
# the comment-field and email-field conventions documented in the README --
# the NodeMCU firmware depends on them exactly as they are.
#
# Replace <BOT_TOKEN> and <CHAT_ID> below with your own (see README step 5).
# Import this AFTER network-and-hotspot.example.rsc.

/ip hotspot user profile
/ip hotspot user profile
set [ find default=yes ] on-login=":put (\",ntfc,10,31d,12,,Disable,\");\
    \n:do {/system logging enable 0; :log info \">>> Hotspot INFO Login||Vouch\
    er: \$user ||Server: \$interface  ||ENTER: \$[/system clock get date] - \$\
    [/system clock get time]\"; / console clear-history;\
    \n\
    \n### hotspot folder for HEX put flash/hotspot for haplite put hotspot onl\
    y\
    \n:local HSFilePath \"hotspot\";\
    \n### enable telegram notification, change from 0 to 1 if you want to enab\
    le telegram\
    \n:local isTelegram 1;\
    \n###replace telegram token\
    \n:local iTBotToken \"<BOT_TOKEN>\";\
    \n###replace telegram chat id / group id\
    \n:local iTGrChatID \"<CHAT_ID>\";\
    \n### enable Random MAC synchronizer\
    \n:local isRandomMacSyncFix 1;\
    \n#\
    \n####### DONT EDIT BEYOND THIS LINE unless you know what your doing! ####\
    ###\
    \n#\
    \n# Get User Data\
    \n:local aUsrNote [/ip hotspot user get \$user comment];\
    \n:local aUsrNote [:toarray \$aUsrNote];\
    \n:local iUsrTime [:totime (\$aUsrNote->0)];\
    \n:local iSaleAmt [:tonum (\$aUsrNote->1)];\
    \n:local iExtCode (\$aUsrNote->2);\
    \n:local iVdoName (\$aUsrNote->3);\
    \n:local iTimeMin [/ip hotspot user get \$user limit-uptime];\
    \n:local iUserReg [/system scheduler find name=\$user];\
    \n:local mac \$\"mac-address\";\
    \n:local sobre [/ip hotspot user get \$user email];\
    \n:local komehtap [/ip hotspot user get \$user comment];\
    \n:local devSerialSN [/system routerboard get serial-number];\
    \n:local iFileMac; :local hsHSprofile; :local htmlFolder;\
    \n  :for i from=0 to=([:len \$mac] - 1) do={\
    \n    :local chr [:pick \$mac \$i];\
    \n    :if (\$chr = \":\") do={ :set \$chr \"\" };\
    \n    :set \$iFileMac (\$iFileMac . \$chr);\
    \n  }\
    \n/system logging disable 0; :local HSemailadd \"bots@juanfi.local\"; /ip \
    hotspot user set \$user email=\"\$HSemailadd\";\
    \n:do {:set \$hsHSprofile [/ip hotspot get [/ip hotspot find interface=\$i\
    nterface] profile];} on-error={ };\
    \n:do {:set \$htmlFolder [/ip hotspot profile get [ /ip hotspot profile fi\
    nd name=\$hsHSprofile] html-directory];} on-error={:set \$htmlFolder \"\$H\
    SFilePath\";};\
    \n:if ([:len \$htmlFolder] != 0) do={:set \$HSFilePath \"\$htmlFolder\";}\
    \n# LOGIN PROFILE STATUS \
    \n:if (\$sobre=\"\$HSemailadd\") do={:do { :local iValidUntil [/system sch\
    eduler get \$user next-run];\
    \n  :if ([/system scheduler find name=\$user]!=\"\") do={\
    \n    /file print file=\"\$HSFilePath/data/\$iFileMac.txt\" where name=\"d\
    ummyfile\";\
    \n    :local x 10;:while ((\$x>0) and ([/file find name=\"\$HSFilePath/dat\
    a/\$iFileMac.txt\"]=\"\")) do={:set \$x (\$x-1);:delay 1s};\
    \n    :do {/file set \"\$HSFilePath/data/\$iFileMac\" contents=\"\$user#\$\
    iValidUntil\";:delay 1s;} on-error={ }; \
    \n    :do {/file set [find name~\"\$iFileMac\"] contents=\"\$user#\$iValid\
    Until\";:delay 1s;} on-error={ }; \
    \n  } \
    \n} on-error={ };}\
    \n# Check User Data \
    \n:if (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\") do={\
    \n/ip hotspot user set \$user comment=\"\" email=\"\$HSemailadd\";\
    \n:local iDateBeg [/system clock get date]; :local iTimeBeg [/system clock\
    \_get time];\
    \n# Extend User\
    \n  :if (\$sobre=\"extend@gmail.com\") do={:log info \"OLD Account\";\
    \n    :local iTimeInt [/system scheduler get \$user interval];\
    \n    :set \$iTimeInt (\$iTimeInt+\$iUsrTime);\
    \n    :if (\$iTimeMin>\$iTimeInt) do={ :set iTimeInt (\$iTimeMin+\$iUsrTim\
    e) };\
    \n    #UserExtend with failsafe routine for HS-Scheduler\
    \n    :do {/system scheduler set \$user interval=\$iTimeInt;} on-error={\
    \n            :do { /system scheduler add name=\"\$user\" interval=\$iTime\
    Int \\\
    \n                start-date=\$iDateBeg start-time=\$iTimeBeg disable=no \
    \\\
    \n                policy=ftp,reboot,read,write,policy,test,password,sniff,\
    sensitive,romon \\\
    \n                on-event=(\":do {/ip hotspot user remove [find name=\$us\
    er];} on-error={};\\r\\n\".\\\
    \n                \":do {/ip hotspot active remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\
    \n                \":do {/ip hotspot cookie remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\
    \n                \":do {/system scheduler remove [find name=\$user];} on-\
    error={};\\r\\n\".\\\
    \n                \":do {/file remove \\\"\$HSFilePath/data/\$iFileMac.txt\
    \\\"} on-error={};\\r\\n\")\
    \n            } on-error={ log error \"( \$user ) /system scheduler add =>\
    \_ERROR ADD!\" };\
    \n    };\
    \n  }\
    \n# ADD User\
    \n  :if (\$sobre=\"new@gmail.com\") do={:log info \"NEW Account\";\
    \n    :local iTimeInt \$iUsrTime;\
    \n    :if (\$iTimeMin>\$iUsrTime) do={ :set \$iTimeInt (\$iTimeMin+\$iUsrT\
    ime) };\
    \n    :do { /system scheduler add name=\"\$user\" interval=\$iTimeInt \\\
    \n      start-date=\$iDateBeg start-time=\$iTimeBeg disable=no \\\
    \n      policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,\
    romon \\\
    \n      on-event=(\":do {/ip hotspot user remove [find name=\$user];} on-e\
    rror={};\\r\\n\".\\\
    \n                \":do {/ip hotspot active remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\
    \n                \":do {/ip hotspot cookie remove [find user=\$user];} on\
    -error={};\\r\\n\".\\\
    \n                \":do {/system scheduler remove [find name=\$user];} on-\
    error={};\\r\\n\".\\\
    \n                \":do {/file remove \\\"\$HSFilePath/data/\$iFileMac.txt\
    \\\"} on-error={};\\r\\n\")\
    \n    } on-error={ log error \"( \$user ) /system scheduler add => ERROR A\
    DD!\" };\
    \n    :local x 10;:while ((\$x>0) and ([/system scheduler find name=\"\$us\
    er\"]=\"\")) do={:set \$x (\$x-1);:delay 1s};\
    \n  };\
    \n:if (([:len [/sys sched find name=\"\$user\" and !disabled]]) != 0) do={\
    /sys sch; :local osDate [/system clock get date]; :local osTime [/system c\
    lock get time]; \
    \n    :local lenNextRun 0; :local StartDate; :local StartTime;:local Sched\
    Date; :local SchedTime; :local nxtSchedDate; :local nxtSchedTime; \
    \n    :local CurrentSchedDate; :local CurrentSchedTime; :local CurrentNext\
    Run; :local CurrentSchedInterval; \
    \n    :local hsSchedevent; :local iTemName; :local logEvent; :local SchedR\
    emarks; \
    \n    :local devSerial \"\$devSerialSN\$user\"; :do {/sys sch remo \$devSe\
    rial;} on-error={ };\
    \n:do {/sys sch add name=\"\$devSerial\" on-event=(\":do {/system schedule\
    r remove [find name=\$devSerial];} on-error={};\") disable=no interval=[(2\
    d)]; :delay 3s; /sys sch set \$devSerial start-time=\"00:00:00\" comment=\
    \$devSerialSN;} on-error={ };\
    \n:if (([:len [/sys sched find name=\"\$user\" and !disabled]]) != 0) do={\
    :set \$SchedDate [:put [/sys sch get \$devSerial next-run]]; :set \$SchedT\
    ime [:put [/sys sch get \$devSerial start-time]]; :set \$nxtSchedDate [:pu\
    t [:pick [/sys sch get \$devSerial next-run] 0 6]];\
    \n    :set \$CurrentNextRun [:put [/sys sch get \$user next-run]]; :set \$\
    lenNextRun [:put [:len [/sys sch get \$user next-run]]]; :delay 1s;\
    \n    :set \$CurrentSchedDate [:put [/sys sch get \$user start-date]]; :se\
    t \$CurrentSchedTime [:put [/sys sch get \$user start-time]];\
    \n    :set \$hsSchedevent [:put [/sys sch get \$user on-event]]; :set \$iT\
    emName [:put [/sys sch get \$user name]]; :set \$SchedRemarks [:put [/sys \
    sch get \$user comment]];\
    \n    :set \$CurrentSchedInterval [:put [/sys sch get \$user interval]];:d\
    o {/sys sch remo \$devSerial;} on-error={ }; :local toTimeInterval [:totim\
    e (\"5m\")];\
    \n        :if (([:put [:len [/system clock get date]]])=10) do={:set \$log\
    Event \"\$iTemName Debug Event Date 10\";:set \$StartDate [:put [:pick [/s\
    ys sch get \$user next-run] 0 10]];:set \$StartTime [:put [:pick [/sys sch\
    \_get \$user next-run] 11 19]];:set \$StartTime [(([:totime (\"\$StartTime\
    \")])+([:totime (\"\$toTimeInterval\")]))];};\
    \n        :if (([:put [:len [/system clock get date]]])=11) do={:if (\$len\
    NextRun=8) do={ :set \$logEvent \"\$iTemName Debug Event Date 8\";:set \$S\
    tartDate [:put [(\"\$nxtSchedDate\$[:pick [/system clock get date] 6 11]\"\
    )]];:set \$StartTime [:put [/sys sch get \$user next-run]];:set \$StartTim\
    e [(([:totime (\"\$StartTime\")])+([:totime (\"\$toTimeInterval\")]))];};\
    \n          :if (\$lenNextRun=15) do={ :set \$logEvent \"\$iTemName Debug \
    Event Date 15\";\
    \n            :set \$StartDate [:put [:pick [/sys sch get \$user next-run]\
    \_0 6]];:set \$StartDate [:put (\"\$StartDate\$[:pick [/system clock get d\
    ate] 6 11]\")];\
    \n            :set \$StartTime [:put [:pick [/sys sch get \$user next-run]\
    \_7 15]];:set \$StartTime [(([:totime (\"\$StartTime\")])+([:totime (\"\$t\
    oTimeInterval\")]))];};\
    \n          :if (\$lenNextRun=20) do={ :set \$logEvent \"\$iTemName Debug \
    Event Date 20\";:set \$StartDate [:put [:pick [/sys sch get \$user next-ru\
    n] 0 11]];:set \$StartTime [:put [:pick [/sys sch get \$user next-run] 12 \
    20]];};};\
    \n        :if (([:len [/sys sched find name=\"\$devSerial\" and !disabled]\
    ]) = 0) do={:do {/system sche set \$user start-date=\$StartDate start-time\
    =\$StartTime interval=\$toTimeInterval comment=\"\$devSerialSN, [<<||User|\
    |Voucher|| CODE: \$user ||>>],  <<***>> \$komehtap <<***>>\"; :delay 1s; :\
    do {/sys sch remo \$devSerial;} on-error={ };} on-error={/system logging e\
    nable 0; :log info  \"\$logEvent\";};}\
    \n}; :log info \"Sched TIME and Date\";};\
    \n# Save Data File\
    \n  :if ([/file find name=\"\$HSFilePath/data\"]=\"\") do={ :do {/tool fet\
    ch dst-path=(\"\$HSFilePath/data/.\") url=\"https://127.0.0.1/\"} on-error\
    ={ };}\
    \n  :local iValidUntil [/system scheduler get \$user next-run];\
    \n  :if ([/system scheduler find name=\$user]!=\"\") do={:log info \"TXT A\
    ccount\";\
    \n    /file print file=\"\$HSFilePath/data/\$iFileMac.txt\" where name=\"d\
    ummyfile\";\
    \n    :local x 10;:while ((\$x>0) and ([/file find name=\"\$HSFilePath/dat\
    a/\$iFileMac.txt\"]=\"\")) do={:set x (\$x-1);:delay 1s};\
    \n    :do {/file set \"\$HSFilePath/data/\$iFileMac\" contents=\"\$user#\$\
    iValidUntil\"; :delay 1s;} on-error={ }; \
    \n    :do {/file set [find name~\"\$iFileMac\"] contents=\"\$user#\$iValid\
    Until\";:delay 1s;} on-error={ }; \
    \n  }\
    \n#### SALES RECORDING\
    \n:if (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\") do={:log\
    \_info \"Sales Module\";\
    \n# Update Today Income\
    \n  :local iSaveAmt [:tonum [/system script get todayincome source]];\
    \n  :local iDailySales (\$iSaleAmt + \$iSaveAmt);\
    \n  :do {/system script set todayincome source=\"\$iDailySales\";} on-erro\
    r={ };\
    \n# Update Monthly Income\
    \n  :local iSaveAmt [:tonum [/system script get monthlyincome source]];\
    \n  :local iMonthSales ( \$iSaleAmt + \$iSaveAmt );\
    \n  :do {/system script set monthlyincome source=\"\$iMonthSales\";} on-er\
    ror={ };\
    \n# Telegram\
    \n  :if (\$isTelegram=1) do={:log info \"Telegram Module\"; :local xVendo;\
    \n    :for i from=0 to=([:len \$iVdoName] - 1) do={ :local chr [:pick \$iV\
    doName \$i];\
    \n      :if (\$chr = \" \") do={ :set \$chr \"%20\" }; :set \$xVendo (\$xV\
    endo . \$chr);\
    \n    }\
    \n    :local iUActive [/ip hotspot active print count-only];\
    \n    :local iMessage (\"<<======New Sales======>>%0A\".\\\
    \n                     \"Vendo: \$xVendo %0A\".\\\
    \n                     \"Voucher: \$user %0A\".\\\
    \n                     \"IP: \$address %0A\".\\\
    \n                     \"MAC: \$mac %0A\".\\\
    \n                     \"Amount: \$iSaleAmt %0A\".\\\
    \n                     \"Extended: \$iExtCode %0A\".\\\
    \n                     \"Total Time: \$iTimeMin %0A %0A\".\\\
    \n                     \"Today Sales: \$iDailySales %0A\".\\\
    \n                     \"Monthly Sales: \$iMonthSales %0A\".\\\
    \n                     \"Active Users: \$iUActive %0A\".\\\
    \n                     \"Valid Until: \$iValidUntil %0A\".\\\
    \n                     \"<<=====================>>\");\
    \n   :do {/tool fetch url=(\"https://api.telegram.org/bot\" . \$iTBotToken\
    \_. \"/sendMessage\") http-method=post http-data=(\"chat_id=\" . \$iTGrCha\
    tID . \"&text=\" . \$iMessage) keep-result=no;} on-error={/system logging \
    enable 0;:log warning \"Skip Sending Telegram Message\";/system logging di\
    sable 0;};\
    \n  }\
    \n}\
    \n#### SALES RECORDING\
    \n#  \
    \n};\
    \n# Random Mac\
    \n:if (\$isRandomMacSyncFix=1) do={ :local ActiveMacAdd \$\"mac-address\";\
    \_:local ActiveUser \"\$user\"; :log info \"Multiple Login Module\";\
    \n/ip hotspot active {\
    \n   :local o [/ip hotspot active find where mac-address!=\"\$ActiveMacAdd\
    \" and user=\"\$ActiveUser\"];\
    \n   :if ([:len \$o] != 0) do={/system logging enable 0;:log warning \"REM\
    OVE Multiple Account using Login|Voucher: \$user \";/system logging disabl\
    e 0; /ip hotspot active remove \$o;};\
    \n } }\
    \n:do {:delay 1s;/ip hotspot user set \$user comment=\"LastUsed_LOG_IN,\$[\
    /system clock get date],\$[/system clock get time]\";:delay 1s;} on-error=\
    { };\
    \n/system logging enable 0; :log info \"<<< Hotspot INFO Login||Voucher: \
    \$user ||Server: \$interface  ||EXIT: \$[/system clock get date] - \$[/sys\
    tem clock get time]\"; / console clear-history;} on-error={/system logging\
    \_enable 0; :log error \"HOTSPOT LOGIN SCRIPT FAILED \$user\";/ console cl\
    ear-history;};\
    \n" on-logout="####################################\
    \n### ON-LOGOUT\
    \n#####################################\
    \n/ console clear-history;/system logging enable 0; :log info \"#|LOGOUT| \
    Hotspot INFO ||Voucher|UserCode: \$user ||Server: \$interface  ||ENTER: \$\
    [/system clock get date] - \$[/system clock get time]\"; /system logging d\
    isable 0;\
    \n:do {:local HSuser \$user; :local mac \$\"mac-address\"; :local hsIfaceN\
    ame \$interface;\
    \n### hotspot folder for HEX put flash/hotspot for haplite put hotspot onl\
    y\
    \n:local hotspotFolder \"hotspot\";\
    \n### IF VoucherCode NO Uptime Limit \
    \n:local NewUPtime \"1d\";\
    \n#\
    \n:local macNoCol; :local hsHSprofile; :local htmlFolder; :local hsValidCo\
    de 1; :local sobre [/ip hotspot user get \$user email];\
    \n:do {:set \$hsHSprofile [/ip hotspot get [/ip hotspot find interface=\$h\
    sIfaceName] profile];} on-error={ };\
    \n:do {:set \$htmlFolder [/ip hotspot profile get [ /ip hotspot profile fi\
    nd name=\$hsHSprofile] html-directory];} on-error={:set \$htmlFolder \"\$h\
    otspotFolder\";};\
    \n:local Limituptime ([/ip hotspot user get \"\$HSuser\" limit-uptime]);:l\
    ocal Uptime ([/ip hotspot user get \"\$HSuser\" uptime]);\
    \n:local macadd ([/ip hotspot user get \"\$HSuser\" mac-address]);:local H\
    Semailadd \"bots@juanfi.local\";\
    \n:if ([:len \$htmlFolder] != 0) do={:set \$hotspotFolder \"\$htmlFolder\"\
    ;}\
    \n:for i from=0 to=([:len \$mac] - 1) do={ :local char [:pick \$mac \$i];:\
    if (\$char = \":\") do={:set \$char \"\";};:set \$macNoCol (\$macNoCol . \
    \$char);}\
    \n:do {:delay 1s;/ip hotspot user set \$user comment=\"LastUsed_LOGOUT,\$[\
    /system clock get date],\$[/system clock get time]\";:delay 1s;} on-error=\
    { };\
    \n:do {/ file remove \"\$hotspotFolder/data/\$macNoCol.txt\";} on-error={ \
    }\
    \n:if (\$Uptime>=\$Limituptime) do={:set \$hsValidCode 0;\
    \n    :do {/ip hotspot active remove [find where user=\"\$HSuser\"]} on-er\
    ror={ };\
    \n    :do {/ip hotspot user remove [find where name=\"\$HSuser\"]} on-erro\
    r={ };\
    \n    :do {/ip hotspot cookie remove [find user=\"\$HSuser\"];} on-error={\
    \_}; \
    \n    :do {/system sche remove [find name=\$user];} on-error={ };\
    \n    /system logging enable 0;:log warning \"\$HSuser Uptime Limit Expire\
    d\"; /system logging disable 0;\
    \n}\
    \n:if (\$hsValidCode != 0) do={\
    \n    :if (([:len [/ip hotspot user get \$user email]]) = 0) do={\
    \n        :do {:delay 1s;/ip hotspot user set \$user email=\$HSemailadd;:d\
    elay 1s;} on-error={ };\
    \n    }\
    \n    :if  (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\") do=\
    {\
    \n        :do {:delay 1s;/ip hotspot user set \$user email=\$HSemailadd;:d\
    elay 1s;} on-error={ };\
    \n    }\
    \n    :if  (\$sobre=\"new@gmail.com\" or \$sobre=\"extend@gmail.com\" or \
    \$sobre=\"\$HSemailadd\") do={\
    \n        :if ([:len [/ip hotspot user get [/ip hotspot user find where na\
    me=\"\$HSuser\"] limit-uptime]] = 0) do={\
    \n            :do {:delay 1s;/ip hotspot user set \$user limit-uptime=\"\$\
    NewUPtime\";:delay 1s;} on-error={ };\
    \n        } \
    \n    }\
    \n}\
    \n} on-error={ };\
    \n/ console clear-history; /system logging enable 0;\
    \n\
    \n/sys sch set [find where name=\$user] comment=\"\";" rate-limit=8M/8M
