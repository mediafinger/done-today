# Data processing agreements (AVV / DPA)

Manual, non-code task. Must be done before the first external team logs real data.
Keep signed copies outside this repository (password manager or document storage), not in git.

## Processors

Source of truth for section 6 ("Empfänger und Auftragsverarbeiter") of the
[privacy policy](../../app/views/legal/privacy.html.erb). Change both in the same PR.

| Processor                  | Purpose                       | Personal data                                          | Location     | AppConf key              | DPA signed |
|----------------------------|-------------------------------|--------------------------------------------------------|--------------|--------------------------|------------|
| Hosting provider (tbd)     | Server, database, backups     | everything in the database, server logs (IP, UA)       | Germany      | `LEGAL_HOSTING_PROVIDER` | [ ]        |
| Mail provider (tbd, P8)    | Transactional email           | recipient email, name, message content, delivery logs  | EU/EEA       | `LEGAL_MAIL_PROVIDER`    | [ ]        |

Add a row when one of these is introduced:

- separate backup storage (ops item 6), if not the hosting provider
- error tracking, e.g. Sentry (ops item 9): receives request data, IPs, user IDs
- any service the browser loads assets from

Not processors (no personal data of users leaves the app), no DPA needed:

- Pwned Passwords API: receives a 5-char SHA-1 prefix from the server's IP
- Container registry (ghcr.io), GitHub: code and images only
- Uptime monitor polling `/up`: no user data
- DNS / domain registrar

`unpkg.com` (Pico CSS in production) currently receives every visitor's IP. Remove it (ops item 8) instead of
adding it here.

## Checklist

### Operator ↔ hosting provider
- [ ] Choose a provider with data centres in Germany
- [ ] Sign the provider's DPA (Art. 28 DSGVO); usually offered in the customer panel
- [ ] Confirm the server location in the contract, and that backups stay in the EU
- [ ] Set `LEGAL_HOSTING_PROVIDER` to the legal name and address

### Operator ↔ mail provider
- [ ] Choose a provider processing in the EU/EEA; for a US company, check the EU-US Data Privacy Framework
  certification or SCCs and add a transfer paragraph to the privacy policy
- [ ] Sign the provider's DPA
- [ ] Check retention of message content and delivery logs; reduce if configurable
- [ ] Set `LEGAL_MAIL_PROVIDER` to the legal name and address

### Operator ↔ each team (organisation)
The teams' time entries are usually their employer's data, which makes the operator their processor.

- [ ] Clarify per team: employer as controller (AVV needed) or individuals using it for themselves (no AVV;
  adjust privacy policy section 3)
- [ ] Sign an AVV with each controlling organisation, covering subject, duration, type of data, categories of
  data subjects, instructions, confidentiality, deletion on termination, audit rights
- [ ] Annex: technical and organisational measures (TOMs, Art. 32), see below
- [ ] Annex: list of sub-processors (the table above), and the notice procedure for changing them

### Operator's own documentation
- [ ] TOMs document: TLS, bcrypt password hashes, per-org access control, SSH key-only access, firewall,
  backups and restore tests, log retention
- [ ] Record of processing activities (Art. 30 Abs. 1 as controller, Abs. 2 as processor)
- [ ] Data breach procedure: notify the authority within 72 hours (Art. 33), the controlling teams without undue
  delay (Art. 33 Abs. 2)
- [ ] Deletion procedure when a team leaves: delete org data and confirm in writing; backups expire by rotation
