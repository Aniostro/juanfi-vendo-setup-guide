# daily-report.example.rsc
# OPTIONAL extension -- not part of JuanFi's official release. Adds an end-of-day
# Telegram + email sales digest at 23:55, derived from a working hAP lite install.
#
# Fix applied: the rate table had a typo, '0e:00:00', with no 14-hour entry to
# match -- a 14h/P25 voucher would show up as 'unmatched' in the report. Corrected
# to '14:00:00' below.
#
# Requires base-income-and-uptime.example.rsc already imported (uses its
# todayincome/monthlyincome running totals) and network-and-hotspot.example.rsc's
# clock/NTP setup for correct daily timing.
#
# Replace <BOT_TOKEN>, <CHAT_ID>, <YOUR_GMAIL_ADDRESS>, <GMAIL_APP_PASSWORD> below.
# Requires a Gmail App Password (Google Account -> Security -> App passwords).

/system scheduler
add interval=1d name=juanfi-daily-email-sched on-event=\
    "/system script run juanfi-daily-email" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-date=jun/14/2026 start-time=23:55:00


/system script
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