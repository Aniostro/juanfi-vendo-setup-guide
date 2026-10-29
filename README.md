# JuanFi vendo setup guide (hAP lite + ESP8266 LanBased)

A step-by-step guide for setting up a new JuanFi Piso WiFi vendo on a **MikroTik hAP lite**
with a **wired (LAN-based) ESP8266 NodeMCU** coin-slot board, from a blank router to a working,
Telegram-alerted vendo.

> **Provenance:** `network-and-hotspot.example.rsc`, `hotspot-login-logic.example.rsc`,
> `base-income-and-uptime.example.rsc`, `settings.example.json` and everything under `hotspot/`
> are taken directly from JuanFi's own official release (`release-4.4`,
> `Haplite/JuanFiHaplite_Script.rsc` and `Haplite/hotspot/`) -- not reconstructed from memory.
> Only placeholders were substituted and two confirmed bugs fixed (listed under **Known
> issues** below); the logic is otherwise unchanged. `daily-report.example.rsc` is a separate,
> optional extra derived from a working hAP lite install, not part of the official release --
> treat it as less proven than the rest.
>
> The surrounding guide (reset steps, NodeMCU flashing order, Telegram setup) has not been run
> end-to-end on hardware by whoever wrote this README. Test each step before relying on it.

## What's in this repo, and what isn't

| File / folder | What it is |
|---|---|
| `network-and-hotspot.example.rsc` | Interfaces, bridge, hotspot server, DHCP, firewall, clock/NTP |
| `hotspot-login-logic.example.rsc` | The on-login/on-logout script that talks to the NodeMCU and sends the Telegram sale alert |
| `base-income-and-uptime.example.rsc` | Income counters + reboot-safe voucher uptime (required companions to the login logic) |
| `daily-report.example.rsc` | **Optional.** End-of-day Telegram + email sales digest (not part of the official release) |
| `hotspot/` | The actual JuanFi captive-portal pages (HTML/CSS/JS/images/sounds) |
| `settings.example.json` | Sanitized copy of the portal's `settings.json` (SSID, vendo name, GCash gateway) |

**Not included:** the NodeMCU firmware (`.bin` files), the flashing tool, and the
CH340/CH341 USB-to-serial driver. These are binary, platform-specific (Windows `.exe`) tools
from the same `release-4.4` bundle -- keep them in your own local copy (`.gitignore` already
excludes `*.bin`, `*.exe` and `/release-4.4/` so you can keep that folder alongside this repo
without committing it).

## Hardware checklist

- MikroTik hAP lite (RB941-2nD)
- ESP8266 NodeMCU board, **LanBased** variant (has an Ethernet jack, not just WiFi)
- Coin acceptor wired to the NodeMCU's pulse input
- A PC with a USB port, for flashing the NodeMCU
- An Ethernet cable between the NodeMCU and the hAP lite's LAN-side port
- A Telegram account (optional, for alerts)

## 1. Check the RouterOS version before you touch anything

**Use RouterOS 6.49.x, not v7.** On the hAP lite's 16MB flash, the hotspot package does not
fit alongside RouterOS v7 -- importing a hotspot-based JuanFi script on v7 will fail partway
through. Check what's installed:

```routeros
/system package print
```

If it's not 6.49.x: try `/system package downgrade` first. If that fails for lack of free flash
space, use **Netinstall** (a separate Windows program, not a router command) to flash
RouterOS 6.49.23 directly. Netinstall wipes everything, including any existing hotspot files, so
do this before any other step.

## 2. Reset the router to a blank config

```routeros
/system reset-configuration no-defaults=yes skip-backup=yes
```

Reconnect to the router at its default address (192.168.88.1) afterward.

## 3. Flash the NodeMCU and note its MAC address

1. Install the CH340/CH341 USB-to-serial driver on your PC (from the JuanFi bundle's
   `CH341SER.zip`) so the board shows up as a COM port.
