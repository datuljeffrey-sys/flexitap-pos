import os
import subprocess

EDGE_EXE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
OUTPUT_DIR = r"c:\FlexiTap\social_media_features"
ARTIFACT_DIR = r"C:\Users\JAY\.gemini\antigravity\brain\7bc54fd8-9955-4598-baa4-016fcd47e1e3"

os.makedirs(OUTPUT_DIR, exist_ok=True)

# SVG Icons library
ICONS = {
    "scan": '<svg viewBox="0 0 24 24"><path d="M3 5v14M8 5v14M12 5v14M17 5v14M21 5v14"/></svg>',
    "shield": '<svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg>',
    "grid": '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>',
    "card": '<svg viewBox="0 0 24 24"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>',
    "globe": '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>',
    "sync": '<svg viewBox="0 0 24 24"><path d="M21.5 2v6h-6M2.5 22v-6h6"/><path d="M22 11.5A10 10 0 0 0 3.2 7.2L2.5 8M2 12.5a10 10 0 0 0 18.8 4.3l.7-.8"/></svg>',
    "share": '<svg viewBox="0 0 24 24"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>',
    "bell": '<svg viewBox="0 0 24 24"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
    "calendar": '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
    "user": '<svg viewBox="0 0 24 24"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    "sparkles": '<svg viewBox="0 0 24 24"><path d="m12 3 1.9 5.8a2 2 0 0 0 1.3 1.3L21 12l-5.8 1.9a2 2 0 0 0-1.3 1.3L12 21l-1.9-5.8a2 2 0 0 0-1.3-1.3L3 12l5.8-1.9a2 2 0 0 0 1.3-1.3L12 3z"/></svg>',
    "dollar": '<svg viewBox="0 0 24 24"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',
    "gauge": '<svg viewBox="0 0 24 24"><path d="M12 2v4M4.93 4.93l2.83 2.83M2 12h4M4.93 19.07l2.83-2.83M12 22v-4M19.07 19.07l-2.83-2.83M22 12h-4M19.07 4.93l-2.83 2.83"/><circle cx="12" cy="12" r="3"/></svg>',
    "lock": '<svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
    "eye": '<svg viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>',
    "qr": '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="5" y="5" width="3" height="3" fill="currentColor"/><rect x="16" y="5" width="3" height="3" fill="currentColor"/><rect x="5" y="16" width="3" height="3" fill="currentColor"/><path d="M14 14h3v3h-3zM17 17h4v4h-4zM14 20h3v1h-3zM20 14h1v3h-1z"/></svg>',
    "chef": '<svg viewBox="0 0 24 24"><path d="M6 13.8V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v9.8M6 13.8a4 4 0 0 0 4 3.8h4a4 4 0 0 0 4-3.8M6 13.8A4 4 0 0 1 3 10V8a2 2 0 0 1 2-2h1M18 13.8A4 4 0 0 0 21 10V8a2 2 0 0 0-2-2h-1M9 22h6"/></svg>',
    "clock": '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
    "check": '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>',
    "tv": '<svg viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"/><polyline points="17 2 12 7 7 2"/></svg>',
    "zap": '<svg viewBox="0 0 24 24"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
    "columns": '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="8" height="18" rx="1"/><rect x="13" y="3" width="8" height="18" rx="1"/></svg>',
    "chart": '<svg viewBox="0 0 24 24"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>',
    "pie": '<svg viewBox="0 0 24 24"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>',
    "file": '<svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>',
    "truck": '<svg viewBox="0 0 24 24"><rect x="1" y="3" width="15" height="13"/><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/></svg>',
    "checkcircle": '<svg viewBox="0 0 24 24"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
    "speaker": '<svg viewBox="0 0 24 24"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"/></svg>',
}

