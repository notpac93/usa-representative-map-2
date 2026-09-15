# CWC / SCWC Approval Quickstart

Updated: 2026-09-15

## Prepare this information first

- Legal project/company name and business address
- Website and a one-paragraph description of the nonpartisan constituent app
- Principal owner/officer names
- Authorized contact: name, title, phone, and email
- Technical contact: name, phone, and email
- States where the entity is authorized to do business
- EIN, DUNS, and CAGE/NCAGE if the entity is registered and has them
- Short security summary: server-hosted credentials, encryption, address/email verification, bot controls, rate limiting, retention/deletion, incident contact, and subprocessors
- Estimated launch date and expected daily/peak message volume; label estimates as estimates

## House CWC

1. Read the [House CWC program page](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc).
2. Review and complete the [CWC Usage Agreement and Access Application](https://www.house.gov/sites/default/files/uploads/documents/CWC-USAGE-AGREEMENT.pdf).
3. Review the linked [Advocacy Vendor Level of Service Standards](https://www.house.gov/sites/default/files/uploads/documents/cwc-advocacy-vendor-level-of-service-standards.pdf).
4. Email the completed application and questions to `CWCVendors@mail.house.gov`.
5. Ask the House to confirm that this neutral, direct-to-constituent app qualifies as an Advocacy Vendor before promising direct delivery.

## Senate SCWC / SOAPBox

1. Read the [Senate SCWC overview](https://www.senate.gov/senators/scwc.htm).
2. Use the [SOAPBox question form](https://soapbox.senate.gov/delivery-agent/help/) to confirm eligibility and application expectations.
3. Review the [SCWC Terms of Service](https://soapbox.senate.gov/registration/terms-of-service/).
4. Submit the [online SCWC Access Application](https://soapbox.senate.gov/registration/).
5. After approval, use [SOAPBox](https://soapbox.senate.gov/) for testing status, technical documentation, and API keys.

## Ask both programs these questions

1. Does a neutral app qualify when each constituent writes and authorizes their own message without a sponsoring advocacy organization?
2. What is the current technical schema or Standards and Requirements Packet, and when can we receive it?
3. Which fields are mandatory? Specifically confirm full address, apartment/unit, ZIP5 versus ZIP+4, email, phone, subject, topic, bill number, and message limits.
4. Is USPS validation required, or is Census address-to-district matching acceptable?
5. What consent record, email confirmation, CAPTCHA, identity check, duplicate detection, or audit evidence is required?
6. How should campaign IDs work for individual user-authored messages and one action addressing a House Member plus two Senators?
7. What minimum readiness, maximum rate, daily volume, burst, concurrency, and message-size limits apply?
8. How are sandbox credentials issued, which acceptance tests are required, and what is the expected approval timeline?
9. Which receipts and statuses are returned? Ask whether they mean gateway acceptance, office routing/retrieval, or staff receipt.
10. What are the retry, backoff, idempotency, duplicate-suppression, outage, and reconciliation rules?
11. What encryption, logging, retention/deletion, incident reporting, data residency, audit, and subprocessor requirements apply?
12. Are fixed U.S. hosting, fixed egress IPs, IP allowlisting, mTLS, credential rotation, or other network controls required?
13. Are there any application, testing, production, support, or per-message fees?

## Important wording while approval is pending

- Say **Open official form** or **Needs your action**, not **Sent**.
- Treat House and Senate approval, credentials, schemas, and endpoints as separate dependencies.
- Keep every secret and direct-delivery call on the future backend, never in the Flutter client.
- Do not encode guessed ZIP+4, topic, receipt, or status rules into the app.

Ready-to-send draft messages and the supporting official-source evidence are in [CWC_SCWC_REQUIREMENTS_OUTREACH.md](CWC_SCWC_REQUIREMENTS_OUTREACH.md).
