# JuanFi vendo setup guide (hAP lite + ESP8266 LanBased)

A step-by-step guide for setting up a new JuanFi Piso WiFi vendo on a **MikroTik hAP lite**
with a **wired (LAN-based) ESP8266 NodeMCU** coin-slot board, from a blank router to a working,
Telegram-alerted vendo.

> **Status:** the three `.rsc` files here are a sanitized, corrected copy of a script that is
> actually running on a real hAP lite vendo. The surrounding guide (reset steps, NodeMCU
> flashing, Telegram setup) has not been run end-to-end on hardware by whoever wrote this
> README. Test each step before relying on it, and read **Known issues** before you start.

## What's in this repo, and what isn't

| Included | Not included (you supply it) |
|---|---|
| `network-and-hotspot.example.rsc` -- interfaces, bridge, hotspot server, DHCP, firewall | The actual JuanFi hotspot portal pages (`hotspot/` folder: HTML, CSS, JS, sounds) |
| `hotspot-login-logic.example.rsc` -- the on-login/on-logout script that talks to the NodeMCU and sends the Telegram sale alert | The NodeMCU firmware (`.bin` files) and the flashing tool |
| `income-and-reports.example.rsc` -- running totals + daily Telegram/email report | The CH340/CH341 USB-to-serial driver (needed to flash the NodeMCU from a PC) |

The portal pages, firmware and driver are JuanFi's own distributed files (commonly shared as a
`release-4.4` bundle). This repo doesn't redistribute them -- get your own copy and drop it into
a local `release-4.4/` and `hotspot/` folder (both already in `.gitignore`), then follow the
steps below to put them on the right hardware.

## Hardware checklist

- MikroTik hAP lite (RB941-2nD)
- ESP8266 NodeMCU board, **LanBased** variant (has an Ethernet jack, not just WiFi)
- Coin acceptor wired to the NodeMCU's pulse input
- A PC with a USB port, for flashing the NodeMCU
- An Ethernet cable between the NodeMCU and the hAP lite's LAN-side port
- A Telegram account

## 1. Check the RouterOS version before you touch anything

**Use RouterOS 6.49.x, not v7.** On the hAP lite's 16MB flash, the hotspot package does not
fit alongside RouterOS v7 -- importing a hotspot-based JuanFi script on v7 will fail partway
through. If the router shipped with v7 or has been upgraded to it, downgrade first:

```routeros
/system package print
```

If it's not 6.49.x: try `/system package downgrade` first. If that fails for lack of free flash
space, use **Netinstall** (a separate Windows program, not a router command) to flash
RouterOS 6.49.23 directly. Netinstall wipes everything, including any existing hotspot files, so
do this before any other step.

## 2. Reset the router to a blank config

In WinBox or a terminal:

```routeros
/system reset-configuration no-defaults=yes skip-backup=yes
```

Reconnect to the router at its default address (192.168.88.1) afterward.

## 3. Flash the NodeMCU and note its MAC address

1. Install the CH340/CH341 USB-to-serial driver on your PC (from the JuanFi bundle's
   `CH341SER.zip`, or any up-to-date CH340 driver) so the board shows up as a COM port.
2. Connect the NodeMCU to the PC over USB.
3. Run the flashing tool from `release-4.4/release/LanBased/ESP8622/` (it's an `.exe`; on
   Windows only). Point it at `JuanFi-FlashFile1.bin` and `JuanFi-FlashFile2.bin` from the same
   folder, pick the correct COM port, and flash.
4. **Write down the NodeMCU's MAC address** -- either printed on the board itself, or read from
   the flashing tool / a serial monitor while it boots. You need it in the next step.

## 4. Import the network and hotspot config

Open `network-and-hotspot.example.rsc`, replace `<NODEMCU_MAC>` (appears twice: the DHCP lease
and the hotspot IP-binding) with the MAC from step 3, and
`<NODEMCU_MAC_LOWER_NO_COLONS_NO_LEADING_ZERO>` with the matching `client-id` value RouterOS
expects (lowercase, no colons, and the last octet without its leading zero -- e.g.
`8C:AA:B5:15:D6:00` becomes `8c:aa:b5:15:d6:0`).

