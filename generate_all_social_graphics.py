import os
import subprocess
import json

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
    "users": '<svg viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    "wifi": '<svg viewBox="0 0 24 24"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>',
    "eye": '<svg viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>',
    "heart": '<svg viewBox="0 0 24 24"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
    "qr": '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="5" y="5" width="3" height="3" fill="currentColor"/><rect x="16" y="5" width="3" height="3" fill="currentColor"/><rect x="5" y="16" width="3" height="3" fill="currentColor"/><path d="M14 14h3v3h-3zM17 17h4v4h-4zM14 20h3v1h-3zM20 14h1v3h-1z"/></svg>',
    "promo": '<svg viewBox="0 0 24 24"><path d="m3 11 18-5v12L3 13v-2z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/></svg>',
    "chef": '<svg viewBox="0 0 24 24"><path d="M6 13.8V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v9.8M6 13.8a4 4 0 0 0 4 3.8h4a4 4 0 0 0 4-3.8M6 13.8A4 4 0 0 1 3 10V8a2 2 0 0 1 2-2h1M18 13.8A4 4 0 0 0 21 10V8a2 2 0 0 0-2-2h-1M9 22h6"/></svg>',
    "clock": '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
    "check": '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>',
    "filter": '<svg viewBox="0 0 24 24"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>',
    "tv": '<svg viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"/><polyline points="17 2 12 7 7 2"/></svg>',
    "zap": '<svg viewBox="0 0 24 24"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
    "ban": '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>',
    "sun": '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>',
    "columns": '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="8" height="18" rx="1"/><rect x="13" y="3" width="8" height="18" rx="1"/></svg>',
    "volume": '<svg viewBox="0 0 24 24"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"/></svg>',
    "coffee": '<svg viewBox="0 0 24 24"><path d="M18 8h1a4 4 0 0 1 0 8h-1M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>',
    "chart": '<svg viewBox="0 0 24 24"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>',
    "box": '<svg viewBox="0 0 24 24"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>',
    "pie": '<svg viewBox="0 0 24 24"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>',
    "file": '<svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>',
}

