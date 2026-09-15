# House CWC and Senate SCWC Requirements & Outreach

Status: Research complete; outreach drafts prepared but **not sent**  
Accessed: 2026-09-15  
Scope: Official U.S. House and U.S. Senate sources only

## Planning conclusion

The app can build the constituent-facing experience and a delivery-provider interface now, but it should not promise direct submission until each chamber approves the operator and supplies or confirms its technical contract. Both programs publicly contemplate approved third-party delivery agents and campaign-based messages to Member offices. Neither chamber publicly specifies enough of the current payload, validation, throughput, error, or retry contract to safely implement production delivery from public material alone.

Treat direct House CWC and Senate SCWC delivery as separate adapters behind one internal delivery interface. Until approved, the product should use an honest handoff to each Member's official contact page rather than label a copied or redirected message as sent.

## Confirmed public requirements

### House CWC

- CWC is for advocacy vendors delivering advocacy-generated constituent communications to House Member offices. It does not address committee, leadership, or support offices.
- Messages use a secure delivery path and a strict XML standard. The current public page says technical information is provided after application approval.
- The application is a legal agreement with the House CAO and requests the vendor's legal/contact information, principals, applicable EIN/DUNS/CAGE identifiers, states of authorization, conduct disclosures, and prior-application history.
- Every communication must include a vendor identification number and a unique campaign identification number for its legislative campaign.
- To the vendor's knowledge, it may not submit a name or email address not authorized by the email owner, an invalid or spam-trap address, or use a subcontractor without prior written CAO approval.
- The House does not charge a fee for CWC use. This does not make the app's hosting, address matching, abuse controls, or support free.
- The public level-of-service standards confirm a sandbox, advance notice for major changes, possible suspension or intake limits, and message-specific confirmation on inquiry that a message was accepted and processed for retrieval by the appropriate office.
- Vendors must respond to normal House communications within 24 hours excluding weekends/holidays and emergency communications within two hours.
- Access may be denied or withdrawn at the CAO's discretion.

### Senate SCWC / SOAPBox

- SCWC is for third-party advocacy organizations or vendors, called Delivery Agents, sending citizen communications to Senate Member offices through the SOAPBox single-entry API. It does not address committee, leadership, or support offices.
- The public Senate page says applicants must be able to meet high-volume sending infrastructure and message-format requirements, but it does not publish numeric thresholds.
- The online application requires company information, principal officers, address, state authorization, authorized and technical contacts, conduct disclosures, and application history. EIN, DUNS, and CAGE/NCAGE are optional unless the company is registered. An automated-message email is optional at application time but required for testing approval.
- Each communication requires the Senate-provided vendor API key and a vendor-assigned unique campaign identification number for each legislative campaign.
- A vendor may not submit an email, email address, or name not authorized by the email owner; an invalid/unusable or spam-trap address; or subcontract without prior written Senate approval.
- The Senate provides a Testing and System Acceptance environment, and production authorization follows testing to the Senate's satisfaction.
- The Senate may suspend or limit the service. A vendor must stop sending to a specific Senate office within 24 hours after receiving an office-suspension notice.
- On a message-specific inquiry, the Senate will confirm whether the message was accepted and redirected to the appropriate office.
- Vendors must respond to normal Senate communications within 24 hours excluding weekends/holidays and emergencies within two hours.
- Access may be denied or withdrawn at the Senate's discretion.

## Not established by public sources

These are requirements questions, not assumptions for implementation:

- Whether a neutral, direct-to-citizen app with no sponsoring advocacy organization qualifies, and what legal entity maturity is expected.
- The current House CWC XML schema and Senate Standards and Requirements Packet, including mandatory constituent fields, enumerations, maximum lengths, and encoding.
- Whether a complete street address, ZIP+4, phone number, prefix, topic, bill number, campaign sponsor, or other fields are mandatory.
- Whether address standardization, deliverability validation, district matching, email confirmation, explicit authorization language, CAPTCHA, or other proof is required.
- Whether one user-authored message may be delivered to one Representative and both Senators, and whether each chamber or recipient needs a distinct campaign ID.
- Minimum/maximum campaign size, messages per second/day, burst rules, concurrency, payload limits, or office-specific limits.
- API protocol and authentication details, current endpoints, IP allowlisting, credential rotation, sandbox data rules, and native/mobile client restrictions.
- Synchronous acknowledgements, durable receipt IDs, rejection/error taxonomy, office retrieval status, later delivery updates, and whether any status means staff receipt rather than gateway acceptance.
- Retry windows, backoff, idempotency/deduplication rules, outage handling, and reconciliation procedures.
- Required logging, constituent-data retention/deletion, encryption, incident reporting, audits, privacy notices, data residency, and approved infrastructure/subprocessors.
- Senate program fees, if any. The House agreement expressly says CWC usage has no fee; the reviewed Senate pages do not make an equivalent public statement.

