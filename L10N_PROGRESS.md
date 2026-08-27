# English Localization — Progress Tracker

Status: **Phase 1 (infrastructure) and Phase 2 (77-file ARB migration) are
both complete.** Pull request: https://github.com/Y1X0/sallehly_app/pull/2

**Phase 3 has started — see §10** for what's been done (`RequestStatus`
enum + `fromWire()` + localized labels, `RequestStatusChip` migrated) and
what's still deliberately out of scope (every other wire-value comparison
site stays on the raw Arabic string, unchanged).

The 16 inline error-banner widgets' consolidation is separately **not**
part of any of this — see §3's "Decision (post-assessment)" for why.
Nothing in §§1-9 below is a pending TODO; it's the historical record of
how Phase 1/2 were done, kept for reference.

## Pre-existing bugs found incidentally (not caused by this work, not fixed here)

Found by `test/widgets/l10n_screen_smoke_test.dart` while validating Phase 1 —
neither is a regression from removing `app.dart`'s hardcoded `Directionality`;
both are flagged for a separate fix, out of scope for the localization work.

- **`EditProfileScreen` — real `RenderFlex` overflow (2.2px) at 320dp width.**
  Reproduces under **both** `locale=ar` and `locale=en` — proof it's a
  pre-existing narrow-screen layout bug, not something the locale/RTL-LTR
  change introduced (a locale-caused overflow would only show under `en`).
  Currently `skip`-marked in the smoke test with a reason, rather than
  removed, so it isn't silently lost and stays easy to re-enable once fixed.
- **`ChatRoomScreen.dispose()` (`chat_room_screen.dart:71`) calls
  `context.read<SocketProvider>()`/`context.read<NotificationProvider>()`
  directly.** Scoped in more depth below (not fixed — the user will decide
  timing after reading this).

  **What's unsafe:** `dispose()` re-reads two providers from `context` at
  teardown time instead of caching them earlier (e.g. in
  `didChangeDependencies()`), which Flutter's own docs warn against. It only
  works because, today, nothing in this codebase tears down the Provider
  ancestors and `ChatRoomScreen` in the same reconciliation pass — see
  below.

  **What triggers it, concretely:** every `Provider`/`ChangeNotifierProvider`
  this screen depends on (`SocketProvider`, `NotificationProvider`, etc.) is
  created once in `SallehlyApp.build()` (`lib/app.dart`), a `StatelessWidget`
  built from the single `runApp()` call in `main.dart`. That `MultiProvider`
  sits **above** the `Navigator`, so any normal navigation — `Navigator.pop()`,
  `pushReplacement`, `pushAndRemoveUntil` (e.g. a logout flow) — only ever
  tears down routes *inside* the Navigator; the Provider ancestors are never
  rebuilt from scratch during a session. Searched the codebase for anything
  that could remove that root scope (a second `runApp()`, a `key:` that would
  force-remount `SallehlyApp`, etc.) and found none. The only way this bug
  was actually reproduced was the smoke test replacing the **entire** widget
  tree at once via a fresh `tester.pumpWidget()` between two unrelated test
  cases (`ChatRoomScreen` → the next screen in the table) — which swaps out
  the Provider ancestors and `ChatRoomScreen` together in one pass. That
  specific pattern has no equivalent in the app's actual navigation code
  today. Net: **I could not find a real user action in the current code
  that triggers this** — only the test-harness artifact that first
  surfaced it. That doesn't make the underlying pattern safe (a future
  change — e.g. an app-level "hard reset" on logout — could reintroduce
  exactly this condition), just that it isn't firing today as far as I can
  tell from the code.

  **Crash or just logged?** The exact error text
  (`"Looking up a deactivated widget's ancestor is unsafe."`) comes from an
  `assert()`-gated check in Flutter's framework — `assert` bodies are
  compiled out entirely in `--release`/`--profile` builds, so this specific
  message can only appear in a **debug** build (which is what the CI-built
  APK for the manual pass is). In debug, framework/lifecycle errors like
  this are reported through `FlutterError.onError` — they print a full
  error to the console/logcat but do not, by themselves, crash the whole
  app process (there's nothing left to render for a widget already being
  disposed). What happens in a **release** build without that assert is
  genuinely unclear without reproducing it there: it could read a stale
  provider harmlessly, or hit a null-check error, depending on exactly when
  Flutter's teardown clears the element's internal ancestor map. Not
  verified either way — flagging the uncertainty rather than guessing.

  **Does Phase 2 make it worse?** No. Phase 2's edits to this file are
  string-extraction only (the ~30+ hardcoded Arabic strings in `build()`,
  the dialogs, `_pickReportReason`, `_ChatHeader`, `_ChatErrorState`,
  `_EmptyChat`, the `showError`/`showInfo` messages, etc.) — it will touch
  most of the file, but none of those edits land inside `initState()` or
  `dispose()` (lines 50–78), which contain no user-facing strings. The
  provider-read pattern is untouched either way; Phase 2 neither improves
  nor worsens this specific issue. Fixing it (caching provider references
  instead of reading them in `dispose()`) would be a separate, deliberate
  change, before or after Phase 2 — user's call.
- **`TechnicianDashboardScreen` — real `RenderFlex` overflow at 320dp only**
  (25px bottom in a `_StatCard`, 10px right in the "requests failed to load"
  error banner). Passes cleanly at 390dp under both locales, fails at 320dp
  under **both** — same "width-dependent, locale-independent" signature as
  `EditProfileScreen`, i.e. a pre-existing narrow-screen bug, not something
  this work introduced. `skip`-marked with a reason, not removed.
- **`CustomerDashboardScreen` — overflow reproduces at all 4 locale/width
  combinations. CONFIRMED test-only artifact of `flutter test`'s default
  font substitution — not a real bug.** Previously left as an unconfirmed
  hedge; empirically resolved as follows.

  Exact overflow sites (from CI `RenderFlex` diagnostics, `flutter test`'s
  default font):
  - `_HeroCard`'s title/subtitle `Column`
    (`customer_dashboard_screen.dart:291`): **72px bottom** at 390dp,
    **92px bottom** at 320dp, both locales (all text here is 100% static
    hardcoded Arabic, not locale/data-dependent).
  - The "خدمات صلّحلي" section-header `Row` (`:177`): **28px right** at
    390dp, **98px right** at 320dp, both locales.
  - `_HeroCard`'s logo/title `Row` (`:294`) — only overflows at 320dp:
    **32px right**, both locales.
  - `_DashboardErrorNotice`'s `Row` (`:223`) — only overflows at 320dp, and
    only when the smoke test's unstubbed API happens to leave the provider
    in its error state: **10px right**, both locales.

  **Re-run with real font metrics instead of the test font:** a temporary
  diagnostic (`test/widgets/customer_dashboard_font_diagnostic_test.dart`,
  now removed) loaded a real Arabic font (Noto Naskh Arabic, installed via
  `apt` in a throwaway CI job — not a project asset) under the `'Roboto'`
  family, which is what Flutter's `Typography` resolves to by default when
  `ThemeData.fontFamily` is `null` (true both of this app's `AppTheme` and
  of the smoke test's plain `MaterialApp()`). This replaces the test
  font's fixed-width square glyphs (which measurably overstate Arabic text
  width and don't apply real Arabic shaping/ligatures) with real
  proportional metrics, without touching any file under `lib/`.

  Result: **all 4 combinations pass with zero overflow** under the real
  font — including both 320dp cases, which had *more* overflow sites than
  390dp under the test font. CI run:
  https://github.com/Y1X0/sallehly_app/actions/runs/33033359294 (job
  `font-diagnostic`, all 4 `[FONT-DIAG]` cases printed "NO OVERFLOW").

  **Verdict: test artifact, not a real bug.** No fix proposed or needed.
  The `skip` entries for `CustomerDashboardScreen` in
  `l10n_screen_smoke_test.dart` are left in place (removing them was not
  asked for) but the "not confidently diagnosed" language there and here is
  now resolved. If desired later, these 4 skips could be safely removed
  from the smoke test now that the underlying cause is understood — that's
  a follow-up decision, not done here.

## Decisions locked in (approved, apply consistently in later phases)

- **Chevron mirroring:** `lib/core/ui/directional_icons.dart` created (mirrors
  back/forward navigational icons via `Directionality.of(context)`, matching
  Flutter's own `BackButtonIcon` convention — `arrow_forward` in RTL,
  `arrow_back` in LTR). **Not yet applied to any of the ~9 call sites** —
  deferred to Phase 2, to be wired in when each of those specific files is
  migrated (same file-by-file discipline as string extraction), per the
  original Phase 2 workflow ("fix RTL/LTR issues in that same file"). Applying
  it will visibly change the Arabic back-icon's direction (left→right) to
  match true RTL convention — flagging again here so it's not a surprise when
  Phase 2 reaches those files. Media/playback/time icons are explicitly out of
  scope for this helper.
- **Request status wire values:** left untouched in `request_model.dart` /
  `request_status_chip.dart` / `socket_provider.dart`. A comment was added at
  the getters in `request_model.dart` marking them as backend wire values.
  The real fix (`RequestStatus` enum + `fromWire()` + localized label lookup,
  with an unknown/fallback case) is deferred to its own **Phase 3**, not to be
  started without explicit approval.
- **Backend error messages:** `ApiException.message` still shows the raw
  server string as-is. One canonical TODO comment was added on the `message`
  field itself in `lib/core/api/api_exception.dart` (not duplicated at each of
  the ~40+ display call sites) explaining why, and pointing back to §5 below.

