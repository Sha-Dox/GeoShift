# Shipping GeoShift

Run:

```sh
./make_release.sh
```

This creates `dist/GeoShift-1.1.1-macOS.dmg`, containing GeoShift and an Applications shortcut.

The local development build is ad-hoc signed. Before distributing it publicly, replace the signing step with your Apple Developer ID Application identity and notarize/staple the app or disk image. Apple documents the current distribution workflow in “Distributing software outside the Mac App Store.”

Keep `THIRD_PARTY_NOTICES.md` with the source/distribution materials. GeoShift downloads `pymobiledevice3` into the user’s private Application Support directory only after they click the setup button; it is not embedded in the app bundle.
