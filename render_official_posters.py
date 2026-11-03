import os
import subprocess

html_poster1 = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>FlexiTap Poster 1 - Outage Resilience</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800;900&family=JetBrains+Mono:wght@600;700&display=swap');
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 1080px; height: 1920px; overflow: hidden;
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: #f8fafc; position: relative;
    }
    .ambient-glow-top {
      position: absolute; top: -200px; left: 50%; transform: translateX(-50%);
      width: 1200px; height: 700px;
      background: radial-gradient(ellipse at center, rgba(16, 185, 129, 0.12) 0%, rgba(37, 99, 235, 0.08) 50%, rgba(248, 250, 252, 0) 70%);
      filter: blur(60px); pointer-events: none;
    }
    .top-header { position: relative; z-index: 20; padding-top: 70px; text-align: center; }
    .brand-logo-lockup {
      display: inline-flex; align-items: center; gap: 16px;
      padding: 10px 24px; background: #ffffff; border-radius: 40px;
      box-shadow: 0 10px 30px -5px rgba(15, 23, 42, 0.08), 0 0 0 1px #e2e8f0; margin-bottom: 36px;
    }
    .brand-logo-lockup img { width: 48px; height: 48px; border-radius: 50%; display: block; }
    .brand-logo-text { font-size: 28px; font-weight: 900; color: #0f172a; letter-spacing: -0.5px; display: flex; align-items: center; gap: 8px; }
    .brand-logo-text span { font-size: 14px; font-weight: 800; color: #ffffff; background: #059669; padding: 4px 10px; border-radius: 8px; }
    .headline-container { max-width: 960px; margin: 0 auto; padding: 0 40px; }
    .headline-container h1 { font-size: 68px; font-weight: 900; color: #0f172a; line-height: 1.12; letter-spacing: -1.5px; }
    .headline-container h1 .accent { color: #059669; }
    .headline-container p { font-size: 25px; color: #64748b; font-weight: 500; margin-top: 18px; line-height: 1.4; }
    .stage-wrapper { position: absolute; top: 510px; left: 0; right: 0; height: 1220px; z-index: 10; }
    .phone-mockup {
      position: absolute; left: 65px; top: 30px; width: 480px; height: 990px;
      background: #0f172a; border-radius: 54px; padding: 14px;
      box-shadow: 0 40px 80px -15px rgba(15, 23, 42, 0.28), 0 0 0 2px rgba(255, 255, 255, 0.1) inset;
    }
    .phone-island { position: absolute; top: 24px; left: 50%; transform: translateX(-50%); width: 120px; height: 28px; border-radius: 20px; background: #000000; z-index: 30; }
    .phone-screen { width: 100%; height: 100%; border-radius: 42px; overflow: hidden; background: #ffffff; position: relative; }
    .app-header { padding: 44px 20px 14px 20px; background: #ffffff; border-bottom: 1px solid #f1f5f9; display: flex; justify-content: space-between; align-items: center; }
    .app-brand { display: flex; align-items: center; gap: 8px; font-size: 16px; font-weight: 800; color: #0f172a; }
    .app-brand img { width: 24px; height: 24px; }
    .app-status-pill { font-size: 10.5px; font-weight: 700; color: #059669; background: #d1fae5; padding: 4px 10px; border-radius: 12px; display: flex; align-items: center; gap: 5px; }
    .app-status-dot { width: 6px; height: 6px; border-radius: 50%; background: #059669; }
    .app-search { padding: 12px 18px; background: #f8fafc; border-bottom: 1px solid #edf2f7; }
    .app-search-box { background: #ffffff; border: 1px solid #cbd5e1; border-radius: 10px; padding: 9px 14px; font-size: 12.5px; color: #94a3b8; display: flex; align-items: center; justify-content: space-between; }
    .app-category-bar { display: flex; gap: 8px; padding: 10px 18px; background: #ffffff; overflow: hidden; }
    .app-cat-pill { font-size: 11px; font-weight: 700; padding: 6px 14px; border-radius: 16px; background: #f1f5f9; color: #64748b; }
    .app-cat-pill.active { background: #0f172a; color: #ffffff; }
    .app-grid { padding: 12px 18px; display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .app-card { background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 10px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.04); position: relative; }
    .app-card-title { font-size: 13px; font-weight: 700; color: #0f172a; margin-top: 8px; }
    .app-card-price { font-size: 13.5px; font-weight: 800; color: #059669; margin-top: 3px; }
    .app-card-badge { position: absolute; top: 16px; right: 16px; background: rgba(16, 185, 129, 0.9); color: #ffffff; font-size: 9px; font-weight: 700; padding: 2px 7px; border-radius: 8px; }
    .app-bottom-cart { position: absolute; bottom: 0; left: 0; right: 0; background: #ffffff; border-top: 1px solid #e2e8f0; padding: 16px 20px; display: flex; justify-content: space-between; align-items: center; }
    .app-cart-total { font-size: 11px; color: #64748b; font-weight: 600; }
    .app-cart-total strong { display: block; font-size: 18px; color: #0f172a; font-weight: 800; }
    .app-charge-btn { background: #059669; color: #ffffff; font-size: 13px; font-weight: 800; padding: 12px 24px; border-radius: 12px; }
    .features-column { position: absolute; left: 585px; top: 30px; width: 435px; display: flex; flex-direction: column; gap: 18px; }
    .feat-card {
      background: #ffffff; border-radius: 20px; padding: 18px 22px;
      box-shadow: 0 14px 30px -4px rgba(15, 23, 42, 0.08), 0 4px 8px -2px rgba(15, 23, 42, 0.02);
      border: 1px solid #e2e8f0; display: flex; align-items: center; gap: 18px;
    }
    .feat-icon-box { width: 56px; height: 56px; border-radius: 16px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
    .icon-green { background: #d1fae5; color: #059669; }
    .icon-blue { background: #e0f2fe; color: #0284c7; }
    .icon-amber { background: #fef3c7; color: #d97706; }
    .icon-purple { background: #ede9fe; color: #7c3aed; }
    .icon-rose { background: #ffe4e6; color: #e11d48; }
    .feat-icon-box svg { width: 28px; height: 28px; stroke: currentColor; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round; fill: none; }
    .feat-text-box { flex: 1; }
    .feat-title { font-size: 18px; font-weight: 800; color: #0f172a; line-height: 1.25; margin-bottom: 4px; letter-spacing: -0.2px; }
    .feat-sub { font-size: 13.5px; color: #64748b; font-weight: 500; line-height: 1.35; }
    .bottom-cta-container { position: absolute; bottom: 65px; left: 65px; right: 65px; z-index: 30; }
    .bottom-cta-banner {
      background: linear-gradient(135deg, #059669 0%, #10b981 100%);
      border-radius: 28px; padding: 22px 36px; display: flex; justify-content: space-between; align-items: center;
      box-shadow: 0 20px 45px -10px rgba(5, 150, 105, 0.38); color: #ffffff;
    }
    .bottom-cta-left { display: flex; align-items: center; gap: 18px; }
    .bottom-cta-icon { width: 48px; height: 48px; border-radius: 50%; background: rgba(255, 255, 255, 0.2); display: flex; align-items: center; justify-content: center; font-size: 24px; }
    .bottom-cta-title { font-size: 24px; font-weight: 900; letter-spacing: -0.4px; }
    .bottom-cta-sub { font-size: 14px; opacity: 0.9; font-weight: 500; }
    .bottom-cta-url { background: #ffffff; color: #059669; font-size: 16px; font-weight: 800; padding: 12px 28px; border-radius: 16px; box-shadow: 0 4px 10px rgba(0, 0, 0, 0.08); }
  </style>
</head>
<body>
  <div class="ambient-glow-top"></div>
  <div class="top-header">
    <div class="brand-logo-lockup">
      <img src="file:///c:/FlexiTap/image_02e503.png" alt="FlexiTap Logo" />
      <div class="brand-logo-text">FlexiTap <span>POINT OF SALE</span></div>
    </div>
    <div class="headline-container">
      <h1>When the Wi-Fi Drops, <span class="accent">Your Sales Don't.</span></h1>
      <p>The offline-first mobile POS built for independent cafes, food pop-ups, and resilient retail counters.</p>
    </div>
  </div>
  <div class="stage-wrapper">
    <div class="phone-mockup">
      <div class="phone-island"></div>
      <div class="phone-screen">
        <div class="app-header">
          <div class="app-brand"><img src="file:///c:/FlexiTap/image_02e503.png" alt="Logo" /> FlexiTap Mobile</div>
          <div class="app-status-pill"><span class="app-status-dot"></span> 100% Offline Active</div>
        </div>
        <div class="app-search">
          <div class="app-search-box"><span>🔍 Search item or scan barcode...</span><span>📷</span></div>
        </div>
        <div class="app-category-bar">
          <div class="app-cat-pill active">All Items</div>
          <div class="app-cat-pill">Coffee &amp; Tea</div>
          <div class="app-cat-pill">Pastries</div>
          <div class="app-cat-pill">Retail</div>
        </div>
        <div class="app-grid">
          <div class="app-card">
            <div class="app-card-badge">Stock: 45</div>
            <div style="font-size: 38px; text-align: center; padding: 12px 0;">☕</div>
            <div class="app-card-title">Caramel Macchiato</div>
            <div class="app-card-price">$4.75</div>
          </div>
          <div class="app-card">
            <div class="app-card-badge">Stock: 28</div>
            <div style="font-size: 38px; text-align: center; padding: 12px 0;">🥐</div>
            <div class="app-card-title">Almond Croissant</div>
            <div class="app-card-price">$3.50</div>
          </div>
          <div class="app-card">
            <div class="app-card-badge">Stock: 60</div>
            <div style="font-size: 38px; text-align: center; padding: 12px 0;">🥪</div>
            <div class="app-card-title">Avocado Toast Melt</div>
            <div class="app-card-price">$7.25</div>
          </div>
          <div class="app-card">
            <div class="app-card-badge">Stock: 15</div>
            <div style="font-size: 38px; text-align: center; padding: 12px 0;">👕</div>
            <div class="app-card-title">Signature T-Shirt</div>
            <div class="app-card-price">$19.99</div>
          </div>
        </div>
        <div class="app-bottom-cart">
          <div class="app-cart-total">Current Order (3 items)<strong>$15.50</strong></div>
          <div class="app-charge-btn">Charge Tender &rarr;</div>
        </div>
      </div>
    </div>
    <div class="features-column">
      <div class="feat-card">
        <div class="feat-icon-box icon-green"><svg viewBox="0 0 24 24"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Sub-15ms Local Writes</div>
          <div class="feat-sub">Local SQLite architecture executes checkout instantaneously with zero cloud latency.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-blue"><svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">100% Offline Resilience</div>
          <div class="feat-sub">Keep ringing up customers, taking cash, and printing receipts even during total internet blackouts.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-amber"><svg viewBox="0 0 24 24"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Bring Your Own Device (BYOD)</div>
          <div class="feat-sub">Run on any iPhone, iPad, Android phone, or Windows PC without buying costly proprietary hardware.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-purple"><svg viewBox="0 0 24 24"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Universal Thermal Printing</div>
          <div class="feat-sub">Native ESC/POS support over Bluetooth, USB, and LAN for instant customer receipts and kitchen tickets.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-rose"><svg viewBox="0 0 24 24"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Zero Terminal Lease Fees</div>
          <div class="feat-sub">No predatory $79/mo hardware leases or hidden processing lock-ins. Free offline local forever.</div>
        </div>
      </div>
    </div>
  </div>
  <div class="bottom-cta-container">
    <div class="bottom-cta-banner">
      <div class="bottom-cta-left">
        <div class="bottom-cta-icon">🛡️</div>
        <div>
          <div class="bottom-cta-title">7-Day Live Shift Money-Back Guarantee</div>
          <div class="bottom-cta-sub">Test it on your real counter. Zero risk. Full offline autonomy.</div>
        </div>
      </div>
      <div class="bottom-cta-url">Get Started Free &rarr;</div>
    </div>
  </div>
</body>
</html>
"""

html_poster2 = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>FlexiTap Poster 2 - Real-Time Analytics</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800;900&family=JetBrains+Mono:wght@600;700&display=swap');
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      width: 1080px; height: 1920px; overflow: hidden;
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: #f8fafc; position: relative;
    }
    .ambient-glow-top {
      position: absolute; top: -200px; left: 50%; transform: translateX(-50%);
      width: 1200px; height: 700px;
      background: radial-gradient(ellipse at center, rgba(37, 99, 235, 0.12) 0%, rgba(16, 185, 129, 0.08) 50%, rgba(248, 250, 252, 0) 70%);
      filter: blur(60px); pointer-events: none;
    }
    .top-header { position: relative; z-index: 20; padding-top: 70px; text-align: center; }
    .brand-logo-lockup {
      display: inline-flex; align-items: center; gap: 16px;
      padding: 10px 24px; background: #ffffff; border-radius: 40px;
      box-shadow: 0 10px 30px -5px rgba(15, 23, 42, 0.08), 0 0 0 1px #e2e8f0; margin-bottom: 36px;
    }
    .brand-logo-lockup img { width: 48px; height: 48px; border-radius: 50%; display: block; }
    .brand-logo-text { font-size: 28px; font-weight: 900; color: #0f172a; letter-spacing: -0.5px; display: flex; align-items: center; gap: 8px; }
    .brand-logo-text span { font-size: 14px; font-weight: 800; color: #ffffff; background: #2563eb; padding: 4px 10px; border-radius: 8px; }
    .headline-container { max-width: 960px; margin: 0 auto; padding: 0 40px; }
    .headline-container h1 { font-size: 68px; font-weight: 900; color: #0f172a; line-height: 1.12; letter-spacing: -1.5px; }
    .headline-container h1 .accent { color: #2563eb; }
    .headline-container p { font-size: 25px; color: #64748b; font-weight: 500; margin-top: 18px; line-height: 1.4; }
    .stage-wrapper { position: absolute; top: 510px; left: 0; right: 0; height: 1220px; z-index: 10; }
    .phone-mockup {
      position: absolute; left: 65px; top: 30px; width: 480px; height: 990px;
      background: #0f172a; border-radius: 54px; padding: 14px;
      box-shadow: 0 40px 80px -15px rgba(15, 23, 42, 0.28), 0 0 0 2px rgba(255, 255, 255, 0.1) inset;
    }
    .phone-island { position: absolute; top: 24px; left: 50%; transform: translateX(-50%); width: 120px; height: 28px; border-radius: 20px; background: #000000; z-index: 30; }
    .phone-screen { width: 100%; height: 100%; border-radius: 42px; overflow: hidden; background: #ffffff; position: relative; }
    .app-header { padding: 44px 20px 14px 20px; background: #ffffff; border-bottom: 1px solid #f1f5f9; display: flex; justify-content: space-between; align-items: center; }
    .app-brand { display: flex; align-items: center; gap: 8px; font-size: 16px; font-weight: 800; color: #0f172a; }
    .app-brand img { width: 24px; height: 24px; }
    .app-status-pill { font-size: 10.5px; font-weight: 700; color: #2563eb; background: #dbeafe; padding: 4px 10px; border-radius: 12px; }
    
    /* Analytics Cards inside Phone */
    .phone-analytics-body { padding: 16px 20px; display: flex; flex-direction: column; gap: 14px; }
    .analytics-kpi-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 16px; padding: 14px 16px; }
    .kpi-label { font-size: 11px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; }
    .kpi-value { font-size: 26px; font-weight: 900; color: #0f172a; margin-top: 4px; display: flex; align-items: baseline; justify-content: space-between; }
    .kpi-badge { font-size: 11px; font-weight: 700; color: #059669; background: #d1fae5; padding: 3px 8px; border-radius: 8px; }
    
    /* Bar Chart Simulation */
    .chart-box { margin-top: 10px; display: flex; align-items: flex-end; gap: 8px; height: 75px; padding-top: 10px; }
    .chart-bar { flex: 1; background: #3b82f6; border-radius: 6px 6px 0 0; opacity: 0.85; }
    
    /* Donut Payment Row */
    .payment-row { display: flex; align-items: center; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-size: 12px; font-weight: 600; color: #334155; }
    .payment-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; margin-right: 6px; }

    .features-column { position: absolute; left: 585px; top: 30px; width: 435px; display: flex; flex-direction: column; gap: 18px; }
    .feat-card {
      background: #ffffff; border-radius: 20px; padding: 18px 22px;
      box-shadow: 0 14px 30px -4px rgba(15, 23, 42, 0.08), 0 4px 8px -2px rgba(15, 23, 42, 0.02);
      border: 1px solid #e2e8f0; display: flex; align-items: center; gap: 18px;
    }
    .feat-icon-box { width: 56px; height: 56px; border-radius: 16px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
    .icon-blue { background: #dbeafe; color: #2563eb; }
    .icon-indigo { background: #e0e7ff; color: #4f46e5; }
    .icon-cyan { background: #cffafe; color: #0891b2; }
    .icon-emerald { background: #d1fae5; color: #059669; }
    .icon-violet { background: #ede9fe; color: #7c3aed; }
    .feat-icon-box svg { width: 28px; height: 28px; stroke: currentColor; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round; fill: none; }
    .feat-text-box { flex: 1; }
    .feat-title { font-size: 18px; font-weight: 800; color: #0f172a; line-height: 1.25; margin-bottom: 4px; letter-spacing: -0.2px; }
    .feat-sub { font-size: 13.5px; color: #64748b; font-weight: 500; line-height: 1.35; }
    .bottom-cta-container { position: absolute; bottom: 65px; left: 65px; right: 65px; z-index: 30; }
    .bottom-cta-banner {
      background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%);
      border-radius: 28px; padding: 22px 36px; display: flex; justify-content: space-between; align-items: center;
      box-shadow: 0 20px 45px -10px rgba(37, 99, 235, 0.38); color: #ffffff;
    }
    .bottom-cta-left { display: flex; align-items: center; gap: 18px; }
    .bottom-cta-icon { width: 48px; height: 48px; border-radius: 50%; background: rgba(255, 255, 255, 0.2); display: flex; align-items: center; justify-content: center; font-size: 24px; }
    .bottom-cta-title { font-size: 24px; font-weight: 900; letter-spacing: -0.4px; }
    .bottom-cta-sub { font-size: 14px; opacity: 0.9; font-weight: 500; }
    .bottom-cta-url { background: #ffffff; color: #1d4ed8; font-size: 16px; font-weight: 800; padding: 12px 28px; border-radius: 16px; box-shadow: 0 4px 10px rgba(0, 0, 0, 0.08); }
  </style>
</head>
<body>
  <div class="ambient-glow-top"></div>
  <div class="top-header">
    <div class="brand-logo-lockup">
      <img src="file:///c:/FlexiTap/image_02e503.png" alt="FlexiTap Logo" />
      <div class="brand-logo-text">FlexiTap <span>REPORTS &amp; INSIGHTS</span></div>
    </div>
    <div class="headline-container">
      <h1>Track Margins. Cut Waste. <span class="accent">Grow Faster.</span></h1>
      <p>Real-time revenue velocity, ingredient inventory depletion, and cashier reconciliation right in your pocket.</p>
    </div>
  </div>
  <div class="stage-wrapper">
    <div class="phone-mockup">
      <div class="phone-island"></div>
      <div class="phone-screen">
        <div class="app-header">
          <div class="app-brand"><img src="file:///c:/FlexiTap/image_02e503.png" alt="Logo" /> Executive Hub</div>
          <div class="app-status-pill">● Shift Audit Live</div>
        </div>
        <div class="phone-analytics-body">
          <div class="analytics-kpi-card">
            <div class="kpi-label">Today's Gross Sales</div>
            <div class="kpi-value">$1,842.50 <span class="kpi-badge">+18.4% vs last week</span></div>
            <div class="chart-box">
              <div class="chart-bar" style="height: 35%;"></div>
              <div class="chart-bar" style="height: 55%;"></div>
              <div class="chart-bar" style="height: 40%;"></div>
              <div class="chart-bar" style="height: 85%;"></div>
              <div class="chart-bar" style="height: 100%;"></div>
              <div class="chart-bar" style="height: 65%;"></div>
              <div class="chart-bar" style="height: 90%;"></div>
            </div>
          </div>
          <div class="analytics-kpi-card">
            <div class="kpi-label">Payment Method Breakdown</div>
            <div style="margin-top: 8px;">
              <div class="payment-row"><span><span class="payment-dot" style="background: #10b981;"></span>Credit / Debit Card</span><span>$985.00 (53.5%)</span></div>
              <div class="payment-row"><span><span class="payment-dot" style="background: #3b82f6;"></span>E-Wallets (Maya / GCash)</span><span>$540.50 (29.3%)</span></div>
              <div class="payment-row"><span><span class="payment-dot" style="background: #f59e0b;"></span>Cash Register Tender</span><span>$317.00 (17.2%)</span></div>
            </div>
          </div>
          <div class="analytics-kpi-card">
            <div class="kpi-label">Top Profit Items</div>
            <div style="margin-top: 8px; font-size: 12px; font-weight: 700; color: #0f172a;">
              <div style="display:flex; justify-content:space-between; padding:4px 0;"><span>1. Iced Caramel Latte</span><span style="color:#059669;">84% Margin</span></div>
              <div style="display:flex; justify-content:space-between; padding:4px 0;"><span>2. Almond Croissant</span><span style="color:#059669;">78% Margin</span></div>
              <div style="display:flex; justify-content:space-between; padding:4px 0;"><span>3. Avocado Melt Toast</span><span style="color:#059669;">72% Margin</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="features-column">
      <div class="feat-card">
        <div class="feat-icon-box icon-blue"><svg viewBox="0 0 24 24"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Hourly Sales Velocity</div>
          <div class="feat-sub">Identify peak counter rush hours and optimize staff shift scheduling with precision.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-indigo"><svg viewBox="0 0 24 24"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Product Margin Mix</div>
          <div class="feat-sub">Spot your true high-margin bestsellers versus costly slow-moving menu items.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-cyan"><svg viewBox="0 0 24 24"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Ingredient Inventory Tracking</div>
          <div class="feat-sub">Automatic ingredient depletion on every ticket with low-stock alerts before items run out.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-emerald"><svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">Cash Drawer &amp; Shift Audits</div>
          <div class="feat-sub">Blind drop counts and automatic cash vs card reconciliation eliminate drawer leakage.</div>
        </div>
      </div>
      <div class="feat-card">
        <div class="feat-icon-box icon-violet"><svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg></div>
        <div class="feat-text-box">
          <div class="feat-title">1-Click Accounting Export</div>
          <div class="feat-sub">Instant CSV and Excel accounting exports ready for your bookkeeper or tax filing.</div>
        </div>
      </div>
    </div>
  </div>
  <div class="bottom-cta-container">
    <div class="bottom-cta-banner">
      <div class="bottom-cta-left">
        <div class="bottom-cta-icon">📈</div>
        <div>
          <div class="bottom-cta-title">Real-Time Financial Intelligence</div>
          <div class="bottom-cta-sub">Run a tighter, more profitable store from any device.</div>
        </div>
      </div>
      <div class="bottom-cta-url">Explore Analytics &rarr;</div>
    </div>
  </div>
</body>
</html>
"""

edge = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
p1_html = r"c:\FlexiTap\poster1_outage.html"
p2_html = r"c:\FlexiTap\poster2_analytics.html"

with open(p1_html, 'w', encoding='utf-8') as f:
    f.write(html_poster1)

with open(p2_html, 'w', encoding='utf-8') as f:
    f.write(html_poster2)

out1 = r"c:\FlexiTap\social_media_features\flexitap_poster_outage_resilience.png"
out2 = r"c:\FlexiTap\social_media_features\flexitap_poster_sales_analytics.png"

for h, o in [(p1_html, out1), (p2_html, out2)]:
    cmd = [
        edge,
        "--headless=old",
        "--disable-gpu",
        "--hide-scrollbars",
        "--user-data-dir=" + os.path.expandvars(r"%TEMP%\edge_posters_official"),
        f"--screenshot={o}",
        "--window-size=1080,1920",
        f"file:///{h.replace(os.sep, '/')}"
    ]
    subprocess.run(cmd, check=True)
    print(f"Rendered: {o}")

print("Both official FlexiTap posters rendered!")
