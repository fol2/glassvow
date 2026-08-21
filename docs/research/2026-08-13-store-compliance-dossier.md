# Store Compliance Dossier — Glassvow (paid, no-IAP, no-ads, offline, local saves)

Research ticket: fol2/glassvow#162. Checked **2026-08-13** against primary sources
(developer.apple.com, support.google.com/googleplay/android-developer,
developer.android.com, docs.godotengine.org, github.com/godotengine). Every claim
carries the URL of the source that owns it; items I could not confirm on a primary
page this check are marked **[verify at entry]**.

**Scope invariants — nothing below assumes these exist:** no IAP, no ads, no
accounts, no cloud saves, no network play. Ship profile: premium one-price,
offline, local saves only, Godot 4.7.2, locales en + zh-Hant. A crash-reporting
SDK MAY be added later; both disclosure paths are covered in §4.

Legend: 🔴 launch blocker · 🟡 nice-to-have / conditional · ⏰ carries a deadline
or version number.

---

## Summary table

| # | Requirement | Store | Status / owner action | Flag | Citation |
|---|---|---|---|---|---|
| 1 | Apple Developer Program membership, US$99/yr; org enrollment needs D-U-N-S + domain website/email | Apple | Enroll (or confirm active) before anything else | 🔴 | [enroll](https://developer.apple.com/programs/enroll/) |
| 2 | Paid Apps Agreement signed by Account Holder + banking + tax info | Apple | Sign in App Store Connect before the app can go on sale | 🔴 | [agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements) |
| 3 | Play Console developer account, US$25 one-time; ID + Android-device verification | Google | Register/verify; note personal-account testing gate (row 21) | 🔴 | [registration](https://support.google.com/googleplay/android-developer/answer/6112435) |
| 4 | Google payments profile (merchant) to sell a paid app | Google | Create payments profile; legal address, no P.O. box | 🔴 | [payments profile](https://support.google.com/googleplay/android-developer/answer/7161426) |
| 5 | EU DSA trader status: declare on every new app; traders verify address/phone/email (2FA), shown on EU product page | Apple | Declare trader status; a commercially sold paid app ⇒ almost certainly trader | 🔴 | [DSA help](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/) |
| 6 | EEA developer identity verification (DMA/DSA conditions) | Google | Complete Play Console identity verification | 🔴 | [EEA conditions](https://support.google.com/googleplay/android-developer/answer/14659200) |
| 7 | ⏰ Builds must use **Xcode 26 / iOS 26 SDK** (effective **2026-04-28**, in force) | Apple | Build exported Xcode project with Xcode 26 on macOS | 🔴⏰ | [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) |
| 8 | iOS distribution signing: Team ID + bundle ID in Godot export; cert/profile/upload via Xcode | Apple | Configure export preset; archive + upload in Xcode | 🔴 | [Godot iOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) |
| 9 | ⏰ New apps must target **Android 16 (API 36)** from **2026-08-31** (extension to 2026-11-01 requestable) | Google | Set `gradle_build/target_sdk` = 36 (Godot 4.7 docs describe SDK 35 tooling) and verify | 🔴⏰ | [target API](https://support.google.com/googleplay/android-developer/answer/11926878) |
| 10 | AAB required for new apps ⇒ Gradle build in Godot; Play App Signing mandatory (auto-enrolled), upload keystore held by you | Google | Enable Gradle build, generate release keystore, upload AAB | 🔴 | [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) · [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html) |
| 11 | ⏰ 16 KB page sizes required for apps targeting Android 15+; update hard-stop **2027-02-01**. Godot ≥4.5 templates (NDK r28b) comply → 4.7.2 OK | Google | No action for GDScript builds; verify with `zipalign -c -P 16` on the artifact | 🔴⏰ | [page sizes](https://developer.android.com/guide/practices/page-sizes) · [godot PR #106358](https://github.com/godotengine/godot/pull/106358) |
| 12 | ⏰ Apple age rating: updated system (4+/9+/13+/16+/18+) live; updated questions mandatory since **2026-01-31** | Apple | Answer new questionnaire; expect 9+ (Cartoon/Fantasy Violence), no gambling descriptors | 🔴⏰ | [age ratings](https://developer.apple.com/help/app-store-connect/reference/age-ratings) |
| 13 | IARC content rating questionnaire mandatory | Google | Complete honestly; declare NO gambling/simulated gambling | 🔴 | [content rating](https://support.google.com/googleplay/android-developer/answer/9859655) |
| 14 | Privacy policy URL required on BOTH stores even with zero collection | Both | Publish a policy URL; also link it inside the app (Apple 5.1.1(i)) | 🔴 | [Apple 5.1.1](https://developer.apple.com/app-store/review/guidelines/) · [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) |
| 15 | Apple privacy nutrition label (declare before submission); Play Data safety form (all apps, incl. test tracks) | Both | Declare "no data collected" now; §4 covers the crash-SDK variant | 🔴 | [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details/) · [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) |
| 16 | Account deletion rules — N/A: Apple 5.1.1(v) triggers only "if your app supports account creation"; Play deletion section moot with zero collection | Both | Cleanly declarable as N/A — keep it that way (no accounts) | 🟡 | [Apple guidelines](https://developer.apple.com/app-store/review/guidelines/) · [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) |
| 17 | Export compliance: set `ITSAppUsesNonExemptEncryption` = false (exempt/HTTPS-only or no network) | Apple | Add key to Info.plist in exported Xcode project | 🟡 | [encryption export](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) |
| 18 | Store assets: Apple 6.9" iPhone + 13" iPad screenshots; Play 512px icon + 1024×500 feature graphic + ≥2 screenshots | Both | Produce asset matrix in §7, per locale | 🔴 | [Apple screenshot specs](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/) · [Play assets](https://support.google.com/googleplay/android-developer/answer/9866151) |
| 19 | "Contains ads" declaration = No (App content) | Google | Declare no ads; misrepresentation is a policy violation | 🟡 | [ads policy](https://support.google.com/googleplay/android-developer/answer/9857753) |
| 20 | TestFlight: internal 100 / external 10,000, Beta App Review for first external build, 90-day build expiry | Apple | Optional but recommended pre-launch | 🟡 | [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) |
| 21 | ⏰ Personal Play accounts created after **2023-11-13**: closed test with **12 testers opted in 14 consecutive days** before production access | Google | Check account type/creation date FIRST — this is a calendar-time gate | 🔴⏰ (if applicable) | [testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465) |
| 22 | zh-Hant metadata: Apple "Chinese (Traditional)" (TWN/HKG/MAC); Play zh-TW + zh-HK translations | Both | Localize listing text; graphics optional per locale | 🟡 | [Apple localizations](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations) · [Play translations](https://support.google.com/googleplay/android-developer/answer/9844778) |

---

## 1. Accounts & agreements

### Apple
- **Apple Developer Program: 99 USD per membership year.** Individuals: Apple
  Account with 2FA, legal name (no aliases), verified email/phone/address (no
  P.O. boxes). Organizations additionally need: legal entity (no DBAs/trade
  names), **D-U-N-S number** (all orgs except government), work email on the
  org's domain, and a functional public website on that domain.
  — https://developer.apple.com/programs/enroll/ 🔴
- **Paid Apps Agreement**: "To sell your apps on the App Store or offer In-App
  Purchases, the Account Holder must sign the Paid Apps Agreement." Only the
  **Account Holder** role can sign; acceptance is irreversible; it must remain
  active (re-agree after membership lapse) to submit or update paid apps. Tax
  and banking information must also be provided (linked flows: "Provide tax
  information", "Enter banking information").
  — https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements 🔴
- **EU DSA trader status** (Articles 30/31 DSA): *every* developer must declare
  trader status when submitting a new app, even if not distributing in the EU.
  Traders distributing in the EU must provide and verify an **address, phone
  number, and email** (2FA validation; manual verification via business/legal
  records possible), which Apple **publishes on the EU App Store product page**.
  Trader-status factors explicitly include "if it's a paid or ad-sponsored app" —
  a commercially sold premium game is, in practice, a trader. Non-trader apps
  show EU consumers a notice that consumer-protection rights don't apply. Apps
  without verified trader status have been removed from the EU App Store since
  **2025-02-17**.
  — https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
  — https://developer.apple.com/news/upcoming-requirements/ 🔴

### Google
- **Play Console developer account: US$25 one-time fee** (credit/debit card; no
  prepaid cards). Identity verification may require a **valid government ID and a
  credit card under your legal name**. New personal account holders (since early
  2024) must verify access to an Android device via the Play Console mobile app.
  — https://support.google.com/googleplay/android-developer/answer/6112435 🔴
- **Payments profile required to sell paid apps.** Create a Google payments
  center profile (auto-links to Play Console); Google requires a valid physical
  legal business address — **no P.O. boxes**.
  — https://support.google.com/googleplay/android-developer/answer/7161426
  — https://support.google.com/googleplay/android-developer/answer/3092739 🔴
- **EEA conditions (DMA/DSA)**: developers must verify their developer identity
  information before distributing to EEA users; Developer Distribution Agreement
  + Developer Program Policies apply.
  — https://support.google.com/googleplay/android-developer/answer/14659200 🔴
  (Exact trader-info display mechanics on Play are surfaced during Play Console
  account verification — **[verify at entry]** when the account is set up.)

## 2. Signing & provisioning

### iOS (Godot 4.7 → App Store)
- Godot's iOS export **produces an Xcode project** ("Opening
  `exported_xcode_project_name.xcodeproj` lets you build and deploy like any
  other iOS app"). Export requires macOS + Xcode; **App Store Team ID and bundle
  Identifier are required export-preset fields**. Distribution certificate,
  provisioning profile, archiving, and upload all happen in Xcode's standard
  workflow (Transporter is the alternative upload path).
  — https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html 🔴
- ⏰ **Since 2026-04-28, uploads to App Store Connect must be built with Xcode 26
  and the iOS 26 SDK.** The Godot-exported project must be opened and archived
  in Xcode 26. — https://developer.apple.com/news/upcoming-requirements/ 🔴⏰

### Android (Godot 4.7 → Play)
- **AAB is mandatory for new Play apps** (since Aug 2021); producing an AAB in
  Godot requires **enabling Gradle builds** (Project > Export > Gradle Build;
  installs a gradle project under `res://android/build`).
  — https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html
  — https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html 🔴
- Godot 4.7 toolchain pins (from the 4.7 export doc): **SDK Platform 35,
  Build-Tools 35.0.1, Platform-Tools ≥35.0.0, NDK r28b (28.1.13356709), CMake
  3.10.2.4988404, OpenJDK 17**. Release keystore generated with `keytool` (RSA,
  10,000-day validity); Godot quirk: **keystore password and key password must be
  identical**; passwords should stick to alphanumerics. "Export With Debug" must
  be unchecked for store builds.
  — https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html 🔴
- **Play App Signing is mandatory with AABs**: new apps are auto-enrolled
  (Google-generated app signing key, RSA 4096); you sign uploads with your own
  **upload key** (RSA 2048 minimum, `.jks`/`.keystore`). Upload key can be reset
  via a Play Console help form if lost. (No API providers to register the
  Google-held key with — this game calls no external APIs.)
  — https://support.google.com/googleplay/android-developer/answer/9842756 🔴
- ⏰ **Target API level**: from **2026-08-31**, new apps and app updates must
  target **Android 16 (API 36)**; an extension to **2026-11-01** can be
  requested in Play Console. The Godot 4.7 docs describe an SDK-35 toolchain, so
  **explicitly set `gradle_build/target_sdk` to 36** in the export preset and
  verify the merged manifest — community reports confirm Play warns Godot apps
  about the 2026-08-31 cutoff, and API 36 compiles/runs.
  — https://support.google.com/googleplay/android-developer/answer/11926878
  — https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html 🔴⏰
- ⏰ **16 KB page sizes**: "all apps targeting Android 15 (API level 35) and
  higher must support 16 KB memory page sizes on 64-bit devices on Google Play.
  Starting **February 1, 2027**, if your app updates don't support 16 KB memory
  page sizes, you won't be able to release these updates." (Requirement began
  applying to new submissions 2025-11-01.) NDK **r28+ aligns 16 KB by default**.
  Godot added 16 KB support (and moved to NDK r28b) in **4.5 dev 5** via
  godotengine/godot **PR #106358** — so **Godot 4.7.2 export templates comply**.
  Caveat: gradle-generated **.NET/C#** exports had an alignment bug
  (godotengine/godot #110262) — irrelevant to this GDScript project, but re-check
  if C# ever enters the tree. Verify the shipped artifact with
  `zipalign -v -c -P 16 4 <apk>` / APK Analyzer.
  — https://developer.android.com/guide/practices/page-sizes
  — https://github.com/godotengine/godot/pull/106358
  — https://github.com/godotengine/godot/issues/110262 🔴⏰

## 3. Age ratings

### Apple (updated system, live)
- ⏰ Ratings moved to **4+ / 9+ / 13+ / 16+ / 18+** tiers; all existing ratings
  were auto-migrated **2026-01-31** and developers had to answer the updated
  questions by that date to avoid submission interruption. New submissions
  answer the updated questionnaire in App Information.
  — https://developer.apple.com/news/upcoming-requirements/
  — https://developer.apple.com/help/app-store-connect/reference/age-ratings 🔴⏰
- Relevant descriptors for a stylized fantasy card-battler:
  - **"Cartoon or Fantasy Violence"** — "physical conflict or harm of an
    exaggerated or fantastical nature that can easily be distinguished from real
    life" → this is the honest answer for glassvow's combat; infrequent/mild
    lands around **9+**.
  - **Sensitive questions to answer NO** (and why it's safe to): **Gambling**
    ("betting or wagering using real money or in-game currency that may be
    exchanged for real money") — none; **Simulated Gambling** ("betting or
    wagering without real money") — deckbuilding/relic draft choices involve no
    betting or wagering, so no; **Loot Boxes** ("randomized virtual items **for
    purchase**") — nothing is purchasable in-game, so no; **Contests** — no
    online rankings/rewards; **Unrestricted Web Access / UGC / Social Media /
    Messaging** — all no (offline, no accounts).
  - Regional notes: Korea's **RCN** requirement only bites "Frequent or Intense
    simulated gambling" (N/A); Brazil's SPA betting-license rule only bites
    fixed-odds betting (N/A); Australia maps loot boxes/simulated gambling to
    higher tiers (N/A).
  — https://developer.apple.com/help/app-store-connect/reference/age-ratings
- Answer honestly per guideline **2.3.6** — mis-rating "could trigger an inquiry
  from government regulators".
  — https://developer.apple.com/app-store/review/guidelines/

### Google (IARC)
- The content rating questionnaire is **required for all new apps**; unrated or
  misrepresented apps can be rejected/removed. One questionnaire maps to ESRB,
  PEGI, USK, ACB, ClassInd, GRAC, and IARC Generic. Redo it whenever content
  changes would alter answers.
  — https://support.google.com/googleplay/android-developer/answer/9859655 🔴
- Sensitive questions: violence (answer: fantasy/mild cartoon violence →
  expect ~ESRB E10+/PEGI 7–12), **gambling/simulated gambling → NO** (same
  reasoning as Apple: card/relic RNG is not betting/wagering; no real-money
  anything exists in the product).

## 4. Privacy

### Both stores, zero-collection baseline (current ship profile)
- **A privacy policy URL is mandatory on both stores even with zero data
  collection**:
  - Apple: guideline 5.1.1(i) — "All apps must include a link to their privacy
    policy in the App Store Connect metadata field **and within the app** in an
    easily accessible manner", and Privacy Policy URL is a required App Store
    Connect property.
    — https://developer.apple.com/app-store/review/guidelines/
    — https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/ 🔴
  - Google: "All developers that have an app published on Google Play must
    complete the Data safety form … **Even developers with apps that do not
    collect any user data must complete this form and provide a link to their
    privacy policy.**"
    — https://support.google.com/googleplay/android-developer/answer/10787469 🔴
  - Owner action: publish a short policy (en + zh-Hant) stating no data is
    collected, and link it from an in-app screen (settings/about) for Apple.
- **Apple nutrition label**: "collect" = "transmitting data off the device in a
  way that allows you and/or your third-party partners to access it for a period
  longer than what is necessary to service the transmitted request in real
  time." Local saves never leave the device → declare **no collection**; the
  product page then shows the **"Data Not Collected"** label.
  — https://developer.apple.com/app-store/app-privacy-details/
- **Play Data safety**: collection = "transmitting data from your app off a
  user's device"; declaring nothing collected/shared shows users the app
  "doesn't collect or share any user data" message.
  — https://support.google.com/googleplay/android-developer/answer/10787469
- **Account deletion — cleanly N/A on both stores**: Apple 5.1.1(v) applies only
  "**If your app supports account creation**"; Play's data-deletion section
  applies to collected data ("For apps collecting no data, this section becomes
  moot"). No accounts, no collection ⇒ nothing to declare. 🟡
  — https://developer.apple.com/app-store/review/guidelines/
  — https://support.google.com/googleplay/android-developer/answer/10787469

### If a crash-reporting SDK is added later (disclosure deltas)
- **Apple**: crash logs fall under the **Diagnostics** data category — **"Crash
  Data: such as crash logs"**, plus "Performance Data" and "Other Diagnostic
  Data" if the SDK gathers them. Device identifiers the SDK collects must be
  declared under Identifiers ("Device ID"). You are responsible for **all
  third-party SDK collection** ("You need to identify all of the data you or
  your third-party partners collect"). If the SDK strips direct identifiers and
  you don't attempt re-linking, declare **"not linked to your identity"**; crash
  reporting alone is **not "Tracking"** (tracking = linking with third-party
  data for advertising purposes or sharing with a data broker). Label update is
  editable any time in App Store Connect; update it **before** shipping the SDK.
  — https://developer.apple.com/app-store/app-privacy-details/
- **Google**: declare under **"App info and performance"** → **"Crash logs"**
  ("stack traces, or other information directly related to a crash") and
  **"Diagnostics"** as applicable, with collection purpose (e.g. Analytics).
  The **ephemeral-processing exemption will NOT cover crash reports** (they are
  stored server-side, not "retained no longer than necessary to service the
  specific request in real-time"). SDK data is explicitly the developer's
  responsibility to research and declare.
  — https://support.google.com/googleplay/android-developer/answer/10787469
- Apple guideline 5.1.1(ii) additionally requires **user consent for collecting
  usage data "even if such data is considered to be anonymous"** — factor a
  consent/opt-in toggle into the crash-SDK evaluation, and update the privacy
  policy on both stores. — https://developer.apple.com/app-store/review/guidelines/

## 5. Export / encryption compliance

- **Apple**: set **`ITSAppUsesNonExemptEncryption` = false** in the exported
  Xcode project's Info.plist. Correct when the app "uses no encryption" or only
  **exempt** encryption (HTTPS/TLS, OS-provided encryption) — an offline game
  with local saves qualifies. If the key is absent, App Store Connect asks
  export-compliance questions **on every submission**. France can require a
  separate declaration for some encryption categories, and US rules involve
  annual self-classification reporting — both moot for an app declaring
  no non-exempt encryption, but re-check if any networking is ever added.
  — https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations 🟡
- **Google Play**: no equivalent encryption declaration exists in Play Console
  (checked 2026-08-13); US export law nominally still applies to any binary with
  crypto, which the no-non-exempt-encryption posture already satisfies. 🟡

## 6. Review guidelines & rejection risks

All citations: https://developer.apple.com/app-store/review/guidelines/ (Apple)
and https://play.google/developer-content-policy/ via
https://support.google.com/googleplay/android-developer/topic/9876964 +
https://support.google.com/googleplay/android-developer/answer/9898842 (Google).

- **Apple 2.1 App Completeness** 🔴: final build, all metadata, functional URLs,
  no placeholders; "We will reject incomplete app bundles and binaries that
  crash or exhibit obvious technical problems." Test on-device before submitting.
- **Apple 2.3 Accurate Metadata** 🔴: 2.3.3 — "Screenshots should show the app in
  use, and not merely the title art, login page, or splash screen" (shoot real
  combat/map/deck screens, per locale); 2.3.7 — unique name, no keyword
  stuffing/trademarks/pricing in metadata; **2.3.8 — metadata (icons,
  screenshots, previews) must itself be appropriate for a 4+ rating even if the
  app is rated higher**.
- **Apple 4.2 Minimum Functionality**: needs "some sort of lasting entertainment
  value" — a full roguelite deckbuilder clears this comfortably; the risk is
  presentational, not substantive.
- **Apple 4.3 Spam**: bites template/re-skinned apps ("indistinguishable from
  what's already widely available"). A distinct original game is safe; make the
  listing communicate what's different (glassvow-world journey, glass aesthetic)
  so a reviewer never reaches for 4.3(b).
- **Paid-upfront specifics (Apple)**: pricing is yours, but "We'll reject
  expensive apps that try to cheat users with irrationally high prices" (3.1.1's
  IAP mandate is N/A — nothing is unlocked in-app). Reviewers get the paid build
  through review infrastructure; no special demo needed for an offline game.
- **Play — Functionality/UX** 🔴: "Apps should provide users with a basic degree
  of adequate functionality and content … Apps that crash, exhibit other
  behavior that is not consistent with a functional user experience … are not
  apps that expand the catalog in a meaningful way."
- **Play — Metadata policy** 🔴: **title ≤30 characters**; no emoji/emoticons/
  repeated special characters/ALL CAPS (unless brand); no store-performance,
  ranking, price, or promo text in title/icon/dev name ("#1", "Best of Play",
  "free"); keep descriptions succinct — repetition/keyword-stuffing is itself a
  violation. This applies to the **zh-Hant listing too** — translated title must
  respect the same 30-char limit and bans.
- **zh-Hant localization**: neither store *requires* localized metadata, but
  both hold localized text to the same accuracy/appropriateness policies as the
  primary locale. Apple locale fallback means missing zh-Hant fields fall back
  to the primary language; Play shows auto-translation with a banner unless a
  manual zh-TW/zh-HK translation is supplied.
  — https://developer.apple.com/help/app-store-connect/reference/app-store-localizations
  — https://support.google.com/googleplay/android-developer/answer/9844778

## 7. Required store assets (matrix, checked 2026-08-13)

### Apple App Store — per-locale text (en-US, zh-Hant each)
| Field | Limit | Required |
|---|---|---|
| Name | 30 chars | 🔴 (localizable) |
| Subtitle | 30 chars | 🟡 (localizable) |
| Promotional text | 170 chars | 🟡 (editable without new build) |
| Description | long-form; no public char limit documented **[verify at entry — Connect enforces ~4,000]** | 🔴 |
| Keywords | 100 chars total, comma-separated | 🔴 |
| Support URL | localizable | 🔴 (submit-time required field) **[verify at entry]** |
| Privacy Policy URL | — | 🔴 (required property) |
| Marketing URL | — | 🟡 optional |

— limits: https://developer.apple.com/app-store/product-page/ · required flags:
https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/

### Apple — visuals (per locale; zh-Hant can reuse en shots or localize)
- **Screenshots: 1–10 per device class; JPEG/PNG, no alpha.** Required classes:
  **iPhone 6.9"** (1290×2796 / 1320×2868 / 1260×2736 or landscape variants; 6.5"
  1284×2778 / 1242×2688 accepted instead) and — because a Godot iPad build runs
  on iPad — **iPad 13"** (2064×2752 or 2048×2732). All smaller classes
  auto-scale down from the largest provided. 🔴
  — https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
- **App previews: optional, up to 3 per device size, ≤30 s each**, autoplay
  muted. 🟡 — https://developer.apple.com/app-store/product-page/
- **App icon** ships inside the build (asset catalog in the exported Xcode
  project; 1024×1024 App Store icon slot) — configured at archive time.
  **[verify in Xcode at archive]**

### Google Play — text
| Field | Limit | Required |
|---|---|---|
| App name | 30 chars (metadata policy) | 🔴 |
| Short description | 80 chars | 🔴 |
| Full description | long-form **[verify at entry — Console enforces 4,000]** | 🔴 |

— https://support.google.com/googleplay/android-developer/answer/9866151 ·
https://support.google.com/googleplay/android-developer/answer/9898842

### Google Play — visuals
- **App icon: 512×512, 32-bit PNG with alpha, ≤1024 KB.** 🔴
- **Feature graphic: 1024×500 JPEG/24-bit PNG (no alpha) — required to publish
  the store listing.** 🔴
- **Screenshots: minimum 2 overall** (each 320–3840 px); up to 8 per device
  type; **7" and 10" tablet sets (4 each, 16:9 / 9:16, 1080–7680 px) are needed
  for tablet-quality listing/featuring** — provide them, since the game runs on
  tablets. 🔴 (phone) / 🟡→🔴-for-featuring (tablet)
- Preview video: optional YouTube URL (ads disabled, public/unlisted). 🟡
- Per-locale: translations are text-first; **localized graphics are optional and
  fall back to default-language assets**. zh-TW and zh-HK are distinct Play
  languages — supply zh-Hant text for both (same script, minor wording).
  — https://support.google.com/googleplay/android-developer/answer/9866151 ·
  https://support.google.com/googleplay/android-developer/answer/9844778
- **Declarations on the App content page**: Data safety (§4), content rating
  (§3), **ads declaration → "No"** (Play labels listings that contain ads;
  misrepresentation violates policy), target audience. 🔴
  — https://support.google.com/googleplay/android-developer/answer/9857753

## 8. Distribution mechanics

### TestFlight (Apple)
- **Internal testers: up to 100** App Store Connect users; no Beta App Review.
- **External testers: up to 10,000**; the **first build added to an external
  group is automatically sent to Beta App Review**; subsequent builds may not
  need full review.
- **Builds expire after 90 days.** Up to 100 builds shareable; testers can use
  up to 30 devices.
  — https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview ·
  https://developer.apple.com/testflight/ 🟡

### Play testing tracks (Google)
- **Internal testing: up to 100 testers**, releases available within minutes,
  "may not be subject to the usual Play policy or security reviews"; paid-app
  testers install free.
- **Closed testing**: email lists / Google Groups; up to 200 lists × 2,000 users
  (50 lists per track); normal review applies.
- **Open testing**: listed on Play, unlimited or capped (min 1,000) testers.
  — https://support.google.com/googleplay/android-developer/answer/9845334 🟡
- ⏰ **Personal-account gate (state of the rule)**: "Developers with personal
  accounts created after **November 13, 2023** … must run a closed test for your
  app with a minimum of **12 testers who have been opted-in for at least the
  last 14 days continuously**" before applying for production access (14 days
  must be consecutive; Google answers production-access applications within ~7
  days). **Does not apply to organization accounts or personal accounts created
  on/before 2023-11-13.** Owner action: check which account type glassvow will
  ship under — if a post-2023 personal account, this adds ≥2 weeks of calendar
  time before launch. 🔴⏰ (conditional)
  — https://support.google.com/googleplay/android-developer/answer/14151465

---

## Owner-action quicklist (blockers only, in order)

1. Confirm/enroll Apple Developer Program ($99/yr; D-U-N-S if org) and sign the
   Paid Apps Agreement + banking/tax (Account Holder).
2. Register/verify Play Console account ($25) + payments profile; determine
   account type re: the 12-tester/14-day gate (calendar risk).
3. Declare DSA trader status (Apple, at first submission) and complete Play EEA
   identity verification.
4. Build pipeline: Xcode 26 on macOS for iOS (in force since 2026-04-28);
   Gradle/AAB export with `gradle_build/target_sdk = 36` (Play cutoff
   **2026-08-31** — 18 days from this dossier's check date) and release keystore;
   verify 16 KB alignment of the shipped AAB (Godot 4.7.2 templates comply).
5. Publish privacy policy URL (en + zh-Hant), link it in-app; declare
   "Data Not Collected" (Apple) / no collection (Play Data safety).
6. Answer Apple's updated age-rating questionnaire (expect 9+) and Play's IARC
   questionnaire (no gambling answers — RNG deck/relic drafting is not
   betting/wagering).
7. Set `ITSAppUsesNonExemptEncryption=false` in the exported Xcode project.
8. Produce asset matrix: Apple 6.9" iPhone + 13" iPad screenshots (1–10 each,
   per locale), name/subtitle/keywords within 30/30/100 chars; Play 512px icon,
   1024×500 feature graphic, ≥2 phone + 4×7" + 4×10" tablet screenshots, short
   description ≤80 chars; zh-Hant variants for Apple zh-Hant and Play
   zh-TW/zh-HK; Play ads declaration = No.

*If the crash-reporting SDK lands later: re-open §4 — Apple label gains
Diagnostics → Crash Data (not linked, not tracking, if SDK config strips
identifiers), Play Data safety gains App info and performance → Crash logs;
update the privacy policy and add a consent posture per Apple 5.1.1(ii). No
other section of this dossier changes.*