FEATURES = [
    {
        "id": "1",
        "file": "feature_1_retail_checkout.png",
        "img_src": "file:///c:/FlexiTap/Retail.png",
        "title_main": "Fast & Resilient",
        "title_accent": "Retail Checkout",
        "subtitle": "Sub-second barcode scanning, quick keys, and uninterrupted offline transaction processing.",
        "tl": {"icon": "scan", "title": "Instant Barcode Scan", "sub": "USB & camera lookups in <15ms"},
        "bl": {"icon": "shield", "title": "100% Offline Mode", "sub": "Keep selling when Wi-Fi drops"},
        "tr": {"icon": "grid", "title": "Quick-Key Catalog", "sub": "Color categories & fast search"},
        "br": {"icon": "card", "title": "Flexible Payments", "sub": "Cash, card, split & QR wallets"}
    },
    {
        "id": "2",
        "file": "feature_2_online_store.png",
        "img_src": "file:///c:/FlexiTap/retail_online.png",
        "title_main": "24/7 Omnichannel",
        "title_accent": "Online Storefront",
        "subtitle": "Sync your counter inventory automatically with a branded web store and social ordering.",
        "tl": {"icon": "globe", "title": "Branded Web Store", "sub": "Mobile-first online customer ordering"},
        "bl": {"icon": "sync", "title": "Auto Stock Sync", "sub": "Deduct stock across all channels"},
        "tr": {"icon": "share", "title": "Social Store Link", "sub": "Sell on Instagram, TikTok & chat"},
        "br": {"icon": "bell", "title": "Live Order Alerts", "sub": "Audio & visual alerts on counter POS"}
    },
    {
        "id": "3",
        "file": "feature_3_services_booking.png",
        "img_src": "file:///c:/FlexiTap/Services.png",
        "title_main": "Seamless Scheduling &",
        "title_accent": "Service Checkout",
        "subtitle": "Manage staff calendars, walk-in appointments, and retail add-ons in one unified screen.",
        "tl": {"icon": "calendar", "title": "Visual Staff Timeline", "sub": "Drag-and-drop bookings across staff"},
        "bl": {"icon": "user", "title": "Client Profiles", "sub": "Visit history, preferences & notes"},
        "tr": {"icon": "sparkles", "title": "Service Add-Ons", "sub": "Upsell treatments & retail products"},
        "br": {"icon": "dollar", "title": "Tip & Commission Pay", "sub": "Automated staff payout & split tips"}
    },
    {
        "id": "4",
        "file": "feature_4_counter_dashboard.png",
        "img_src": "file:///c:/FlexiTap/dashboard.png",
        "title_main": "All-in-One Live",
        "title_accent": "Counter Dashboard",
        "subtitle": "High-velocity register overview with shift tracking, cash drawer balancing, and terminal status.",
        "tl": {"icon": "gauge", "title": "Real-Time Register", "sub": "Live shift sales & transaction counter"},
        "bl": {"icon": "lock", "title": "Cash Drawer Audit", "sub": "Blind drops & end-of-day X/Z reports"},
        "tr": {"icon": "users", "title": "Fast Cashier Switch", "sub": "4-digit PIN for instant operator lock"},
        "br": {"icon": "wifi", "title": "Hybrid Cloud Sync", "sub": "Local SQLite speed with cloud backup"}
    },
    {
        "id": "5",
        "file": "feature_5_customer_display.png",
        "img_src": "file:///c:/FlexiTap/cds.png",
        "title_main": "Transparent & Modern",
        "title_accent": "Customer Display",
        "subtitle": "Turn any secondary tablet into a customer-facing screen for item review, tipping, and QR payment.",
        "tl": {"icon": "eye", "title": "Itemized Bill View", "sub": "Guests watch items tally in real-time"},
        "bl": {"icon": "heart", "title": "Interactive Tipping", "sub": "One-tap percentage tips boost income"},
        "tr": {"icon": "qr", "title": "Dynamic QR Payment", "sub": "Instant scan for digital wallets & cards"},
        "br": {"icon": "promo", "title": "Idle Promo Slides", "sub": "Showcase seasonal specials when idle"}
    },
    {
        "id": "6",
        "file": "feature_6_kitchen_kds.png",
        "img_src": "file:///c:/FlexiTap/kds.png",
        "title_main": "Paperless & Rapid",
        "title_accent": "Kitchen Display (KDS)",
        "subtitle": "Replace lost paper tickets with digital order routing, color cook timers, and bump bar control.",
        "tl": {"icon": "chef", "title": "Instant Ticket Routing", "sub": "Orders beam to kitchen in under 50ms"},
        "bl": {"icon": "clock", "title": "Color Cook Timers", "sub": "Green, amber, & red delay alerts"},
        "tr": {"icon": "check", "title": "One-Tap Bump Bar", "sub": "Clear ready dishes or recall orders"},
        "br": {"icon": "filter", "title": "Station Filtering", "sub": "Separate bar, grill, and prep tickets"}
    },
    {
        "id": "7",
        "file": "feature_7_digital_menuboard.png",
        "img_src": "file:///c:/FlexiTap/menuboard.png",
        "title_main": "Dynamic & Vibrant",
        "title_accent": "Digital Menu Board",
        "subtitle": "Turn any smart TV or monitor into a high-impact menu that updates prices and specials in real-time.",
        "tl": {"icon": "tv", "title": "Full HD & 4K Display", "sub": "Crisp typography & high-res imagery"},
        "bl": {"icon": "zap", "title": "Live Price Updates", "sub": "Change price on POS; board syncs now"},
        "tr": {"icon": "ban", "title": "Automatic 86 / Sold Out", "sub": "Depleted items automatically grey out"},
        "br": {"icon": "sun", "title": "Dayparting Menus", "sub": "Auto-switch breakfast, lunch & happy hour"}
    },
    {
        "id": "8",
        "file": "feature_8_order_status_osd.png",
        "img_src": "file:///c:/FlexiTap/osd.png",
        "title_main": "Organized & Clear",
        "title_accent": "Order Status Screen",
        "subtitle": "Streamline customer pickups and waiting areas with real-time 'Preparing' and 'Ready' columns.",
        "tl": {"icon": "columns", "title": "Dual Status Columns", "sub": "Clear Preparing and Ready sections"},
        "bl": {"icon": "volume", "title": "Audio Chime Callout", "sub": "Subtle chime when order number is ready"},
        "tr": {"icon": "coffee", "title": "Zero Counter Crowds", "sub": "Guests relax until their number calls"},
        "br": {"icon": "sync", "title": "Zero Manual Effort", "sub": "Updates instantly when kitchen bumps"}
    },
    {
        "id": "9",
        "file": "feature_9_backoffice_reports.png",
        "img_src": "file:///c:/FlexiTap/backoffice.png",
        "title_main": "Comprehensive & Actionable",
        "title_accent": "Back Office Analytics",
        "subtitle": "Deep dive into profit margins, ingredient depletion, hourly sales trends, and tax exports.",
        "tl": {"icon": "chart", "title": "Real-Time Revenue", "sub": "Hourly velocity, net sales & basket size"},
        "bl": {"icon": "box", "title": "Ingredient Tracking", "sub": "Low-stock reorder thresholds & waste"},
        "tr": {"icon": "pie", "title": "Product Mix & Margin", "sub": "Spot bestsellers vs high-cost dishes"},
        "br": {"icon": "file", "title": "1-Click Tax Export", "sub": "Ready-to-file CSV & accounting exports"}
    }
]

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>FlexiTap Graphic</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@500;700&display=swap');
    
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
      background: #06080e;
      color: #ffffff;
      position: relative;
    }}

    /* Dramatic Studio Lighting */
    .spotlight-center {{
      position: absolute;
      top: -120px;
      left: 50%;
      transform: translateX(-50%);
      width: 950px;
      height: 560px;
      background: radial-gradient(ellipse at center, rgba(37, 99, 235, 0.16) 0%, rgba(16, 185, 129, 0.13) 45%, rgba(6, 8, 14, 0) 70%);
      filter: blur(55px);
      z-index: 1;
      pointer-events: none;
    }}

    .spotlight-bottom {{
      position: absolute;
      bottom: -160px;
      left: 50%;
      transform: translateX(-50%);
      width: 1100px;
      height: 420px;
      background: radial-gradient(ellipse at center, rgba(16, 185, 129, 0.18) 0%, rgba(6, 8, 14, 0) 70%);
      filter: blur(65px);
      z-index: 1;
      pointer-events: none;
    }}

    /* Subtle Technical Cyber-Grid */
    .cyber-grid {{
      position: absolute;
      top: 0;
      left: 0;
      width: 1280px;
      height: 720px;
      background-image: 
        linear-gradient(to right, rgba(255, 255, 255, 0.04) 1px, transparent 1px),
        linear-gradient(to bottom, rgba(255, 255, 255, 0.04) 1px, transparent 1px);
      background-size: 38px 38px;
      mask-image: radial-gradient(circle at 50% 40%, rgba(0, 0, 0, 0.75) 30%, transparent 80%);
      -webkit-mask-image: radial-gradient(circle at 50% 40%, rgba(0, 0, 0, 0.75) 30%, transparent 80%);
      z-index: 2;
      pointer-events: none;
    }}

    /* Top Brand Bar */
    .top-brand-bar {{
      position: absolute;
      top: 22px;
      left: 42px;
      right: 42px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 30;
    }}

    .brand-logo-pill {{
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 6px 14px 6px 8px;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 30px;
      backdrop-filter: blur(12px);
    }}

    .brand-logo-pill img {{
      width: 22px;
      height: 22px;
      border-radius: 50%;
    }}

    .brand-logo-pill span {{
      font-size: 13px;
      font-weight: 800;
      letter-spacing: -0.2px;
      color: #ffffff;
    }}

    .top-meta-badge {{
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      color: #10b981;
      background: rgba(16, 185, 129, 0.1);
      border: 1px solid rgba(16, 185, 129, 0.3);
      padding: 5px 12px;
      border-radius: 20px;
      letter-spacing: 0.5px;
      font-weight: 600;
    }}

    /* Hero Typography */
    .hero-header {{
      position: relative;
      z-index: 20;
      padding-top: 56px;
      text-align: center;
    }}

    .hero-header h1 {{
      font-size: 38px;
      font-weight: 900;
      letter-spacing: -0.8px;
      line-height: 1.15;
    }}

    .hero-header h1 .accent-gradient {{
      background: linear-gradient(135deg, #34d399 0%, #10b981 50%, #38bdf8 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }}

    .hero-header p {{
      font-size: 14.5px;
      color: #94a3b8;
      font-weight: 500;
      margin-top: 7px;
      max-width: 780px;
      margin-left: auto;
      margin-right: auto;
    }}

    /* Floating Tablet Stage */
    .stage-container {{
      position: absolute;
      top: 172px;
      left: 50%;
      transform: translateX(-50%);
      width: 650px;
      height: 442px;
      z-index: 10;
    }}

    .tablet-glow-backing {{
      position: absolute;
      top: -15px;
      left: -15px;
      right: -15px;
      bottom: -15px;
      background: linear-gradient(135deg, rgba(16, 185, 129, 0.3) 0%, rgba(59, 130, 246, 0.3) 100%);
      border-radius: 36px;
      filter: blur(24px);
      opacity: 0.65;
      z-index: 1;
    }}

    .tablet-chassis {{
      position: relative;
      width: 100%;
      height: 100%;
      background: linear-gradient(145deg, #1e293b, #090d16);
      border-radius: 28px;
      padding: 10px;
      border: 1px solid rgba(255, 255, 255, 0.18);
      box-shadow: 
        0 35px 80px -15px rgba(0, 0, 0, 0.8),
        0 0 0 1px rgba(255, 255, 255, 0.08) inset;
      z-index: 2;
    }}

    .tablet-camera-notch {{
      position: absolute;
      top: 5px;
      left: 50%;
      transform: translateX(-50%);
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: #475569;
    }}

    .tablet-screen {{
      width: 100%;
      height: 100%;
      border-radius: 20px;
      overflow: hidden;
      background: #000000;
      position: relative;
    }}

    .tablet-screen img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }}

    .screen-gloss {{
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 48%;
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.07) 0%, rgba(255, 255, 255, 0) 100%);
      pointer-events: none;
      z-index: 5;
    }}

    .tablet-home-bar {{
      position: absolute;
      bottom: 6px;
      left: 50%;
      transform: translateX(-50%);
      width: 90px;
      height: 3px;
      border-radius: 2px;
      background: rgba(255, 255, 255, 0.7);
      z-index: 6;
    }}

    /* Reflective Floor */
    .reflective-floor {{
      position: absolute;
      bottom: 25px;
      left: 50%;
      transform: translateX(-50%);
      width: 600px;
      height: 30px;
      background: radial-gradient(ellipse at center, rgba(16, 185, 129, 0.35) 0%, rgba(0,0,0,0) 70%);
      filter: blur(14px);
      z-index: 4;
    }}

    /* Dark Glassmorphic Feature Cards */
    .feature-card {{
      position: absolute;
      z-index: 25;
      background: rgba(15, 23, 42, 0.78);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 18px;
      padding: 12px 15px;
      box-shadow: 
        0 20px 40px -10px rgba(0, 0, 0, 0.7),
        0 0 0 1px rgba(255, 255, 255, 0.05) inset;
      backdrop-filter: blur(20px);
      display: flex;
      align-items: center;
      gap: 12px;
      width: 236px;
    }}

    .card-tl {{ left: 32px; top: 195px; }}
    .card-bl {{ left: 32px; top: 510px; }}
    .card-tr {{ right: 32px; top: 195px; }}
    .card-br {{ right: 32px; top: 510px; }}

    .card-icon {{
      width: 44px;
      height: 44px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      position: relative;
    }}

    .card-tl .card-icon, .card-bl .card-icon {{
      background: linear-gradient(135deg, rgba(16, 185, 129, 0.25) 0%, rgba(5, 150, 105, 0.15) 100%);
      border: 1px solid rgba(16, 185, 129, 0.4);
      color: #34d399;
      box-shadow: 0 0 15px rgba(16, 185, 129, 0.2);
    }}

    .card-tr .card-icon, .card-br .card-icon {{
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.25) 0%, rgba(37, 99, 235, 0.15) 100%);
      border: 1px solid rgba(59, 130, 246, 0.4);
      color: #60a5fa;
      box-shadow: 0 0 15px rgba(59, 130, 246, 0.2);
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
      font-size: 13.5px;
      font-weight: 800;
      color: #ffffff;
      line-height: 1.25;
      margin-bottom: 3px;
      letter-spacing: -0.2px;
    }}

    .card-sub {{
      font-size: 11px;
      color: #94a3b8;
      font-weight: 500;
      line-height: 1.35;
    }}

    /* Laser Connecting Paths */
    .laser-layer {{
      position: absolute;
      top: 0;
      left: 0;
      width: 1280px;
      height: 720px;
      z-index: 22;
      pointer-events: none;
    }}

    /* Footer Meta */
    .footer-bar {{
      position: absolute;
      bottom: 22px;
      left: 42px;
      right: 42px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 30;
      font-size: 12px;
      color: #64748b;
      font-weight: 600;
    }}

    .footer-url {{
      color: #10b981;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 6px;
    }}
  </style>
