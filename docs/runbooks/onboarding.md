# Onboarding a team

There is no public sign-up. An operator creates the org and its first owner, the owner invites the rest.

## 1. Create the org and its first owner (operator, shell on the server)

```bash
bin/rails done:org:create NAME="Acme" OWNER_EMAIL=ada@example.com OWNER_NAME="Ada"
# on the server: kamal app exec 'bin/rails done:org:create NAME="Acme" OWNER_EMAIL=ada@example.com'
```

- New email: the task stores an owner invitation, prints the link and mails it. The link is valid for 7 days.
  The account is created when the owner accepts it and chooses name and password.
- Existing account: it becomes an owner of the org right away (also reactivates or promotes an existing membership). No mail.
- Running it again for the same NAME reuses the org. For a pending invitation it sends a new link and the old one stops working.
- If the mail fails, the task says so. Send the printed link yourself.

## 2. Invite the team (org owner, in the app)

`/:org/members` → "Invite by email", with the roles member and/or owner. The list below the form shows pending
invitations with "Resend" (new link, old one dies) and "Revoke".

- An email that already has an account (e.g. a member of another org) gets the same link. It asks them to sign in,
  then to "Join". The link never sets the password of an existing account.
- Inviting a deactivated member back reactivates their membership with the invited roles. Their entries and
  project participations come back with it.
