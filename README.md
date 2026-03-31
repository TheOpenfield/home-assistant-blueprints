# home-assistant-blueprints

A collection of Home Assistant Blueprints zum einfachen Import und Bearbeiten in VS Code.

## Projektstruktur

- `blueprints/`
  - `automation/`
    - `linked_entities/linked_entities.yaml` (Beispiel-Blueprint)
  - `script/` (optional)
  - `scene/` (optional)

## Setup

1. Klonen
   - `git clone https://github.com/<dein-user>/home-assistant-blueprints.git`
2. Öffnen in VS Code
   - `code .`
3. Ordnerstruktur prüfen
   - `blueprints/automation/linked_entities/linked_entities.yaml`

## Blueprint importieren in Home Assistant

1. Datei in `config/blueprints/automation/linked_entities/linked_entities.yaml` kopieren (z. B. per Samba/SSH/rsync/Docker-Volume)
2. Home Assistant: Einstellungen > Automatisierung > Blueprints (automatisch laden)
3. Neuer Blueprint: `Linked Entities` auswählen

## Git Workflow

- `git status`
- `git add .`
- `git commit -m "Add Linked Entities blueprint and initial project structure"`
- `git push origin main`

## Fork und Anpassung eines externen Blueprints

1. Fork im GitHub-Repo erstellen
2. Fork klonen und lokale Änderungen bearbeiten
3. Blueprint testen in Home Assistant
4. PR an original Repository öffnen

## Hinweise

- Verwende YAML-Validation in VS Code (`YAML` Extension)
- `secrets.yaml` niemals ins Repo committen
- Kopiere nur geprüfte Blueprint-Dateien in das HA `config/blueprints` Verzeichnis

