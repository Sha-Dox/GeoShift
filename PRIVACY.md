# Privacy

GeoShift has no analytics, advertising, accounts, or telemetry. Favorites and recent locations are stored locally in macOS user defaults. The managed phone bridge is installed locally under the current user’s Application Support directory.

GeoShift communicates with:

- Apple MapKit when the user searches for a place or views the map.
- Google only when the user imports a shortened `maps.app.goo.gl` link, so the redirect can be resolved.
- Python package infrastructure when the user explicitly clicks **Set Up Automatically** or **Repair or Update Setup**.

Connected-device details and command diagnostics remain on the Mac unless the user explicitly copies and shares them.
