# Hot Water Circulation Pump on Demand

## Overview

Runs a domestic hot water circulation pump in short 3-minute bursts instead of around the
clock, and only right before hot water is likely to be needed: shortly before someone gets
up, and when someone comes home. There are no fixed times. The pump hangs on a smart plug
(here an Eve Energy via HomeKit Controller), so the automation only switches mains power.

Key properties:

- **10 minutes before each phone alarm**, if the alarm's owner is at home and the run
  falls before noon. Every day, weekends included. No alarm, no run.
- **One run on arrival** of a person who was away for at least 30 minutes, at any time of
  day.
- **At least 30 minutes between starts.** Two alarms or two arrivals close together
  produce a single run.
- **No polling.** Alarm runs use time triggers on the alarm sensors, so they fire to the
  second and the automation does nothing in between.
- **Safety shutoff** after 10 minutes, in case the off command got lost.

Replayed against a week of real alarms and arrivals in this house: 0–4 runs a day, 14 runs
in six days. The earlier version with fixed morning and evening hours did 46 in the same
period. The pump draws 20.7 W, so electricity is negligible. The real saving is heat: the
loop is only kept warm when someone is about to use it.

Deployed on Home Assistant OS 2026.9.4, Raspberry Pi 4. Intended for a small house with
short pipes (bathroom, kitchen, WC).

## How it works

| Trigger | Runs if |
| --- | --- |
| `time` at a `next_alarm` sensor, offset −10 min | before 12:00 and the alarm's owner is `home` |
| `person.*` from `not_home` to `home` | the person was `not_home` for ≥ 30 min |

Both paths also require the pump to be off and the automation's last start to be at least
29 minutes ago (`this.attributes.last_triggered`). The minute of tolerance lets two alarms
exactly 30 minutes apart both count. Because the throttle uses the automation's own last
start rather than the plug's `last_changed`, a plug that briefly goes `unavailable` during
a Core restart does not block the next run.

Each alarm trigger's `id` is the entity of the person who owns the phone, so one condition
(`is_state(trigger.id, 'home')`) covers all phones. Adding a phone means adding one
trigger.

The trace shows which trigger fired and which condition blocked.

### Alarm handling

The Companion app's `next_alarm` sensor is a timestamp sensor. A time trigger with
`entity_id` and `offset` fires 10 minutes before that timestamp and follows the sensor
when the alarm is changed. Observed behaviour:

- OnePlus clock (`com.coloros.alarmclock`): the value stays until the alarm has rung, then
  jumps to the next alarm.
- Pixel clock: the value is set in the evening, and the sensor turns `unavailable` exactly
  at the alarm time.

Both keep the alarm time until it rings, which is all the trigger needs.

The noon cut-off is checked at the trigger time: an alarm at 12:05 still triggers at
11:55. An alarm on a phone whose owner is away (hotel, night shift) does nothing at home.

### Arrival filtering

Router-based presence (here Omada) occasionally reported everyone as away for ~33
seconds. An arrival only counts if the previous `not_home` lasted at least 30 minutes,
which also skips short errands. Transitions from `unknown` after a restart are ignored.
There is no time window: ten days of history showed no false arrival at night.

## Requirements

- Circulation pump on a switchable plug. If the pump has its own timer or learning mode
  (e.g. Grundfos AUTOADAPT), set it to continuous operation, otherwise it fights the plug.
  Do not also schedule the plug in the vendor app.
- `person.*` entities for everyone living there.
- Companion app `next_alarm` sensor enabled on each phone, **in HA and in the app**.
  Restrict it to the clock app's package (app settings → Manage sensors → Next alarm →
  allow list), otherwise calendar reminders can show up as alarms. Examples:
  `com.coloros.alarmclock` (OnePlus), `com.google.android.deskclock` (Pixel).
  A disabled or `unavailable` sensor is simply ignored.

## Hygiene

A single- or two-family house counts as a small installation under DVGW W 551. The rules on
circulation run times (at most 8 hours of interruption a day, 60/55 °C) apply to large
installations. What matters hygienically is the storage tank regularly reaching 60 °C,
which the pump does not affect. On days without alarm and arrival the pump does not run at
all and the return line stands still. With short pipes that is a small volume, and the same
already happens during holidays.

## Known limits

- Days without alarms and without arrivals, e.g. weekends at home, get no pre-warming. The
  first hot water takes as long as without circulation. This is intended.
- Two alarms less than 30 minutes apart produce one run, for the earlier alarm. The loop
  is not re-warmed for the later one.
- Time triggers do not catch up: a Core restart at the trigger time misses that run, and an
  alarm set less than 10 minutes ahead does not trigger.
- If presence drops out exactly at the trigger time, the alarm run is skipped.
- The 3-minute run time suits this house. Check it once: right after a run, open the tap
  farthest from the boiler. If hot water does not arrive immediately, increase the delay.

## Verification

- Automation trace → trigger and condition results.
- Log errors: `ha core logs | grep -iE "umwalz|error rendering"`.
- Pump history: `switch.umwalzpumpe`, `sensor.umwalzpumpe_power` (≈ 20.7 W while running).
