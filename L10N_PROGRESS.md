# English Localization — Progress Tracker

Status: **PHASE 0 (Audit) complete — awaiting approval to start Phase 1.**
Do not check off any item below until it has actually been migrated, tested with
`flutter analyze`, and reviewed.

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

### Needs a design call, not a code bug

- `Alignment.centerLeft : Alignment.centerRight` used for **"is this my chat bubble"** placement (`chat_bubble.dart:161`, `support_chat_screen.dart:345`, `admin_support_chat_screen.dart:294`) and one **section-title alignment** (`settings_screen.dart:525`, `package_card.dart:59`, bonus badge). Chat-bubble side-by-sender is arguably fine to keep absolute (WhatsApp-style: "my messages" stay on one visual side regardless of language) — flagging for your call before Phase 2 touches those 5 files, since converting to `AlignmentDirectional` would flip bubble sides between AR and EN.

---

## 4. Two structural issues to flag before any code changes (important)

These aren't "strings to translate" — they're places where the **backend's Arabic text is load-bearing business logic**, not just display copy. Getting this wrong would silently break status logic app-wide.

1. **`lib/models/request_model.dart`** — getters like `isWaiting`, `isCompleted`, `isCancelled`, `hasOffers`, `isCancellable` compare `status` against literal Arabic strings (`'بانتظار العروض'`, `'مكتمل'`, `'ملغي'`, `'وصلت عروض'`, `'قيد التنفيذ'`) because **the backend itself sends these Arabic strings as the wire value of `status`**, not an enum code.
2. **`lib/features/requests/widgets/request_status_chip.dart`** renders that same raw `status` string directly as the chip's `Text(status, ...)` — so today, the Arabic word literally *is* both the data and the display label, with the same pattern echoed in `socket_provider.dart:193` when applying an optimistic local update.

**Implication for Phase 2:** these Arabic values must **not** be replaced with English text or ARB keys — that would break comparisons across the entire app the moment the backend still sends Arabic and the client no longer recognizes it. The correct fix is a small **status → localized label mapping function** (Arabic wire value in, `AppLocalizations` key out) introduced in `request_status_chip.dart` (and the ~6 other screens listed in the table that read `.status` directly), while `request_model.dart`'s comparisons stay untouched against the Arabic backend values. This will need to be called out explicitly again when we reach file #15 and #23 in Phase 2 — not something to solve generically now.

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

## 6. Suggested Phase 1 scope checklist (for your approval)

- [ ] `l10n.yaml` + `lib/l10n/app_ar.arb` (template) + `lib/l10n/app_en.arb`
- [ ] `LocaleProvider` (mirrors `ThemeController` shape) persisted via `SharedPreferences`
- [ ] `MaterialApp`: wire `AppLocalizations.delegate`, `supportedLocales: [Locale('ar'), Locale('en')]`, `locale` from `LocaleProvider`, default/fallback `ar`
- [ ] Replace the hardcoded `Directionality(TextDirection.rtl)` in `app.dart`'s `builder` with locale-derived direction
- [ ] Language switcher added to `settings_screen.dart` (file #77 above)
- [ ] Verify `flutter analyze` + app still builds/runs identically in Arabic (zero visible change) before Phase 2 starts

Phase 2 will then proceed through the 77-file table above, smallest first, ≤3 files per turn, each followed by `flutter analyze` and a checkbox tick here.