FEATURES = [
    {
        "id": "1",
        "file": "feature_1_retail_checkout.png",
        "img_src": "file:///c:/FlexiTap/Retail.png",
        "title_main": "High-Density SKU",
        "title_accent": "& Parked Sales",
        "subtitle": "Sub-second barcode scanning, live SKU inventory, customer profiles, and 100% offline checkout.",
        "tl": {"icon": "user", "title": "Loyalty Profiles", "sub": "Instant member lookup & points", "tx": 380, "ty": 218},
        "bl": {"icon": "shield", "title": "100% Offline Checkout", "sub": "Keep selling when Wi-Fi drops", "tx": 380, "ty": 520},
        "tr": {"icon": "scan", "title": "Instant Barcode Scan", "sub": "Sub-second SKU lookup in <15ms", "tx": 715, "ty": 218},
        "br": {"icon": "grid", "title": "Live SKU Inventory", "sub": "Real-time stock & category filters", "tx": 715, "ty": 360}
    },
    {
        "id": "2",
        "file": "feature_2_online_store.png",
        "img_src": "file:///c:/FlexiTap/retail_online.png",
        "title_main": "Pop-Up Register by Day,",
        "title_accent": "Online Desk by Night",
        "subtitle": "Intake orders directly from Instagram & WhatsApp DMs, verify payment slips, and dispatch couriers.",
        "tl": {"icon": "share", "title": "Social DM Intake", "sub": "Instagram & WhatsApp orders", "tx": 385, "ty": 225},
        "bl": {"icon": "checkcircle", "title": "Payment Proof Check", "sub": "Verify GCash & Maya slips", "tx": 550, "ty": 480},
        "tr": {"icon": "truck", "title": "3-Lane Fulfillment", "sub": "Pack, ready & courier dispatch", "tx": 880, "ty": 225},
        "br": {"icon": "sync", "title": "Auto Stock Reserve", "sub": "Eliminate double-selling live", "tx": 880, "ty": 450}
    },
    {
        "id": "3",
        "file": "feature_3_services_booking.png",
        "img_src": "file:///c:/FlexiTap/Services.png",
        "title_main": "Integrated Timeline Booking",
        "title_accent": "& Staff Commission",
        "subtitle": "Manage daily appointment timelines, track booking statuses, and attribute therapist commissions.",
        "tl": {"icon": "calendar", "title": "Visual Staff Timeline", "sub": "Daily schedule across specialists", "tx": 400, "ty": 220},
        "bl": {"icon": "user", "title": "Timeline Check-In", "sub": "Schedule, check in & settle in 1 tap", "tx": 480, "ty": 480},
        "tr": {"icon": "sparkles", "title": "Suite & Room Routing", "sub": "Massage & nail room assignment", "tx": 880, "ty": 230},
        "br": {"icon": "dollar", "title": "Staff Commission", "sub": "Attributed per checkout ticket", "tx": 880, "ty": 490}
    },
    {
        "id": "4",
        "file": "feature_4_counter_dashboard.png",
        "img_src": "file:///c:/FlexiTap/dashboard.png",
        "title_main": "High-Speed Cashier Flow",
        "title_accent": "& Ticket Holding",
        "subtitle": "Rings orders up in milliseconds with quick-category tabs, instant barcode lookup, and check holding.",
        "tl": {"icon": "gauge", "title": "Ticket Holding", "sub": "Suspend & recall multi-guest tabs", "tx": 390, "ty": 220},
        "bl": {"icon": "lock", "title": "Quick Action Matrix", "sub": "No-Sale, Transfer, Split & Drawer", "tx": 390, "ty": 520},
        "tr": {"icon": "scan", "title": "Barcode & SKU Lookup", "sub": "Sub-millisecond item search", "tx": 850, "ty": 218},
        "br": {"icon": "grid", "title": "Fast Category Grid", "sub": "High-velocity touch screen keys", "tx": 850, "ty": 380}
    },
    {
        "id": "5",
        "file": "feature_5_customer_display.png",
        "img_src": "file:///c:/FlexiTap/cds.png",
        "title_main": "Customer-Facing Display",
        "title_accent": "& Loyalty QR",
        "subtitle": "Turn any secondary tablet toward your customer to stream active cart items, taxes, and loyalty sign-up.",
        "tl": {"icon": "eye", "title": "Branded Greeting", "sub": "Welcome screen, logo & store clock", "tx": 380, "ty": 420},
        "bl": {"icon": "qr", "title": "Loyalty QR Club", "sub": "Scan QR to join & save 10%", "tx": 550, "ty": 430},
        "tr": {"icon": "grid", "title": "Live Cart Broadcast", "sub": "Itemized order stream in real-time", "tx": 660, "ty": 340},
        "br": {"icon": "card", "title": "Transparent Total", "sub": "Subtotal, tax & grand total preview", "tx": 660, "ty": 520}
    },
    {
        "id": "6",
        "file": "feature_6_kitchen_kds.png",
        "img_src": "file:///c:/FlexiTap/kds.png",
        "title_main": "Dedicated Kitchen Display",
        "title_accent": "System (KDS)",
        "subtitle": "Replace lost paper tickets with clean digital prep screens, color cook timers, and station routing.",
        "tl": {"icon": "chef", "title": "Station Line Routing", "sub": "Separate Hot Bar, Grill & Drinks", "tx": 400, "ty": 220},
        "bl": {"icon": "clock", "title": "Color Cook Timers", "sub": "Visual alerts keep kitchen on pace", "tx": 420, "ty": 500},
        "tr": {"icon": "grid", "title": "Paperless Kitchen Flow", "sub": "Zero tickets lost, 100% digital", "tx": 840, "ty": 240},
        "br": {"icon": "check", "title": "One-Tap Bump Bar", "sub": "Clear dishes the instant ready", "tx": 840, "ty": 500}
    },
    {
        "id": "7",
        "file": "feature_7_digital_menuboard.png",
        "img_src": "file:///c:/FlexiTap/menuboard.png",
        "title_main": "Dynamic Digital Menu",
        "title_accent": "Boards (DMB)",
        "subtitle": "Mount any TV or screen overhead to broadcast live categories, real-time pricing, and promotional tickers.",
        "tl": {"icon": "tv", "title": "High-Impact Visuals", "sub": "High-res photos & category tabs", "tx": 400, "ty": 240},
        "bl": {"icon": "zap", "title": "Zero Cloud Subscriptions", "sub": "Direct LAN TV & HDMI broadcast", "tx": 400, "ty": 520},
        "tr": {"icon": "dollar", "title": "Live Price Updates", "sub": "Price changes sync immediately", "tx": 860, "ty": 240},
        "br": {"icon": "bell", "title": "Dynamic Promo Ticker", "sub": "Announce specials & ticker news", "tx": 860, "ty": 510}
    },
    {
        "id": "8",
        "file": "feature_8_order_status_osd.png",
        "img_src": "file:///c:/FlexiTap/osd.png",
        "title_main": "Live Order Status",
        "title_accent": "Display (OSD)",
        "subtitle": "Eliminate crowded pickup counters with real-time 'Preparing' and 'Now Serving' pickup columns.",
        "tl": {"icon": "clock", "title": "⏳ Preparing Queue", "sub": "Live orders cooking in kitchen", "tx": 430, "ty": 220},
        "bl": {"icon": "speaker", "title": "Zero Counter Congestion", "sub": "Guests relax until number calls", "tx": 430, "ty": 480},
        "tr": {"icon": "checkcircle", "title": "✓ Now Serving Board", "sub": "Bright green illuminated ready orders", "tx": 830, "ty": 220},
        "br": {"icon": "sync", "title": "Auto KDS Bump Sync", "sub": "Advances automatically from kitchen", "tx": 830, "ty": 480}
    },
    {
        "id": "9",
        "file": "feature_9_backoffice_reports.png",
        "img_src": "file:///c:/FlexiTap/backoffice.png",
        "title_main": "Executive Back Office",
        "title_accent": "Reports Hub",
        "subtitle": "Stay on top of store performance with comprehensive revenue trend curves, product mix, and audit exports.",
        "tl": {"icon": "chart", "title": "Executive KPI Summary", "sub": "Gross revenue, net sales & basket", "tx": 380, "ty": 385},
        "bl": {"icon": "gauge", "title": "Hourly Rush Curves", "sub": "Detect peak sales & rush hours", "tx": 420, "ty": 490},
        "tr": {"icon": "file", "title": "1-Click Report Export", "sub": "One-tap PDF & CSV audit export", "tx": 880, "ty": 260},
        "br": {"icon": "pie", "title": "Product Category Mix", "sub": "Visual revenue distribution donut", "tx": 600, "ty": 500}
    }
]

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>FlexiTap Graphic</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800;900&display=swap');
    
    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}

    body {{
      width: 1280px;
      height: 720px;
      overflow: hidden;
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: #f8fafc;
      position: relative;
    }}

    /* Ambient Soft Background */
    .bg-layer {{
      position: absolute;
      top: 0;
      left: 0;
      width: 1280px;
      height: 720px;
      pointer-events: none;
      z-index: 1;
    }}

    /* Centered Header */
    .header {{
      position: relative;
      z-index: 20;
      padding-top: 32px;
      text-align: center;
    }}

    .header h1 {{
      font-size: 38px;
      font-weight: 800;
      color: #0f172a;
      letter-spacing: -0.7px;
      line-height: 1.15;
    }}

    .header h1 span {{
      color: #059669;
    }}

    .header p {{
      font-size: 15px;
      color: #64748b;
      font-weight: 500;
      margin-top: 6px;
    }}

    /* Central Tablet Stage */
    .tablet-wrapper {{
      position: absolute;
      top: 146px;
      left: 50%;
      transform: translateX(-50%);
      width: 660px;
      height: 422px;
      z-index: 10;
    }}

    .tablet-device {{
      width: 100%;
      height: 100%;
      background: #0f172a;
      border-radius: 26px;
      padding: 9px;
      box-shadow: 
        0 25px 50px -12px rgba(15, 23, 42, 0.2),
        0 0 0 1px rgba(0, 0, 0, 0.08);
      position: relative;
    }}

    .tablet-camera {{
      position: absolute;
      top: 4px;
      left: 50%;
      transform: translateX(-50%);
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: #334155;
    }}

    .tablet-screen {{
      width: 100%;
      height: 100%;
      border-radius: 18px;
      overflow: hidden;
      background: #ffffff;
      position: relative;
    }}

    .tablet-screen img {{
      width: 100%;
      height: 100%;
      object-fit: fill;
      display: block;
    }}

    .tablet-shadow {{
      position: absolute;
      bottom: -16px;
      left: 5%;
      width: 90%;
      height: 28px;
      background: radial-gradient(ellipse at center, rgba(15, 23, 42, 0.22) 0%, rgba(15, 23, 42, 0) 70%);
      filter: blur(8px);
      z-index: 5;
    }}

    /* 4 Callout Cards - Strictly Aligned */
    .callout-card {{
      position: absolute;
      z-index: 25;
      background: #ffffff;
      border-radius: 18px;
      padding: 13px 18px;
      box-shadow: 
        0 12px 28px -4px rgba(15, 23, 42, 0.08),
        0 4px 6px -2px rgba(15, 23, 42, 0.02);
      border: 1px solid #edf2f7;
      display: flex;
      align-items: center;
      gap: 14px;
      width: 252px;
    }}

    .card-tl {{ left: 36px; top: 180px; }}
    .card-bl {{ left: 36px; top: 500px; }}
    .card-tr {{ right: 36px; top: 180px; }}
    .card-br {{ right: 36px; top: 500px; }}

    .card-icon {{
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: #d1fae5;
      color: #059669;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }}

    .card-icon svg {{
      width: 22px;
      height: 22px;
      stroke: currentColor;
      stroke-width: 2.2;
      stroke-linecap: round;
      stroke-linejoin: round;
      fill: none;
    }}

    .card-text {{
      flex: 1;
    }}

    .card-title {{
      font-size: 14px;
      font-weight: 700;
      color: #0f172a;
      line-height: 1.25;
      margin-bottom: 3px;
    }}

    .card-sub {{
      font-size: 11.5px;
      color: #64748b;
      font-weight: 500;
      line-height: 1.35;
    }}

    /* SVG Connecting Arrows */
    .arrows-svg {{
      position: absolute;
      top: 0;
      left: 0;
      width: 1280px;
      height: 720px;
      z-index: 35;
      pointer-events: none;
    }}
  </style>
</head>
<body>

  <!-- Ambient Light Background -->
  <svg class="bg-layer" viewBox="0 0 1280 720" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="100" cy="80" r="300" fill="url(#grad-tl)" opacity="0.55" />
    <circle cx="1180" cy="640" r="340" fill="url(#grad-br)" opacity="0.45" />

    <circle cx="90" cy="350" r="2.5" fill="#cbd5e1" /><circle cx="108" cy="350" r="2.5" fill="#cbd5e1" /><circle cx="126" cy="350" r="2.5" fill="#cbd5e1" />
    <circle cx="90" cy="368" r="2.5" fill="#cbd5e1" /><circle cx="108" cy="368" r="2.5" fill="#cbd5e1" /><circle cx="126" cy="368" r="2.5" fill="#cbd5e1" />
    <circle cx="1154" cy="350" r="2.5" fill="#cbd5e1" /><circle cx="1172" cy="350" r="2.5" fill="#cbd5e1" /><circle cx="1190" cy="350" r="2.5" fill="#cbd5e1" />
    <circle cx="1154" cy="368" r="2.5" fill="#cbd5e1" /><circle cx="1172" cy="368" r="2.5" fill="#cbd5e1" /><circle cx="1190" cy="368" r="2.5" fill="#cbd5e1" />

    <path d="M-20 260 C 120 220, 200 320, 290 300" stroke="#10b981" stroke-width="1.5" stroke-dasharray="4 8" opacity="0.25" />
    <path d="M990 410 C 1080 390, 1160 480, 1300 450" stroke="#10b981" stroke-width="1.5" stroke-dasharray="4 8" opacity="0.25" />

    <defs>
      <radialGradient id="grad-tl" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(100 80) rotate(90) scale(300)">
        <stop stop-color="#a7f3d0" />
        <stop offset="1" stop-color="#a7f3d0" stop-opacity="0" />
      </radialGradient>
      <radialGradient id="grad-br" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(1180 640) rotate(90) scale(340)">
        <stop stop-color="#bae6fd" />
        <stop offset="1" stop-color="#bae6fd" stop-opacity="0" />
      </radialGradient>
    </defs>
  </svg>

  <!-- Centered Header -->
  <div class="header">
    <h1>{title_main} <span>{title_accent}</span></h1>
    <p>{subtitle}</p>
  </div>

  <!-- Central Tablet Stage -->
  <div class="tablet-wrapper">
    <div class="tablet-device">
      <div class="tablet-camera"></div>
      <div class="tablet-screen">
        <img src="{img_src}" alt="{title_main} {title_accent}" />
      </div>
    </div>
    <div class="tablet-shadow"></div>
  </div>

  <!-- 4 Aligned Callout Cards -->
  <div class="callout-card card-tl">
    <div class="card-icon">{icon_tl}</div>
    <div class="card-text">
      <div class="card-title">{title_tl}</div>
      <div class="card-sub">{sub_tl}</div>
    </div>
  </div>

  <div class="callout-card card-bl">
    <div class="card-icon">{icon_bl}</div>
    <div class="card-text">
      <div class="card-title">{title_bl}</div>
      <div class="card-sub">{sub_bl}</div>
    </div>
  </div>

  <div class="callout-card card-tr">
    <div class="card-icon">{icon_tr}</div>
    <div class="card-text">
      <div class="card-title">{title_tr}</div>
      <div class="card-sub">{sub_tr}</div>
    </div>
  </div>

  <div class="callout-card card-br">
    <div class="card-icon">{icon_br}</div>
    <div class="card-text">
      <div class="card-title">{title_br}</div>
      <div class="card-sub">{sub_br}</div>
    </div>
  </div>

  <!-- SVG Connecting Arrows Pointing Directly to the Exact Screen Elements -->
  <svg class="arrows-svg" viewBox="0 0 1280 720">
    <defs>
      <marker id="arrowhead" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6.5" markerHeight="6.5" orient="auto-start-reverse">
        <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="#059669" />
      </marker>
    </defs>
    
    <!-- Top-Left: Card (288, 215) -> Target ({tl_tx}, {tl_ty}) -->
    <path d="M 288 215 C 320 215, {tl_c1x} {tl_ty}, {tl_tx} {tl_ty}" stroke="#059669" stroke-width="2.6" fill="none" stroke-linecap="round" marker-end="url(#arrowhead)" />

    <!-- Bottom-Left: Card (288, 535) -> Target ({bl_tx}, {bl_ty}) -->
    <path d="M 288 535 C 320 535, {bl_c1x} {bl_ty}, {bl_tx} {bl_ty}" stroke="#059669" stroke-width="2.6" fill="none" stroke-linecap="round" marker-end="url(#arrowhead)" />

    <!-- Top-Right: Card (992, 215) -> Target ({tr_tx}, {tr_ty}) -->
    <path d="M 992 215 C 920 215, {tr_c1x} {tr_ty}, {tr_tx} {tr_ty}" stroke="#059669" stroke-width="2.6" fill="none" stroke-linecap="round" marker-end="url(#arrowhead)" />

    <!-- Bottom-Right: Card (992, 535) -> Target ({br_tx}, {br_ty}) -->
    <path d="M 992 535 C 920 535, {br_c1x} {br_ty}, {br_tx} {br_ty}" stroke="#059669" stroke-width="2.6" fill="none" stroke-linecap="round" marker-end="url(#arrowhead)" />
  </svg>

</body>
</html>
"""

print(f"Generating all 9 layout-aligned social media graphics...")
for feat in FEATURES:
    # Compute smooth bezier control points based on target x
    tl_c1x = int(feat["tl"]["tx"] - 15)
    bl_c1x = int(feat["bl"]["tx"] - 15)
    tr_c1x = int(feat["tr"]["tx"] + 15)
    br_c1x = int(feat["br"]["tx"] + 15)

    html = HTML_TEMPLATE.format(
        title_main=feat["title_main"],
        title_accent=feat["title_accent"],
        subtitle=feat["subtitle"],
        img_src=feat["img_src"],
        icon_tl=ICONS[feat["tl"]["icon"]],
        title_tl=feat["tl"]["title"],
        sub_tl=feat["tl"]["sub"],
        tl_tx=feat["tl"]["tx"],
        tl_ty=feat["tl"]["ty"],
        tl_c1x=tl_c1x,
        icon_bl=ICONS[feat["bl"]["icon"]],
        title_bl=feat["bl"]["title"],
        sub_bl=feat["bl"]["sub"],
        bl_tx=feat["bl"]["tx"],
        bl_ty=feat["bl"]["ty"],
        bl_c1x=bl_c1x,
        icon_tr=ICONS[feat["tr"]["icon"]],
        title_tr=feat["tr"]["title"],
        sub_tr=feat["tr"]["sub"],
        tr_tx=feat["tr"]["tx"],
        tr_ty=feat["tr"]["ty"],
        tr_c1x=tr_c1x,
        icon_br=ICONS[feat["br"]["icon"]],
        title_br=feat["br"]["title"],
        sub_br=feat["br"]["sub"],
        br_tx=feat["br"]["tx"],
        br_ty=feat["br"]["ty"],
        br_c1x=br_c1x,
    )
    
    html_path = os.path.join(OUTPUT_DIR, f"template_{feat['id']}.html")
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)
        
    out_png = os.path.join(OUTPUT_DIR, feat["file"])
    cmd = [
        EDGE_EXE,
        "--headless=old",
        "--disable-gpu",
        "--hide-scrollbars",
        "--user-data-dir=" + os.path.expandvars(r"%TEMP%\edge_render_all_v2"),
        f"--screenshot={out_png}",
        "--window-size=1280,720",
        f"file:///{html_path.replace(os.sep, '/')}"
    ]
    subprocess.run(cmd, check=True)
    
    # Also copy to artifacts directory for inline markdown carousel/viewing
    artifact_png = os.path.join(ARTIFACT_DIR, feat["file"])
    if os.path.exists(out_png):
        with open(out_png, "rb") as src, open(artifact_png, "wb") as dst:
            dst.write(src.read())
        print(f"[{feat['id']}/9] Rendered: {feat['file']} ({os.path.getsize(out_png)} bytes)")

print("All 9 layout-aligned graphics generated successfully!")
