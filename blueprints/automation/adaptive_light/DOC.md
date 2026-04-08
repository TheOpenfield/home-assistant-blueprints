# Adaptive Light Automation

## Overview

The `adaptive_light.yaml` file contains a Home Assistant automation that dynamically adjusts the brightness and color temperature of a specified light based on the time of day and the sun's position. This creates a more natural lighting experience by simulating daylight changes throughout the day. The automation adjusts the light's settings every 5 minutes or when the sun's elevation changes, but only when the light is on and not in manual override mode.

Key features:
- Adjusts brightness from 1% to 100% based on time periods (morning, day, evening, night).
- Changes color temperature from warm (2202K) to cool (4504K) to match natural light.
- Includes a manual override toggle to prevent automatic adjustments when desired.
- Integrates seamlessly with existing motion-activated lighting automations.

## Setup Instructions

### Step 1: Create Helpers in Home Assistant UI

Navigate to **Settings → Devices & Services → Helpers → Create Helper** in your Home Assistant interface:

1. **Helper A: Toggle Switch**
   - Type: Toggle
   - Name: Dining Table Lamp Manual Override
   - This creates the entity `input_boolean.dining_table_lamp_manual_override`.

2. **Helper B: Timer**
   - Type: Timer
   - Name: Dining Table Lamp Manual Override Timer
   - Duration: 01:00:00 (1 hour)
   - This creates the entity `timer.dining_table_lamp_manual_override`.

### Step 2: Add Automations to `automations.yaml`

1. Access your `automations.yaml` file via SMB or your preferred method.
2. Remove any existing automation block with ID `'1775584881928'` (if present).
3. Append the three new automation blocks from `adaptive_light.yaml` to the end of your `automations.yaml` file.

### Step 3: Reload Automations

In Home Assistant:
- Go to **Developer Tools → YAML → Reload Automations**, or restart Home Assistant completely.
- Check **Settings → Automations** to confirm the three new automations are listed.

### Notes

- Your existing motion-light automation (e.g., for entrance area) and LED cabinet automations remain unaffected.
- The adaptive light automation only activates when the light is already on, complementing your motion scripts that handle on/off states.
- Customize the entity IDs in the YAML (e.g., `light.esstischlampe`) to match your actual light entities.