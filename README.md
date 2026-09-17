# GeoShift

![GeoShift icon](Resources/AppIcon.svg)

GeoShift is a small macOS companion for setting a **software-simulated location** on a USB-connected iPhone. It provides an address search, Google Maps link import, click-to-pin map, exact coordinates, presets, connection checks, automatic retries, and a one-click restore button.

Once the one-time setup is complete, connection is automatic: leave GeoShift open, plug in the trusted iPhone, and it will be detected within a few seconds. GeoShift also reconnects after a cable disconnect without requiring a manual tunnel command.

## Requirements

- macOS 14 or newer
- Xcode installed
- iPhone connected by USB, unlocked, and trusted
- Developer Mode enabled on the iPhone
- [`pymobiledevice3`](https://github.com/doronz88/pymobiledevice3)

On first launch, click **Set Up Automatically**. GeoShift creates a private runtime in Application Support and installs the phone bridge itself—there is nothing to paste into Terminal and no shell configuration to change. The same button becomes **Repair or Update Setup** afterward.

Build the app:

```sh
chmod +x make_app.sh
./make_app.sh
open dist/GeoShift.app
```

Create the drag-to-Applications release image with `./make_release.sh`. See `SHIPPING.md` for Developer ID and notarization notes.

## Using it with Snap Map

1. Connect the iPhone by USB, unlock it, and keep the screen on.
2. Enable **Settings → Privacy & Security → Developer Mode** if it is not already enabled.
3. Choose a place in GeoShift and click **Apply to iPhone**.
4. Open Snapchat on the iPhone and refresh Snap Map.
5. Click **Restore real GPS** when finished. Rebooting the iPhone also clears developer simulation.

You can paste a full Google Maps URL into the search box or drag a link onto it. Standard place URLs, coordinate queries, directions destinations, and `maps.app.goo.gl` share links are supported.

GeoShift also keeps local favorites and a short recent-location history, can copy coordinates, opens the selected pin in Maps, shows connected-device details, and provides copyable diagnostics when setup or connection fails.

Location simulation uses Apple's developer services and is intended for development and personal testing. iOS marks these fixes as software-simulated, so an app may detect or ignore them. Follow the terms of any app you test.

## Privacy

GeoShift contains no analytics, accounts, advertising, or telemetry. See [PRIVACY.md](PRIVACY.md) for the small number of network interactions initiated by user actions.
