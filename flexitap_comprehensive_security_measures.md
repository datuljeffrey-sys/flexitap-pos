# FlexiTap POS & Web Ecosystem: Full Comprehensive Security Measures & Architecture Audit

**Document Version:** 3.0.0 (Production Hardened)  
**Target Environment:** Cross-Platform POS (Flutter Android/Windows), Web Portals (`flexitapapp.com`), Supabase Cloud Backend  
**Audit Purpose:** Comprehensive technical documentation of all defensive measures, access controls, network boundaries, cryptographic implementations, and regulatory mitigations for independent third-party security assessors.

---

## Executive Summary

FlexiTap operates on a **hybrid local-first architecture**. Operational POS transaction data, inventory, order processing, and timecard logs are handled locally via an isolated SQLite engine (`flexitap.db`) on terminal hardware, with optional peer-to-peer LAN replication. Cloud services (Supabase PostgreSQL, Realtime WebSockets, Supabase Storage, and Web Portals) provide account authentication, multi-store licensing, daily sales aggregation, support desk telemetry, and remote assistance.

The platform enforces **defense-in-depth across 5 isolated layers**:
1. **Database & Row-Level Security (PostgreSQL / Supabase)**: Strict kernel-level data isolation and anti-privilege escalation triggers.
2. **Web Application & Surface Security (HTML5 / Vanilla JS)**: DOM XSS sanitization, anti-credential leaking, and strict staff authorization gates.
3. **Point of Sale Client Security (Flutter Core Engine)**: Role-Based Access Control (RBAC), Supervisor PIN verification, and isolated websocket broadcasting.
4. **Transport & Network Isolation**: Tenant-scoped channels, LAN token authorization, and partitioned remote support.
5. **Regulatory & Industry Scope Reduction**: Processor-agnostic checkout isolating cardholder data from software networks.

---

```mermaid
flowchart TD
    subgraph "Public Internet / External Surface"
        MerchantPortal["Merchant Portal\n(portal.html)"]
        DevPortal["Staff Operations Console\n(dev-portal.html)"]
        RemotePortal["Remote Support Portal\n(remote-support.html)"]
        PaddleGW["Paddle.js MoR Gateway\n(Hosted Billing)"]
    end

    subgraph "Supabase Cloud Security Boundary"
        PostgREST["PostgREST API Engine"]
        RLS["PostgreSQL Row-Level Security\n(Tenant & Staff Scoped)"]
        TriggerShield["DB Trigger Shield\n(trg_guard_profile_sensitive_columns)"]
        StorageEngine["Supabase Storage\n(Encrypted .bak Archives)"]
        DB[(PostgreSQL Primary DB)]
    end

    subgraph "Local Merchant Network (Zero Cloud Dependency)"
        MasterPOS["Master POS Terminal\n(Encrypted SQLite: flexitap.db)"]
        SubPOS["Satellite POS Terminals\n(LAN Token Verified)"]
        KDS["Kitchen Display (KDS)\n(Peer-to-Peer Socket)"]
        ExtTerminal["Standalone Card Terminal\n(Bank Network Only)"]
    end

    MerchantPortal -->|Auth Session / Tenant Channel| PostgREST
    DevPortal -->|Staff Verification / is_flexitap_staff()| PostgREST
    RemotePortal -->|6-Digit PIN Ephemeral RPC| PostgREST
    PostgREST --> RLS
    RLS --> TriggerShield
    TriggerShield --> DB
    MasterPOS -->|Nightly Compressed .bak| StorageEngine
    MasterPOS <-->|Auth Token / Local LAN Socket| SubPOS
    MasterPOS <-->|Order Broadcast| KDS
    MasterPOS -.->|Zero Card Data / Cashier Enters Total| ExtTerminal
```

---

## 1. Database & Supabase Cloud Security Shield

### 1.1 Server-Side Staff Verification (`public.is_flexitap_staff()`)
Privilege checks are evaluated directly within PostgreSQL using a `SECURITY DEFINER` function set with a hardened search path (`set search_path = public`). 
* Checks caller UUID against `public.profiles.role` for recognized administrative titles (`admin`, `super_admin`, `dev`, `developer`, `devops`, `support`, `staff`, `ops`, `agent`).
* Validates verified email domains against official internal company domains (`@flexitapapp.com`, `@flexitap.io`).
* Rejects unauthorized callers at the database kernel level, preventing client-side spoofing or REST parameter manipulation.

### 1.2 Anti-Privilege Escalation Trigger (`trg_guard_profile_sensitive_columns`)
To mitigate common SaaS privilege-escalation vulnerabilities where an authenticated user updates their own profile row via Supabase client SDK:
* A `BEFORE INSERT OR UPDATE` trigger intercepts all writes to `public.profiles`.
* Non-staff callers are prohibited from setting or altering their own `role` to staff tiers; attempts to inject administrative roles revert to `owner`.
* Callers cannot modify `is_suspended` flags or override device licensing counts (`max_devices_override`). Only verified staff or service-role administrative runners can alter these values.