---

## 1. Current infrastructure state (as found)

| Item | State |
|---|---|
| `pubspec.yaml` | `flutter_localizations` (sdk) and `intl: ^0.20.2` are **already declared as dependencies**, but unused — no `l10n.yaml`, no `lib/l10n/` directory, no generated `AppLocalizations`. |
| `l10n.yaml` | Does not exist. |
| `lib/l10n/` | Does not exist. |
| `MaterialApp` (`lib/app.dart`) | `locale` is hardcoded to `const Locale('ar')`. `supportedLocales` contains only `Locale('ar')`. `localizationsDelegates` only lists the three Flutter/Cupertino global delegates (no app-specific delegate, since none is generated). The `builder:` wraps everything in a hardcoded `Directionality(textDirection: TextDirection.rtl, ...)` — **this alone forces RTL app-wide regardless of locale** and must be replaced with locale-driven direction in Phase 1. |
| Existing note in code | `app.dart` already has a comment block (search `[FIX-LOCALE-01]`) explicitly documenting that English was deliberately removed earlier because it wasn't really translated — i.e. this is a known, previously-flagged gap. |
| Theme persistence pattern to mirror | `lib/providers/theme_controller.dart` — a `ChangeNotifier` (`ThemeController`) that loads/saves a single value via `SharedPreferences` under one string key (`sallehly_light_mode`), and is registered as a `ChangeNotifierProvider` in `app.dart`, consumed via `context.watch<ThemeController>()` at the `MaterialApp` root to force a full rebuild. **`LocaleProvider` in Phase 1 should copy this exact shape** (key e.g. `sallehly_locale`, `loadSaved()`, `setLocale()`). |

**Conclusion:** the plumbing is half-declared (dependencies present) but zero actual localization exists — every user-facing string is a literal in the widget tree.

---

## 2. Hardcoded Arabic strings — file inventory

77 files contain user-facing Arabic string literals (comment-only lines excluded from the count). Ordered smallest → largest as requested, for Phase 2 migration order. Two files are called out separately below the table because they need special handling, not line-by-line ARB extraction.

| # | File | ~Strings | Screen / feature |
|---|---|---|---|
| 1 | `lib/config/app_config.dart` | 1 | App brand name constant (`appName = 'صلّحلي'`) |
| 2 | `lib/core/widgets/app_logo.dart` | 1 | App logo widget |
| 3 | `lib/features/chat/data/chat_api.dart` | 1 | Chat API layer |
| 4 | `lib/features/notifications/widgets/notification_bell.dart` | 1 | Notification bell (tooltip) |
| 5 | `lib/models/support_ticket_model.dart` | 1 | Support ticket model |
| 6 | `lib/providers/socket_provider.dart` | 1 | Socket provider — sets a status label locally (see §4 note) |
| 7 | `lib/core/widgets/consent_checkbox.dart` | 2 | Consent checkbox (used in registration) |
| 8 | `lib/features/technician/widgets/technician_request_card.dart` | 2 | Technician request card |
| 9 | `lib/app.dart` | 3 | App root — title, offline/slow-server banner |
| 10 | `lib/features/wallet/screens/ledger_screen.dart` | 3 | Wallet ledger |
| 11 | `lib/models/admin_user_model.dart` | 3 | Admin user model |
| 12 | `lib/core/widgets/services_multi_select.dart` | 4 | Services multi-select (technician registration) — **also has an RTL bug, see §3** |
| 13 | `lib/features/chat/widgets/chat_bubble.dart` | 4 | Chat bubble |
| 14 | `lib/features/notifications/screens/notifications_screen.dart` | 4 | Notifications screen |
| 15 | `lib/features/requests/widgets/request_status_chip.dart` | 4 | Request status chip — **displays the raw backend status string directly, see §4** |
| 16 | `lib/features/support/provider/support_provider.dart` | 4 | Support provider |
| 17 | `lib/features/wallet/screens/packages_screen.dart` | 4 | Wallet packages |
| 18 | `lib/features/wallet/widgets/package_card.dart` | 4 | Package card |
| 19 | `lib/features/auth/data/auth_api.dart` | 5 | Auth API layer |
| 20 | `lib/features/splash/splash_screen.dart` | 5 | Splash screen |
| 21 | `lib/features/wallet/provider/wallet_provider.dart` | 5 | Wallet provider |
| 22 | `lib/features/wallet/widgets/topup_card.dart` | 5 | Topup card |
| 23 | `lib/models/request_model.dart` | 5 | Request model — **status getters compare against raw Arabic values, see §4** |
| 24 | `lib/core/notifications/firebase_notification_service.dart` | 6 | Push notification title/body templates |
| 25 | `lib/features/customer/widgets/offer_card.dart` | 6 | Offer card |
| 26 | `lib/features/admin/screens/admin_ledger_screen.dart` | 7 | Admin ledger |
| 27 | `lib/features/admin/screens/admin_support_chat_screen.dart` | 7 | Admin support chat |
| 28 | `lib/features/auth/screens/register_role_screen.dart` | 7 | Register: choose role |
| 29 | `lib/features/auth/screens/verify_otp_screen.dart` | 7 | Verify OTP |
| 30 | `lib/features/chat/widgets/chat_input.dart` | 7 | Chat input bar |
| 31 | `lib/features/layout/customer_layout.dart` | 7 | Customer bottom-nav layout |
| 32 | `lib/features/technician/screens/my_reviews_screen.dart` | 7 | Technician reviews |
| 33 | `lib/providers/auth_provider.dart` | 7 | Auth provider |
| 34 | `lib/features/admin/screens/admin_audit_screen.dart` | 8 | Admin audit log |
| 35 | `lib/features/layout/technician_layout.dart` | 8 | Technician bottom-nav layout |
| 36 | `lib/features/admin/screens/admin_support_screen.dart` | 9 | Admin support tickets list |
| 37 | `lib/features/auth/screens/landing_screen.dart` | 9 | Landing / welcome |
| 38 | `lib/features/chat/provider/chat_provider.dart` | 9 | Chat provider |
| 39 | `lib/features/customer/widgets/complaint_sheet.dart` | 9 | Complaint sheet |
| 40 | `lib/features/support/screens/support_chat_screen.dart` | 9 | Support chat (customer/technician side) |
| 41 | `lib/features/technician/screens/technician_request_details_screen.dart` | 10 | Technician request details |
| 42 | `lib/core/api/api_client.dart` | 11 | API client — local (non-backend) error strings |
| 43 | `lib/features/customer/screens/offers_screen.dart` | 11 | Customer: offers list |
| 44 | `lib/features/layout/admin_layout.dart` | 11 | Admin bottom-nav layout |
| 45 | `lib/features/requests/provider/requests_provider.dart` | 11 | Requests provider |
| 46 | `lib/features/technician/screens/new_requests_screen.dart` | 11 | Technician: new requests |
| 47 | `lib/features/auth/screens/login_screen.dart` | 13 | Login |
| 48 | `lib/features/settings/screens/change_password_screen.dart` | 13 | Change password |
| 49 | `lib/features/settings/screens/edit_profile_screen.dart` | 13 | Edit profile |
| 50 | `lib/features/technician/screens/technician_orders_screen.dart` | 13 | Technician orders |
| 51 | `lib/core/widgets/image_source_picker.dart` | 14 | Image source picker (camera/gallery) |
| 52 | `lib/features/customer/widgets/rate_technician_sheet.dart` | 14 | Rate technician sheet |
| 53 | `lib/features/wallet/screens/wallet_screen.dart` | 14 | Wallet home |
| 54 | `lib/features/wallet/screens/topup_request_screen.dart` | 15 | Topup request |
| 55 | `lib/features/admin/screens/admin_topups_screen.dart` | 16 | Admin topups |
| 56 | `lib/features/customer/screens/customer_request_details_screen.dart` | 16 | Customer request details |
| 57 | `lib/features/auth/screens/customer_register_screen.dart` | 17 | Customer registration |
| 58 | `lib/features/chat/screens/chats_screen.dart` | 17 | Chats list |
| 59 | `lib/features/customer/screens/customer_dashboard_screen.dart` | 17 | Customer dashboard |
| 60 | `lib/features/technician/screens/send_offer_screen.dart` | 17 | Send offer |
| 61 | `lib/features/auth/screens/forgot_password_screen.dart` | 18 | Forgot password |
| 62 | `lib/features/technician/screens/technician_dashboard_screen.dart` | 18 | Technician dashboard |
| 63 | `lib/features/customer/screens/customer_requests_screen.dart` | 22 | Customer requests list |
| 64 | `lib/features/customer/screens/create_request_screen.dart` | 23 | Create request |
| 65 | `lib/features/admin/provider/admin_provider.dart` | 24 | Admin provider |
| 66 | `lib/features/support/screens/support_screen.dart` | 24 | Support (entry screen) |
| 67 | `lib/features/auth/screens/technician_register_screen.dart` | 26 | Technician registration |
| 68 | `lib/providers/notification_provider.dart` | 29 | Notification provider |
| 69 | `lib/features/admin/screens/admin_dashboard_screen.dart` | 32 | Admin dashboard |
| 70 | `lib/features/admin/screens/admin_requests_screen.dart` | 32 | Admin requests |
| 71 | `lib/features/admin/screens/admin_user_detail_screen.dart` | 32 | Admin user detail |
| 72 | `lib/features/admin/screens/admin_meta_screen.dart` | 40 | Admin services/meta management |
| 73 | `lib/features/admin/screens/admin_moderation_screen.dart` | 48 | Admin moderation (complaints) |
| 74 | `lib/features/admin/screens/admin_users_screen.dart` | 50 | Admin users list |
| 75 | `lib/features/settings/screens/privacy_policy_screen.dart` | 51 | Privacy policy |
| 76 | `lib/features/chat/screens/chat_room_screen.dart` | 57 | Chat room |
| 77 | `lib/features/settings/screens/settings_screen.dart` | 57 | Settings (language switcher goes here in Phase 1) |

