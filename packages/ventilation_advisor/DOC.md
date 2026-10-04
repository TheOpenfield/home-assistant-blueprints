# Ventilation Advisor (Lüftungsempfehlung)

## Overview

A dashboard page that tells you, per room, whether opening the windows will actually dry
the air, plus a push notification when a room is too humid and the outside air is drier.
Outdoor data comes from the Met.no weather entity, indoor data from two existing sensors.
Everything is computed with template entities and Jinja macros; no HACS, no custom cards,
no extra integration.

Key properties:

- **Physics instead of percentages.** Relative humidity alone cannot tell you whether
  ventilating helps. The package compares *absolute* humidity (g/m³) and dew points of
  room air and outside air, computed with the Magnus formula (Sonntag 1990 coefficients).
- **Per-room recommendation** in seven plain-language states, colour-coded with the
  built-in `ha-alert` element, plus the water mass one air change would remove.
- **Weather forecast as outdoor source.** No outdoor sensor is needed. The current Met.no
  values (temperature, humidity, dew point) feed the comparison, the hourly forecast gives a
  12-hour outlook ("ventilating pays off at 13, 14, 15 h").
- **Adjustable without redeploying.** Target and warning humidity per room, the minimum
  useful humidity difference and the room volumes are `input_number` sliders on the page.
- **Low recorder load by design.** All derived values are trigger-based template entities
  that update every 10 minutes, not on every tick of the fast-reporting Govee sensor.
- **Honest about stale data.** The basement sensor reports over Bluetooth LE with gaps of
  several hours; the page shows the data age, the status switches to "Daten veraltet" and
  the push stays silent.
- **Push notification** to the Companion app, same mechanism as the camera package, with
  a 30-minute confirmation delay, a daytime window, a presence check and a per-room
  4-hour cooldown.

Deployed on Home Assistant OS 2026.9.4, Raspberry Pi 4 (64-bit).

## Why not an existing solution

| Option | Verdict |
| --- | --- |
| HACS `thermal_comfort` | Provides dew point and absolute humidity sensors out of the box, but needs HACS. Three lines of Jinja do the same. |
| `blush-lueftungskarte` custom card | The most complete decision logic found (dead band, heat loss vs. water removed, duration hint), but it is a JavaScript resource. Its logic was rebuilt here with built-in cards. |
| Core `mold_indicator` | Estimates humidity at the coldest wall surface, which is the right criterion for mould. Needs a calibration factor from an actual wall temperature measurement. Planned as a later step for the basement. |
| Blog templates (simon42 et al.) | Same absolute-humidity approach, but the common rule "difference > 4.5 g/m³" never fires here: the measured difference over ten days peaked at 2.6 g/m³ (living room) and 3.7 g/m³ (basement). |
| Arduino "Taupunktlüfter" (Make/heise) | Fan controller: start at a dew point spread of 5 K, stop below 1 K, minimum temperatures +10 °C indoor / −10 °C outdoor. Good hysteresis reference, but it drives a fan, not a person. |

## Measured baseline

Ten days of recorder data and six months of long-term statistics were analysed before
choosing the thresholds and the update interval.

| | Living room (Govee H5075) | Basement (Eve Room) | Outside (Met.no) |
| --- | --- | --- | --- |
| Update interval | ~6 s, 5,000–8,000 recorder rows/day | median 20 min, **gaps of 4–24 h** | hourly |
| Relative humidity, 10 days | 37–64 %, above 60 % for 15 % of the time | 42–59 %, never above 65 % since April | 33–99 % |
| Dew point spread indoor − outdoor | −1.7 … +5.4 K | −3.1 … +8.0 K | |
| Absolute humidity spread indoor − outdoor | −1.3 … +2.6 g/m³, ≥ 1 g/m³ for 37 % of hours | −2.2 … +3.7 g/m³, ≥ 1 g/m³ for 41 % of hours | |

Consequences: derived values must not follow the Govee tick (write load on a USB-stick
system without backup), the basement needs a data-age indicator, and 1.0 g/m³ is both a
sensible minimum benefit and roughly the resolution limit of model-based outdoor data
(Met.no dew point ±1 K ≈ ±0.6 g/m³).