### 1.3 Row-Level Security (RLS) Matrix
Every public table exposed to PostgREST enforces Row-Level Security. Direct anonymous (`anon`) table access is revoked.

| Table Name | Anon Access | Authenticated Policy Boundary | Audit Impact / Data Protected |
| :--- | :---: | :--- | :--- |
| `public.profiles` | Blocked | User can view/update own ID; verified staff can view/update all. | Merchant identity, account emails, assigned stores. |
| `public.stores` | Blocked | Store owner or assigned staff only. | Store telemetry, physical address, business configurations. |
| `public.devices` | Blocked | Store owner or assigned staff only. | POS terminal IDs, network roles, licensing counts. |
| `public.daily_sales_summaries` | Blocked | Store owner matching `store_id` / `owner_id` or staff. | Financial aggregations, gross/net sales, tax, tips. |
| `public.tickets` | Blocked | Store owner matching email/store or support specialists. | Support tickets, merchant issues, hardware diagnostics. |
| `public.ticket_notifications` | Blocked | Recipient matching authenticated email or staff. | Automated lifecycle email dispatch records. |
| `public.merchant_feedback` | Blocked | Submitting store owner or platform staff. | Merchant feature requests, bug reports, sentiment data. |
| `public.affiliates` | Blocked | Owning affiliate matching `user_id`/`email` or admin staff. | GCash, Maya, and Bank account payout credentials. |
| `public.affiliate_referrals` | Blocked | Linked affiliate or administrative staff. | Partner referral bindings and client identities. |
| `public.affiliate_commissions` | Blocked | Linked affiliate or administrative staff. | Partner transaction earnings and payout statuses. |
| `public.affiliate_payouts` | Blocked | Linked affiliate or administrative staff. | Disbursement ledger and banking reference codes. |
| `public.remote_support_sessions`| Selective RPC | Ephemeral lookup by session code; updates staff-only. | Remote desktop IDs, one-time pairing codes. |
| `public.merchant_crm_*` | Blocked | Store owner matching `profile_id` or platform staff. | Accounts, contacts, hardware assets, subscriptions. |
| `public.pos_devices` (Legacy) | Blocked | Store owner matching `store_id` or platform staff. | Resolves Supabase Security Advisor sensitive exposure. |
| `public.users` (Legacy) | Blocked | Authenticated store scope or staff. | Terminal employee PIN hashes and wage structures. |
| `public.invoices` / `items` | Blocked | Authenticated store scope or staff. | Legacy table backups and inventory lists. |

### 1.4 Hardened Stored Procedures (RPCs)
Remote assistance stored procedures are explicitly declared with strict execution barriers:
* `public.create_support_session()`: Generates random 6-digit collision-checked pairing codes with a 15-minute expiration; asserts `public.is_flexitap_staff()`.
* `public.staff_start_session(uuid)`: Validates that the activating user has verified staff credentials before transitioning session states to active.

---

## 2. Web Application & Surface Security (`flexitapapp.com`)

### 2.1 Multi-Layer Authentication Gate (`dev-portal.html`)
The internal developer and support console is guarded by a sequential 3-tier validation engine:
1. **Affiliate Intercept**: Rejects any account registered in `public.affiliates` to maintain strict boundary separation between external partners and internal engineering.
2. **Explicit Role Reject**: Rejects standard merchant roles (`owner`, `customer`, `partner`).
3. **App Metadata Validation**: Rejects client-writable `user_metadata.role` (which an attacker could spoof via `supabase.auth.updateUser()`). Enforces verification against server-controlled `app_metadata.role` or `public.profiles.role` validated via the DB trigger.

### 2.2 Staff Inspection Mode Isolation (`portal.html`)
The URL-based store inspection tool (`?dev_inspect=true&store_id=...`) is restricted to verified system roles (`admin`, `super_admin`, `dev`, `developer`, `support`, `staff`). Standard `owner` roles cannot activate the switcher to inspect foreign stores.

### 2.3 Stored DOM XSS Elimination
All dynamic parameters loaded from database rows or URL queries are passed through strict HTML entity encoding (`escapeHtml()`) prior to DOM insertion:
* Support tickets (`t.ticket_number`, `t.subject`, `t.category`, `assignedInfo`, `t.status`).
* CRM and lead directory tables (`business_name`, `contact_email`, `phone`, `dateFormatted`).
* Action button attributes (`onclick="convertLeadToMerchant(...)"` escapes single quotes, double quotes, and backslashes).

### 2.4 Removal of Client-Exposed API Keys
Hardcoded external AI / LLM API key strings have been removed from frontend scripts. The merchant analytics assistant operates via a local deterministic 42-guide Retrieval-Augmented Generation (RAG) knowledge engine and client-side statistical forecasting. Custom cloud LLM keys require authenticated session resolution.

### 2.5 Branded Email Webhook Sanitization
Email notifications dispatched to Google Workspace webhooks format all dynamic inputs (`storeName`, `ticketNumber`, `subject`, `details`, `resolutionNotes`) using sanitized HTML entity representations before dispatch.