Upload the edited file to the router (WinBox: **Files**, drag and drop) and run:

```routeros
/import file-name=network-and-hotspot.example.rsc
```

This sets up: the `bridge.HS` hotspot bridge, the `Piso WiFi` wireless network, the hotspot
server on `10.0.0.1/24`, a LAN side on `ether4.LAN` (192.168.88.1/24), DHCP, NAT/masquerade to
`ether1.ISP`, and a bypass + walled-garden entry so the NodeMCU (assumed at `10.0.0.5`) can reach
the network without going through the hotspot login itself.

If your NodeMCU should use a different IP than `10.0.0.5`, change every `10.0.0.5` in this file
consistently, and use the same IP in step 6's NodeMCU network settings.

## 5. Upload the hotspot portal files

Copy your `hotspot/` folder (from the JuanFi bundle's `Haplite/hotspot/`) to the router's file
system, at the top level (not inside a subfolder), via WinBox **Files** or FTP. The folder must
be named `hotspot` on a hAP lite (a hEX install uses `flash/hotspot` instead -- the scripts in
this repo already account for either, by reading the hotspot profile's `html-directory` setting
at runtime).

## 6. Create the Telegram bot

1. In Telegram, message **@BotFather** and send `/newbot`. Copy the **bot token**.
2. Send any message to your new bot (or add it to a group and message there).
3. Get the chat ID from `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
   (`message.chat.id`; a group's ID is negative).

## 7. Import the hotspot login logic

Open `hotspot-login-logic.example.rsc` and replace `<BOT_TOKEN>` and `<CHAT_ID>` with your real
values from step 6. Upload and import:

```routeros
/import file-name=hotspot-login-logic.example.rsc
```

### How this script talks to the NodeMCU (read this before debugging anything)

The NodeMCU doesn't call a separate API to record a sale -- it creates or updates a MikroTik
**hotspot user** and signals what happened through two fields on that user:

- **`comment`**: `"<minutes>m,<price>,<extension-code>,<vendo-name>"` -- e.g. `2880m,15,0,JuanFi
  Vendo` means a 2880-minute voucher that cost ₱15.
- **`email`**: a marker value, not a real email --
  - `new@gmail.com` = this is a brand-new voucher
  - `extend@gmail.com` = this is a top-up of an existing voucher
  - `bots@juanfi.local` = normal state once the script has processed the signal (what every
    already-created user sits at between events)

On every hotspot login, the on-login script reads these fields. If the email marker is `new@`
or `extend@`, it treats this as a sale: it updates the running income counters, builds the
voucher's expiry (`/system scheduler`, separate from the hotspot's own `limit-uptime`, so a
voucher can expire even if never fully used), resets the email back to the `bots@juanfi.local`
marker, and -- if Telegram is enabled -- sends the "New Sales" message with the voucher, MAC, IP,
amount, extension, total time, today's and monthly totals, active user count, and the expiry
time. If the marker is already `bots@juanfi.local`, it's an ordinary reconnect, and no sale is
recorded.

On logout, it checks whether the hotspot's own `limit-uptime` has been used up; if so, it
removes the user, active session, cookie and scheduler entirely (the voucher is spent). If not,
the user stays, ready for the next login.

A separate block (`isRandomMacSyncFix`) removes any other active session using the same voucher
on a different MAC address, which stops one voucher being used from two devices at once when a
phone's randomized MAC changes mid-session.

## 8. (Optional) Import income tracking and the daily report

This adds running today/monthly totals (shown in each sale alert) and a Telegram + email digest
at 23:55 daily.

1. In Gmail, create an **App Password** for the Gmail account you'll send from (Google Account →
   Security → App passwords; requires 2-Step Verification to be on).
2. Open `income-and-reports.example.rsc` and replace `<BOT_TOKEN>`, `<CHAT_ID>`,
   `<YOUR_GMAIL_ADDRESS>` and `<GMAIL_APP_PASSWORD>`.
3. Set the router's time zone and clock source first (the daily report runs on a schedule and the
   per-sale alert includes timestamps):

```routeros
/system clock set time-zone-name=Asia/Manila
/system ntp client set enabled=yes
```

4. Upload and import:

```routeros
/import file-name=income-and-reports.example.rsc
```

## 9. Wire up and connect

1. Connect the coin acceptor's pulse output to the NodeMCU as its firmware/documentation
   specifies.
2. Connect the NodeMCU to the hAP lite over Ethernet, on a LAN-side port (bridged into
   `bridge.HS` per `network-and-hotspot.example.rsc`).
3. Power on the NodeMCU. Confirm it gets `10.0.0.5` (or whatever IP you chose) from the router:

```routeros
/ip dhcp-server lease print
```

## 10. Test end-to-end

- **Hotspot portal:** connect a phone to the `Piso WiFi` network -- you should see the captive
  portal page.
- **Coin sale:** insert a coin. Within a few seconds you should see a new Telegram "New Sales"
  message, and the hotspot user list should show a new (or extended) voucher:

```routeros
/ip hotspot user print
```

- **Login/logout logging:** `/log print where message~"Hotspot INFO"` should show enter/exit
  lines for each connect and disconnect.
- **Daily report** (if installed): run it manually rather than waiting for 23:55:

```routeros
/system script run juanfi-daily-email
```

## Known issues to check on your own router

These were found by reading the script, not by testing on hardware -- confirm them yourself:

- **`uptime restore` scheduler:** the original export had `hsolduptime` used without its `$`
  sigil in one line, which would make RouterOS treat it as literal text instead of the stored
  variable. The copy in `income-and-reports.example.rsc` has the `$` added back in. This only
  affects restoring a voucher's remaining time after a router reboot -- verify it by rebooting
  the router mid-voucher and checking `/ip hotspot user get <voucher> limit-uptime` before and
  after.
- **Orphaned schedulers, if you're migrating from an existing router:** a live export this guide
  was built from had `juanfi-sale-alert-sched` (every minute) and `juanfi-seen-reset` (daily)
  schedulers pointing at a script named `juanfi-sale-alert` that did not exist in that export, so
  they would error on every run. Neither is included here. If you're copying config from an
  existing vendo rather than starting fresh, check `/system script print` for a script with that
  name before you also copy those two schedulers -- if it's missing, leave them out or recreate
  the script first.
- **Price table coverage:** `income-and-reports.example.rsc`'s daily report maps `limit-uptime`
  values to prices for the report only (sales themselves are priced by the NodeMCU, via the
  voucher's `comment` field, not by this table). If you add new voucher durations/prices on the
  NodeMCU side, add the matching `limit-uptime` line to that table too, or they'll show up as
  "unmatched" in the daily report.

## Troubleshooting

- **Hotspot import fails partway through:** almost always a RouterOS v7 flash-space issue (see
  step 1) or a stray non-ASCII character pasted into a script field. Re-copy the file rather than
  retyping it.
- **No Telegram message on sale:** check `/log print` for fetch errors first. Common causes: wrong
  bot token or chat ID, you never messaged the bot, or the router has no internet. Test the bot
  in isolation:

```routeros
/tool fetch mode=https keep-result=no http-method=post \
  url=("https://api.telegram.org/bot<BOT_TOKEN>/sendMessage") \
  http-data=("chat_id=<CHAT_ID>&text=test")
```

- **NodeMCU never shows up in `/ip dhcp-server lease print`:** check the Ethernet cable and
  that the NodeMCU is actually drawing power; check the bridge port list
  (`/interface bridge port print`) to confirm the LAN port is in `bridge.HS`.
- **Voucher created but no portal / wrong page shown:** the `hotspot` folder is missing, in the
  wrong location, or named differently than what the hotspot profile's `html-directory` expects
  -- re-check step 5.

## Security

- Keep real credentials only in your edited copies of the `.example.rsc` files on the router
  itself, or in a local `config.rsc` (git-ignored). Never commit a filled-in copy.
- `/export` and router backups include script sources in full, so don't share those files either.
- If a bot token or Gmail app password has ever been pasted into a chat, a doc, or committed to
  git, treat it as compromised: revoke the bot token in @BotFather (`/revoke`) and delete the
  Gmail app password, then issue new ones.
