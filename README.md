# PhishScraper

A PowerShell script that monitors Microsoft Entra (Azure AD) sign-in logs for suspicious **OfficeHome** authentication activity. It runs on a schedule, flags anomalous logins, and emails a formatted report — designed to help security teams detect credential phishing attempts early.

---

## How It Works

1. Authenticates to Microsoft Graph using certificate-based auth (no passwords stored).
2. Queries Entra sign-in audit logs for all **OfficeHome** app logins from the past 24 hours.
3. Flags entries that match known phishing indicators.
4. Writes results to a text file and emails a summary report.

### Phishing Indicators Flagged

| Indicator | Why It Matters |
|---|---|
| `axios` in User-Agent | Phishing toolkits (e.g., Evilginx, Modlishka) commonly use the `axios` HTTP library to relay credentials in real time — it's rarely seen in legitimate browser-based logins. |
| Successful login (`ErrorCode: 0`) | A successful auth after a suspicious UA or foreign IP is a high-priority alert. |
| Login origin outside the United States | Logins from unexpected countries may indicate account takeover after credential theft. |

---

## Prerequisites

- **PowerShell 7+**
- **Microsoft Graph PowerShell SDK**
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser
  ```
- **An Azure App Registration** with the following Graph API permissions (application permissions):
  - `AuditLog.Read.All`
  - `User.Read.All`
- **Certificate authentication** configured on the App Registration (thumbprint used at runtime — no client secrets).
- An accessible **SMTP server** for outbound email.

---

## Configuration

Before running, update the placeholders in the script:

| Placeholder | Description |
|---|---|
| `<email@example.com>` | Sender email address |
| `<someoneelse@example.com>` | Recipient email address |
| `<stmp server>` | Your SMTP server hostname |
| `<appid>` | Azure App Registration Application (client) ID |
| `<tenantid>` | Your Azure tenant ID |
| `<subject>` | Certificate subject string used to locate the cert in `Cert:\CurrentUser\My` |

---

## Usage

Run manually:
```powershell
.\PhishScraper.ps1
```

Or schedule it with **Windows Task Scheduler** to run daily. The script queries the previous 24 hours of logs on each execution, so a daily schedule provides continuous coverage with no gaps.

---

## Output

- **`C:\temp\officeHome.txt`** — Formatted table of OfficeHome sign-in events with flagged anomalies.
- **`C:\temp\PhishScraper-debug.txt`** — Transcript log, attached to the failure email if the script errors.
- **Email (on success):** Subject `Phishy Sign-In Scraper` with the login count in the body and the report as an attachment.
- **Email (on failure):** Subject `Phishy Sign-In Scraper Failed` with the debug transcript attached.

### Report Columns

| Column | Description |
|---|---|
| Name | User display name |
| User Agent | Browser/client UA string; `axios` matches are marked `<--- IMPORTANT` |
| IP | Source IP address of the login |
| Region | Country/region; non-US logins marked `<--- NOT IN UNITED STATES` |
| Status | Auth result detail; successful logins marked `<--- SUCCESSFUL` |

---

## Security Notes

- The script uses **certificate-based authentication** — no credentials are stored in the script or in plaintext anywhere.
- Ensure `C:\temp\` is access-controlled, as the output files may contain sensitive user and IP data.
- Scope Graph API permissions to the minimum required (`AuditLog.Read.All`, `User.Read.All`).
- Rotate the certificate on your regular key rotation schedule.

---

## Why `axios` Is a Red Flag

Most phishing kits that perform adversary-in-the-middle (AiTM) attacks — such as those built on **Evilginx2** or **Modlishka** — use Node.js-based backends to proxy authentication traffic. These frameworks frequently use `axios` to forward requests to Microsoft's login endpoint on the victim's behalf. When a sign-in log shows `axios` as the user agent instead of a real browser string, it strongly suggests the login was relayed through a phishing proxy rather than made directly by the user.

---

## License

GPLv3