### Excluded from the table (handled separately)

- **`lib/firebase_options.dart`** — its Arabic text is entirely inside `UnsupportedError()` messages thrown when a platform isn't configured (dev-only diagnostics, never seen by end users). Per the "don't touch debug strings" rule, **excluded from migration**.
- **`lib/core/utils/app_constants.dart`** (~167 lines) — this is the Jordan governorates/areas dataset (just completed in a prior task). These are **place names**, not UI copy. See §5 below for why this needs a different approach than ARB keys.

---

## 3. RTL/LTR breakage found

### Will actually break (or look wrong) in LTR

| Issue | Location | Detail |
|---|---|---|
| App-wide forced RTL | `lib/app.dart:267-268` | `MaterialApp.builder` wraps everything in `Directionality(textDirection: TextDirection.rtl, ...)` unconditionally. **This is the #1 blocker** — must become locale-derived (or removed — `Localizations`/`MaterialApp` already derive direction from `locale` automatically; this explicit override currently defeats that). |
| Asymmetric `EdgeInsets.only` | `lib/core/widgets/services_multi_select.dart:123` | `padding: const EdgeInsets.only(right: 6)` on the "at least N services required" hint — a single-sided inset tied to the visual right, should be `EdgeInsetsDirectional.only(end: 6)`. |
| Hardcoded directional back-icons | `chat_room_screen.dart:767`, `register_role_screen.dart:39,167`, `customer_requests_screen.dart:306`, `create_request_screen.dart:315`, `offers_screen.dart:149`, `admin_dashboard_screen.dart:472` | Custom back buttons use `Icon(Icons.arrow_back_rounded)` / `Icons.arrow_back_ios_new_rounded` directly instead of Flutter's direction-aware `BackButtonIcon()`. These will keep pointing the same visual direction in both locales instead of mirroring for LTR. Needs a design decision in Phase 1 (mirror vs. keep fixed) before Phase 2 touches these files. |
| Forward-chevron list icons | `settings_screen.dart:619`, `chats_screen.dart:389`, `technician_request_card.dart:193` | Same class of issue — `Icons.arrow_forward_ios_rounded` used as a static "navigate into" affordance; same mirroring decision applies. |

### Found but NOT a bug (checked, safe to leave)

- `EdgeInsets.only(left: X, right: X, ...)` in `support_screen.dart:368`, `rate_technician_sheet.dart:99`, `complaint_sheet.dart:73` — symmetric (equal left/right), so direction-agnostic. Fine to leave, though could be tidied to `symmetric(horizontal:)` opportunistically while touching those files.
- `MainAxisAlignment.start/end`, `CrossAxisAlignment.start/end` (89 occurrences, 40 files) — these already respect `Directionality` automatically in Flutter; not a bug.
- `Positioned(top:0, left:0, right:0, ...)` in `app.dart`'s offline banner — symmetric, direction-agnostic.
- `TextDirection.ltr` forced on phone-number/OTP/password fields in 8 auth/settings screens (`login_screen.dart`, `forgot_password_screen.dart`, `customer_register_screen.dart`, `technician_register_screen.dart`, `verify_otp_screen.dart`, `change_password_screen.dart`, `edit_profile_screen.dart`, `send_offer_screen.dart`) — **intentional**, forcing digits/phone numbers to render LTR regardless of app language is correct behavior and should be preserved as-is in both locales.
- `Alignment.topRight/bottomLeft/centerRight/centerLeft` in `app_colors.dart` (gradient definitions) and `glass_card.dart` — purely decorative diagonal gradients, not tied to reading direction. Leave as-is.
- No `TextAlign.right` found anywhere in `lib/`.
- No asymmetric `Positioned(left:/right:)` found.

### Arabic content renders on the wrong side under `locale=en` (bidi mismatch)

Found via the real-font CI screenshots (see "Visual regression net" below), confirmed
in 4 places initially, then swept for every other site with the same root cause.

**Mechanism:** a `Text` widget with no explicit `textDirection` inherits
`Directionality.of(context)` as its paragraph base direction. Under `locale=en`
that's now `TextDirection.ltr` (correctly — Phase 1 removed the hardcoded RTL
override). When the widget's *content* is still Arabic, trailing punctuation
(a sentence-ending period, in every case caught) visually jumps to the
**start** of the line instead of staying at the end — e.g. `.اطلب الفني
الأقرب إليك` instead of `اطلب الفني الأقرب إليك.`. This is a real instance of
"an element stuck on the wrong side after the LTR flip," not a font/rendering
artifact — confirmed by eye in the screenshots at
`l10n-screenshots-latest`.

This splits into two categories with different fixes:

**A. Transitional — resolves on its own once Phase 2 migrates the string.**
These are hardcoded Arabic *UI labels* that become real English text under
`locale=en` once extracted to ARB; a genuinely-English string in an LTR
paragraph has no bidi mismatch to begin with.
- `customer_dashboard_screen.dart:348` — `_HeroCard` subtitle
- `technician_dashboard_screen.dart:308` — hero subtitle
- `chats_screen.dart:194` — empty-state subtitle

No action needed on these beyond their normal Phase 2 migration.

**B. Needs a content-direction fix — stays Arabic regardless of locale.**
This is content Phase 2 does **not** migrate (by earlier decisions in this
doc — see §5): it's real Arabic text embedded in a UI whose *ambient*
direction can now be LTR. Swept the codebase for every render site, grouped
by source (not limited to the 4 the screenshots happened to catch):

- **User-generated text** (§5 already lists these categories; these are the
  concrete render sites):
  - `RequestModel.description` — `customer_request_details_screen.dart:144`,
    `technician_request_details_screen.dart:131`,
    `customer_request_card.dart:108`, `technician_request_card.dart:154`
  - Chat messages (`MessageModel.body`) — `chat_bubble.dart:211`
  - Support ticket messages (`SupportMessageModel.body`) —
    `support_chat_screen.dart:373`, `admin_support_chat_screen.dart:322`
  - Support ticket title/body (`SupportTicketModel.title`/`.body`) —
    `support_screen.dart:238,274`, `admin_support_screen.dart:220,253`
  - Review comments (`ReviewModel.comment`) — `my_reviews_screen.dart:253`
  - Offer duration/note (`OfferModel.duration`/`.note`, technician-entered
    free text) — `offer_card.dart:58,64`
  - *Considered, not included:* `UserModel.name`. Names are short,
    single-token in practice, and none of the screenshots showed a
    mis-placed name — lower priority, your call whether to include it.
