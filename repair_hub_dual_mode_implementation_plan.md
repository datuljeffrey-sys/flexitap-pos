# FlexiTap Sales & Repair Engine: Full Implementation Plan

**Target Software:** FlexiTap POS Platform (Flutter POS Engine v2.0, Web Portal & Supabase Cloud)  
**Feature:** Dual-Mode Workspace: Counter POS + Repair Hub  
**Author:** Google DeepMind / Antigravity Agent  
**Status:** Architecture Blueprint & Implementation Specification  
**Version:** 1.0 (Draft)

---

## 1. Executive Summary & Architectural Vision

In retail and service environments, modern shops frequently operate a dual-revenue business model:
1. **Counter Sales:** Fast over-the-counter retail transactions for merchandise and accessories.
2. **Device / Equipment Repairs:** In-depth customer drop-off servicing requiring intake documentation, diagnosis, parts allocation, labor fees, claim stubs, status tracking, and warranty management.

Currently, merchants are forced to juggle two disconnected systems: a legacy PC running a ticketing web app, and an independent cash register or tablet on the checkout counter.

**FlexiTap Dual-Mode Architecture** introduces an integrated, instant-toggle workspace in the POS header bar:
```
+---------------------------------------------------------------------------------------------------+
|  [FLEXITAP LOGO]       [ 🛒 Counter POS ]  |  [ 🔧 Repair Hub (3) ]            [Shift: Juan] [⚙️]  |
+---------------------------------------------------------------------------------------------------+
```
* **One Single Tablet / Terminal:** Eliminates duplicate hardware and screen clutter.
* **100% Offline-First:** Intake, claim printing, and repair status changes execute with zero internet dependency in SQLite.
* **The "Magic Cart Bridge":** Completed repairs seamlessly convert into standard POS cart items, allowing parts, labor, and shelf merchandise to be paid on a single unified invoice.
* **Real-Time Customer Web Tracking:** Thermal claim tickets print a dynamic QR code pointing to a customer-facing status page (`flexitapapp.com/track?j=JOB-XXXX`) powered by Supabase Realtime.

---

## 2. Navigation & Header Switcher UX Architecture

### 2.1 Mode State Management
A reactive state provider (`posModeProvider`) governs the active workspace:
```dart
enum PosActiveMode {
  counterPos, // High-speed retail sales & checkout
  repairHub,  // Job orders, repair Kanban, technician workbench
}
```
* **Persistent Cart State:** When switching from `Counter POS` to `Repair Hub` to look up a ticket, the active cashier cart is **never cleared**. The cashier can switch modes, check a repair status, and return to the active sale with zero lost line items.
* **Badge Counter:** The `[ 🔧 Repair Hub ]` pill displays a live badge count indicating tickets currently in progress (`in_progress` + `waiting_parts` + `ready_for_pickup`).
* **Hardware Hotkey / Barcode Shortcut:** Pressing `F2` on a physical keyboard or scanning a special "Switch Mode" barcode immediately flips between modes.

---

## 3. Database Architecture & Schema Specification

### 3.1 Local SQLite Schema (Offline-First)

#### Table 1: `repair_jobs`
Stores core ticket header and device metadata.
```sql
CREATE TABLE IF NOT EXISTS repair_jobs (
  id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL,
  job_number TEXT NOT NULL UNIQUE,          -- Human-readable e.g. "JOB-1001"
  customer_id TEXT,                         -- Optional link to existing customer
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  device_type TEXT NOT NULL,                 -- 'Smartphone', 'Laptop', 'Bicycle', 'Motorcycle', 'Other'
  brand TEXT NOT NULL,                      -- e.g. "Apple", "Honda", "Shimano"
  model TEXT NOT NULL,                      -- e.g. "iPhone 13 Pro", "Click 125i"
  serial_or_imei TEXT,                      -- Serial / IMEI / Plate #
  passcode TEXT,                            -- Optional device lock PIN (for testing)
  stated_issue TEXT NOT NULL,               -- Problem description
  technician_notes TEXT,                    -- Internal diagnosis remarks
  cosmetic_condition TEXT,                  -- JSON string of checklist e.g. ["scratched_screen", "dent_corner"]
  status TEXT NOT NULL DEFAULT 'received',  -- 'received', 'diagnosing', 'waiting_parts', 'in_progress', 'ready_for_pickup', 'completed', 'cancelled'
  priority TEXT NOT NULL DEFAULT 'normal',  -- 'low', 'normal', 'urgent'
  assigned_technician_id TEXT,              -- Staff user ID
  assigned_technician_name TEXT,
  estimated_cost REAL NOT NULL DEFAULT 0.0,
  downpayment_amount REAL NOT NULL DEFAULT 0.0,
  total_parts_amount REAL NOT NULL DEFAULT 0.0,
  total_labor_amount REAL NOT NULL DEFAULT 0.0,
  final_amount REAL NOT NULL DEFAULT 0.0,
  balance_due REAL NOT NULL DEFAULT 0.0,
  invoice_id TEXT,                          -- Populated once paid in POS cart
  warranty_days INTEGER NOT NULL DEFAULT 30,
  warranty_expires_at TEXT,                 -- ISO timestamp
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_repair_jobs_store_id ON repair_jobs(store_id);
CREATE INDEX IF NOT EXISTS idx_repair_jobs_status ON repair_jobs(status);
CREATE INDEX IF NOT EXISTS idx_repair_jobs_phone ON repair_jobs(customer_phone);
```

