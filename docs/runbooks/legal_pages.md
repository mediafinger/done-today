# Legal pages: Impressum and Datenschutzerklärung

Public routes, no login required, linked from the footer (and therefore from the login page):

- `/impressum` → [imprint.html.erb](../../app/views/legal/imprint.html.erb)
- `/datenschutz` → [privacy.html.erb](../../app/views/legal/privacy.html.erb)

Both pages are German only. The UI stays English; an English translation of the privacy policy is optional.

## Configuration

Operator details are never hardcoded. Set them as ENV vars (Kamal `env.clear` in `config/deploy.yml`).
Keys marked *required* raise `KeyError` on boot in production. Outside production, missing values render as a
highlighted "nicht konfiguriert" placeholder plus a notice listing every missing key.

| ENV var                  | Required | Example                                            |
|--------------------------|----------|----------------------------------------------------|
| `LEGAL_OPERATOR_NAME`    | yes      | `Erika Mustermann` or `Beispiel GmbH`              |
| `LEGAL_STREET`           | yes      | `Musterstraße 1` (no P.O. box)                     |
| `LEGAL_CITY`             | yes      | `12345 Musterstadt`                                |
| `LEGAL_EMAIL`            | yes      | `kontakt@example.org`                              |
| `LEGAL_PHONE`            | no       | recommended as second direct contact channel       |
| `LEGAL_REPRESENTATIVE`   | no       | legal entities only: managing director(s)          |
| `LEGAL_REGISTER`         | no       | `Amtsgericht Musterstadt, HRB 12345`               |
| `LEGAL_VAT_ID`           | no       | only if one exists, `DE…`                          |
| `LEGAL_HOSTING_PROVIDER` | yes      | name and address of the hosting provider           |
| `LEGAL_MAIL_PROVIDER`    | yes      | name and address of the email provider             |

Optional keys are omitted from the page when unset.

## Before go-live

- [ ] Lawyer reviews both texts, then delete the draft notice in [_notices.html.erb](../../app/views/legal/_notices.html.erb)
- [ ] All required keys set in production
- [ ] Clarify the operator's role per team: controller vs. processor for time entries (privacy policy section 3)
- [ ] Every retention period stated in the privacy policy is true on the server:
  - [ ] server logs deleted after 14 days (Docker log rotation, ops item 9)
  - [ ] backups stored with the hosting provider, inside the EU; otherwise add the backup provider to section 6
- [ ] Pico CSS is served locally, not from `unpkg.com` (ops item 8). Until then every page load sends the visitor's
  IP to a third party outside the EU, which contradicts section 6
- [ ] Mail provider processes data inside the EU/EEA; for a US provider (e.g. AWS SES) add a third-country transfer
  paragraph (EU-US Data Privacy Framework or SCCs) to section 6

## Keep in sync

Update the privacy policy in the same PR as any change to:

- models storing personal data (`users`, `members`, `sessions`, `entries`, `record_histories`)
- cookies (`session_id`, `_done_today_session`, `display_mode`); e.g. session expiry (ops item 8) changes the
  `session_id` retention
- logging, error tracking (Sentry), uptime monitoring or any new external service
- outgoing email types (invites, reminders, summaries)