- **Place names from `app_constants.dart`** (client-side constant, excluded
  from migration per §5) — rendered standalone or as the recurring
  `'${city}${area == null ? '' : ' - $area'}'` composite:
  `customer_request_details_screen.dart:129`,
  `technician_request_details_screen.dart:114`,
  `customer_request_card.dart:96`, `technician_request_card.dart:29`,
  `chat_room_screen.dart:495`, `send_offer_screen.dart:163`,
  `settings_screen.dart:255-256` (standalone, not composite). Unlike the
  user-generated category, these don't strictly need runtime *detection*
  (they're always Arabic) — a hardcoded `TextDirection.rtl` would work just
  as well; grouping them with the same helper is for consistency, not
  necessity.
- **Backend error messages** (`ApiException.message`, §5) — rendered through
  two recurring duplicated-per-screen patterns, not one shared widget:
  - A local `showError(String)` method → `SnackBar(content: Text(message))`,
    duplicated in 18 files: `chat_room_screen.dart`,
    `topup_request_screen.dart`, `send_offer_screen.dart`,
    `support_chat_screen.dart`, `edit_profile_screen.dart`,
    `change_password_screen.dart`, `complaint_sheet.dart`,
    `create_request_screen.dart`, `forgot_password_screen.dart`,
    `login_screen.dart`, `technician_register_screen.dart`,
    `verify_otp_screen.dart`, `customer_register_screen.dart`,
    `admin_meta_screen.dart`, `admin_support_chat_screen.dart`,
    `admin_topups_screen.dart`, `admin_user_detail_screen.dart`,
    `admin_users_screen.dart`.
  - A local `_XxxErrorState`/`_XxxNotice` private widget reading
    `provider.error` for a persistent inline banner (not a toast),
    duplicated in 16 files: `chat_room_screen.dart`, `wallet_screen.dart`,
    `new_requests_screen.dart`, `technician_dashboard_screen.dart`,
    `technician_orders_screen.dart`, `support_screen.dart`,
    `customer_dashboard_screen.dart`, `customer_requests_screen.dart`,
    `offers_screen.dart`, `chats_screen.dart`, `admin_dashboard_screen.dart`,
    `admin_ledger_screen.dart`, `admin_requests_screen.dart`,
    `admin_user_detail_screen.dart`, `admin_users_screen.dart`,
    `admin_audit_screen.dart`.
  - This matches the "~40+ call sites" already noted on `ApiException.message`
    itself — the fix is the same one-line change at each site (wrap the
    `Text(message)`), not a refactor of the duplication itself (that's a
    separate, unrelated cleanup this doc isn't proposing).

  **Would a shared error widget be small or large? Checked both patterns —
  they're not the same size of change:**
  - The 18-file `showError` SnackBar pattern is **small**. It's already
    byte-for-byte uniform (`ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(backgroundColor: AppColors.danger, content: Text(message)))`)
    and there's an existing precedent to mirror exactly:
    `showSuccessSnackBar(BuildContext, String)` already lives in
    `core/widgets/success_feedback.dart` as a top-level function, not a
    per-widget method. A `showErrorSnackBar` twin plus deleting the 18 local
    `showError` methods in favor of it is mechanical, low-risk, and doesn't
    require any per-site judgment calls.
  - The 16-file `_XxxErrorState`/`_XxxNotice` inline-banner pattern is
    **larger**. Unlike the SnackBar helper, these are NOT byte-identical:
    title copy differs per screen ("تعذّر تحميل بياناتك" and others), some
    include a retry button (`onRetry: VoidCallback`) and some don't, and
    they're inline `StatelessWidget`s embedded in each screen's layout
    rather than an ephemeral overlay — so consolidating them means actually
    designing one parameterized widget (title, message, optional retry) and
    verifying each of the 16 sites still reads correctly afterward, not
    just a search-and-replace. Real work, not large in an absolute sense,
    but a different category of change than the SnackBar half.
  - Not being done now, per your instruction — this is only the size
    assessment for you to decide on later.

  **Decision (post-assessment): do the SnackBar half, defer the banner
  half.** `showErrorSnackBar(BuildContext, String)` now lives in
  `core/widgets/success_feedback.dart` as a twin to `showSuccessSnackBar`
  (same file, same conventions — one difference: it checks
  `context.mounted` before showing, since most call sites fire after an
  awaited API call where the widget can already be gone; the original 18
  local methods all had this same guard, so it's preservation, not a new
  behavior). All 18 local `showError` methods are deleted; their call
  sites now call the shared function directly. The 16 `_XxxErrorState`/
  `_XxxNotice` inline banners are **deliberately left as they are** —
  they're not byte-identical (different titles, some have a retry button
  and some don't), so consolidating them into one parameterized widget is
  a real design task, not a mechanical rename, and isn't worth doing
  right now. Revisit only if a new banner site is about to be added and
  copy-pasting one of the 16 starts to feel wrong.

**Implemented, tested, and CI-verified (`BidiText`, `lib/core/widgets/bidi_text.dart`
+ `test/widgets/bidi_text_test.dart`) — not yet applied to any Category B call
site. Landed as its own commit ahead of Phase 2, per the user's request.**

`BidiText` wraps `Text` and derives `textDirection` from
`Bidi.estimateDirectionOfText(content)` — the whole-string heuristic, not
`detectRtlDirectionality` (first-strong-character only) originally sketched
above. This was a deliberate, validated choice: a throwaway 15-case
comparison test (real Arabic descriptions, city-area composites, digit/
phone/punctuation/Latin-brand-leading Arabic, genuine English, mixed
content, empty/whitespace) showed both heuristics agree on every realistic
case here — digits and punctuation are *weak/neutral* directionality types
per the Unicode Bidi Algorithm, so `detectRtlDirectionality` already skips
them to find the first true script character. The real reason to prefer
`estimateDirectionOfText` is its three-way result: `UNKNOWN` for
directionally-neutral content (empty, whitespace-only, punctuation-only),
which `BidiText` uses as a signal to fall back to the ambient
`Directionality` instead of forcing a direction onto content that has none.

```dart
class BidiText extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const BidiText(this.text, {super.key, this.style, this.textAlign,
      this.maxLines, this.overflow, this.softWrap});

  @override
  Widget build(BuildContext context) {
    final ambient = Directionality.of(context);
    final content = text ?? '';
    final direction = switch (intl.Bidi.estimateDirectionOfText(content)) {
      intl.TextDirection.RTL => TextDirection.rtl,
      intl.TextDirection.LTR => TextDirection.ltr,
      _ => ambient, // UNKNOWN — no strong-direction content, keep ambient
    };
    // .start/.end resolve against AMBIENT direction, not detected content
    // direction, so alignment never shifts as a side effect of content-based
    // direction detection (see settings_screen.dart's _InfoTile below).
    var resolvedAlign = textAlign;
    if (textAlign == TextAlign.start) {
      resolvedAlign = ambient == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    } else if (textAlign == TextAlign.end) {
      resolvedAlign = ambient == TextDirection.rtl ? TextAlign.left : TextAlign.right;
    }
    return Text(content, textDirection: direction, style: style,
        textAlign: resolvedAlign, maxLines: maxLines, overflow: overflow,
        softWrap: softWrap);
  }
}
```

Two things the original sketch above missed, both required by real call
sites and both covered by tests:

- **Never throws, never moves the parent.** `Text.textDirection` is a
  leaf-level paragraph-shaping parameter only — it cannot propagate to an
  ancestor `Align`/`Column`. A chat bubble's side (`chat_bubble.dart`,
  `Align(alignment: isMe ? .centerLeft : .centerRight)`) stays exactly where
  the sender puts it, even when an Arabic-UI user types an English reply
  ("OK", "done", "call me at 0791234567") that renders LTR internally.
  Verified with widget tests, not just reasoned about.
- **`textAlign.start`/`.end` track ambient direction, not content
  direction.** `settings_screen.dart`'s `_InfoTile` (the one real call site
  using `TextAlign.end` today) pins a trailing value (city/area, always
  Arabic/RTL) to the end of a row. Naively deriving alignment from detected
  content direction would have flipped that value's visual side the moment
  `BidiText` landed, even though nothing about the row's layout changed —
  exactly the alignment side-effect risk the user flagged. Resolving
  `.start`/`.end` against ambient direction first keeps existing layouts
  pixel-identical.

Test coverage (`bidi_text_test.dart`): no-throw across
empty/whitespace/digits-only/punctuation-only/emoji-only/null × both
ambient directions; content-derived direction for real Arabic, real
English, and the English-in-Arabic-UI case (`'OK'`, `'done'`, `'call me at
0791234567'` all render LTR under ambient RTL); ambient fallback on
UNKNOWN in both directions; parent-`Align`-position independence (mirrors
`chat_bubble.dart`'s pattern); `.start`/`.end`-follows-ambient (mirrors
`_InfoTile`); full passthrough of `style`/`maxLines`/`overflow`/`softWrap`.
CI: `flutter analyze` clean, full suite green including this file.

This is a drop-in replacement for `Text(...)` at each Category B site
listed above — same parameters used at those sites, so applying it is a
mechanical per-file change, not a redesign. **Not yet applied anywhere** —
pending the user's go-ahead to start the batch-of-~5 rollout.

### Needs a design call, not a code bug

- `Alignment.centerLeft : Alignment.centerRight` used for **"is this my chat bubble"** placement (`chat_bubble.dart:161`, `support_chat_screen.dart:345`, `admin_support_chat_screen.dart:294`) and one **section-title alignment** (`settings_screen.dart:525`, `package_card.dart:59`, bonus badge). Chat-bubble side-by-sender is arguably fine to keep absolute (WhatsApp-style: "my messages" stay on one visual side regardless of language) — flagging for your call before Phase 2 touches those 5 files, since converting to `AlignmentDirectional` would flip bubble sides between AR and EN.

---

## 4. Two structural issues to flag before any code changes (important)

These aren't "strings to translate" — they're places where the **backend's Arabic text is load-bearing business logic**, not just display copy. Getting this wrong would silently break status logic app-wide.

1. **`lib/models/request_model.dart`** — getters like `isWaiting`, `isCompleted`, `isCancelled`, `hasOffers`, `isCancellable` compare `status` against literal Arabic strings (`'بانتظار العروض'`, `'مكتمل'`, `'ملغي'`, `'وصلت عروض'`, `'قيد التنفيذ'`) because **the backend itself sends these Arabic strings as the wire value of `status`**, not an enum code.
2. **`lib/features/requests/widgets/request_status_chip.dart`** renders that same raw `status` string directly as the chip's `Text(status, ...)` — so today, the Arabic word literally *is* both the data and the display label, with the same pattern echoed in `socket_provider.dart:193` when applying an optimistic local update.

**Implication for Phase 2:** these Arabic values must **not** be replaced with English text or ARB keys — that would break comparisons across the entire app the moment the backend still sends Arabic and the client no longer recognizes it. The correct fix is a small **status → localized label mapping function** (Arabic wire value in, `AppLocalizations` key out) introduced in `request_status_chip.dart` (and the ~6 other screens listed in the table that read `.status` directly), while `request_model.dart`'s comparisons stay untouched against the Arabic backend values. **Decision (locked in):** this real fix is its own **Phase 3** (`RequestStatus` enum + `fromWire()` + localized label lookup with an unknown/fallback case), started only on explicit approval, after all of Phase 2's plain-string migration is done. For now (Phase 1), a comment was added directly above the getters in `request_model.dart` marking them as backend wire values that must never be changed — no logic touched.

---

## 5. Backend strings (do not fake-translate — list only)

Per your rule: if a string comes from the backend, it's listed here, not migrated to ARB with an invented translation.