2. Connect the NodeMCU to the PC over USB.
3. Run the flashing tool from `release-4.4/release/LanBased/ESP8622/` (Windows `.exe`). Point it
   at `JuanFi-FlashFile1.bin` and `JuanFi-FlashFile2.bin` from the same folder, pick the correct
   COM port, and flash.
4. **Write down the NodeMCU's MAC address** -- printed on the board, or read from the flashing
   tool / a serial monitor while it boots. You need it in the next step.

## 4. Import the network and hotspot config

Open `network-and-hotspot.example.rsc` and replace `<NODEMCU_MAC>` (appears twice: the DHCP
lease and the hotspot IP-binding) with the MAC from step 3.

Upload the edited file to the router (WinBox: **Files**, drag and drop) and run:

```routeros
/import file-name=network-and-hotspot.example.rsc
```

This sets up: the `bridge.HS` hotspot bridge, the `Piso WiFi` wireless network, the hotspot
server on `10.0.0.1/24`, a LAN side on `ether4.LAN` (192.168.88.1/24), DHCP, NAT/masquerade to
`ether1.ISP`, a bypass + walled-garden entry so the NodeMCU (assumed at `10.0.0.5`) can reach
the network without going through the hotspot login itself, and the clock/NTP settings.

If your NodeMCU should use a different IP than `10.0.0.5`, change every `10.0.0.5` in this file
and in `settings.example.json` consistently.

The file also contains a placeholder line noting that the real on-login/on-logout content comes
from `hotspot-login-logic.example.rsc` (step 7) -- don't import that placeholder line literally,
import the real file instead.

## 5. Upload the hotspot portal files