---

## 3. POS Engine & Flutter Runtime Security

### 3.1 Cashier Role Partitioning & Isolation
To prevent cashier staff from accessing executive financial intelligence:
* **Remote Support Launcher (`remote_support_launcher.dart`)**: Cashiers tapping "Remote Support" launch a dedicated screen (`remote-support.html`) containing only diagnostic tools, RustDesk pairing, and ticket dispatch. Access to gross revenue, net margin, and employee payroll reports (`portal.html`) is inaccessible from this workflow.
* **Supervisor PIN Overrides**: Destructive actions inside the cashier interface require on-screen supervisor authorization (`UserRole.manager` or `UserRole.admin`):
  * **Ticket Voids**: Requires Manager PIN; records an immutable event in local `audit_logs`.
  * **Transaction Refunds**: Requires Manager PIN; records counter-balancing entries in `cash_ledger` or `customer_ar_ledger`.
  * **Ticket Re-opening**: Requires Manager PIN; voids the historical invoice and restores items into the active cart memory.
  * **Reprint Receipts**: Allowed without supervisor intervention to support normal customer checkout.

### 3.2 Cryptographic Local Storage & Authentication
* Local database (`flexitap.db`) runs under sandboxed OS application boundaries.
* Staff PIN codes are hashed using PBKDF2 with unique salts. Legacy SHA hashes are automatically upgraded to salted PBKDF2 upon first successful validation.

---

## 4. Network Boundary & Realtime Isolation

### 4.1 Tenancy-Scoped WebSocket Relays
The on-demand report relay engine enables store owners to query live, in-memory SQLite balances directly from browser portals over WebSockets without exposing inbound firewall ports:
* **Legacy Shared Channel Removed**: The platform has deprecated and purged the fallback broadcasting channel (`store_reports_relay_a927b91f...`).
* **Tenant Partitioning**: WebSockets subscribe strictly to `store_reports_relay_<storeId>`.
* **Bi-Directional Validation**:
  * Outbound `RUN_REPORT` requests must carry a payload matching the current store ID.
  * Inbound `REPORT_RESPONSE` packets on both Flutter POS and web portals verify `resp.storeId === activeStore.id`; foreign payloads are dropped.

### 4.2 Local Network Synchronization (LAN POS Architecture)
For multi-terminal environments (Master POS, Satellite Registers, Kitchen Display Systems):
* Terminals communicate across the local subnet using HTTP/REST and Raw TCP sockets.
* Inter-terminal payloads require a shared local network security token (`X-FlexiTap-Token`) generated during initial pairing.
* Unauthenticated LAN connections are rejected with HTTP 401 Unauthorized.

---

## 5. Regulatory Compliance & Scope Reduction Architecture

### 5.1 PCI DSS v4.0 Scope Mitigation (Standalone Semi-Integrated Pattern)
* **Zero Cardholder Data Storage**: Cardholder Primary Account Numbers (PAN), CVVs, and magnetic track data are neither collected, processed, nor stored within FlexiTap applications, local SQLite databases, or cloud tables.
* **Payment Isolation**: Card transactions occur on external, bank-issued card terminals. The POS simply records tender classification (`CC`, `VISA`) and authorization codes entered by the operator.
* **SaaS Subscription Processing**: SaaS billing is offloaded to Paddle (acting as Merchant of Record). No credit cards are processed directly by FlexiTap web servers.

### 5.2 Regional Privacy Alignment (US State Laws & PH RA 10173)
* **Data Minimization**: The platform restricts personal collection to operational metadata necessary for commerce (merchant accounts, staff time entries, optional customer loyalty).
* **Right to Erasure Compliance**: Standard database utilities allow immediate, cascade-deletion of customer profiles, transaction history, and associated backup archives upon verified customer request.
* **Audit Trail Protection**: High-risk financial operations maintain persistent audit logging (`audit_logs`) tracking timestamp, authorization mechanism, financial impact, and reason code.

---

## 6. Security Assurance Checklist for Auditors

- [x] **PostgreSQL RLS Active**: Enabled on 100% of public tables exposed to PostgREST.
- [x] **Anonymous Access Denied**: Public anonymous read/write revoked on sensitive financial, audit, and credential tables.
- [x] **Privilege Escalation Blocked**: Kernel trigger prevents unauthorized elevation to `admin` / `dev` / `support`.
- [x] **Realtime WebSocket Isolated**: Multi-store broadcast channels partitioned per tenant ID.
- [x] **XSS Mitigation Active**: Dynamic DOM insertions sanitized via HTML entity encoding.
- [x] **Card Data Out of Scope**: Zero PAN/CVV storage; architecture qualifies for simplified PCI scope.
- [x] **Cashier Financial Isolation**: Cashiers operate without exposure to store owner financial dashboards.
- [x] **Cryptographic Hygiene**: Employee PINs stored as PBKDF2 salted hashes.