- **API/business error messages** — `ApiException.message` (`lib/core/api/api_exception.dart`) carries the server's raw error text through to the UI in ~40+ call sites across every provider/screen that does a `try { ... } on ApiException catch (e) { ... e.message ... }`. The backend currently only replies in Arabic. Real English support here requires the **backend** to either (a) return a language-agnostic error `code` (already partly done — see `ApiException.code`, added for `INSUFFICIENT_BALANCE`) that the Flutter side maps to a localized message, or (b) support an `Accept-Language` header. Out of scope for this Flutter-only migration; flagging so it's not silently missed. Some screens already partially use `code` for branching (e.g. `send_offer_screen.dart`) — that pattern should be extended, not the message text translated client-side.
- **Request/offer/ticket/topup `status` fields** — see §4 above. Raw Arabic wire values from the backend, not translatable strings.
- **User-generated content** — chat messages, complaint text, support ticket bodies, review comments — inherently whatever language the user typed in; not part of this migration.
- **`lib/core/utils/app_constants.dart`** governorate/area names — not backend-sourced (client-side constant), but same principle applies: these are proper place names. See note below.

### Special note: place names (`app_constants.dart`)

Jordan's 12 governorates and ~153 areas are proper nouns. Standard practice is a transliteration/exonym table (e.g. `عمّان` → `Amman`, `إربد` → `Irbid`), not a "translation." This is a well-defined but separate ~165-entry data task, not a UI-copy extraction — recommend handling it as its own small Phase 2 item (its own ARB file section or a static lookup map), after the infrastructure lands, rather than folding it into any single screen's turn.

---

## 6. Phase 1 scope checklist — DONE

