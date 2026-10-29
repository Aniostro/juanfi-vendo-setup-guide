# network-and-hotspot.example.rsc
# Base network + hotspot server setup for a fresh hAP lite JuanFi vendo install.
# Verified against JuanFi's own official release (release-4.4 / Haplite/JuanFiHaplite_Script.rsc).
# Contains no secrets. Replace <NODEMCU_MAC> (appears twice: the DHCP lease and the
# hotspot IP-binding) with your NodeMCU's real MAC address.
# Import AFTER formatting the router to default config (see README step 2).

/interface wireless
set [ find default-name=wlan1 ] country=philippines disabled=no mode=\
    ap-bridge ssid="Piso WiFi"
/interface bridge
add name=bridge.HS
/interface ethernet
set [ find default-name=ether1 ] name=ether1.ISP
set [ find default-name=ether2 ] name=ether2.AP
set [ find default-name=ether3 ] name=ether3.AP
set [ find default-name=ether4 ] name=ether4.LAN
/interface list
add name=WAN
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/ip hotspot profile
add hotspot-address=10.0.0.1 login-by=cookie,http-chap,http-pap,mac-cookie \
    name="JuanFi Profile"

/ip hotspot user profile
set [ find default=yes ] on-login="..." on-logout="..." rate-limit=8M/8M
# (see hotspot-login-logic.example.rsc for the real on-login/on-logout content --
#  import that file, which sets this same property, instead of the line above.)

/ip pool
add name=HS ranges=10.0.0.6-10.0.0.254
add name=LAN ranges=192.168.88.2-192.168.88.254
/ip dhcp-server
add address-pool=HS disabled=no interface=bridge.HS name=dhcp1
add address-pool=LAN disabled=no interface=ether4.LAN name=dhcp2
/ip hotspot
add address-pool=HS addresses-per-mac=1 disabled=no idle-timeout=20s \
    interface=bridge.HS name=hotspot1 profile="JuanFi Profile"
/interface bridge port
add bridge=bridge.HS interface=ether2.AP
add bridge=bridge.HS interface=ether3.AP
add bridge=bridge.HS interface=wlan1
/ip address
add address=10.0.0.1/24 interface=bridge.HS network=10.0.0.0
add address=192.168.88.1/24 interface=ether4.LAN network=192.168.88.0
/ip dhcp-client
add disabled=no interface=ether1.ISP
/ip dhcp-server lease
add address=10.0.0.5 mac-address=<NODEMCU_MAC> server=dhcp1
/ip dhcp-server network
add address=10.0.0.0/24 gateway=10.0.0.1
add address=192.168.88.0/24 gateway=192.168.88.1
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,8.8.4.4
/ip firewall filter
add action=accept chain=input comment=NodeMCUIP src-address=10.0.0.5
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
/ip firewall mangle
add action=change-ttl chain=postrouting new-ttl=set:1 out-interface=bridge.HS \
    passthrough=no
/ip firewall nat
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=masquerade chain=srcnat out-interface=ether1.ISP
add action=masquerade chain=srcnat comment="masquerade hotspot network" \
    src-address=10.0.0.0/24
/ip hotspot ip-binding
add address=10.0.0.5 mac-address=<NODEMCU_MAC> server=hotspot1 \
    to-address=10.0.0.5 type=bypassed
/ip hotspot walled-garden
add comment="place hotspot rules here" disabled=yes
/ip hotspot walled-garden ip
add action=accept disabled=no dst-address=10.0.0.5

/system clock
set time-zone-name=Asia/Manila
/system ntp client
set enabled=yes primary-ntp=202.65.114.202 secondary-ntp=119.28.183.184
# NTP server IPs above are JuanFi's documented recommendation for the Philippines.
