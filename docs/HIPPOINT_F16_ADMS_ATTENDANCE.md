# Hippoint F16 Attendance System Guide

This guide explains how to configure the Hippoint F16 face/fingerprint
attendance terminal, how the app receives and sorts attendance, and how owners
or managers can check whether the full system is ready.

## Production Endpoint

Firebase function:

```text
https://us-central1-manage-care-1e96b.cloudfunctions.net/iclock
```

ADMS paths handled by the function:

```text
GET  /iclock/cdata?SN=<serial>&options=all
POST /iclock/cdata?SN=<serial>&table=ATTLOG
GET  /iclock/getrequest?SN=<serial>
```

## Package Strategy

Two Flutter packages were reviewed for this ZKTeco workflow:

```text
flutter_zkteco
zkfinger10
```

Recommendation:

Use `flutter_zkteco` only for optional LAN/admin operations, and keep ADMS push
as the production attendance path.

Why:

- `flutter_zkteco` connects to network fingerprint machines over TCP/IP.
- It can retrieve attendance logs.
- It can retrieve device users.
- It lets the app test whether the terminal is reachable on LAN.
- The constructor accepts a custom port, so this device can be tested with
  `5005` instead of the common ZKTeco `4370`.

Do not use `zkfinger10` for this wall-mounted attendance terminal.

Why:

- `zkfinger10` targets USB ZKTeco fingerprint scanners such as SLK20R, ZK9500,
  ZK6500, and ZK8500R.
- It is useful for a separate Android USB enrollment station.
- It does not manage this Ethernet/WiFi attendance terminal over ADMS or TCP/IP.

Best-fit architecture:

```text
Production:
F16 terminal -> ADMS relay/server -> Firebase iclock function -> Firestore

Optional LAN tools:
Manage Care app/admin device -> flutter_zkteco -> F16 terminal on same LAN
```

Use `flutter_zkteco` for:

- Test LAN connection to the device IP.
- Pull attendance logs manually when ADMS is unavailable.
- Pull user list to help map terminal IDs to app workers.
- Compare terminal users against worker cards in `Attendance -> Device Setup`.

LAN connection timeout checklist:

- Run LAN tools from Android, Windows, or another native Flutter target. Flutter
  web/Chrome cannot open raw TCP sockets to the terminal.
- Use the terminal `IP Address` from `Network -> Ethernet` or `Network -> WIFI`,
  not the ADMS `Server IP`.
- The phone, tablet, or computer running the app must be on the same local
  network as the terminal.
- Confirm the saved device `Ethernet Port No` matches the terminal `Port No`.
  The photographed manual/device screens show `5005`.
- If the terminal is on guest WiFi, disable client isolation or move the app
  device to the same normal LAN.
- If TCP socket opens but the ZKTeco handshake fails, check the terminal
  communication password and whether LAN SDK/TCP-IP access is enabled.

Do not rely on `flutter_zkteco` alone for:

- Cloud/offsite attendance sync.
- Devices behind NAT where the phone cannot reach the terminal IP.
- Full user enrollment workflows such as face/fingerprint capture.
- Every low-level device configuration screen.

Use the physical terminal for enrollment and sensitive operations:

```text
MENU -> User -> Enroll
MENU -> User -> Browse
MENU -> User -> Modify
MENU -> User -> Delete
DevSet -> Set COMM -> Network
```

Implemented LAN tool path:

1. `flutter_zkteco` is added to `pubspec.yaml`.
2. The app uses a guarded LAN service with a stub for unsupported platforms.
3. Each saved device card includes actions:
   - Test connection
   - Pull users
   - Pull attendance logs
4. Pulled terminal users can be mapped to app workers.
5. Worker cards can still be edited manually when LAN access is unavailable.

Keep the current ADMS backend even after LAN tools are added. ADMS is the better
production path because the terminal pushes attendance without requiring an
admin phone to be online on the same local network.

If the terminal supports DNS/hostnames and path fields, use:

```text
Server host: us-central1-manage-care-1e96b.cloudfunctions.net
Port: 443
Path/function: iclock
Protocol: HTTPS, if the firmware provides that option
```

Your photographed terminal variant stores the server name as `www.fkweb.com`,
but the practical test fields are `Server IP` and `SerPortNo`. For that model,
use an IP-based ADMS relay/server:

```text
Server IP: <public relay IP>
SerPortNo: 7005
```

The relay should forward the terminal ADMS requests to:

```text
https://us-central1-manage-care-1e96b.cloudfunctions.net/iclock
```

For quick testing on a reachable Windows/Linux machine or VPS, this repo now
includes a simple relay:

```bash
node tools/zkteco_adms_relay.js
```

It listens on port `7005` by default. Set the terminal `Server IP` to that
machine's reachable IP address and `SerPortNo` to `7005`.

Optional environment variables:

```text
PORT=7005
HOST=0.0.0.0
ZK_UPSTREAM_HOST=us-central1-manage-care-1e96b.cloudfunctions.net
ZK_UPSTREAM_FUNCTION=iclock
```

The photographed terminal screens show the factory/FKWeb ADMS relay settings:

```text
DevSet -> Set COMM -> Network
Server Req: Yes

Network -> Server Set
DNS: Yes
Server Name: www.fkweb.com
SerPortNo: 7005

Network -> Ethernet
DHCP: No
Port No: 5005
```

For this firmware, leave the stored `www.fkweb.com` server name as-is if the
device does not allow editing it. Place a relay/proxy in front of the Firebase
function and point the terminal to the relay IP.

## What Users Should See In The App

Open:

```text
Attendance -> Device Setup
```

The screen shows a live status checklist:

- Device registered
- Worker terminal IDs mapped
- Active schedules created
- Punches received today
- Unmatched punches count

The screen also includes:

- The cloud endpoint to enter on the terminal
- Registered F16 devices
- Worker terminal ID cards that can be tapped to add, edit, or clear IDs
- Device setup instructions
- App setup instructions
- Attendance sorting explanation
- Troubleshooting status notes

## Readiness Checklist

Before relying on biometric attendance, all required items should pass.

Required:

- At least one active F16 device is registered in the app.
- The registered device serial number exactly matches the F16 serial number.
- Each worker has a matching F16 terminal user ID in the app.
- Each worker has an active attendance schedule.
- The terminal date and time are correct.
- Test punches appear in `Attendance -> Today -> Live Device Punches`.
- Unmatched punch count is zero after worker IDs are mapped.

Optional but recommended:

- Confirm the terminal has stable Ethernet/LAN internet.
- Confirm the terminal is using the same timezone expected by the station.
- Run a morning and evening test punch for one worker.
- Confirm worker history shows check-in and check-out for the same day.

## Physical Device Setup

Use the terminal menu on the Hippoint F16.

1. Connect the F16 to Ethernet/LAN.
2. Confirm the terminal has internet access.
3. Set the terminal date and time correctly.
4. Open `DevSet -> Set COMM -> Network`.
5. In `Ethernet`, configure the LAN values and keep `Port No` as:

```text
5005
```

6. In `Network`, set:

```text
Server Req: Yes
```

7. Open `Server Set`.
8. The stored `Server Name` on this unit is `www.fkweb.com`. Leave it as-is if
the terminal does not allow editing it.
9. Enter the public IP of the ADMS relay/server in `Server IP` and set
`SerPortNo` to:

```text
7005
```

The relay should forward `/iclock/cdata` and `/iclock/getrequest` requests to
the Firebase function.

10. If the firmware supports DNS/hostnames, direct Firebase testing can use this
server host:

```text
us-central1-manage-care-1e96b.cloudfunctions.net
```

and this port:

```text
443
```

The photos show the default FKWeb relay host and port instead:

```text
DNS: Yes
Server Name: www.fkweb.com
SerPortNo: 7005
```

Those default FKWeb settings will not post directly to the Firebase function
unless FKWeb is configured to forward to this app.

11. Set the path/function to one of these values if the firmware exposes a path
field:

```text
iclock
```

or:

```text
/iclock
```

12. Enable ADMS/cloud push mode if the device has a switch for it.
13. Save the settings.
14. Restart or reconnect the terminal if it does not sync immediately.
15. Enroll each worker with face/fingerprint.
16. Record the terminal user ID assigned to each worker.

The terminal user ID is the most important mapping value. The backend uses it
to decide which app worker owns each punch.

## Manual Quick Reference

Keypad:

- `MENU`: open device menu.
- `OK`: confirm.
- `ESC`: exit or cancel.
- Up/down keys: move between menu options.
- `0`: change input method while editing text or numbers.

Add a user:

```text
MENU -> User -> Enroll
```

Enter the device user `ID` and `Name`, then register face, finger, card, or
password. The `ID` is the value to save in the app worker terminal ID field.

Browse or modify a user:

```text
MENU -> User -> Browse
```

Select a user to modify ID, name, card, password, position, privilege, face, or
finger records. Use this when you need to confirm the terminal ID before saving
it in the app.

Privileges:

- `User`: normal attendance user.
- `Admin`: can enter menus and operate the device.

Use `Admin` only for managers or trusted operators. If no admin is set, anyone
can enter the menu.

USB/download:

- `Report.xls`: attendance report in Excel format.
- `Log.txt`: attendance record in text format.
- The manual recommends FAT32 USB drives under 32GB from common brands.

Network:

- `Server Req`: set to `Yes`.
- Ethernet `Port No`: `5005`.
- ADMS `SerPortNo`: `7005`.
- Keep the date, time, and timezone correct before testing punches.

WiFi:

```text
Network -> WIFI Setting -> Enable -> Search
```

Choose the WiFi network and enter the password. Use DHCP unless your local
network requires a static IP.

## App Device Setup

Open:

```text
Attendance -> Device Setup -> Add F16 Device
```

Enter:

- Device name: example `Hippoint F16 Main Gate`
- Device LAN IP address: the local IP shown on the device; required for Test
  LAN, Pull users, and Pull logs
- Ethernet Port No: `5005`, matching the photographed Ethernet screen
- Stored Server Name: `www.fkweb.com`
- Server IP: the public IP of your ADMS relay/server
- SerPortNo: `7005`, matching the photographed server port
- Serial number: the exact serial printed on the device or box

The serial number must match the value sent by the device as `SN`.

Stored location:

```text
businesses/{businessId}/attendance_devices/{deviceId}
```

Important fields:

```text
serialNumber: "2510200453"
model: "F16"
protocol: "zkteco_adms"
syncMode: "adms_push"
ethernetPort: 5005
serverIp: "203.0.113.10"
serverName: "www.fkweb.com"
serverPort: 7005
firebaseAdmsHost: "us-central1-manage-care-1e96b.cloudfunctions.net"
firebaseAdmsPort: 443
firebaseAdmsPath: "iclock"
isActive: true
```

## Worker Mapping Setup

Each worker must have a terminal user ID matching the ID enrolled on the F16.

Open:

```text
Attendance -> Device Setup -> Worker terminal IDs
```

Tap the worker card, enter the device `ID`, and save. The app stores the same
value in `terminalUserId`, `deviceUserId`, and `attendanceDeviceUserId` so older
records and backend matching paths stay compatible.

The backend checks these worker fields:

```text
terminalUserId
deviceUserId
attendanceDeviceUserId
```

At least one of those fields must match the F16 terminal user ID.

Example:

```text
workers/{workerId}
businessId: "{businessId}"
terminalUserId: "1001"
```

Do not rely on worker names for matching. Names on the terminal can differ from
names in the app. The terminal user ID is the stable identifier.

## Schedule Setup

Open:

```text
Attendance -> Schedules -> Schedule
```

Configure:

- Worker
- Device user ID
- Start time
- End time
- Days of week
- Optional weeks of month
- Late grace minutes

Stored location:

```text
businesses/{businessId}/attendance_schedules/{scheduleId}
```

Schedules are used to calculate:

- Absent
- Late
- Checked in
- Present

Without schedules, punches can still be stored, but the system cannot reliably
calculate lateness or expected attendance.

## How Data Flows

1. A worker punches on the F16.
2. The F16 sends an ADMS `ATTLOG` row to the Firebase `iclock` function.
3. The function checks the device serial number.
4. The function finds the registered business device.
5. The function matches the terminal user ID to a worker.
6. The raw punch is stored in `attendance_punches`.
7. The daily worker log is updated in the business attendance logs.
8. The app listens to Firestore snapshots and updates in real time.

Canonical raw punch collection:

```text
attendance_punches/{punchId}
```

Daily UI log collection:

```text
businesses/{businessId}/attendance_logs/{workerId}_{dateKey}
```

Unmatched/error collection:

```text
attendance_punches_unmatched/{punchId}
```

## How Punches Are Sorted

For each worker and date:

- First punch becomes `check_in`.
- Second punch becomes `check_out`.
- Third punch becomes `check_in`.
- Fourth punch becomes `check_out`.

This alternating approach supports:

- Normal check-in/check-out
- Breaks
- Return from break
- Extra audit punches

The raw punch history is preserved in `attendance_punches`, while the daily
worker summary is mirrored to `attendance_logs`.

## Status Check Meaning

Device registered:

The business has at least one active F16 device saved with a serial number.

Worker IDs mapped:

At least one worker has a terminal ID. Ideally every active worker should be
mapped.

Schedules:

At least one active schedule exists. Schedules are required for late and absent
analytics.

Punches today:

The device has successfully pushed attendance for the selected day. If this is
zero before workers arrive, it may be normal. If this is zero after test
punches, check the network and endpoint settings.

Unmatched punches:

The backend received logs, but could not match the terminal user ID to an app
worker. Fix the worker terminal ID, then test again.

## First Live Test

1. Add the device in the app.
2. Map one worker with the F16 terminal user ID.
3. Create one active schedule for that worker.
4. Punch once on the terminal.
5. Open `Attendance -> Today -> Live Device Punches`.
6. Confirm the worker name appears.
7. Open `Attendance -> My History`.
8. Confirm the day shows a check-in time.
9. Punch again.
10. Confirm the day shows a check-out time.

Expected result:

```text
attendance_punches: raw punch rows exist
attendance_logs: worker daily checkInAt/checkOutAt updated
attendance_punches_unmatched: no new entries for mapped workers
```

## Emulator Test

Start emulators:

```bash
firebase emulators:start --only functions,firestore
```

Register a device in Firestore first:

```text
businesses/{businessId}/attendance_devices/{deviceId}
serialNumber: "2510200453"
name: "Hippoint F16"
protocol: "zkteco_adms"
syncMode: "adms_push"
ethernetPort: 5005
serverIp: "203.0.113.10"
serverName: "www.fkweb.com"
serverPort: 7005
isActive: true
```

Set a worker terminal ID:

```text
workers/{workerId}
businessId: "{businessId}"
terminalUserId: "1001"
```

Handshake:

```bash
curl "http://127.0.0.1:5001/manage-care-1e96b/us-central1/iclock/cdata?SN=2510200453&options=all&pushver=2.4"
```

Simulated ATTLOG upload:

```bash
curl -X POST "http://127.0.0.1:5001/manage-care-1e96b/us-central1/iclock/cdata?SN=2510200453&table=ATTLOG" \
  -H "Content-Type: text/plain" \
  --data-binary $'1001\t2026-06-29 08:01:00\t0\t1\n1001\t2026-06-29 17:02:00\t1\t1\n'
```

Command polling:

```bash
curl "http://127.0.0.1:5001/manage-care-1e96b/us-central1/iclock/getrequest?SN=2510200453"
```

## Troubleshooting

No device registered:

Add the F16 in `Attendance -> Device Setup`. Use the exact serial number.

No punches today:

Check LAN internet, `Server Req=Yes`, Server IP, ADMS server port, ADMS path,
and terminal time. For this IP-only firmware, the Server IP must be an ADMS
relay/proxy that forwards to the Firebase `iclock` function. The photographed
`www.fkweb.com:7005` setting only works if that relay is forwarding to this app.

Unmatched punches:

The device is sending logs, but the terminal user ID does not match a worker.
Open the worker profile and correct the attendance terminal user ID.

Wrong check-in or check-out order:

Check the physical terminal clock. The backend sorts by punch timestamp and
alternates punch direction per worker per date.

Device sends logs but no worker appears:

Confirm the serial number in `attendance_devices` matches the `SN` sent by the
terminal.

Late/absent analytics look wrong:

Confirm the schedule days, start time, grace minutes, and weeks of month.

## Production Notes

HTTP Cloud Functions and Firestore writes require Firebase billing to be enabled
for production usage. Confirm in Firebase Console:

```text
Project settings -> Usage and billing -> Details & settings
```

Keep the Cloud Function endpoint available publicly enough for the terminal to
reach it. The F16 is not a signed-in app user, so it cannot use normal Firebase
client authentication.