#### Table 2: `repair_job_items`
Tracks parts deducted from store inventory and labor fees applied to the ticket.
```sql
CREATE TABLE IF NOT EXISTS repair_job_items (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
  item_id TEXT,                             -- Points to public.items (NULL for custom labor)
  name TEXT NOT NULL,                       -- e.g. "OEM iPhone 13 OLED Screen" or "Screen Replacement Labor"
  item_type TEXT NOT NULL,                  -- 'part' vs 'labor'
  quantity REAL NOT NULL DEFAULT 1.0,
  unit_price REAL NOT NULL,
  cost_price REAL NOT NULL DEFAULT 0.0,     -- Item inventory COGS
  technician_commission_rate REAL DEFAULT 0.0, -- e.g. 0.30 (30% of labor)
  technician_commission_amount REAL DEFAULT 0.0,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_repair_job_items_job_id ON repair_job_items(job_id);
```

#### Table 3: `repair_job_status_logs`
Audit trail of all status transitions for customer accountability.
```sql
CREATE TABLE IF NOT EXISTS repair_job_status_logs (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  notes TEXT,
  changed_by_user_name TEXT,
  created_at TEXT NOT NULL
);
```

### 3.2 Supabase Cloud Schema & RLS Mirror
- Both `repair_jobs` and `repair_job_items` tables will be provisioned in the public schema with `ENABLE ROW LEVEL SECURITY`.
- Policed via:
  ```sql
  CREATE POLICY "Merchants access own store repair jobs"
  ON public.repair_jobs FOR ALL TO authenticated
  USING (store_id::text IN (SELECT id::text FROM public.stores WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text))
  WITH CHECK (store_id::text IN (SELECT id::text FROM public.stores WHERE owner_id::text = auth.uid()::text OR user_id::text = auth.uid()::text));
  ```
- Added to `SyncService` outbox replication worker for bidirectional offline/online sync.

---

## 4. Workflows & Functional Modules

### 4.1 Module 1: The Rapid Intake Modal
* **Trigger:** Floating Action Button `[+ New Job Order]` in Repair Hub or Hotkey `Ctrl+N`.
* **Step 1: Customer Info:** Phone number lookup auto-fills returning customers or creates a new profile.
* **Step 2: Equipment Identification:** Type picker (Smartphone, Laptop, Bike, Vehicle, etc.), Brand, Model, Serial/IMEI.
* **Step 3: Issue & Condition Inspection Checklist:**
  * Tap checkboxes: `[✓] Cracked Glass`, `[✓] Scratched Housing`, `[✓] Water Damage Markers Red`, `[✓] Battery Swelling`, `[✓] Missing Screws`.
  * Stated customer complaint.
  * Passcode / Pattern note (securely recorded with customer consent).
* **Step 4: Estimate & Downpayment:**
  * Estimated total quote.
  * Optional upfront downpayment or diagnostic fee (if collected, automatically pops cash drawer and logs initial deposit).

### 4.2 Module 2: ESC/POS Thermal Claim Printing
Upon intake submission, the thermal printer immediately executes:
1. **Customer Claim Stub (Thermal Slip):**
   * Shop Branding, Address, Hotline.
   * Prominent Box: `JOB ORDER #: JOB-1042`.
   * Date & Estimated Ready Time.
   * Customer Name & Device Summary.
   * **Dynamic QR Code:** Rendered using ESC/POS QR raster commands:
     `https://flexitapapp.com/track?id=JOB-1042`
   * Disclaimer: *"Items unclaimed after 60 days shall be disposed of. Shop is not liable for data loss or pre-existing board defects."*
   * Customer signature line.
2. **Device Attachment Sticker (Tear-off Tag):**
   * Compact 2-inch tear-off slip containing Job #, Customer Phone, Serial #, and problem summary to physically tape onto the customer's phone/bike.

### 4.3 Module 3: Visual Repair Kanban Workbench
When switched to `[ 🔧 Repair Hub ]`, the screen displays a multi-column Kanban board:
* **Columns:**
  1. `[ Intake / Received ]`: Fresh drop-offs waiting for technical inspection.
  2. `[ Under Repair ]`: Currently being worked on by an assigned technician.
  3. `[ Waiting for Parts ]`: Paused awaiting delivery of special-order components.
  4. `[ Ready for Pickup ]`: Work completed and tested; customer notified.
* **Card Features:**
  * Elapsed time counter (e.g. *"2 hrs ago"*, *"Due Today at 5:00 PM"*).
  * Priority color border: Red (Urgent), Green (Normal).
  * Assigned Technician avatar/name.
  * Direct Action Buttons on Card:
    * `[Add Parts/Labor]`: Modal to deduct inventory items or add service fees.
    * `[Mark Ready]`: Moves to pickup column and triggers status sync.
    * `[Settle at Counter]`: Launches Cart Bridge.

