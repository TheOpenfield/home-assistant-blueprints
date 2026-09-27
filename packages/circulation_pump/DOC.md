# Hot Water Circulation Pump on Demand

## Overview

Runs a domestic hot water circulation pump in short 3-minute bursts instead of around the
clock. The pump hangs on a smart plug (here an Eve Energy via HomeKit Controller), so the
automation only switches mains power.

Key properties:

- **Only when someone is home** (`zone.home > 0`). On holiday the pump never runs.
- **Weekday mornings follow the phone alarms** of everyone at home: one run 10 minutes
  before each alarm, one about 20–25 minutes after it.
- **Fixed hours only when no alarm was set that morning**, and on weekends: 07:00, 08:00,
  09:00.
- **Evenings hourly** from 18:00 to 21:00.
- **One run on arrival** of a person who was away for at least 20 minutes.
- **One shared throttle** merges everything: at least 30 minutes between starts for alarm
  and arrival runs, 60 minutes for fixed hours. Close alarms, an arrival just before a
  fixed slot, or an alarm next to a fixed time never cause extra runs.
- **Safety shutoff** after 10 minutes, in case the off command got lost.

Typical day: 6–8 runs, 18–24 minutes of pump time. The pump draws 20.7 W, so electricity
is negligible (~7 Wh/day). The real saving is heat: the circulation loop no longer loses
energy around the clock.

Deployed on Home Assistant OS 2026.9.3, Raspberry Pi 4.

## How it works

A single automation evaluates a `phase` variable every 5 minutes and on each arrival:

| Phase | When | Min. gap between starts |
| --- | --- | --- |
| `wecker` | Weekdays, 10 min before to the alarm, and 20–35 min after it | 30 min |
| `ohne_wecker` | Weekdays 07:00–10:00, only if nobody at home had an alarm that morning | 60 min |
| `wochenende` | Sat/Sun 07:00–10:00 | 60 min |
| `abend` | Daily 18:00–22:00 | 60 min |
| `ankunft` | A person comes home after ≥ 20 min away, 05:00–23:00 | 30 min |
| `''` | Anything else, the automation stops at the first condition | – |

The gap is implemented as "pump off for at least 26 (or 56) minutes": 3 minutes of run
time plus the pause, rounded up by the 5-minute tick. Each trace shows the `phase` value,
so it is always visible why the pump ran or not.

### Alarm handling

The Companion app's `next_alarm` sensor holds the next alarm as a timestamp. After the
alarm rings, the sensor jumps to the following alarm, so today's alarm is gone. The
template therefore treats the sensor's **last change today** as the alarm time once the
alarm has passed. If the sensor does not update at all, the stale value still produces the
two runs.

An alarm suppresses the fixed hours if its owner is at home or left **after** the alarm
rang (compared against `person.*.last_changed`). An alarm set on the phone in a hotel does
not suppress anything at home.

The alarm windows are wider than the 5-minute tick on purpose: if the throttle blocks a
run because another person's alarm just triggered one, the run is caught up once the
throttle clears instead of being dropped.

### Arrival filtering

Router-based presence (here Omada) occasionally reports everyone as away for ~33 seconds.
The arrival trigger fires on `person.*` going from `not_home` to `home` and only counts if
the previous `not_home` lasted at least 20 minutes. Transitions from `unknown` after a
restart are ignored.

## Requirements

- Circulation pump on a switchable plug. If the pump has its own timer or learning mode
  (e.g. Grundfos AUTOADAPT), set it to continuous operation, otherwise it fights the plug.
  Do not also schedule the plug in the vendor app.
- `person.*` entities for everyone living there.
- Companion app `next_alarm` sensor enabled on each phone, **in HA and in the app**.
  Restrict it to the clock app's package (app settings → Manage sensors → Next alarm →
  allow list), otherwise calendar reminders can show up as alarms. Examples:
  `com.coloros.alarmclock` (OnePlus), `com.google.android.deskclock` (Pixel).
  A disabled or missing sensor is simply ignored.

## Known limits

- A Core restart between 04:00 and 10:00 on a weekday changes the alarm sensors'
  `last_changed` and is taken for an alarm: one extra run and no fixed hours that morning.
- The second alarm run lands 20–25 minutes after the alarm because of the 5-minute tick.
- Public holidays on weekdays count as weekdays. Without an alarm they fall back to the
  fixed hours anyway.
- The 3-minute run time suits this house. Check it once: right after a run, open the tap
  farthest from the boiler. If hot water does not arrive immediately, increase the delay.

## Verification

- Automation trace → *Variables* → `phase`.
- Log errors: `ha core logs | grep -iE "umwalz|error rendering"`.
- Pump history: `switch.umwalzpumpe`, `sensor.umwalzpumpe_power` (≈ 20.7 W while running).