- [x] `l10n.yaml` + `lib/l10n/app_ar.arb` (template) + `lib/l10n/app_en.arb` — only the 3 language-switcher strings for now, nothing else migrated
- [x] `LocaleProvider` (`lib/providers/locale_provider.dart`) — mirrors `ThemeController` shape exactly (same `ChangeNotifier` + `SharedPreferences` pattern, key `sallehly_locale`), persisted via `SharedPreferences`
- [x] `MaterialApp` (`lib/app.dart`): wired `AppLocalizations.delegate`, `supportedLocales: [Locale('ar'), Locale('en')]`, `locale` from `LocaleProvider` (default/fallback `ar`), `localeResolutionCallback` returning `ar` for any unsupported device locale (defensive — not actually exercised since `locale` is always explicit/non-null)
- [x] Removed the hardcoded `Directionality(TextDirection.rtl)` wrapper entirely — direction is now derived automatically by the framework from `locale`/`GlobalWidgetsLocalizations.delegate` (already registered), not replaced with any conditional `Directionality` widget
- [x] Language switcher added to `settings_screen.dart` (file #77), right next to the existing `_ThemeModeTile`, same visual/interaction pattern (icon + title + subtitle + `Switch`)
- [x] `pubspec.yaml`: added `generate: true` under `flutter:` to enable `flutter gen-l10n` (runs automatically on `flutter pub get`)
- [x] `.gitignore`: added the two generated `lib/l10n/app_localizations*.dart` files (regenerated by every build, never committed)
- [x] Fixed the one existing test that renders `SettingsScreen` (`test/widgets/settings_logout_test.dart`) to also provide `LocaleProvider` + the localization delegates, since it previously only wired `AuthProvider`/`ThemeController` and would have broken the moment `_LanguageTile` needed `AppLocalizations.of(context)`
- [x] Added `test/widgets/locale_switch_test.dart`: `LocaleProvider` persistence across a simulated restart (fresh instance + `loadSaved()`), and a full `SettingsScreen` widget test proving the switch flips `Directionality` from `rtl`→`ltr` with zero uncaught exceptions (covers the overflow-check acceptance criterion)
- [x] `request_model.dart`: added the wire-value comment (§4/decisions above), no logic changed
- [x] `api_exception.dart`: added the one canonical TODO comment (§5/decisions above), no logic changed
- [x] `lib/core/ui/directional_icons.dart` created per the chevron-mirroring decision — **not yet wired into any screen**, deferred to Phase 2 (see decisions section above)
- [x] CI green (`flutter analyze` + `flutter test` + build) — verified via GitHub Actions throughout, no local Flutter SDK in this environment

Phase 2 proceeded through the 77-file table below, smallest first, in
batches of 5, each followed by `flutter analyze` via CI and a checkbox tick
here. **Complete — see §9.**

---

## 9. Phase 2 progress checklist — DONE, all 77 files migrated

Worked continuously in batches of 5 files (smallest → largest, per §2's
table), `flutter analyze` clean after each batch via CI, no approval gate
between batches per the user's instruction. Checked off here as each file's
strings were fully migrated to ARB keys (plus any §3 RTL fix / nav-icon
mirroring due in that same file).

- [x] 1. `lib/config/app_config.dart` — `appName` is unused dead code (verified, zero call sites); left as a plain constant with a note, not converted
- [x] 2. `lib/core/widgets/app_logo.dart` — `appWordmark` key ("صلّحلي" / "Sallehly", transliterated brand name matching the domain)
- [x] 3. `lib/features/chat/data/chat_api.dart` — fallback string deferred to #38/#76 (data-layer, no BuildContext; will thread as nullable), noted inline
- [x] 4. `lib/features/notifications/widgets/notification_bell.dart` — `notificationsBellTooltip` key
- [x] 5. `lib/models/support_ticket_model.dart` — `'عام'` is a wire-value default (SupportTicketModel.type, same class of issue as RequestModel.status), commented per the established Phase 3 wire-value convention, not migrated
- [x] 6. `lib/providers/socket_provider.dart` — `'تم اختيار عرض'` is a wire-value (matches RequestModel.status), commented per Phase 3 convention, not migrated
- [x] 7. `lib/core/widgets/consent_checkbox.dart` — `consentAgreeToPrefix` + `privacyPolicyTitle` (shared key, reused by #75)
- [x] 8. `lib/features/technician/widgets/technician_request_card.dart` — `newRequestBadge` + `viewDetailsAndSendOffer`; also §3 forward-chevron → `DirectionalIcons.forwardIosStyle`
- [x] 9. `lib/app.dart` — title moved from `MaterialApp.title` to `onGenerateTitle` (reuses `appWordmark`, since `title:`'s context is above where Localizations gets built); `connectivityOfflineMessage` + `connectivityServerSlowMessage`
- [x] 10. `lib/features/wallet/screens/ledger_screen.dart` — `ledgerTitle` + `ledgerComingSoonTitle` + `ledgerComingSoonSubtitle`
- [x] 11. `lib/models/admin_user_model.dart` — `roleAr` deferred to #74 (only call site, needs BuildContext for AppLocalizations, model class has none), commented
- [x] 12. `lib/core/widgets/services_multi_select.dart` — `servicesMultiSelectPlaceholder`, `servicesMinRequired` (ARB plural, not concatenation), `listSeparator`; §3 `EdgeInsets.only(right:)` → `EdgeInsetsDirectional.only(end:)` fixed
- [x] 13. `lib/features/chat/widgets/chat_bubble.dart` — `audioMessagePlaying`, `audioMessageLabel`, `locationMessageLabel`, `imageLoadFailedMessage` (shared by both error sites)
- [x] 14. `lib/features/notifications/screens/notifications_screen.dart` — `notificationsMarkAllRead`, `notificationsEmptyTitle`, `notificationsEmptySubtitle`; AppBar title reused `notificationsBellTooltip`
- [x] 15. `lib/features/requests/widgets/request_status_chip.dart` — **SKIPPED, Phase 3** per instruction
- [x] 16. `lib/features/support/provider/support_provider.dart` — 4 fallback strings feed the deferred banner widgets (same BidiText-phase decision), commented not migrated
- [x] 17. `lib/features/wallet/screens/packages_screen.dart` — `packagesScreenTitle`, `packagesLoadFailedTitle`, `retryButton`, `packagesEmptyTitle`; `wallet.error!` left alone (not a literal, resolved at #21)
- [x] 18. `lib/features/wallet/widgets/package_card.dart` — new `core/utils/currency_format.dart` helper (`NumberFormat`-based, reused going forward for all 14 files using "د.أ"); `packageBonusLabel`, `packageBalanceAfterApproval`, `selectPackageButton`
- [x] 19. `lib/features/auth/data/auth_api.dart` — 5 backend-fallback strings, data layer with no BuildContext, deferred to their consuming screens (register/OTP/forgot-password/reset-password/delete-account flows), commented
- [x] 20. `lib/features/splash/splash_screen.dart` — `splashTagline`, `splashServerWakingHint`, `splashConnectionFailed`; reused `appWordmark` + `retryButton`
- [x] 21. `lib/features/wallet/provider/wallet_provider.dart` — 5 fallback strings, displayed as-is by packages_screen.dart/#53/#54, deferred/commented (same cross-layer pattern)
- [x] 22. `lib/features/wallet/widgets/topup_card.dart` — status labels derived from booleans (not wire values, safe to translate normally): `topupStatusApproved/Rejected/Pending`, `topupRequestFallbackName`; uses `formatJod`
- [x] 23. `lib/models/request_model.dart` — **SKIPPED, Phase 3** per instruction
- [x] 24. `lib/core/notifications/firebase_notification_service.dart` — **structural exception, documented not migrated**: notification channel name/description is `const` (no BuildContext even possible) and Android caches channel metadata by ID at first creation, so changing the string has no effect on existing installs anyway; the title/body fallback runs in `firebaseBackgroundHandler`'s background isolate, which has no BuildContext by design (not a "defer to consuming widget" case — there is no widget). Both commented in place.
- [x] 25. `lib/features/customer/widgets/offer_card.dart` — `technicianFallbackName`, `offerPriceLabel` (+ `formatJod`), `offerDurationLabel`, `offerAcceptButton`, `offerRejectButton`, `offerAcceptedStatus`, `offerRejectedStatus`
- [x] 26. `lib/features/admin/screens/admin_ledger_screen.dart` — one of the "16 deferred banner" files, but that decision was about widget *consolidation*, not skipping ARB migration; migrated all literals normally (title+count, empty/error states, formatJod), only `admin.error!` itself deferred to #65
- [x] 27. `lib/features/admin/screens/admin_support_chat_screen.dart` — send/close/reopen/hint/tooltip/fallback-name keys
- [x] 28. `lib/features/auth/screens/register_role_screen.dart` — role-selection copy; §3 back-icon → `DirectionalIcons.back`, and the `_RoleCard` trailing chevron (same forward-into-content pattern as #8/#77) → `DirectionalIcons.forwardIosStyle`
- [x] 29. `lib/features/auth/screens/verify_otp_screen.dart` — resolved the #19 deferral: `VerifyOtpResult.message` is now nullable, fallback supplied here via `AppLocalizations`; otp screen copy migrated
- [x] 30. `lib/features/chat/widgets/chat_input.dart` — attachment sheet + input bar copy, reused `audioMessageLabel`/`sendButtonTooltip`
- [x] 31. `lib/features/layout/customer_layout.dart` — nav keys (`navHome/MyRequests/Chats/Settings/Support`), reused `appWordmark`
- [x] 32. `lib/features/technician/screens/my_reviews_screen.dart` — the two `error =` fallbacks are set synchronously from `initState()` (unsafe to call `AppLocalizations.of(context)` there), deferred/commented; everything else migrated including a real ARB plural (`myReviewsBasedOnCount`); fixed `my_reviews_error_state_test.dart` (same missing-Localizations gap as batch 4)
- [x] 33. `lib/providers/auth_provider.dart` — all 7 identical `_error` fallbacks deferred (consumed by many auth screens later in the queue), commented
- [x] 34. `lib/features/admin/screens/admin_audit_screen.dart` — distinct `adminAuditTitle` key (not reusing `ledgerTitle` — same Arabic wording today, different concept, likely to diverge in English)
- [x] 35. `lib/features/layout/technician_layout.dart` — reused `navHome/MyRequests/Chats/Settings/Support`, new `navNewRequests`/`navWallet`/`technicianDashboardTitle`
- [x] 36. `lib/features/admin/screens/admin_support_screen.dart` — status messages, load/empty states, ticket fallback title/status labels, reused `retryButton`/`userFallbackName`; `admin.error!` itself deferred to #65 (same convention as #26)
- [x] 37. `lib/features/auth/screens/landing_screen.dart` — hero copy, CTA buttons, decorative marketing stat cards; fixed §3 issue: `textAlign: TextAlign.right` → `TextAlign.start` on the two hero `Text` widgets (hardcoded right instead of direction-aware start)
- [x] 38. `lib/features/chat/provider/chat_provider.dart` — data-layer, no BuildContext; `error`/`chatsError` fallbacks deferred with `[L10N-TODO]` (`error` consumed by chat_room_screen.dart #76; `chatsError` currently has no UI consumer at all — chats_screen.dart reads `RequestsProvider.error` instead), no functional change
- [x] 39. `lib/features/customer/widgets/complaint_sheet.dart` — title/labels/hint/validation/submit button, `complaintSheetAboutTechnician(name)` placeholder
- [x] 40. `lib/features/support/screens/support_chat_screen.dart` — empty/error/closed states, input hint, reused `retryButton`/`sendButtonTooltip`, new `supportTeamLabel`; `support.error!` deferred (SupportProvider, later file)
- [x] 41. `lib/features/technician/screens/technician_request_details_screen.dart` — title/labels/buttons migrated; `technicianRequestStatusUpdated({status})` embeds the raw RequestModel.status wire value (Phase 3, stays Arabic until then, commented); button *label* for "بانتظار تأكيد الدفع" migrated separately from the unchanged wire value passed to `updateStatus()`
- [x] 42. `lib/core/api/api_client.dart` — pure network layer, no BuildContext, consumed by nearly every screen via `ApiException.message`; all client-generated fallback copy (timeouts/connectivity/HTTP-status defaults) deferred with one `[L10N-TODO]` comment on `handleError()`, no functional change. `serverMessage` (actual backend-sourced text) correctly left alone per the "don't touch backend error strings" rule — it's real server content, not app copy
- [x] 43. `lib/features/customer/screens/offers_screen.dart` — full migration incl. real ICU plural (`offersReceivedCount`) for the offers-received hero text, `offersHeroServiceLabel({service})` wrapping backend catalog data; applied `DirectionalIcons.back` at the §3 back-icon site (line 149); `provider.error!` deferred (RequestsProvider, #45)
- [x] 44. `lib/features/layout/admin_layout.dart` — logout dialog, appbar, nav tab labels; reused `navHome`/`navSettings`/`navSupport`, new `navUsers`/`navTopups`, new shared `cancelButton`
- [x] 45. `lib/features/requests/provider/requests_provider.dart` — data-layer, no BuildContext, huge fan-out of consumers; `error` fallbacks deferred with `[L10N-TODO]` (same convention as #38/#42), no functional change. `_availableStatuses` and `status: 'مكتمل'` are RequestModel.status wire values — untouched, Phase 3
- [x] 46. `lib/features/technician/screens/new_requests_screen.dart` — full migration incl. real ICU plural (`newRequestsAvailableCount`) for the hero count text; `provider.error!` deferred (#45)
- [x] 47. `lib/features/auth/screens/login_screen.dart` — full migration; new reusable field/validation keys (`emailFieldLabel`, `passwordFieldLabel`, `show/hidePasswordTooltip`, etc.) for reuse by later auth/settings screens; fixed `login_screen_test.dart` to pin `locale: const Locale('ar')` (test asserts on literal Arabic text via `find.text`, which is now ARB-driven rather than hardcoded)
- [x] 48. `lib/features/settings/screens/change_password_screen.dart` — full migration, reused `show/hidePasswordTooltip` from #47
- [x] 49. `lib/features/settings/screens/edit_profile_screen.dart` — full migration; new reusable `fullNameFieldLabel`/`phoneFieldLabel`/`cityFieldLabel`/`areaFieldLabel`; `AppConstants.cities` dropdown values correctly left untouched (place names rule)
- [x] 50. `lib/features/technician/screens/technician_orders_screen.dart` — full migration incl. reusable `statAllLabel`/`statActiveLabel`/`statCompletedLabel`; `e.status` comparisons against `'مكتمل'`/`'ملغي'` are RequestModel.status wire values, untouched (Phase 3)

**CI checkpoint**: batches 8+9 (files #36-45, commits `17de5c1`/`94d9804`) confirmed green via `android-build.yml` run #109 — this run also validated the screenshot-harness font fix (`2e9b636`) and the `login_screen_test.dart` Localizations-delegate fix (`b96c80e`) queued just before batch 8. **Note on CI triggering**: `android-build.yml` only runs automatically on push/PR to `main`; on this branch it must be triggered manually per push via `mcp__github__actions_run_trigger` (`method: run_workflow`) — it does not fire on its own from a push to a feature branch with no open PR.
- [x] 51. `lib/core/widgets/image_source_picker.dart` — full migration (bottom sheet + permission-denied dialogs), reused `cancelButton`
- [x] 52. `lib/features/customer/widgets/rate_technician_sheet.dart` — full migration incl. 5 star-rating hint strings and named/generic subtitle split
- [x] 53. `lib/features/wallet/screens/wallet_screen.dart` — full migration incl. real ICU plural (`walletPendingTopupsCount`) and `formatJod` for the balance display; reused `ledgerTitle`; `wallet.error!` deferred (WalletProvider)
- [x] 54. `lib/features/wallet/screens/topup_request_screen.dart` — full migration incl. `formatJod` at 3 currency sites; backend payment-method fields (bank/account/instructions) correctly left untouched
- [x] 55. `lib/features/admin/screens/admin_topups_screen.dart` — full migration incl. `formatJod`; reused `technicianFallbackName`/`retryButton`/`cancelButton`; new generic `confirmButton`; `status` string literals ('approved'/'rejected'/'pending') are internal API params, not Arabic wire values — left untouched as ordinary code, not a Phase 3 concern

**CI checkpoint**: batch 10 (commit `ee7af8b`) initially failed on `android-build.yml` run #110 — 2 more tests hit the missing-Localizations-locale gap, this time via *indirect* navigation into the now-ARB-driven `LoginScreen` (not by constructing it directly, which is what the earlier proactive `grep "ClassName("` check looks for): `forgot_password_screen_test.dart` navigates there on password-reset success (had zero delegates), `settings_logout_test.dart` navigates there on logout (had delegates but no pinned `locale:`). Both fixed (commit `f43c53b`) by pinning `locale: const Locale('ar')`, matching the standing convention. **Lesson for future batches**: the proactive test-gap check must also consider screens reached via in-app navigation from an already-passing test, not just direct `WidgetClassName(` construction — a plain `grep` for the migrated screen's class name can miss this. **Confirmed fixed**: run #112 (commit `f43c53b`) — Analyze + Test both green (Test step succeeded at 20:02:23Z). Also proactively fixed `chat_error_state_test.dart` (batch 12, file #58 migrated `chats_screen.dart`) before it could break the same way — had zero delegates, added `locale: const Locale('ar')` + delegates.
- [x] 56. `lib/features/customer/screens/customer_request_details_screen.dart` — full migration incl. dialog/buttons; reused `requestProblemDescriptionLabel`/`complaintSheetTitle`; `request.status ==` comparisons untouched (Phase 3)
- [x] 57. `lib/features/auth/screens/customer_register_screen.dart` — full migration; reused most field labels/validations from #47/#49 (email/password/city/phone); kept a few screen-specific validation-text variants distinct where the Arabic wording genuinely differs from the reused key
- [x] 58. `lib/features/chat/screens/chats_screen.dart` — full migration incl. 2 real ICU plurals (active-chats count, unread-messages count); applied `DirectionalIcons.forwardIosStyle` at the §3 site; proactively fixed `chat_error_state_test.dart`'s missing delegates
- [x] 59. `lib/features/customer/screens/customer_dashboard_screen.dart` — full migration; reused `appWordmark`/`landingHeroTitle`/`statCompletedLabel` (exact text matches from earlier files)
- [x] 60. `lib/features/technician/screens/send_offer_screen.dart` — full migration incl. real ICU plural (free-offers-remaining count) and `formatJod` at 3 currency sites, replacing manual conditional-decimals formatting; reused `walletTopupActionTitle`/`optionalNoteLabel`
- [x] 61. `lib/features/auth/screens/forgot_password_screen.dart` — full migration, reuses most field/validation keys from #47/#48/#49; test already had `locale: ar` pinned from an earlier fix
- [x] 62. `lib/features/technician/screens/technician_dashboard_screen.dart` — full migration incl. `formatJod`; proactively applied the `minHeight` fix (found on customer_dashboard_screen.dart during screenshot review) to `_StatCard` before it could overflow with English titles
- [x] 63. `lib/features/customer/screens/customer_requests_screen.dart` — full migration; applied `DirectionalIcons.back` at the §3 site; proactively applied the same `minHeight`/`maxLines:2` overflow fix to `_MiniStat`; proactively fixed `customer_requests_filter_test.dart`'s missing Localizations delegates (2 sites) before it could break the same way as batch 10
- [x] 64. `lib/features/customer/screens/create_request_screen.dart` — full migration; applied `DirectionalIcons.back` at the §3 site
- [x] 65. `lib/features/admin/provider/admin_provider.dart` — data-layer, no BuildContext, 24 distinct fallback messages consumed by many admin screens (several already migrated leaving `admin.error!` deferred); deferred with one documented comment, no functional change

**Screenshot review (user-requested checkpoint after #60)**: re-ran `l10n-screenshots.yml`, reviewed all 12 screens × 2 locales × 2 widths. Confirmed: no tofu anywhere (font-fallback fix holds, specifically re-verified the two sites that showed it before — `chat_room_screen`'s message hint, `customer_register_screen`'s consent text), RTL→LTR flip correct, Arabic side pixel-identical to before. Found and fixed 2 real English-only layout bugs on `customer_dashboard_screen.dart` (commit `bcc5eef`): `_HeroCard` overflowed vertically (fixed `height` + flex `Spacer()` sized for Arabic's shorter text), `_ActionCard`/`_StatCard` truncated English titles mid-word (fixed width + `maxLines:1`). Both fixed via `minHeight` (was `height`) + wrapping instead of truncating. Noted one unrelated pre-existing issue (not touched): `ConsentCheckbox`'s raw `RichText` doesn't inherit `ThemeData.fontFamilyFallback` via `DefaultTextStyle` the way `Text` does, so it renders as tofu-like blocks in this test harness in *both* locales — confirmed via the Arabic screenshot too, so not a regression, just a harness limitation real devices don't have.

**Established defensive pattern going forward**: fixed-`height` `Container` + `maxLines: 1` on Arabic-tuned stat/action cards is a recurring source of English-only overflow — now checking for and fixing this pattern (fixed height → `minHeight`, `maxLines: 1` → `2`) proactively in every file as it's migrated, not just the one screenshot-caught instance.
- [x] 66. `lib/features/support/screens/support_screen.dart` — full migration incl. `_NewTicketSheet`; reused `adminSupportLoadFailedTitle`/`retryButton`/`adminSupportTicketOpenLabel`/`adminSupportTicketClosedLabel`/`complaintSheetBodyValidationError`; `type`/`types` ticket-classification list deferred (wire value, same convention as `RequestModel.status`), commented; proactively fixed `support_error_state_test.dart`'s missing Localizations delegates
- [x] 67. `lib/features/auth/screens/technician_register_screen.dart` — full migration, heavy reuse from #57/#47/#49 field/validation keys; new `technicianRegisterTitle`/`Heading`/`Subtitle`, `nationalNumberFieldLabel`/`FormatValidation`/`PrivacyNote`, `workAreaDropdownLabel`, avatar-selection keys
- [x] 68. `lib/providers/notification_provider.dart` — data-layer, no BuildContext, ~15 distinct notification title/body pairs built from socket-event handlers (`handleNewRequest`, `handleOfferCreated`, `handleRequestStatus`, etc.), wired up from `app.dart`; deferred with one documented comment before `handleNewRequest`, no functional change
- [x] 69. `lib/features/admin/screens/admin_dashboard_screen.dart` (also §3 back-icon) — full migration incl. 2 real ICU plurals (`activityRequestsCount`/`activityUsersCount`) and a plural+placeholder combo (`completedJobsWithRating`); applied `DirectionalIcons.forwardIosStyle` at `_ActionCard`'s trailing chevron (functions as forward-into-content despite the iOS-back glyph, same pattern as #28); proactively added defensive `maxLines: 2`/ellipsis to `_StatCard` title inside the `GridView.count`; `formatJod` applied to revenue/activity amounts; reused `statCompletedLabel`/`statCancelledLabel`/`adminAuditTitle`
- [x] 70. `lib/features/admin/screens/admin_requests_screen.dart` — full migration incl. cancel-request dialog (`adminCancelRequestConfirmMessage({id})` placeholder) and `statusChangedMessage({status})` (raw wire-value status embedded via placeholder, `[L10N-TODO]` noted in ARB description, same pattern as #41's `technicianRequestStatusUpdated`); `_filter`/`_statuses` (incl. the `'الكل'` pseudo-status) and all `status`/`_statusOptions` comparisons deferred (wire values, Phase 3), commented
- [x] 71. `lib/features/admin/screens/admin_user_detail_screen.dart` — full migration incl. role-conversion dialog, ledger/offers/requests section titles with counts, `formatJod` for balance/offer price/ledger amount
- [x] 72. `lib/features/admin/screens/admin_meta_screen.dart` — full migration of profession/package CRUD dialogs, tab labels, empty/error states; `formatJod` for package amount+bonus
- [x] 73. `lib/features/admin/screens/admin_moderation_screen.dart` — full migration of tabs and card content; `_ComplaintStatusMenu` labels safely translated (keyed by stable English enum); `_ViolationStatusMenu`/`_MessageReportStatusMenu` `_labels` maps deferred (Arabic text IS the wire value sent to backend), `[L10N-TODO]` commented, only tooltip/error messages translated
- [x] 74. `lib/features/admin/screens/admin_users_screen.dart` — full migration incl. all 4 action dialogs (activate/suspend/edit/adjust-balance/delete); resolved the `AdminUserModel.roleAr` deferral from #74's own placeholder note — moved role-label logic into `_UserCard` (has BuildContext) and deleted the getter; updated `admin_user_model_test.dart` to test `isCustomer`/`isTechnician`/`isAdmin` instead of the removed getter; found and fixed a pre-existing bug in `admin_error_state_test.dart` — the test asserted `'تعذر تحميل المستخدمين'` (no shadda) against source text `'تعذّر تحميل المستخدمين'` (with shadda), two different strings that never matched even before this migration; fixed the assertion text and added missing Localizations delegates
- [x] 75. `lib/features/settings/screens/privacy_policy_screen.dart` — full migration of the entire static policy page (~35 new keys: section titles/bodies, permission rows, rights bullets, 9-row data table with required/optional badges); reused `privacyPolicyTitle` from #7
- [x] 76. `lib/features/chat/screens/chat_room_screen.dart` (also §3 back-icon) — full migration incl. permission-rationale dialogs (location/mic), block/unblock/report flows; applied `DirectionalIcons.back` at the header back button; report-reason list (`_pickReportReason`) deferred as wire value (`ChatProvider.reportMessage(reason:)` sends it straight to the backend), only the bottom-sheet title translated, `[L10N-TODO]` commented; reused `backButtonTooltip`/`supportChatLoadFailedTitle`/`retryButton`/`cancelButton`
- [x] 77. `lib/features/settings/screens/settings_screen.dart` (also §3 forward-chevron; language switcher strings already migrated in Phase 1) — full migration incl. logout dialog, delete-account dialog (checklist items, password confirmation), profile/account info sections, theme toggle, about dialog; applied `DirectionalIcons.forwardIosStyle` at `_ActionTile`'s trailing chevron; `formatJod` for balance display (hero chip + info tile); reused `customerFallbackName`/`technicianFallbackName`/`adminRoleLabel` for `roleLabel()` (same resolution pattern as `AdminUserModel.roleAr` in #74), plus `navSettings`/`emailFieldLabel`/`cityLabel`/`areaDropdownLabel`/`nationalNumberFieldLabel`/`nameFieldLabel`/`balanceButtonLabel`/`supportScreenTitle`/`privacyPolicyTitle`/`appWordmark`/`showPasswordTooltip`/`hidePasswordTooltip`/`passwordRequiredValidation`/`cancelButton`

**All 77 files migrated — Phase 2 complete.**

**CI bug found and fixed while migrating this batch**: two new ARB keys introduced during batch 15 collided with pre-existing keys of the same name — `offersSectionTitle` (a new `{count}`-placeholder variant in `admin_user_detail_screen.dart` shadowed the existing plain-string key used by `offers_screen.dart`, breaking analyze at the older call site) and `userFallbackName` (a duplicate definition with different text silently overrode the version already used by two earlier admin screens, per JSON last-key-wins). Fixed by renaming the new key to `userOffersSectionTitle` and removing the duplicate `userFallbackName` entry (commit `491f53b`). Root cause: the established "grep before creating a new key" check was only being applied to check for *text* reuse, not to check whether the *key name itself* already existed under different text. Added a second check this batch — before adding any new key, grep the exact key name against both ARB files, not just its Arabic text — and used it for the rest of batch 16 (caught one more near-miss: `currentPasswordFieldLabel` in `settings_screen.dart` already existed with identical text, reused instead of duplicated).

**Final mandated screenshot review (after all 77 files), two more bugs found and fixed**:
1. `settings_screen.dart`'s `_SectionCard` title used hardcoded `Alignment.centerRight` — correct-looking in Arabic (right = RTL reading start) but wrong in English, where section titles ("Account Information", "Account & Privacy", etc.) were pinned to the right instead of starting at the natural LTR reading position. Fixed to `AlignmentDirectional.centerStart` (right in RTL, left in LTR) — another §3-class hardcoded-direction bug, exposed only once English text was actually rendered and reviewed.
2. `customer_dashboard_screen.dart`'s `_ActionCard` title (`maxLines: 2`) still truncated mid-word at the narrowest tested width (320dp) for English strings — "New Request" rendered as "New Req…", "My Requests" as "My Re/quests" — while the shorter Arabic originals ("إنشاء طلب", "طلباتي") fit cleanly. Bumped title to `maxLines: 3`; the container's `minHeight`-only constraint (from the earlier per-file fix) lets it grow safely. This is exactly the "English strings don't overflow where the shorter Arabic fit" check the review was for.

Both fixed (commit `2e2847d`) and confirmed via a final CI + screenshot
re-run: `android-build.yml` green, and the corrected screenshots show
`settings_screen.dart`'s section titles starting at the left in English and
`customer_dashboard_screen.dart`'s action-card titles wrapping in full
instead of truncating mid-word at 320dp. **Phase 2 closed out here — see
pull request https://github.com/Y1X0/sallehly_app/pull/2.**

---

## 7. Visual regression net — re-run after every Phase 2 batch

`.github/workflows/l10n-screenshots.yml` captures a real PNG (real Arabic
font, not `flutter test`'s placeholder font — see the `CustomerDashboardScreen`
entry above for why that distinction matters) for every screen in
`test/support/l10n_screen_cases.dart`, both locales, both widths (48 images).
This is now the standing visual check for Phase 2, not a one-off diagnostic —
**re-run it after each Phase 2 batch** (triggers automatically on push to
this branch if the workflow/test files change, or manually via Actions →
"L10N Screenshots" → Run workflow) and skim the results for the four things
it's good at catching that `l10n_screen_smoke_test.dart` structurally can't:
text overflow/clipping, icons pointing the wrong way, elements on the wrong
side after the LTR flip, anything that just looks broken. Results: a
downloadable zip (Actions artifact) and the `l10n-screenshots-latest` branch
(force-pushed each run, images only, no history — the artifact zip is the
one to keep if a specific run's images need to be preserved past the
14-day artifact retention).

## 8. CI status-polling lag — four apparent hangs in one session

While verifying the BidiText commits, `android-build.yml` runs appeared
stuck four separate times when polled via the GitHub Actions API/tooling
used in this session. Recorded here because four occurrences in one
session is worth having written down, even though three of the four turned
out to be a polling artifact rather than the CI itself:

1. **Run 33088056716** (BidiText widget + tests commit, `b87ace1`) —
   `Build Android App Bundle` step reported `in_progress` for ~55 minutes
   (baseline: ~7 min). Cancelled it rather than keep waiting. **Unresolved
   — genuinely inconclusive.** Unlike the two incidents below, this run
   was cancelled before it could either finish or keep hanging, so there's
   no confirmation either way. Given the pattern found in incidents 2 and
   3, it's plausible this one was also just reporting lag and got
   cancelled prematurely — but that's a guess, not a finding.
2. **Run 33089613655** (error-widget consolidation commit, `f84b432`) —
   `Setup Flutter` reported `in_progress` for 10+ minutes (baseline: ~30s).
   Left it running. **Confirmed reporting lag**: the run had actually
   completed in ~9m27s total, with `Setup Flutter` itself taking 27s per
   its real timestamps — the polling tool was just returning a stale
   snapshot for several minutes after the step (and eventually the whole
   run) had already finished.
3. **Run 33090744776** (BidiText batch 1 commit, `2f07c1c`) — same
   symptom, `Setup Flutter` reported `in_progress` for 18+ minutes. Left
   it running without polling further. **Confirmed reporting lag**, same
   as #2: real total time ~9m54s, `Setup Flutter` itself 26s.
4. **Run 33097721540** (BidiText batch 2 commit, `b375aed`) — same
   symptom, but far more extreme: polling kept reporting each step as
   `in_progress` (moving forward one step every few polls, never catching
   up) for **over an hour** of wall-clock time, including a stretch where
   `Build Android App Bundle` looked stuck for 45+ minutes. Left it
   running the whole time, no cancel. **Confirmed reporting lag**: the run
   had actually completed in ~8m56s total (17:18:24–17:27:20), fully
   within baseline — the polling tool was just extremely delayed catching
   up to real state, worse than incidents 2 and 3 by a wide margin.

**Takeaway:** the job/step `status` field returned by this session's
GitHub Actions polling can lag real state by 10 minutes to well over an
hour — cross-check against the run's actual `started_at`/`completed_at`
timestamps (or just wait longer and re-check) before concluding a run is
actually stuck. Incident 4 sets a useful upper bound: even 60+ minutes of
"stuck" polling turned out to be lag, not a real hang, once checked
against real timestamps — so a long apparent stall on its own is no
longer strong evidence of a genuine CI problem here. Incident 1 remains
the one open question: it was cancelled before it could resolve either
way, so whether the underlying infrastructure can genuinely hang, or
every apparent hang this session was reporting lag, is still not fully
settled — but incident 4 makes "it was also just lag" the more likely
read in hindsight. If a future run shows the same symptom, let it run
well past 20 minutes (ideally to completion) before treating it as a real
hang, and prefer checking `run_started_at`/`completed_at` over step-level
polling.

---

## 10. Phase 3 — started (scoped, per explicit approval)

Scope, as given: `RequestStatus` enum + `fromWire()` parser + localized
labels, with `RequestStatusChip` rendering the label instead of the raw
value, and an unknown fallback so an unrecognised server value never
crashes the UI. Explicitly **not** in scope: changing what's sent to the
backend, or touching any of the other wire-value comparison sites listed
in §4/§9 — those stay exactly as they are.

- **`lib/models/request_status.dart` (new)** — `RequestStatus` enum with
  one variant per known wire value (`waitingForOffers`, `offersReceived`,
  `offerSelected`, `inProgress`, `awaitingPaymentConfirmation`,
  `completed`, `cancelled`) plus `unknown`. `RequestStatus.fromWire(String)`
  matches against each variant's `wireValue` (the exact Arabic string) and
  returns `unknown` for anything unrecognized — never throws.
  `label(AppLocalizations t, {rawWire})` returns the localized display
  string for a known status, or `rawWire` itself for `unknown` (shows
  whatever the server actually sent rather than a generic placeholder —
  still meaningful, and nothing to hide).
- **`lib/features/requests/widgets/request_status_chip.dart`** — now
  parses `status` via `RequestStatus.fromWire()` and renders
  `requestStatus.label(t, rawWire: status)` instead of the raw string
  directly; the color lookup switches on the enum instead of raw-string
  comparisons, same 4 colors as before (`completed`→success,
  `cancelled`→danger, `offersReceived`→warning, `inProgress`→secondary)
  plus the same default for everything else, `unknown` included — no
  visual change beyond the label text itself.
- **7 new ARB keys** (`requestStatusWaitingForOffers` ... `requestStatusCancelled`)
  — Arabic text is byte-identical to each status's wire value by design
  (so Arabic-locale output is pixel-identical to before this change);
  English gets a real translation.
- **`lib/models/request_model.dart`** — the `[FIX-L10N-03]` comment above
  `hasOffers`/`isWaiting`/`isCompleted`/`isCancelled`/`isCancellable`
  updated to reflect that the display-label part is now done and lives in
  `request_status_chip.dart`; the comparisons themselves are untouched.
- **Not touched, on purpose**: `RequestModel`'s own comparisons; the
  `status ==` checks in `customer_requests_screen.dart`,
  `technician_dashboard_screen.dart`, `technician_orders_screen.dart`,
  `chats_screen.dart`, `customer_request_details_screen.dart`,
  `technician_request_details_screen.dart`; `admin_requests_screen.dart`'s
  `_filter`/`_statuses`/`_statusOptions`; `requests_provider.dart`'s
  `_availableStatuses` and the `status: 'مكتمل'` literal it constructs;
  `socket_provider.dart`'s optimistic `status: 'تم اختيار عرض'` update.
  All of these still compare against or construct the raw Arabic wire
  value directly — exactly as before, per "don't change what's sent to
  the backend."