## Files

```
packages/ventilation_advisor/
  DOC.md                            this file
  configuration-snippet.yaml        append to configuration.yaml (one Core restart)
  automations-snippet.yaml          append to automations.yaml (reload is enough)
  custom_templates/lueftung.jinja   copy to /config/custom_templates/ (Magnus macros)
  dashboards/lueftung.yaml          copy to /config/dashboards/ (YAML-mode dashboard)
```

## Setup instructions

### Step 1: Copy the two files

```sh
mkdir -p /config/custom_templates /config/dashboards
# from the repo machine, byte-exact (umlauts survive, unlike a terminal heredoc):
ssh root@<host> 'cat > /config/custom_templates/lueftung.jinja' < custom_templates/lueftung.jinja
ssh root@<host> 'cat > /config/dashboards/lueftung.yaml'        < dashboards/lueftung.yaml
```

### Step 2: Extend `configuration.yaml`

Append the contents of `configuration-snippet.yaml` (without the banner). It adds three
top-level keys: `template:`, `input_number:` and `lovelace:`. If any of them already exists,
merge into the existing block instead of adding a second key.

Adjust the three source entities at the top of the `template:` block to your own sensors
and weather entity. Then `ha core check` and restart Core. The restart is needed once:
`lovelace:` is not reloadable, and if this is the first `template:` block, the template
integration is not even loaded yet, so its reload entry does not exist either. From then
on, changes to the template block only need **Developer Tools -> YAML -> Template
entities**, changes to `lueftung.jinja` need the action
`homeassistant.reload_custom_templates`, and changes to the dashboard file only need
**Refresh** in the dashboard's three-dot menu.

The seven sliders start at their `min` value when they are created, because the snippet
deliberately has no `initial:` (that would reset them on every restart). Set them once on
the page's "Einstellungen" section, or temporarily add `initial:` lines for the first
restart and remove them afterwards (the values are restored from the last state).
Start values: living room 50/60 %, basement 55/60 %, 1.0 g/m³, volumes 55 and 30 m³.

### Step 3: Add the automations

Append `automations-snippet.yaml` to `automations.yaml`, adjust the notify service and
the person, then **Developer Tools -> YAML -> Reload Automations**.

### Step 4: Test the push without waiting for weather

Test through the real path first, before pressing "Run" on an automation: a manual run
sets `last_triggered`, and the 4-hour cooldown would then block the real path. Pull the
living room warning slider below the current humidity (and, if needed, the minimum
difference slider below the current difference). The binary sensor turns on at once, the
push arrives after 30 minutes. Then use "Run" on the basement automation to check text and
`clickAction`, and restore the sliders.

## How the recommendation works

### Formulas (`lueftung.jinja`)

- Dew point: α = ln(RH/100) + a·T/(b+T), Td = b·α/(a−α) with a = 17.62, b = 243.12
- Absolute humidity: AH = 216.7 · (RH/100 · 6.112 · e^(a·T/(b+T))) / (273.15 + T) g/m³
- Absolute humidity from dew point (used for outside, where Met.no gives Td directly):
  AH = 216.7 · 6.112 · e^(a·Td/(b+Td)) / (273.15 + T)

Both are independent of air pressure, so altitude does not matter. Control values:
`taupunkt(20, 50)` = 9.25 °C, `abs_feuchte(20, 50)` = 8.62 g/m³. The macros return text,
so every call is followed by `| float`.

### Entities

All derived entities are in one trigger-based `template:` block that fires every 10
minutes and whenever one of the sliders changes (so a slider nudge is also the fastest
way to get the first values after a restart). Three `variables` layers compute raw values,
then dew points and absolute humidities, then differences and the status.