The House's public standards are dated June 2013 but remain linked from the current House CWC page. The outreach should ask whether they and the public application are the controlling versions.

## Application and contact routes

### House

- Program page and application instructions: [Communicating with Congress (CWC)](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc)
- Application/agreement PDF: [CWC Usage Agreement and Access Application](https://www.house.gov/sites/default/files/uploads/documents/CWC-USAGE-AGREEMENT.pdf)
- Public standards PDF: [Advocacy Vendor Level of Service Standards](https://www.house.gov/sites/default/files/uploads/documents/cwc-advocacy-vendor-level-of-service-standards.pdf)
- Submit the completed application and ask program questions: `CWCVendors@mail.house.gov`
- The agreement also lists `cwc.vendors@mail.house.gov`, (202) 226-2140, and fax (202) 226-1872. Prefer the address printed on the current program page and ask the team to confirm the canonical mailbox.

### Senate

- Program overview: [Senate Communicating with Congress](https://www.senate.gov/senators/scwc.htm)
- Online application: [SCWC Access Application](https://soapbox.senate.gov/registration/)
- Terms and public standards: [SCWC Terms of Service](https://soapbox.senate.gov/registration/terms-of-service/)
- Pre-application questions: [SOAPBox question form](https://soapbox.senate.gov/delivery-agent/help/)
- The Terms of Service also names `SAACWC@saa.senate.gov` for notices and application-information updates.
- Approved/account holders use [SOAPBox sign-in](https://soapbox.senate.gov/) to check application status, retrieve technical documentation and, once approved, API keys.

## Requirements questionnaire

Use the same numbered questions for both chambers so answers can become a comparable delivery contract.

1. **Eligibility:** Can a neutral consumer app that lets an individual find their own Members and author their own message qualify as an Advocacy Vendor/Delivery Agent without a sponsoring advocacy organization? What entity, registration, insurance, or operating-history requirements apply?
2. **Current documents:** Are the linked public application, agreement, and standards controlling? May you provide the latest schema/Standards and Requirements Packet and implementation guide before approval or under an NDA?
3. **Constituent fields:** Which fields are mandatory, optional, enumerated, and length-limited? Please confirm requirements for name, prefix/suffix, street/unit, city, state, ZIP5, ZIP+4, email, phone, subject, topic, bill, message, organization, and recipient.
4. **Address and district:** Is ZIP+4 mandatory? Must the vendor use USPS validation or another approved service? Who is responsible for congressional-district and recipient matching, including ambiguous addresses and at-large districts?
5. **Authorization and abuse controls:** What affirmative authorization must be captured from the constituent? Is email ownership confirmation required? Are CAPTCHA, device/IP rate limits, duplicate detection, attestations, audit evidence, or identity checks required or prohibited?
6. **Campaigns and recipients:** How is a legislative campaign defined for a neutral user-authored message? May one action address the user's House Member and both Senators? Must campaign IDs differ by chamber, Member, issue, template, or time period? Are identical/template messages permitted?
7. **Volume and availability:** What minimum readiness and maximum rate/volume, burst, concurrency, message-size, maintenance, or office-specific limits apply? How are limit changes and office suspensions communicated?
8. **Testing and launch:** How are sandbox/testing credentials issued? What test cases, security review, acceptance criteria, certification, and expected review timeline precede production approval?
9. **Receipts and status:** What acknowledgement and durable identifiers are returned? Which states distinguish schema acceptance, gateway acceptance, office routing/retrieval, rejection, and staff receipt? Is status queryable or available only through support?
10. **Errors and retries:** What error taxonomy, retryable conditions, retry windows/backoff, idempotency keys, duplicate suppression, outage queueing, and reconciliation rules apply?
11. **Privacy and security:** What retention/deletion, encryption, logging, audit, incident-notification, data-residency, privacy-notice, access-control, and subprocessor requirements apply to constituent data and credentials?
12. **Architecture:** Must all calls originate from a U.S.-hosted server? Are native iOS/Android or browser clients allowed only through the vendor backend? Are IP allowlists, mTLS, fixed egress IPs, or credential-rotation procedures required?
13. **Costs and support:** Are there application, testing, production, support, or per-message fees? What support route and response expectations apply during integration and production incidents?

## Draft House outreach email — not sent

**To:** `CWCVendors@mail.house.gov`  
**Subject:** CWC eligibility and current technical requirements for neutral constituent app

Hello CWC Vendor Team,

We are developing a neutral, nonpartisan application that helps an individual identify their own U.S. Representative and Senators, write a personal message, review it, and authorize its delivery with as little friction as possible. The app would not send a message without the named constituent's action, and we are designing address matching, email confirmation, rate limits, bot protection, deduplication, privacy controls, and auditable consent before enabling direct delivery.

Could you confirm whether this direct-to-citizen model is eligible to apply as a House CWC Advocacy Vendor when no advocacy organization sponsors the message?

We reviewed the current House CWC program page, CWC Usage Agreement and Access Application, and the June 2013 Advocacy Vendor Level of Service Standards. Before we finalize the delivery architecture and user disclosures, could you please answer the attached/below numbered requirements questionnaire, or provide the current technical and policy documents that answer it? We especially need confirmation of mandatory constituent fields and ZIP+4 rules, authorization/verification requirements, campaign-ID treatment for individual user-authored messages, volume limits, sandbox and acceptance steps, delivery-status semantics, retry/deduplication rules, data-retention/security duties, server/mobile architecture restrictions, and all costs.

Please also confirm whether the publicly linked agreement and standards are the controlling versions and whether `CWCVendors@mail.house.gov` is the canonical application and support mailbox.

We have not enabled automated House delivery and will not represent messages as delivered through CWC until approval and successful testing. Thank you for pointing us to the correct next step.

Sincerely,  
[Name]  
[Title / legal entity]  
[Phone]  
[Email]  
[Website]

## Draft Senate outreach message — not sent

**Route:** [SOAPBox question form](https://soapbox.senate.gov/delivery-agent/help/) or `SAACWC@saa.senate.gov`  
**Subject:** SCWC eligibility and current technical requirements for neutral constituent app

Hello SCWC Team,

We are developing a neutral, nonpartisan application that helps an individual identify their own U.S. Representative and Senators, write a personal message, review it, and authorize its delivery with as little friction as possible. The app would not send a message without the named constituent's action, and we are designing address matching, email confirmation, rate limits, bot protection, deduplication, privacy controls, and auditable consent before enabling direct delivery.

Could you confirm whether this direct-to-citizen model is eligible to apply as a Senate SCWC Delivery Agent when no advocacy organization sponsors the message, and how the Senate's high-volume eligibility requirement applies to a new service?

We reviewed the SCWC overview, online Access Application, and Terms of Service. Before we finalize the delivery architecture and user disclosures, could you please answer the attached/below numbered requirements questionnaire, or advise when the current Standards and Requirements Packet can be reviewed? We especially need confirmation of mandatory constituent fields and ZIP+4 rules, authorization/verification requirements, campaign-ID treatment for individual user-authored messages, volume limits, testing and acceptance steps, delivery-status semantics, retry/deduplication rules, data-retention/security duties, server/mobile architecture restrictions, and all costs.

We have not enabled automated Senate delivery and will not represent messages as delivered through SCWC until approval and successful testing. Thank you for pointing us to the correct next step.

Sincerely,  
[Name]  
[Title / legal entity]  
[Phone]  
[Email]  
[Website]

## Evidence table

| Official source | Confirmed evidence used | Accessed |
| --- | --- | --- |
| [House CWC program page](https://www.house.gov/doing-business-with-the-house/communicating-with-congress-cwc) | Advocacy-vendor scope; secure XML delivery; application review; technical information after approval; current submission/contact route | 2026-09-15 |
| [House CWC Usage Agreement/Application](https://www.house.gov/sites/default/files/uploads/documents/CWC-USAGE-AGREEMENT.pdf) | House Member-only purpose; no CWC fee; applicant background; vendor/campaign IDs; prohibited practices; discretionary access; contact routes | 2026-09-15 |
| [House Advocacy Vendor Level of Service Standards](https://www.house.gov/sites/default/files/uploads/documents/cwc-advocacy-vendor-level-of-service-standards.pdf) | Version/date; sandbox; response duties; downtime/change notice; suspension/limits; message-specific acceptance confirmation | 2026-09-15 |
| [Senate SCWC overview](https://www.senate.gov/senators/scwc.htm) | Delivery Agent scope; mandatory/optional standardized fields; SOAPBox API; high-volume and format readiness; application link | 2026-09-15 |
| [Senate SCWC application](https://soapbox.senate.gov/registration/) | Public application fields; testing-notice email requirement; House-status question; conduct and certification sections | 2026-09-15 |
| [Senate SCWC Terms of Service](https://soapbox.senate.gov/registration/terms-of-service/) | Member-only purpose; API/campaign IDs; authorization and invalid-email rules; subcontracting; testing; maintenance; limits/suspension; receipt inquiries; response duties | 2026-09-15 |
| [Senate SOAPBox sign-in](https://soapbox.senate.gov/) | Application-status workflow; technical-document access; approved API-key retrieval | 2026-09-15 |
| [Senate SOAPBox question form](https://soapbox.senate.gov/delivery-agent/help/) | Public pre-application contact route and required form fields | 2026-09-15 |

## Planning guardrail

Do not encode guessed chamber rules into the UI. The product may ask for the likely common fields during prototyping, but field requirements and delivery status labels must be remotely configurable. In particular, reserve **Sent** for a status whose meaning is confirmed by the chamber; the public documents support only gateway acceptance/routing confirmation on inquiry, not proof that a staff member read the message.
