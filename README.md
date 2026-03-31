# home-assistant-blueprints

A collection of Home Assistant blueprints and automation templates for easy reuse and sharing.

## Project structure

- `blueprints/`
  - `automation/` (automation blueprints)
    - `linked_entities/linked_entities.yaml`
    - `philips_hue_filament_sync/philips_hue_filament_sync.yaml`
  - `script/` (optional)
  - `scene/` (optional)

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