| Entity | Unit | Meaning |
| --- | --- | --- |
| `sensor.lueftung_<raum>_taupunkt`, `sensor.lueftung_aussen_taupunkt` | °C | dew point |
| `sensor.lueftung_<raum>_absolute_feuchte`, `sensor.lueftung_aussen_absolute_feuchte` | g/m³ | absolute humidity |
| `sensor.lueftung_<raum>_feuchtedifferenz` | g/m³ | indoor − outdoor; **positive = outside is drier** |
| `sensor.lueftung_<raum>_wasser_pro_luftwechsel` | g | difference × room volume |
| `sensor.lueftung_<raum>_status` | text | one of seven states, attributes `alert_type`, `hinweis` |
| `binary_sensor.lueftung_<raum>_empfohlen` | on/off | drives the push; `unavailable` on stale data |
| `sensor.lueftung_aussen_temperatur` | °C | mirror of the weather attribute, so it can be plotted |
| `sensor.lueftung_aussen_prognose` | g/m³ | driest outside air within the next 12 h; attribute `stunden` holds the hourly list |

`<raum>` is `wohnzimmer` or `keller`. Entity ids are fixed with `default_entity_id`;
without it HA would slugify "Lüftung" to `luftung_`.

Numeric sensors stay available when the indoor sensor is stale: the last measurement is
still true, and the graphs keep no holes. Only the status and the binary sensor react to
data age, measured with `last_reported` (which also counts updates that did not change the
value): Govee older than 30 min, Eve Room or Met.no older than 3 h.

### Status ladder

Evaluated top to bottom. The condensation check comes before "Alles gut" because "keep the
windows closed today" is useful even when the room is fine.

| State | Condition | Colour |
| --- | --- | --- |
| Daten veraltet | a source is unavailable or older than the limits above | info |
| Nicht lüften - Kondensatgefahr | outdoor dew point ≥ indoor temperature − 2 K (living room) / − 4 K (basement) | error |
| Alles gut | RH < target | success |
| Nicht lüften - draußen feuchter | difference ≤ −0.5 g/m³ | info |
| Kaum Nutzen | difference < minimum difference | info |
| Lüften empfohlen | RH ≥ warning threshold (and difference ≥ minimum) | error |
| Lüften sinnvoll | target ≤ RH < warning, difference ≥ minimum | warning |

The basement margin is larger because ground-coupled walls sit 3–5 K below the basement
air in summer; warm, humid outside air then condenses on them even though the room air
would take it. Ten days of autumn data never came close to this case; expect it in July and
August.

The binary sensor has a hysteresis around the thresholds: once on, it stays on until the
humidity drops 2 percentage points below the warning threshold or the difference drops
0.3 g/m³ below the minimum. Without it the 30-minute confirmation in the automation would
keep resetting while values hover at a threshold.

### Thresholds

| Slider | Start value | Why |
| --- | --- | --- |
| living room target / warning | 50 % / 60 % | 40–60 % is the comfort band recommended by the Umweltbundesamt; sustained values above 60 % raise the mould risk |
| basement target / warning | 55 % / 60 % | a basement has the coldest walls, so there is no physical reason for a *higher* warning level; the measured maximum of 63 % in six months means 65 % would never fire |
| minimum difference | 1.0 g/m³ | met in 37–41 % of hours; about the resolution of model-based outdoor data |
| room volumes | 55 m³ / 30 m³ | for the "grams of water per air change" figure |

The water figure is an upper bound per complete air change. A short burst of ventilation
exchanges perhaps 50–80 % of the volume, and walls and furniture release buffered moisture
within an hour, which is why the humidity bounces back afterwards.

## Dashboard

`dashboards/lueftung.yaml` is a sections view with five sections, built only from core
cards:

1. **Wohnzimmer** and **Keller**: a Markdown card with the colour-coded `ha-alert`, a
   small table (temperature, RH, dew point, absolute humidity indoor/outdoor), the
   difference, the grams of water per air change, the heat loss per air change
   (0.34 Wh/(m³·K) × ΔT × volume) with a duration hint (18/√ΔT minutes), and the data
   age of sensor and weather. A gauge for RH with static colour bands (they do not follow
   the sliders). The basement section has an extra alert that is only visible in the
   condensation state.
2. **Außen**: hourly weather forecast card and the 12-hour outlook table with a text bar
   per hour and a tick mark per room where the outside air will be at least the minimum
   difference drier than the room is now.
3. **Verlauf**: 48-hour history graphs of the three dew points, the three absolute
   humidities and the two differences, a timeline of the status and binary sensors (this is
   the "when was ventilating recommended" tracking), and a 14-day statistics graph of both
   rooms' relative humidity.
