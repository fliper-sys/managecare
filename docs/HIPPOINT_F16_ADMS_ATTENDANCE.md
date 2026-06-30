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

If the terminal separates the host and path fields, use:

```text
Server host: us-central1-manage-care-1e96b.cloudfunctions.net
Port: 443
Path/function: iclock
Protocol: HTTPS, if the firmware provides that option
```

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
- Workers that still need terminal user IDs
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
4. Open `Comm -> Cloud Server Setting`.
5. Set the server host to:

```text
us-central1-manage-care-1e96b.cloudfunctions.net
```

6. Set the port to:

```text
443
```

7. Set the path/function to one of these values depending on firmware:

```text
iclock
```

or:

```text
/iclock
```

8. Enable ADMS/cloud push mode if the device has a switch for it.
9. Save the settings.
10. Restart or reconnect the terminal if it does not sync immediately.
11. Enroll each worker with face/fingerprint.
12. Record the terminal user ID assigned to each worker.

The terminal user ID is the most important mapping value. The backend uses it
to decide which app worker owns each punch.

## App Device Setup

Open:

```text
Attendance -> Device Setup -> Add F16 Device
```

Enter:

- Device name: example `Hippoint F16 Main Gate`
- LAN IP address: the local IP shown on the device
- TCP port: usually `4370`
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
port: 4370
isActive: true
```

## Worker Mapping Setup

Each worker must have a terminal user ID matching the ID enrolled on the F16.

Open:

```text
Workers -> Edit Permissions
```

Set:

```text
Attendance terminal user ID
```

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
port: 4370
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

Check LAN internet, cloud server host, port `443`, ADMS path, and terminal time.

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
