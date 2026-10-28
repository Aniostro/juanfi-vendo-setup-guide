# income-and-reports.example.rsc
# Running income counters, their daily/monthly resets, and the end-of-day
# Telegram + email sales report. Optional: the vendo works without this file,
# but you lose the daily digest and the today/monthly totals in each sale alert.
#
# Fixes applied vs. the original export this was derived from:
#  - todayincome / monthlyincome reset to 0 (were live totals, not useful as a template)
#  - rate table typo '0e:00:00' corrected to '14:00:00' (a 14h/P25 voucher was being
#    reported as unmatched in the daily report)
#  - 'uptime restore' scheduler: fixed a missing '$' on hsolduptime that likely made
#    the restore-after-reboot calculation fail (RouterOS treats a bare word, not a
#    dereferenced variable, as the literal text 'hsolduptime'). Not confirmed on
#    real hardware -- test this one specifically (see README).
#
# NOT included here (see README 'Known issues to check on your own router' section):
#  - 'juanfi-sale-alert-sched' / 'juanfi-seen-reset' schedulers: these referenced a
#    script that did not exist in the source export, so they would error every run.
#  - Per-voucher one-shot cleanup schedulers: these are created automatically at
#    runtime by the on-login script in hotspot-login-logic.example.rsc, not something
#    to import by hand.
#
# Replace <BOT_TOKEN>, <CHAT_ID>, <YOUR_GMAIL_ADDRESS>, <GMAIL_APP_PASSWORD> below.
# Import this AFTER hotspot-login-logic.example.rsc.

/system clock
set time-zone-name=Asia/Manila

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

add interval=1d name="Reset Daily Income" on-event=\
    "/system script set source=\"0\" todayincome " policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=sep/28/2021 start-time=00:00:00

add interval=4w2d name="Reset Monthly Income" on-event=\
    "/system script set source=\"0\" monthlyincome " policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=sep/28/2021 start-time=00:00:00

add interval=1d name=juanfi-daily-email-sched on-event=\
    "/system script run juanfi-daily-email" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=jun/14/2026 start-time=23:55:00

/system script
add dont-require-permissions=no name=todayincome owner=*sys policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="0"

add dont-require-permissions=no name=monthlyincome owner=*sys policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="0"