Copy the whole `hotspot/` folder from this repo to the router's file system, at the top level
(not inside a subfolder), via WinBox **Files** or FTP. The folder must be named `hotspot` on a
hAP lite (a hEX install uses `flash/hotspot` instead -- the scripts already handle either, by
reading the hotspot profile's `html-directory` setting at runtime).

Then open `settings.example.json`, fill in `<YOUR_SSID>` and `<YOUR_VENDO_NAME>`, and upload it
to `hotspot/settings.json` on the router (replacing the placeholder copy). Leave
`gcash_payment` as `false` unless you have your own GCash merchant integration -- if you do,
fill in `<GCASH_PAYMENT_GATEWAY_URL>` and `<GCASH_PORTAL_KEY>` from your provider and flip the
top-level `gcash_payment` flag to `true`.

## 6. Create the Telegram bot (optional)

Skip this if you don't want Telegram alerts -- Telegram is off by default
(`isTelegram 0` in the login script).

1. In Telegram, message **@BotFather** and send `/newbot`. Copy the **bot token**.
2. Send any message to your new bot (or add it to a group and message there).
3. Get the chat ID from `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
   (`message.chat.id`; a group's ID is negative).

## 7. Import the hotspot login logic

Open `hotspot-login-logic.example.rsc`. If you want Telegram alerts, change `isTelegram 0` to
`isTelegram 1` and replace `iTBotToken` / `iTGrChatID`'s placeholder values with your real
token and chat ID from step 6. Upload and import:

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

## 8. Import income tracking (required companion to step 7)

```routeros
/import file-name=base-income-and-uptime.example.rsc
```

This adds the `todayincome`/`monthlyincome` running totals the sales block in step 7 writes to,
their daily/monthly resets, and the reboot-safe voucher uptime restore.

## 9. (Optional) Import the daily sales digest

Adds a Telegram + email report at 23:55 daily. Requires step 8 and a Gmail App Password.

1. In Gmail, create an **App Password** (Google Account → Security → App passwords; requires
   2-Step Verification to be on).
2. Open `daily-report.example.rsc` and replace `<BOT_TOKEN>`, `<CHAT_ID>`,
   `<YOUR_GMAIL_ADDRESS>` and `<GMAIL_APP_PASSWORD>`.
3. Upload and import:

```routeros
/import file-name=daily-report.example.rsc
```

## 10. Wire up and connect

1. Connect the coin acceptor's pulse output to the NodeMCU as its firmware/documentation
   specifies.
2. Connect the NodeMCU to the hAP lite over Ethernet, on a LAN-side port (bridged into
   `bridge.HS`).
3. Power on the NodeMCU. Confirm it gets `10.0.0.5` (or whatever IP you chose) from the router:

```routeros
/ip dhcp-server lease print
```

## 11. Test end-to-end

- **Hotspot portal:** connect a phone to the `Piso WiFi` network -- you should see the captive
  portal page.
- **Coin sale:** insert a coin. If Telegram is enabled, you should see a "New Sales" message
  within a few seconds, and the hotspot user list should show a new (or extended) voucher:

```routeros
/ip hotspot user print
```

- **Login/logout logging:** `/log print where message~"Hotspot INFO"` should show enter/exit
  lines for each connect and disconnect.
- **Daily report** (if installed): run it manually rather than waiting for 23:55:

```routeros
/system script run juanfi-daily-email
```

## Known issues (confirmed in JuanFi's own release, fixed here)

- **`uptime restore` scheduler** (in `base-income-and-uptime.example.rsc`): the official file
  uses `hsolduptime` without its `$` sigil in one line, which makes RouterOS read it as literal
  text instead of the stored variable. Fixed here by adding the `$` back in. This only affects
  restoring a voucher's remaining time after a router reboot -- verify it yourself by rebooting
  the router mid-voucher and checking `/ip hotspot user get <voucher> limit-uptime` before and
  after.
- **`daily-report.example.rsc`'s price table** (not part of the official release): had a typo,
  `0e:00:00`, with no 14-hour entry to match, so a 14h/₱25 voucher would show up as "unmatched"
  in the daily report. Fixed to `14:00:00`. If you add new voucher durations/prices on the
  NodeMCU side, add the matching `limit-uptime` line to this table too (sales themselves are
  priced by the NodeMCU via the voucher's `comment` field, not by this table -- it only affects
  the daily report's own breakdown).
- **Orphaned schedulers, if you're migrating config from an existing router instead of starting
  fresh:** some live hAP lite exports carry schedulers like `juanfi-sale-alert-sched` or
  `juanfi-seen-reset` pointing at a script that no longer exists, which then errors on every
  run. Check `/system script print` for the named script before copying any scheduler that
  references one, from any router.

## Security

- `hotspot-login-logic.example.rsc` has Telegram off and placeholder credentials by default.
  Only fill in a real token/chat ID in your own copy on the router, or in a local `config.rsc`
  (git-ignored) -- never commit a filled-in copy.
- The portal's `settings.json` can hold a real GCash `portal_key`, which is a credential, not a
  public setting -- keep your filled-in copy off of git the same way.
- `/export` and router backups include script sources in full, so don't share those either.
- If a bot token or Gmail app password has ever been pasted into a chat, a doc, or committed to
  git, treat it as compromised: revoke the bot token in @BotFather (`/revoke`) and delete the
  Gmail app password, then issue new ones.
- The NodeMCU side also ships with default `admin`/`admin` (and `operator`/`operator`) web
  credentials in some releases -- change these on the device itself once it's set up.

## Troubleshooting

- **Hotspot import fails partway through:** almost always a RouterOS v7 flash-space issue (see
  step 1) or a stray non-ASCII character pasted into a script field. Re-copy the file rather than
  retyping it.
- **No Telegram message on sale:** check that `isTelegram` is `1`, not `0`, then check
  `/log print` for fetch errors. Common causes: wrong bot token or chat ID, you never messaged
  the bot, or the router has no internet.
- **NodeMCU never shows up in `/ip dhcp-server lease print`:** check the Ethernet cable and
  that the NodeMCU is actually drawing power; check the bridge port list
  (`/interface bridge port print`) to confirm the LAN port is in `bridge.HS`.
- **Voucher created but no portal / wrong page shown:** the `hotspot` folder is missing, in the
  wrong location, or named differently than what the hotspot profile's `html-directory` expects
  -- re-check step 5.