</head>
<body>

  <!-- Studio Lighting -->
  <div class="spotlight-center"></div>
  <div class="spotlight-bottom"></div>
  <div class="cyber-grid"></div>

  <!-- Top Brand Navigation Bar -->
  <div class="top-brand-bar">
    <div class="brand-logo-pill">
      <img src="file:///c:/FlexiTap/image_02e503.png" alt="Logo" />
      <span>FlexiTap POS</span>
    </div>
    <div class="top-meta-badge">
      ⚡ 100% OFFLINE RESILIENT • SUB-15MS
    </div>
  </div>

  <!-- Hero Header -->
  <div class="hero-header">
    <h1>{title_main} <span class="accent-gradient">{title_accent}</span></h1>
    <p>{subtitle}</p>
  </div>

  <!-- Center Floating Tablet Stage -->
  <div class="stage-container">
    <div class="tablet-glow-backing"></div>
    <div class="tablet-chassis">
      <div class="tablet-camera-notch"></div>
      <div class="tablet-screen">
        <img src="{img_src}" alt="{title_main} {title_accent}" />
        <div class="screen-gloss"></div>
        <div class="tablet-home-bar"></div>
      </div>
    </div>
  </div>
  <div class="reflective-floor"></div>

  <!-- 4 Dark Glassmorphic Feature Cards -->
  <div class="feature-card card-tl">
    <div class="card-icon">{icon_tl}</div>
    <div class="card-text">
      <div class="card-title">{title_tl}</div>
      <div class="card-sub">{sub_tl}</div>
    </div>
  </div>

  <div class="feature-card card-bl">
    <div class="card-icon">{icon_bl}</div>
    <div class="card-text">
      <div class="card-title">{title_bl}</div>
      <div class="card-sub">{sub_bl}</div>
    </div>
  </div>

  <div class="feature-card card-tr">
    <div class="card-icon">{icon_tr}</div>
    <div class="card-text">
      <div class="card-title">{title_tr}</div>
      <div class="card-sub">{sub_tr}</div>
    </div>
  </div>

  <div class="feature-card card-br">
    <div class="card-icon">{icon_br}</div>
    <div class="card-text">
      <div class="card-title">{title_br}</div>
      <div class="card-sub">{sub_br}</div>
    </div>
  </div>

  <!-- Glowing Laser Guide Connectors -->
  <svg class="laser-layer" viewBox="0 0 1280 720">
    <defs>
      <linearGradient id="laser-green" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#10b981" />
        <stop offset="100%" stop-color="#34d399" />
      </linearGradient>
      <linearGradient id="laser-blue" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#3b82f6" />
        <stop offset="100%" stop-color="#60a5fa" />
      </linearGradient>
      <filter id="laser-glow" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="3" result="glow" />
        <feComposite in="SourceGraphic" in2="glow" operator="over" />
      </filter>
    </defs>
    
    <!-- Top-Left Laser: Card is 32 to 268 (center y=228), Tablet left is 315 -->
    <circle cx="270" cy="230" r="3.5" fill="#34d399" />
    <path d="M 270 230 C 298 245, 290 275, 312 295" stroke="url(#laser-green)" stroke-width="2.5" fill="none" stroke-linecap="round" filter="url(#laser-glow)" />
    <circle cx="312" cy="295" r="3.5" fill="#34d399" />

    <!-- Bottom-Left Laser: Card center y=543, Tablet left is 315 -->
    <circle cx="270" cy="540" r="3.5" fill="#34d399" />
    <path d="M 270 540 C 298 525, 290 495, 312 475" stroke="url(#laser-green)" stroke-width="2.5" fill="none" stroke-linecap="round" filter="url(#laser-glow)" />
    <circle cx="312" cy="475" r="3.5" fill="#34d399" />

    <!-- Top-Right Laser: Card is 1012 to 1248 (center y=228), Tablet right is 965 -->
    <circle cx="1010" cy="230" r="3.5" fill="#60a5fa" />
    <path d="M 1010 230 C 982 245, 990 275, 968 295" stroke="url(#laser-blue)" stroke-width="2.5" fill="none" stroke-linecap="round" filter="url(#laser-blue)" />
    <circle cx="968" cy="295" r="3.5" fill="#60a5fa" />

    <!-- Bottom-Right Laser: Card center y=543, Tablet right is 965 -->
    <circle cx="1010" cy="540" r="3.5" fill="#60a5fa" />
    <path d="M 1010 540 C 982 525, 990 495, 968 475" stroke="url(#laser-blue)" stroke-width="2.5" fill="none" stroke-linecap="round" filter="url(#laser-blue)" />
    <circle cx="968" cy="475" r="3.5" fill="#60a5fa" />
  </svg>

  <!-- Footer Branding -->
  <div class="footer-bar">
    <div>Hardware Agnostic • Bring Your Own Android, iOS, or Windows Device</div>
    <div class="footer-url">
      <span>flexitapapp.com</span>
      <span>•</span>
      <span>Zero Monthly Hardware Leases</span>
    </div>
  </div>

</body>
</html>
"""

print(f"Generating all 9 reimagined social media graphics...")
for feat in FEATURES:
    html = HTML_TEMPLATE.format(
        title_main=feat["title_main"],
        title_accent=feat["title_accent"],
        subtitle=feat["subtitle"],
        img_src=feat["img_src"],
        icon_tl=ICONS[feat["tl"]["icon"]],
        title_tl=feat["tl"]["title"],
        sub_tl=feat["tl"]["sub"],
        icon_bl=ICONS[feat["bl"]["icon"]],
        title_bl=feat["bl"]["title"],
        sub_bl=feat["bl"]["sub"],
        icon_tr=ICONS[feat["tr"]["icon"]],
        title_tr=feat["tr"]["title"],
        sub_tr=feat["tr"]["sub"],
        icon_br=ICONS[feat["br"]["icon"]],
        title_br=feat["br"]["title"],
        sub_br=feat["br"]["sub"],
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
        "--user-data-dir=" + os.path.expandvars(r"%TEMP%\edge_render_all"),
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

print("All 9 reimagined graphics generated successfully!")
