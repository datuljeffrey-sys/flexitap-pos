/**
 * Flexitap Privacy & Tracking Consent Banner
 * Complies with GDPR, CCPA/CPRA, and Global Privacy Standards.
 */
(function() {
  'use strict';

  const STORAGE_KEY = 'flexitap_privacy_consent';

  // Check if user has already made a choice
  try {
    const existingConsent = localStorage.getItem(STORAGE_KEY);
    if (existingConsent === 'accepted' || existingConsent === 'declined') {
      if (existingConsent === 'declined') {
        disableTracking();
      }
      return; // Do not show banner
    }
  } catch (_) {}

  function disableTracking() {
    try {
      if (typeof window !== 'undefined') {
        window['ga-disable-default'] = true;
        if (window.FLEXITAP_GA_ID) {
          window['ga-disable-' + window.FLEXITAP_GA_ID] = true;
        }
      }
    } catch (_) {}
  }

  function handleConsent(action) {
    try {
      localStorage.setItem(STORAGE_KEY, action);
    } catch (_) {}

    if (action === 'declined') {
      disableTracking();
    }

    const banner = document.getElementById('ft-privacy-consent-banner');
    if (banner) {
      banner.style.opacity = '0';
      banner.style.transform = 'translateY(100%)';
      banner.style.transition = 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)';
      setTimeout(() => banner.remove(), 350);
    }
  }

  function injectBanner() {
    if (document.getElementById('ft-privacy-consent-banner')) return;

    const banner = document.createElement('div');
    banner.id = 'ft-privacy-consent-banner';
    banner.setAttribute('role', 'region');
    banner.setAttribute('aria-label', 'Privacy and cookie consent');

    banner.innerHTML = `
      <style>
        #ft-privacy-consent-banner {
          position: fixed;
          bottom: 0;
          left: 0;
          right: 0;
          z-index: 999999;
          background-color: #ffffff;
          color: #111827;
          border-top: 1px solid #e5e7eb;
          box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.08);
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          font-size: 13px;
          line-height: 1.5;
          padding: 16px 24px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 24px;
          opacity: 0;
          transform: translateY(100%);
          transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
        }
        @media (prefers-color-scheme: dark) {
          #ft-privacy-consent-banner {
            background-color: #0f172a;
            color: #f1f5f9;
            border-top: 1px solid #334155;
            box-shadow: 0 -4px 25px rgba(0, 0, 0, 0.35);
          }
        }
        #ft-privacy-consent-banner .ft-consent-text {
          flex: 1;
          margin: 0;
          max-width: 1200px;
        }
        #ft-privacy-consent-banner .ft-consent-text a {
          color: inherit;
          text-decoration: underline;
          font-weight: 600;
          transition: opacity 0.2s;
        }
        #ft-privacy-consent-banner .ft-consent-text a:hover {
          opacity: 0.8;
        }
        #ft-privacy-consent-banner .ft-consent-actions {
          display: flex;
          align-items: center;
          gap: 10px;
          flex-shrink: 0;
        }
        #ft-privacy-consent-banner .ft-btn {
          border: none;
          outline: none;
          cursor: pointer;
          font-size: 13.5px;
          font-weight: 700;
          padding: 8px 22px;
          border-radius: 9999px;
          transition: all 0.2s ease;
          letter-spacing: 0.2px;
        }
        #ft-privacy-consent-banner .ft-btn-accept {
          background-color: #0284c7;
          color: #ffffff;
        }
        #ft-privacy-consent-banner .ft-btn-accept:hover {
          background-color: #0369a1;
          transform: translateY(-1px);
        }
        #ft-privacy-consent-banner .ft-btn-decline {
          background-color: #0284c7;
          color: #ffffff;
        }
        #ft-privacy-consent-banner .ft-btn-decline:hover {
          background-color: #0369a1;
          transform: translateY(-1px);
        }
        @media (max-width: 820px) {
          #ft-privacy-consent-banner {
            flex-direction: column;
            align-items: flex-start;
            gap: 14px;
            padding: 14px 18px;
            font-size: 12px;
          }
          #ft-privacy-consent-banner .ft-consent-actions {
            width: 100%;
            justify-content: flex-end;
          }
          #ft-privacy-consent-banner .ft-btn {
            flex: 1;
            text-align: center;
            padding: 9px 16px;
          }
        }
      </style>
      <div class="ft-consent-text">
        With your consent, our site will use tracking tools for marketing (including targeted advertising) and to personalize your experience. These tools collect data from and about you, including your interests and how you interact with our site. We also may share this data with vendors, including marketing and analytics vendors. See our <a href="privacy.html">Privacy Policy</a> for more details. To allow us to use tracking tools, click &ldquo;Accept.&rdquo; To prevent the site from using tracking tools, click &ldquo;Decline.&rdquo; See &ldquo;<a href="privacy.html#choices">Your Privacy Choices</a>&rdquo; for additional choices. By continuing to use our site, you agree to our <a href="terms.html">Terms of Use</a>.
      </div>
      <div class="ft-consent-actions">
        <button type="button" class="ft-btn ft-btn-accept" id="ft-btn-accept">Accept</button>
        <button type="button" class="ft-btn ft-btn-decline" id="ft-btn-decline">Decline</button>
      </div>
    `;

    document.body.appendChild(banner);

    // Animate in
    requestAnimationFrame(() => {
      setTimeout(() => {
        banner.style.opacity = '1';
        banner.style.transform = 'translateY(0)';
      }, 100);
    });

    document.getElementById('ft-btn-accept').addEventListener('click', () => handleConsent('accepted'));
    document.getElementById('ft-btn-decline').addEventListener('click', () => handleConsent('declined'));
  }

  // Ensure DOM is ready before injecting
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectBanner);
  } else {
    injectBanner();
  }
})();