### 4.4 Module 4: The "Settle at Counter" Cart Bridge
This connects the repair world directly into the sales world:
1. When cashier taps **`Settle at Counter`** on a ready job:
2. The system checks `repair_job_items` for that ticket:
   * Line Item 1: `OEM OLED Display (Part) - ₱2,200`
   * Line Item 2: `Screen Replacement Service (Labor) - ₱600`
3. If an initial downpayment was paid (e.g. `₱500`), it applies an automatic credit line: `-₱500 Downpayment Applied`.
4. The system switches to **`[ 🛒 Counter POS ]`** with the items pre-populated in the cart.
5. Cashier can add any retail shelf items (e.g. Tempered Glass, Bike Oil, Phone Case).
6. Cashier tenders payment &rarr; Cash drawer kicks open.
7. Thermal receipt prints unified invoice showing retail items, repair items, and warranty date.
8. Job status flips to `completed` with `completed_at = now()`.

---

## 5. Customer Web Tracking Portal Architecture

* **URL Pattern:** `https://flexitapapp.com/track.html?id=JOB-1042`
* **Zero Account Barrier:** Customers do not create an account or download an app.
* **Privacy Gate:** Entering the link prompts for the **last 4 digits of the customer's phone number** to verify ownership before displaying device details.
* **Live Stepper UI:**
  * Step 1: `Device Received` (Checked)
  * Step 2: `Diagnosis & Parts` (Checked)
  * Step 3: `Under Repair` (Active)
  * Step 4: `Ready for Pickup at Store` (Pending)
* **Realtime Broadcast:** When the technician taps "Ready" in the shop, Supabase Realtime updates the customer's web browser instantly without refreshing.

---

## 6. Implementation Phasing & Task Breakdown

| Phase | Milestone Name | Scope & Deliverables | Duration |
| :---: | :--- | :--- | :---: |
| **Phase 1** | **Database & Data Layer** | SQLite tables (`repair_jobs`, `repair_job_items`), models, repositories, and Supabase cloud sync integration. | 1.5 Days |
| **Phase 2** | **Navigation & Header Pill** | Top-bar mode switcher (`[ Counter POS ] <-> [ Repair Hub ]`), reactive badge counters, workspace view switching. | 1.0 Day |
| **Phase 3** | **Intake & Claim Printing** | `NewJobOrderDialog` intake modal, condition checklist, thermal claim receipt generator with QR code raster. | 1.5 Days |
| **Phase 4** | **Kanban Workbench** | Multi-column repair queue board, technician assignment, status transition state machine, filter/search. | 2.0 Days |
| **Phase 5** | **Cart Settlement Bridge** | One-tap transition from Job Order to active POS cart, parts deduction verification, downpayment credits, warranty receipt. | 1.5 Days |
| **Phase 6** | **Web Tracking Portal** | Public customer status tracking web page on `flexitapapp.com/track.html` with Supabase Realtime updates. | 1.0 Day |

---

## 7. Risk Analysis & Mitigation Strategies

1. **Risk: Inventory Double Deduction**
   * *Scenario:* A technician adds an LCD screen to a repair job, and the cashier accidentally scans that same LCD screen at checkout.
   * *Mitigation:* The Cart Bridge explicitly tags repair parts as `source: 'repair_job'`. If an item was already deducted during the repair stage, the checkout transaction does not decrement inventory twice.
2. **Risk: Offline Claim Stub Printing with Unknown Web URL**
   * *Scenario:* The shop is offline when the ticket is created; can the QR code still work later?
   * *Mitigation:* Yes! The QR code encodes a deterministic URL using the permanent UUID or Job Number (e.g. `https://flexitapapp.com/track?s=<storeId>&j=JOB-1042`). As soon as the POS terminal reconnects to the internet, the background sync queue uploads the ticket to Supabase, and the customer's QR link activates automatically.
3. **Risk: Technician Unauthorized Discounts**
   * *Mitigation:* Inherits FlexiTap's existing Manager PIN gate. Editing pre-agreed quotes or waiving diagnostic fees requires an authorized Manager/Admin PIN.

---

## 8. Verification & Acceptance Criteria

- [ ] **Mode Switching:** Tapping the header switcher transitions between POS and Repair Hub in under 200ms with zero cart loss.
- [ ] **Intake & Thermal Print:** Creating an intake prints a clear thermal claim stub with an unscrambled, high-contrast QR code on standard 58mm/80mm ESC/POS printers.
- [ ] **Inventory Link:** Assigning a retail item to a repair ticket decrements store stock immediately in SQLite.
- [ ] **Cart Bridge:** Hitting "Settle at Counter" populates the active cart with correct line items and handles downpayment credits accurately.
- [ ] **Warranty Expiration:** Closing a repair ticket prints the computed warranty expiration date on the customer's sales invoice.
