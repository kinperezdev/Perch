# Shipping Perch (RevenueCat Shipaton 2026)

Perch is a macOS app, which is an eligible platform for Shipaton 2026
(iOS, iPadOS, macOS, and Android all qualify). This is the checklist to
publish it on the Mac App Store inside the submission window.

## Timing (critical)

- Submissions run **August 1 to September 30, 2026**.
- The app's **first public release must fall inside that window**. Do not
  release before August 1, or it is disqualified as a previously released app.
- Mac App Store review takes a few days. Plan to submit for review in
  **late July** with the release date set to **manual release on August 1**.

## 1. App Store Connect

1. Create the app record (bundle id `com.kinclark.perch`, category Health & Fitness).
2. Create the in-app purchases, product IDs must match the RevenueCat Offering:
   - `monthly` — auto-renewable subscription, group "Perch Pro", with a 1-week free trial (introductory offer).
   - `yearly` — auto-renewable subscription, same group, 1-week free trial.
   - `lifetime` — non-consumable.
3. Fill in localized names, descriptions, and prices ($9.99 / $79.99 / $99.99 suggested).
4. Generate **promo codes** for the judges (Users and Access > or the IAP page), or rely on the free trial. The submission requires judges be able to unlock Pro.

## 2. RevenueCat dashboard

1. Create the entitlement with identifier exactly `Perch Pro`.
2. Add the three App Store products and attach all three to the `Perch Pro` entitlement.
3. Put the three packages (Monthly, Annual, Lifetime) in the current Offering.
4. Copy the **production Apple public key** (starts with `appl_`).

## 3. Code

1. Paste the `appl_` key into `SubscriptionManager.productionAPIKey`
   (or set the `PERCH_REVENUECAT_KEY` environment variable at runtime).
   The resolver prefers env, then the production key, then the test key.
2. Bump `MARKETING_VERSION` to `1.0` and `CURRENT_PROJECT_VERSION` as needed.
3. Archive with a Distribution signing certificate and an App Store
   provisioning profile (Xcode manages this when you Product > Archive with
   automatic signing and a paid team selected).

### Local purchase testing before shipping

`Config/Perch.storekit` is a StoreKit configuration file with the three
products and free trials. In Xcode: Edit Scheme > Run > Options >
StoreKit Configuration > `Perch.storekit`. Now the paywall shows real
prices and purchases complete locally without App Store Connect.

## 4. Devpost submission assets

- Text description of features.
- Demo video, 2 minutes max, on YouTube or Vimeo, showing Perch running on a Mac.
- URL to the published Mac App Store listing.
- 1024x1024 app icon (already in `Assets.xcassets/AppIcon`).
- At least one screenshot (the 1179x2556 spec is iPhone-oriented; provide a clean Mac screenshot or confirm the format with organizers).
- A free trial (configured above) or promo codes so judges can unlock Pro.

## Student / Next Gen note

As a student you may also enter the **Next Gen Award**, which only needs a
video and this open-source repo, no store release required. Publishing to
the Mac App Store keeps you eligible for the main categories (Grand Prize,
Peace Prize, Design Award) as well.
