/**
 * FlexiTap Regional Policy & Merchant Feature Guard
 * Restricts merchant-specific actions (downloads, merchant registration,
 * paid plans, merchant login, cashier web app, merchant back-office) for
 * visitors located in the Philippines, while preserving normal informational
 * browsing across the website.
 */
(function() {
  'use strict';

  // Developer & Operations portals, simulation suites, and dev tools are strictly exempt from regional restrictions
  const currentPath = (window.location.pathname || '').toLowerCase();
  if (currentPath.includes('dev-portal') ||
      currentPath.includes('dev_portal') ||
      currentPath.includes('simulation_suite') ||
      window.FLEXITAP_DEV_MODE === true ||
      localStorage.getItem('flexitap_dev_bypass') === 'true') {
    return;
  }

  const REGIONAL_POLICY_ACTIVE = true;
  let isPH = false;

  // 1. Synchronous preliminary check (Timezone & Language)
  try {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || '';
    if (tz === 'Asia/Manila' || tz.includes('Manila')) {
      isPH = true;
    }
    const langs = (navigator.languages || [navigator.language || '']).join(',');
    if (langs.includes('fil') || langs.includes('tl') || langs.includes('en-PH')) {
      isPH = true;
    }
  } catch (_) {}

  // Check cached session
  try {
    const cached = sessionStorage.getItem('flexitap_is_ph');
    if (cached === 'true') isPH = true;
    if (cached === 'false') isPH = false;
  } catch (_) {}

  // 2. Async Geo-IP verification
  async function verifyGeoIP() {
    if (!REGIONAL_POLICY_ACTIVE) return;
    try {
      const res = await fetch('https://api.country.is/', { cache: 'no-cache' });
      if (res.ok) {
        const geo = await res.json();
        if (geo && geo.country) {
          isPH = (geo.country === 'PH');
          try { sessionStorage.setItem('flexitap_is_ph', isPH ? 'true' : 'false'); } catch(_) {}
          if (isPH) applyRestrictions();
        }
      }
    } catch (_) {}
  }

  // 3. Subtle floating toast notification
  window.showPhRestrictionNotice = function(customMsg) {
    let toast = document.getElementById('ph-subtle-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'ph-subtle-toast';
      toast.className = 'ph-subtle-toast';
      document.body.appendChild(toast);
    }
    const msg = customMsg || 'FlexiTap is currently not available for your country.';
    toast.innerHTML = '<span>🌐</span> ' + msg;
    toast.classList.add('show');

    // Scroll to inline alert if present
    const inlineAlert = document.getElementById('ph-alert');
    if (inlineAlert) {
      inlineAlert.scrollIntoView({ behavior: 'smooth', block: 'center' });
      inlineAlert.style.borderColor = 'rgba(148, 163, 184, 0.5)';
      setTimeout(() => { inlineAlert.style.borderColor = 'rgba(148, 163, 184, 0.2)'; }, 1500);
    }

    clearTimeout(window._phToastTimeout);
    window._phToastTimeout = setTimeout(() => {
      toast.classList.remove('show');
    }, 3500);
  };

  // 4. Toast and banner styles injection
  function injectStyles() {
    if (document.getElementById('ph-policy-styles')) return;
    const style = document.createElement('style');
    style.id = 'ph-policy-styles';
    style.textContent = `
      .ph-subtle-toast {
        position: fixed;
        bottom: 30px;
        left: 50%;
        transform: translateX(-50%) translateY(20px);
        background: rgba(15, 23, 42, 0.95);
        border: 1px solid rgba(148, 163, 184, 0.25);
        box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5);
        color: #f1f5f9;
        padding: 12px 24px;
        border-radius: 9999px;
        font-size: 14px;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 10px;
        opacity: 0;
        pointer-events: none;
        transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
        z-index: 999999;
      }
      .ph-subtle-toast.show {
        opacity: 1;
        transform: translateX(-50%) translateY(0);
        pointer-events: auto;
      }
      .btn-disabled-ph {
        background: rgba(255, 255, 255, 0.08) !important;
        color: #94a3b8 !important;
        border: 1px solid rgba(255, 255, 255, 0.15) !important;
        cursor: not-allowed !important;
        transform: none !important;
        box-shadow: none !important;
        opacity: 0.85 !important;
      }
      .ph-restricted-alert {
        background: rgba(30, 41, 59, 0.7);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        border: 1px solid rgba(148, 163, 184, 0.2);
        border-radius: 16px;
        padding: 16px 22px;
        max-width: 840px;
        margin: 0 auto 32px;
        text-align: left;
        box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.25);
        animation: fadeInNotice 0.35s ease-out;
      }
      .ph-notice-wrap {
        display: flex;
        align-items: center;
        gap: 14px;
      }
      .ph-notice-icon {
        font-size: 22px;
        line-height: 1;
        opacity: 0.9;
        flex-shrink: 0;
      }
      .ph-notice-text {
        font-size: 14px;
        color: #94a3b8;
        line-height: 1.5;
      }
      .ph-notice-text strong {
        color: #f1f5f9;
        font-weight: 600;
        display: inline-block;
        margin-right: 4px;
      }
      @keyframes fadeInNotice {
        from { opacity: 0; transform: translateY(-4px); }
        to { opacity: 1; transform: translateY(0); }
      }
    `;
    document.head.appendChild(style);
  }

  // 5. Apply restrictions to merchant functions
  function applyRestrictions() {
    if (!REGIONAL_POLICY_ACTIVE || !isPH) return;

    window.isPhRestricted = true;
    injectStyles();

    const path = window.location.pathname.toLowerCase();

    // A. Dedicated Merchant Portal Pages Guard: portal.html, partner-portal.html, flexi-app.html
    const isPortalPage = path.endsWith('/portal.html') || path.endsWith('/portal') ||
                         path.endsWith('/partner-portal.html') || path.endsWith('/partner-portal') ||
                         path.endsWith('/flexi-app.html');

    if (isPortalPage) {
      document.body.innerHTML = `
        <div style="min-height: 100vh; background: #0f172a; color: #f8fafc; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 24px; text-align: center; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
          <div style="background: rgba(30, 41, 59, 0.7); border: 1px solid rgba(148, 163, 184, 0.2); border-radius: 20px; padding: 40px 32px; max-width: 520px; width: 100%; box-shadow: 0 20px 50px rgba(0,0,0,0.5);">
            <div style="font-size: 40px; margin-bottom: 16px;">🌐</div>
            <h1 style="font-size: 22px; font-weight: 700; color: #fff; margin-bottom: 12px;">FlexiTap is currently not available for your country</h1>
            <p style="font-size: 14.5px; color: #94a3b8; line-height: 1.6; margin-bottom: 28px;">
              Direct merchant access, terminal registration, and back-office services are restricted in your region at this time.
            </p>
            <a href="index.html" style="display: inline-block; background: #2563eb; color: #fff; text-decoration: none; font-weight: 600; font-size: 14px; padding: 12px 28px; border-radius: 9999px; transition: background 0.2s;">
              Back to Home
            </a>
          </div>
        </div>
      `;
      return;
    }

    // B. Intercept window.openModal for login-modal and signup-modal
    const origOpenModal = window.openModal;
    window.openModal = function(modalId) {
      if (modalId === 'login-modal') {
        window.showPhRestrictionNotice('Merchant login is currently not available for your country.');
        return;
      }
      if (modalId === 'signup-modal') {
        window.showPhRestrictionNotice('Merchant registration is currently not available for your country.');
        return;
      }
      if (typeof origOpenModal === 'function') {
        return origOpenModal.apply(this, arguments);
      }
    };

    // Global Interception of "Merchant Login" and "Get Started" buttons
    document.querySelectorAll('.btn-login, [onclick*="login-modal"]').forEach(el => {
      el.onclick = function(e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        window.showPhRestrictionNotice('Merchant login is currently not available for your country.');
        return false;
      };
    });

    document.querySelectorAll('[onclick*="signup-modal"]').forEach(el => {
      el.onclick = function(e) {
        if (e) { e.preventDefault(); e.stopPropagation(); }
        window.showPhRestrictionNotice('Merchant registration is currently not available for your country.');
        return false;
      };
    });

    // C. Pricing Page Specific Guard: pricing.html
    if (path.includes('pricing') || document.getElementById('btn-action-free')) {
      // Injects subtle banner above pricing if not present
      let alertBox = document.getElementById('ph-alert');
      if (!alertBox) {
        const target = document.querySelector('.pricing-grid') || document.querySelector('.billing-cycle-switch') || document.querySelector('.section-title');
        if (target && target.parentNode) {
          alertBox = document.createElement('div');
          alertBox.id = 'ph-alert';
          alertBox.className = 'ph-restricted-alert';
          alertBox.style.display = 'block';
          alertBox.innerHTML = `
            <div class="ph-notice-wrap">
              <span class="ph-notice-icon">🌐</span>
              <div class="ph-notice-text">
                <strong>FlexiTap is currently not available for your country.</strong>
                <span>Merchant account subscriptions and signups are restricted in your region at this time.</span>
              </div>
            </div>
          `;
          target.parentNode.insertBefore(alertBox, target);
        }
      } else {
        alertBox.style.display = 'block';
      }

      // Hide local currency tags
      const geoTag = document.getElementById('geo-location-tag');
      if (geoTag) geoTag.style.display = 'none';

      const enforcePricingButtons = function() {
        ['btn-action-free', 'btn-action-plus', 'btn-action-pro'].forEach(id => {
          const btn = document.getElementById(id);
          if (btn) {
            btn.classList.add('btn-disabled-ph');
            btn.innerHTML = '<span>🌐</span> Not Available in Your Country';
            btn.onclick = function(e) {
              if (e) { e.preventDefault(); e.stopPropagation(); }
              window.showPhRestrictionNotice('Subscriptions are currently not available for your country.');
              return false;
            };
          }
        });
      };

      enforcePricingButtons();
      setInterval(enforcePricingButtons, 500);

      // Override modal trigger
      window.openSignupModalWithPlan = function() {
        window.showPhRestrictionNotice('Subscriptions are currently not available for your country.');
      };
    }

    // D. Download Page Specific Guard: download.html
    if (path.includes('download') || document.getElementById('detected-btn')) {
      const phAlert = document.getElementById('ph-alert');
      if (phAlert) phAlert.style.display = 'block';

      ['detected-btn', 'btn-win-download', 'btn-android-download'].forEach(id => {
        const btn = document.getElementById(id);
        if (btn) {
          btn.classList.add('btn-disabled-ph');
          btn.innerHTML = '<span>🌐</span> Not Available in Your Country';
          btn.onclick = function(e) {
            if (e) { e.preventDefault(); e.stopPropagation(); }
            window.showPhRestrictionNotice('Downloads are currently not available for your country.');
            return false;
          };
        }
      });
      const detectedMeta = document.getElementById('detected-meta');
      if (detectedMeta) {
        detectedMeta.innerText = 'FlexiTap is currently not available for your country';
      }
    }
  }

  // Run on DOM ready & initialize Geo verification
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      injectStyles();
      if (isPH) applyRestrictions();
      verifyGeoIP();
    });
  } else {
    injectStyles();
    if (isPH) applyRestrictions();
    verifyGeoIP();
  }
})();
