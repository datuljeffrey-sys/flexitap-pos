/**
 * FlexiTap POS — In-House Philippine Affiliate & Referral Tracker
 * (c) 2026 FlexiTap POS. Zero external 3rd-party tracking dependencies.
 */

(function () {
  'use strict';

  var STORAGE_KEY = 'flexitap_ref';
  var COOKIE_NAME = 'flexitap_ref';
  var COOKIE_DAYS = 60;

  // 1. Read Cookie Helper
  function getCookie(name) {
    var match = document.cookie.match(new RegExp('(^|;\\s*)(' + name + ')=([^;]*)'));
    return match ? decodeURIComponent(match[3]) : null;
  }

  // 2. Set Cookie Helper
  function setCookie(name, value, days) {
    var d = new Date();
    d.setTime(d.getTime() + (days * 24 * 60 * 60 * 1000));
    var expires = 'expires=' + d.toUTCString();
    document.cookie = name + '=' + encodeURIComponent(value) + '; ' + expires + '; path=/; SameSite=Lax';
  }

  // 3. Extract parameter from URL query string (?ref=CODE or ?aff=CODE)
  function getRefFromUrl() {
    try {
      var urlParams = new URLSearchParams(window.location.search);
      var code = urlParams.get('ref') || urlParams.get('aff') || urlParams.get('referral');
      if (code) {
        return code.trim().toUpperCase();
      }
    } catch (e) {
      // Fallback regex for older browsers
      var match = window.location.search.match(/[?&](ref|aff|referral)=([^&#]+)/i);
      if (match && match[2]) {
        return decodeURIComponent(match[2]).trim().toUpperCase();
      }
    }
    return null;
  }

  // 4. Retrieve Active Referral Code (URL > localStorage > Cookie)
  function getActiveReferralCode() {
    var fromUrl = getRefFromUrl();
    if (fromUrl) return fromUrl;
    try {
      var fromStorage = localStorage.getItem(STORAGE_KEY);
      if (fromStorage) return fromStorage.trim().toUpperCase();
    } catch (e) {}
    var fromCookie = getCookie(COOKIE_NAME);
    if (fromCookie) return fromCookie.trim().toUpperCase();
    return null;
  }

  // 5. Hash IP or Session for Anonymous Click Deduplication
  function getSessionHash() {
    var nav = window.navigator || {};
    var raw = (nav.userAgent || '') + (nav.language || '') + (screen.width || '') + 'x' + (screen.height || '');
    var hash = 0;
    for (var i = 0; i < raw.length; i++) {
      hash = ((hash << 5) - hash) + raw.charCodeAt(i);
      hash |= 0;
    }
    return 'h_' + Math.abs(hash).toString(16);
  }

  // 6. Record Click in Supabase
  function logClickToSupabase(code) {
    if (!code) return;
    try {
      // Deduplicate: Don't log same code multiple times in same browser session
      var sessionLoggedKey = 'flexitap_ref_logged_' + code;
      if (sessionStorage.getItem(sessionLoggedKey)) {
        return;
      }
      sessionStorage.setItem(sessionLoggedKey, '1');

      var client = window.supabaseClient;
      if (client && client.from) {
        client.from('affiliate_clicks').insert([{
          affiliate_code: code,
          landing_path: window.location.pathname + window.location.search,
          referrer: document.referrer || 'direct',
          ip_hash: getSessionHash(),
          user_agent: (navigator.userAgent || '').substring(0, 150)
        }]).then(function (res) {
          // Click recorded silently
        }).catch(function (err) {
          // Fail silently
        });
      }
    } catch (e) {}
  }

  // 7. Initialize & Persist
  var incomingCode = getRefFromUrl();
  if (incomingCode) {
    try {
      localStorage.setItem(STORAGE_KEY, incomingCode);
    } catch (e) {}
    setCookie(COOKIE_NAME, incomingCode, COOKIE_DAYS);

    // Wait until Supabase client is ready or DOM loads
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      logClickToSupabase(incomingCode);
    } else {
      window.addEventListener('DOMContentLoaded', function () {
        logClickToSupabase(incomingCode);
      });
    }
  }

  // 8. Public API for Global Access
  window.FlexiTapAffiliate = {
    getCode: getActiveReferralCode,
    clearCode: function () {
      try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
      setCookie(COOKIE_NAME, '', -1);
    },
    enrichPaddleCheckout: function (checkoutPayload) {
      var code = getActiveReferralCode();
      if (!code) return checkoutPayload;
      checkoutPayload = checkoutPayload || {};
      checkoutPayload.customData = checkoutPayload.customData || {};
      checkoutPayload.customData.affiliate_code = code;
      return checkoutPayload;
    }
  };

})();
