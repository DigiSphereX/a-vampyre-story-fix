# A Vampyre Story - Fix and Play

Makes the 2008 **Panda3D** release of *A Vampyre Story* playable on modern
Windows (10/11). Fixes both the **start-up hang** (DirectX9 driver mismatch)
and the **black screen after clicking "New Game"**.

## Root cause

- `main.exe` is a `py2exe` stub on **Panda3D 1.3.2** (Python 2.4 era).
- The engine's DirectX9 renderer (`pandadx9`) spins the CPU at 100% on current
  NVIDIA/AMD drivers **without ever creating a window**.
- Switching to the OpenGL backend (`pandagl`) opens the window and lets the
  menus run, but the **pre-rendered movie sequences (Bink) show a black
  screen**, which is why the game appears stuck right after "New Game".
- The community-proven fix is to keep the game on DirectX9 but route it through
  the **dgVoodoo2** wrapper (Direct3D -> D3D11/D3D12), emulating a legacy
  "GeForce FX 5700 Ultra" device.

## What the script does

1. **`etc\Config.prc`** - forces the DirectX9 renderer (`load-display pandadx9`).
2. **dgVoodoo2 wrapper** - installs local `D3D8/D3D9/D3DImm/DDraw.dll`.
   Auto-downloads dgVoodoo2 v2.87.4 (SHA256 verified) if missing.
3. **`dgVoodoo.conf`** - emulates a "GeForce FX 5700 Ultra" GPU, watermark off,
   GDI hooking enabled (needed for movie playback).
4. **Windows XP SP2 compatibility** - registered for both `main.exe` and
   `LAUNCHER.exe` (per-user, no admin needed).
5. **Antialiasing off** - forces `anti_alias_level` to `0` in
   `assets/scripts/14793.bin` (avoids texture freezes on new GPUs).
6. **Launch** - starts the game through `LAUNCHER.exe` (SmartSteamEmu loader)
   so Steam emulation is injected automatically.

## Usage

Run the game with the fix (applies what is missing, then launches):

```bat
A_Vampyre_Story_Fix_and_Play.bat
```

Or via PowerShell:

```powershell
.\A_Vampyre_Story_Fix_and_Play.ps1            # apply fixes + launch
.\A_Vampyre_Story_Fix_and_Play.ps1 -NoLaunch  # apply fixes only
.\A_Vampyre_Story_Fix_and_Play.ps1 -Force     # re-apply / re-download
.\A_Vampyre_Story_Fix_and_Play.ps1 -SkipInstall  # skip dgVoodoo2 download
```

### Notes

- The script must sit in the game's `game` folder (next to `main.exe`).
- Backups are created automatically: `Config.prc.bak`, `14793.bin.bak`.
- If a movie still shows black, **press a key to skip it** - gameplay is
  unaffected (the OpenGL fallback route). With dgVoodoo2 in place the movies
  should play normally.
- dgVoodoo2 is freeware by Dege: https://github.com/dege-diosg/dgVoodoo2
- Release build **v2.87.4**, SHA256 `74AEB464D829DB80E3F4AA8FAE235E6E3B38FC01188776C5C2376BB0DEA0956E`
  (re-verified before extraction every time).

## Disclaimer / Backup advice

Use this fix at your own risk. Before applying it: read the scripts (everything here
is plain, readable source), **back up** the game folder / `ddraw.dll` you replace,
and create a system restore point. A fix that works on most machines can behave
unexpectedly on a specific setup. The author is not responsible for any
unintentional damage or data loss.

## License

MIT - see [LICENSE](LICENSE). dgVoodoo2 remains the property of its author and
is distributed under its own terms.

---

## ☕ Support this project

Free and open source (MIT). If this fix saved you time or money, consider a small thank-you:

- **GitHub Sponsors** -> https://github.com/sponsors/DigiSphereX
- **PayPal** -> https://www.paypal.com/donate/?hosted_button_id=CFANQH892RPH2
