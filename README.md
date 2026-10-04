# home-assistant-blueprints

A collection of Home Assistant blueprints and automation templates for easy reuse and sharing.

## Project structure

- `blueprints/`
  - `automation/` (automation blueprints and standalone automation templates)
    - `adaptive_light/adaptive_light.yaml`
    - `desktop_pc_auto_off/desktop_pc_auto_off.yaml`
    - `linked_entities/linked_entities.yaml`
    - `philips_hue_filament_sync/philips_hue_filament_sync.yaml`
  - `script/` (optional)
  - `scene/` (optional)
- `packages/` (multi-file setups that span several HA domains and are not importable
  blueprints, e.g. shell scripts plus `configuration.yaml` and `automations.yaml` parts)
  - `camera_motion_recording/`
  - `circulation_pump/`
  - `ventilation_advisor/`

## Quickstart

1. Clone repository
   - `git clone https://github.com/<your-user>/home-assistant-blueprints.git`
2. Open with VS Code
   - `code .`
3. Review structure
   - `blueprints/automation/linked_entities/linked_entities.yaml`

## How to import blueprints in Home Assistant

1. Copy the YAML file to `config/blueprints/<domain>/<your-folder>/`
2. Go to Home Assistant UI: Settings -> Automations & Scenes -> Blueprints
3. Choose "Import Blueprint" or use the detected blueprint

## Git workflow

- `git status`
- `git add .`
- `git commit -m "Add blueprint and project structure"`
- `git push origin main`

## Forking and contributing

1. Fork this repository on GitHub
2. Clone your fork and apply local changes
3. Add or update blueprint YAML records
4. Test in Home Assistant
5. Open a pull request upstream

## Best practices

- Use YAML validation extension in VS Code (`YAML`) for syntax check
- Do not commit `secrets.yaml` or device-specific secrets
- Keep blueprints generic and documented

## Philips Hue Filament Sync blueprint

File: `blueprints/automation/philips_hue_filament_sync/philips_hue_filament_sync.yaml`

This blueprint is tailored for Philips Hue Filament bulbs (model LTA005) via ZHA. It syncs:

- on/off state
- brightness
- color temperature (color_temp / color_temp_kelvin)

### Usage

1. Copy blueprint to `config/blueprints/automation/philips_hue_filament_sync/`
2. Add it from the Blueprint UI in Home Assistant
3. Select all `filament_lights` entities (same model family)
4. Test:
   - turn one bulb on/off
   - adjust brightness
   - adjust color temperature

## Motion-triggered USB webcam recording

Directory: `packages/camera_motion_recording/`

Turns a USB webcam into a motion-triggered recorder without any add-on. `ffmpeg` is
launched on demand, records to `/share/kamera/` with hardware H.264 encoding, follows the
motion sensor for the clip length and deletes clips older than 90 days.

This is not a blueprint. It consists of three shell scripts plus snippets for
`configuration.yaml` and `automations.yaml`. See
`packages/camera_motion_recording/DOC.md` for setup, measured camera limits and tuning.

## Hot water circulation pump on demand

Directory: `packages/circulation_pump/`

Runs the circulation pump for 3 minutes at a time, with no fixed times: 10 minutes before
each phone alarm until noon if its owner is home, and when someone comes home after at
least 30 minutes away. One shared throttle keeps runs at least 30 minutes apart. See
`packages/circulation_pump/DOC.md`.

## Ventilation advisor (dew point and absolute humidity)

Directory: `packages/ventilation_advisor/`

Adds a "Lüftung" dashboard that tells you per room whether opening the windows helps.
Indoor sensors (Govee H5075 in the living room, Eve Room in the basement) are compared
with Met.no weather data via dew point and absolute humidity, computed by Jinja macros
without any custom integration. Includes threshold sliders, a 12-hour outlook from the
hourly forecast, 48-hour plots, and a push notification when a room is too humid and the
outside air is actually drier. See `packages/ventilation_advisor/DOC.md`.

## Device capability check

1. Home Assistant -> Developer Tools -> States
   - inspect your `light.<device>` entity
   - check attributes:
     - `supported_color_modes` includes `color_temp`
     - `color_temp`, `color_temp_kelvin`, `brightness`

2. Developer Tools -> Services
   - call `light.turn_on` with:
     - `entity_id: light.<your_light>`
     - `brightness_pct: 50`
     - `color_temp: 300`

3. Vendor/model spec
   - Use Settings -> Devices & Services -> select device
   - verify `Manufacturer` and `Model` (e.g. `Signify Netherlands B.V.` / `LTA005`)

4. For Zigbee (ZHA, deCONZ, Zigbee2MQTT):
   - verify color capability through `supported_color_modes`
   - if only `brightness`, color temperature is not supported for that entity

## Future improvements

- add group-based syncing for local scenes (instead of individual entities)
- add fallback for `xy`/`hs` color modes
- add optional `max_sync_interval`/de-bounce to avoid racing events