4. **Einstellungen**: the seven sliders and the enable switches of the two automations,
   plus a legend.

Markdown card contents must use the literal block scalar `|`. The folded `>-` joins lines
with spaces and destroys the tables.

## Push notification

Two near-identical automations, one per room, so that the cooldown and the traces are per
room. Each has two triggers: the binary sensor turning on for 30 minutes, and a
`time_pattern` every 30 minutes that catches the case where the sensor was already on when
the automations were reloaded and that repeats the reminder while the situation persists.
Conditions: binary sensor on for 30 minutes, 07:00–22:00, `person.jaybe` at home (you
cannot open a window from elsewhere), and at least 4 hours since the automation last ran.

The notification uses the same delivery path as the camera package (`ttl: 0`,
`priority: high`, `continue_on_error: true`, no Nabu Casa needed). New here: `tag` so a
repeated reminder replaces the previous one instead of stacking, `channel: Lüftung` so the
messages get their own Android channel that can be muted separately, and `clickAction`
pointing at the dashboard.

## Forecast

A second trigger-based block calls `weather.get_forecasts` (hourly) every 30 minutes and
computes dew point and absolute humidity for the next 12 forecast hours (the forecast has
temperature and humidity, but no dew point). The result is one sensor whose state is the
driest value and whose `stunden` attribute holds the hourly list; the comparison with each
room is rendered in the dashboard, not stored. If the forecast call fails, the sensor keeps
its previous state.

## Verification

- `ha core check` validates the template schema, including `default_entity_id` and
  `device_class: absolute_humidity`, but neither the dashboard YAML nor the notify service
  name. Dashboard errors show up only in the UI.
- **Developer Tools -> Template**:
  ```
  {% from 'lueftung.jinja' import taupunkt, abs_feuchte %}
  {{ taupunkt(20, 50) | float | round(2) }} {{ abs_feuchte(20, 50) | float | round(2) }}
  {{ states('sensor.lueftung_aussen_taupunkt') }} vs {{ state_attr('weather.forecast_home', 'dew_point') }}
  ```
  expected `9.26 8.62` and two equal dew points.
- **Developer Tools -> States**, filter `lueftung`: 16 template entities, none `unknown`
  after the first 10-minute tick; the forecast sensor fills at the next half hour.
- `ha core logs | grep -iE "template|lovelace|lueftung"` shows no errors; a broken `.jinja`
  surfaces as `TemplateSyntaxError`, a missing one as `TemplateNotFound`.
- Recorder load after a day: roughly 1,000 rows for the whole package, against 5,000–8,000
  for the Govee sensor alone.
- Automation traces (`/config/.storage/trace.saved_traces`, written with a delay) list each
  condition's result, so a blocked run tells you which gate stopped it.

## Known limits

- **Met.no values are model data** for the configured coordinates, not a measurement in
  your garden. Typical error ±1 K / ±10 % RH, worse during fog or right after rain. A second
  Govee H5075 in a shaded spot outside would turn the outdoor side into a measurement; only
  the three `state_attr` lines at the top of the template block would change.
- **Eve Room over HomeKit BLE reports with gaps** of several hours. The page shows the age,
  the status says "Daten veraltet" and the basement push stays silent during a gap. A
  Bluetooth proxy near the basement would fix the root cause.
- **No window contacts**, so Home Assistant does not know whether you actually ventilated.
  Planned follow-up: an action button in the notification that records the time.
- **Gauge colours are static**; the sliders move the thresholds of the logic, not the
  gauge bands.
- **Renaming the dashboard key** costs another restart. Everything else is reloadable.
- All derived values are written to the same USB stick Home Assistant runs from; the
  10-minute interval keeps that at about 1,000 rows per day.

## Notes

- `initial:` on `input_number` resets the value at every restart. Leave it out and set the
  values once; they are restored from the last state.
- `this` is available in template entity state templates and is what makes the hysteresis
  possible without an extra helper.
- `last_reported` (available since HA 2024.4) is the right timestamp for data age;
  `last_updated` misses polls that returned the same value.
- Changing the Jinja file needs `homeassistant.reload_custom_templates`; reloading the
  template entities alone does not re-read it.
