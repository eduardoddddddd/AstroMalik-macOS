# LaunchAgents para `astromalik-cli`

Estos plist ejecutan el informe cross-personal de AstroMalik desde `launchd`:

- `com.astromalik.cli.weekly.plist`: cada sábado a las 18:00 con `--scope weekly`.
- `com.astromalik.cli.monthly.plist`: el día 1 de cada mes a las 09:00 con `--scope monthly`.

## Preparación

1. Compila el CLI:

   ```bash
   cd /Users/eduardoariasbravo/Developer/AstroMalik-macOS
   swift build -c release --product astromalik-cli
   mkdir -p ~/Library/Logs/AstroMalik ~/Library/LaunchAgents
   ```

2. Si quieres usar otro binario, edita `ASTROMALIK_CLI_BIN` dentro del plist antes de instalarlo.

3. Copia el plist deseado:

   ```bash
   cp scripts/launchagents/com.astromalik.cli.weekly.plist ~/Library/LaunchAgents/
   cp scripts/launchagents/com.astromalik.cli.monthly.plist ~/Library/LaunchAgents/
   ```

## Cargar / descargar

```bash
launchctl load ~/Library/LaunchAgents/com.astromalik.cli.weekly.plist
launchctl unload ~/Library/LaunchAgents/com.astromalik.cli.weekly.plist

launchctl load ~/Library/LaunchAgents/com.astromalik.cli.monthly.plist
launchctl unload ~/Library/LaunchAgents/com.astromalik.cli.monthly.plist
```

Logs:

- `~/Library/Logs/AstroMalik/cli.out`
- `~/Library/Logs/AstroMalik/cli.err`