add dont-require-permissions=no name=juanfi-daily-email owner=admin policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=":\
    local botToken \"<BOT_TOKEN>\"\
    \n:local chatId \"<CHAT_ID>\"\
    \n:local today [/system clock get date]\
    \n:local rawTime [/system clock get time]\
    \n:local total 0\
    \n:local count 0\
    \n:local detail \"\"\
    \n:local unmatched \"\"\
    \n:local activeDetail \"\"\
    \n:local activeCount 0\
    \n:local activeTotal 0\
    \n:local tgDetail \"\"\
    \n:local tgActive \"\"\
    \n\
    \n# Get running totals from JuanFi income scripts\
    \n:local todayTotal [:tonum [/system script get todayincome source]]\
    \n:local monthTotal [:tonum [/system script get monthlyincome source]]\
    \n\
    \n:foreach i in=[/ip hotspot user find where comment~\"LastUsed_LOGOUT\"] \
    do={\
    \n  :local vcomment [/ip hotspot user get \$i comment]\
    \n  :local vname [/ip hotspot user get \$i name]\
    \n\
    \n  :local p1 [:find \$vcomment \",\"]\
    \n  :local rest [:pick \$vcomment (\$p1+1) [:len \$vcomment]]\
    \n  :local p2 [:find \$rest \",\"]\
    \n  :local logoutDate [:pick \$rest 0 \$p2]\
    \n  :local logoutTime [:pick \$rest (\$p2+1) [:len \$rest]]\
    \n\
    \n  :if (\$logoutDate = \$today) do={\
    \n    :local uptimeLimit [/ip hotspot user get \$i limit-uptime]\
    \n    :local price 0\
    \n    :local matched true\
    \n\
    \n    :if (\$uptimeLimit = \"00:10:00\") do={ :set price 1 }\
    \n    :if (\$uptimeLimit = \"02:00:00\") do={ :set price 5 }\
    \n    :if (\$uptimeLimit = \"04:00:00\") do={ :set price 10 }\
    \n    :if (\$uptimeLimit = \"12:00:00\") do={ :set price 20 }\
    \n    :if (\$uptimeLimit = \"00:20:00\") do={ :set price 2 }\
    \n    :if (\$uptimeLimit = \"00:30:00\") do={ :set price 3 }\
    \n    :if (\$uptimeLimit = \"00:40:00\") do={ :set price 4 }\
    \n    :if (\$uptimeLimit = \"02:10:00\") do={ :set price 6 }\
    \n    :if (\$uptimeLimit = \"02:20:00\") do={ :set price 7 }\
    \n    :if (\$uptimeLimit = \"02:30:00\") do={ :set price 8 }\
    \n    :if (\$uptimeLimit = \"02:40:00\") do={ :set price 9 }\
    \n    :if (\$uptimeLimit = \"06:00:00\") do={ :set price 15 }\
    \n    :if (\$uptimeLimit = \"08:00:00\") do={ :set price 20 }\
    \n    :if (\$uptimeLimit = \"14:00:00\") do={ :set price 25 }\
    \n    :if (\$uptimeLimit = \"10:00:00\") do={ :set price 30 }\
    \n    :if (\$uptimeLimit = \"16:00:00\") do={ :set price 35 }\
    \n    :if (\$uptimeLimit = \"1d00:00:00\") do={ :set price 40 }\
    \n    :if (\$uptimeLimit = \"1d12:00:00\") do={ :set price 60 }\
    \n    :if (\$uptimeLimit = \"2d00:00:00\") do={ :set price 80 }\
    \n\
    \n    :if (\$price = 0) do={ :set matched false }\
    \n\
    \n    :if (\$matched = true) do={\
    \n      :set total (\$total + \$price)\
    \n      :set count (\$count + 1)\
    \n      :set detail (\$detail . \$vname . \" | P\" . \$price . \" | \" . \
    \$uptimeLimit . \" | logout: \" . \$logoutTime . \"\\n\")\
    \n      :set tgDetail (\$tgDetail . \$vname . \" P\" . \$price . \" out:\"\
    \_. \$logoutTime . \"\\n\")\
    \n    } else={\
    \n      :set unmatched (\$unmatched . \$vname . \" | \" . \$uptimeLimit . \
    \" | logout: \" . \$logoutTime . \"\\n\")\
    \n    }\
    \n  }\
    \n}\
    \n\
    \n:foreach j in=[/ip hotspot active find] do={\
    \n  :local acomment [/ip hotspot active get \$j comment]\
    \n  :local auser [/ip hotspot active get \$j user]\
    \n  :local auptime [/ip hotspot active get \$j uptime]\
    \n  :local atimeleft [/ip hotspot active get \$j session-time-left]\
    \n\
    \n  :if (\$acomment ~ \"JuanFi Vendo\") do={\
    \n    :local p1 [:find \$acomment \",\"]\
    \n    :local rest [:pick \$acomment (\$p1+1) [:len \$acomment]]\
    \n    :local p2 [:find \$rest \",\"]\
    \n    :local price [:tonum [:pick \$rest 0 \$p2]]\
    \n\
    \n    :set activeTotal (\$activeTotal + \$price)\
    \n    :set activeCount (\$activeCount + 1)\
    \n    :set activeDetail (\$activeDetail . \$auser . \" | P\" . \$price . \
    \" | connected: \" . \$auptime . \" | remaining: \" . \$atimeleft . \"\\n\
    \")\
    \n    :set tgActive (\$tgActive . \$auser . \" P\" . \$price . \" left:\" \
    . \$atimeleft . \"\\n\")\
    \n  }\
    \n}\
    \n\
    \n# ---- EMAIL BODY ----\
    \n:local bodyText (\"Saludar WiFi Vendo - Daily Sales Report\\n\")\
    \n:set bodyText (\$bodyText . \"Date        : \" . \$today . \"\\n\")\
    \n:set bodyText (\$bodyText . \"Reported at : \" . \$rawTime . \"\\n\")\
    \n:set bodyText (\$bodyText . \"\\n=======================================\
    =\\n\")\
    \n:set bodyText (\$bodyText . \"COMPLETED SESSIONS\\n\")\
    \n:set bodyText (\$bodyText . \"========================================\\\
    n\")\
    \n:set bodyText (\$bodyText . \"Vouchers Sold : \" . \$count . \"\\n\")\
    \n:set bodyText (\$bodyText . \"Total Income  : P\" . \$total . \"\\n\")\
    \n:set bodyText (\$bodyText . \"\\nMAC              | Price | Duration  | \
    Logout\\n\")\
    \n:set bodyText (\$bodyText . \"------------------------------------------\
    ----\\n\")\
    \n:set bodyText (\$bodyText . \$detail)\
    \n\
    \n:if ([:len \$unmatched] > 0) do={\
    \n  :set bodyText (\$bodyText . \"\\n--- UNMATCHED (check rate table) ---\
    \\n\")\
    \n  :set bodyText (\$bodyText . \$unmatched)\
    \n}\
    \n\
    \n:set bodyText (\$bodyText . \"\\n=======================================\
    =\\n\")\
    \n:set bodyText (\$bodyText . \"ACTIVE SESSIONS (still connected)\\n\")\
    \n:set bodyText (\$bodyText . \"========================================\\\
    n\")\
    \n:set bodyText (\$bodyText . \"Active Users  : \" . \$activeCount . \"\\n\
    \")\
    \n:set bodyText (\$bodyText . \"Active Value  : P\" . \$activeTotal . \"\\\
    n\")\
    \n:set bodyText (\$bodyText . \"\\nMAC              | Price | Connected | \
    Remaining\\n\")\
    \n:set bodyText (\$bodyText . \"------------------------------------------\
    --------\\n\")\
    \n:set bodyText (\$bodyText . \$activeDetail)\
    \n:set bodyText (\$bodyText . \"\\n=======================================\
    =\\n\")\
    \n:set bodyText (\$bodyText . \"RUNNING TOTALS (JuanFi)\\n\")\
    \n:set bodyText (\$bodyText . \"========================================\\\
    n\")\
    \n:set bodyText (\$bodyText . \"Today Income   : P\" . \$todayTotal . \"\\\
    n\")\
    \n:set bodyText (\$bodyText . \"Monthly Income : P\" . \$monthTotal . \"\\\
    n\")\
    \n:set bodyText (\$bodyText . \"\\n=======================================\
    =\\n\")\
    \n:set bodyText (\$bodyText . \"GRAND TOTAL (done + active): P\" . (\$tota\
    l + \$activeTotal) . \"\\n\")\
    \n\
    \n# ---- SEND EMAIL ----\
    \n/tool e-mail send to=\"<YOUR_GMAIL_ADDRESS>\" subject=(\"Saludar \
    WiFi Vendo Daily Sales - \" . \$today) body=\$bodyText\
    \n\
    \n# ---- SEND TELEGRAM (POST method) ----\
    \n:local tgText (\"Saludar WiFi Vendo - Daily Report\\n\")\
    \n:set tgText (\$tgText . \"Date: \" . \$today . \"\\n\")\
    \n:set tgText (\$tgText . \"Time: \" . \$rawTime . \"\\n\\n\")\
    \n:set tgText (\$tgText . \"COMPLETED SESSIONS\\n\")\
    \n:set tgText (\$tgText . \"Vouchers: \" . \$count . \"\\n\")\
    \n:set tgText (\$tgText . \"Income  : P\" . \$total . \"\\n\")\
    \n:set tgText (\$tgText . \$tgDetail)\
    \n:set tgText (\$tgText . \"\\nACTIVE SESSIONS\\n\")\
    \n:set tgText (\$tgText . \"Users: \" . \$activeCount . \"\\n\")\
    \n:set tgText (\$tgText . \"Value: P\" . \$activeTotal . \"\\n\")\
    \n:set tgText (\$tgText . \$tgActive)\
    \n:set tgText (\$tgText . \"\\nRUNNING TOTALS\\n\")\
    \n:set tgText (\$tgText . \"Today  : P\" . \$todayTotal . \"\\n\")\
    \n:set tgText (\$tgText . \"Monthly: P\" . \$monthTotal . \"\\n\")\
    \n:set tgText (\$tgText . \"\\nGRAND TOTAL: P\" . (\$total + \$activeTotal\
    ))\
    \n\
    \n/tool fetch url=(\"https://api.telegram.org/bot\" . \$botToken . \"/send\
    Message\") http-method=post http-data=(\"chat_id=\" . \$chatId . \"&text=\
    \" . \$tgText) keep-result=no"

/tool e-mail
set address=smtp.gmail.com from=<YOUR_GMAIL_ADDRESS> password=\
    "<GMAIL_APP_PASSWORD>" port=587 start-tls=yes user=\
    <YOUR_GMAIL_ADDRESS>