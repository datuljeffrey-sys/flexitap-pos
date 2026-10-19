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

  // 7. Automatic Link Decoration & URL Preservation Helpers
  function syncCurrentPageUrl(code) {
    if (!code || !window.history || !window.history.replaceState) return;
    try {
      if (window.location.pathname.includes('dev-portal') || window.location.pathname.includes('dev_portal')) return;
      var urlParams = new URLSearchParams(window.location.search);
      if (!urlParams.get('ref') && !urlParams.get('aff') && !urlParams.get('referral')) {
        urlParams.set('ref', code);
        var newSearch = urlParams.toString();
        var newUrl = window.location.pathname + (newSearch ? '?' + newSearch : '') + window.location.hash;
        window.history.replaceState({ ref: code }, '', newUrl);
      }
    } catch (e) {}
  }

  function decorateUrl(rawUrl, code) {
    if (!rawUrl || !code) return rawUrl;
    try {
      if (/^(mailto:|tel:|javascript:|#)/i.test(rawUrl)) return rawUrl;
      var parsed = new URL(rawUrl, window.location.href);
      // Only decorate same-origin links
      if (parsed.hostname !== window.location.hostname && parsed.hostname !== 'flexitapapp.com' && parsed.hostname !== 'www.flexitapapp.com') {
        return rawUrl;
      }
      if (parsed.pathname.includes('dev-portal') || parsed.pathname.includes('dev_portal')) {
        return rawUrl;
      }
      if (!parsed.searchParams.get('ref') && !parsed.searchParams.get('aff') && !parsed.searchParams.get('referral')) {
        parsed.searchParams.set('ref', code);
      }
      if (!/^https?:\/\//i.test(rawUrl)) {
        return parsed.pathname + parsed.search + parsed.hash;
      }
      return parsed.toString();
    } catch (e) {
      return rawUrl;
    }
  }

  function decorateAllLinks(code) {
    if (!code) return;
    try {
      var links = document.querySelectorAll('a[href]');
      for (var i = 0; i < links.length; i++) {
        var a = links[i];
        var href = a.getAttribute('href');
        if (!href) continue;
        var decorated = decorateUrl(href, code);
        if (decorated && decorated !== href) {
          a.setAttribute('href', decorated);
        }
      }
    } catch (e) {}
  }

  function renderPartnerBadge(code) {
    if (!code) return;
    if (window.location.pathname.includes('partner-portal') || window.location.pathname.includes('dev-portal') || window.location.pathname.includes('portal.html')) return;
    if (document.getElementById('flexitap-partner-pill')) return;

    try {
      var pill = document.createElement('div');
      pill.id = 'flexitap-partner-pill';
      pill.style.position = 'fixed';
      pill.style.bottom = '20px';
      pill.style.left = '20px';
      pill.style.zIndex = '99990';
      pill.style.display = 'flex';
      pill.style.alignItems = 'center';
      pill.style.gap = '8px';
      pill.style.padding = '8px 14px';
      pill.style.background = 'rgba(15, 23, 42, 0.94)';
      pill.style.backdropFilter = 'blur(10px)';
      pill.style.webkitBackdropFilter = 'blur(10px)';
      pill.style.border = '1px solid rgba(16, 185, 129, 0.45)';
      pill.style.borderRadius = '30px';
      pill.style.boxShadow = '0 10px 25px rgba(0,0,0,0.4), 0 0 15px rgba(16,185,129,0.15)';
      pill.style.fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
      pill.style.fontSize = '12px';
      pill.style.color = '#ffffff';
      pill.style.lineHeight = '1';

      pill.innerHTML = [
        '<span style="display:inline-block;width:7px;height:7px;border-radius:50%;background:#10b981;box-shadow:0 0 8px #10b981;"></span>',
        '<span style="color:#94a3b8;font-size:11.5px;">Partner Pass:</span>',
        '<strong style="color:#34d399;font-family:monospace;font-size:12.5px;letter-spacing:0.5px;">' + code + '</strong>',
        '<button onclick="this.parentElement.style.display=\'none\'" style="background:none;border:none;color:#64748b;margin-left:4px;cursor:pointer;font-size:14px;padding:0;line-height:1;" title="Dismiss">&times;</button>'
      ].join(' ');

      document.body.appendChild(pill);
    } catch (e) {}
  }

  // 8. Initialize, Persist & Decorate Across All Subpages
  var incomingCode = getRefFromUrl();
  var activeCode = incomingCode || getActiveReferralCode();

  if (activeCode) {
    try {
      localStorage.setItem(STORAGE_KEY, activeCode);
      sessionStorage.setItem(STORAGE_KEY, activeCode);
    } catch (e) {}
    setCookie(COOKIE_NAME, activeCode, COOKIE_DAYS);

    // Keep address bar synchronized with ?ref=CODE across subpages
    syncCurrentPageUrl(activeCode);

    // Record click if fresh incoming code
    if (incomingCode) {
      if (document.readyState === 'complete' || document.readyState === 'interactive') {
        logClickToSupabase(incomingCode);
      } else {
        window.addEventListener('DOMContentLoaded', function () {
          logClickToSupabase(incomingCode);
        });
      }
    }

    // Decorate internal navigation links so clicking any link retains ?ref=CODE
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function () {
        decorateAllLinks(activeCode);
        renderPartnerBadge(activeCode);
      });
    } else {
      decorateAllLinks(activeCode);
      renderPartnerBadge(activeCode);
    }

    // Global click listener to ensure dynamically added links retain ?ref=CODE
    document.addEventListener('click', function (e) {
      var target = e.target && e.target.closest ? e.target.closest('a[href]') : null;
      if (target) {
        var href = target.getAttribute('href');
        if (href) {
          var updated = decorateUrl(href, activeCode);
          if (updated && updated !== href) {
            target.setAttribute('href', updated);
          }
        }
      }
    }, true);
  }

  // 9. Public API for Global Access
  window.FlexiTapAffiliate = {
    getCode: getActiveReferralCode,
    clearCode: function () {
      try { localStorage.removeItem(STORAGE_KEY); sessionStorage.removeItem(STORAGE_KEY); } catch (e) {}
      setCookie(COOKIE_NAME, '', -1);
    },
    enrichPaddleCheckout: function (checkoutPayload) {
      var code = getActiveReferralCode();
      if (!code) return checkoutPayload;
      checkoutPayload = checkoutPayload || {};
      checkoutPayload.customData = checkoutPayload.customData || {};
      checkoutPayload.customData.affiliate_code = code;
      return checkoutPayload;
    },
    decorateLinks: function() {
      var c = getActiveReferralCode();
      if (c) decorateAllLinks(c);
    },
    dispatchSignupEmails: dispatchAffiliateSignupEmails
  };

  // 9. Dispatch Affiliate Welcome & Internal Alert Emails (Strictly NO PWA Link)
  function dispatchAffiliateSignupEmails(partner) {
    if (!partner || !partner.email) return;

    var GOOGLE_TICKET_WEBHOOK_URL = 'https://script.google.com/macros/s/AKfycbzJu1CEi1qhT-k7Qc_tisMN7vXbbCuGymgiMMk_K6PGIMnrUHkIrYEuQFMCviZfaYvoQw/exec';

    function escapeHtml(str) {
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }

    var name = escapeHtml(partner.full_name || partner.name || 'Partner');
    var code = escapeHtml((partner.affiliate_code || partner.code || '').toUpperCase());
    var email = escapeHtml(partner.email);
    var phone = escapeHtml(partner.phone_ph || partner.phone || 'Not provided');
    var payoutType = (partner.payout_type || 'gcash').toUpperCase();
    var bankName = escapeHtml(partner.payout_bank_name || partner.bankName || '');
    var acctName = escapeHtml(partner.payout_account_name || partner.acctName || '');
    var acctNum = escapeHtml(partner.payout_account_number || partner.acctNum || '');
    var referralUrl = 'https://www.flexitapapp.com/?ref=' + encodeURIComponent(code);
    var portalUrl = 'https://flexitapapp.com/partner-portal.html';

    var payoutSummary = payoutType;
    if (payoutType === 'BANK' && bankName) {
      payoutSummary = bankName + ' (' + payoutType + ')';
    }

    // 1. Welcome Email for New Affiliate (NO PWA LINK)
    var affiliateHtml = [
      '<div style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">',
      '  <div style="background: #0f172a; padding: 28px 24px; text-align: center;">',
      '    <span style="display: inline-block; background: rgba(16,185,129,0.15); color: #34d399; font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; padding: 5px 14px; border-radius: 20px; border: 1px solid rgba(16,185,129,0.3); margin-bottom: 12px;">',
      '      Philippine Partner Program',
      '    </span>',
      '    <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">Welcome to FlexiTap Partners!</h1>',
      '    <p style="color: #94a3b8; margin: 6px 0 0; font-size: 13.5px;">Your partner account is active and ready to start earning bounties.</p>',
      '  </div>',
      '  <div style="padding: 28px 24px;">',
      '    <p style="font-size: 15px; color: #1e293b; line-height: 1.6; margin: 0 0 16px;">',
      '      Kumusta <strong>' + name + '</strong>,',
      '    </p>',
      '    <p style="font-size: 14px; color: #475569; line-height: 1.6; margin: 0 0 20px;">',
      '      Welcome to the <strong>FlexiTap Philippine Partner &amp; Referral Program</strong>! Whenever a café, restaurant, food truck, or retail store activates FlexiTap POS using your referral, you earn an instant cash bounty paid directly to your registered payout account.',
      '    </p>',
      '    <div style="background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 10px; padding: 20px; margin-bottom: 24px; text-align: center;">',
      '      <div style="font-size: 11px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px;">Your Official Referral Code</div>',
      '      <div style="font-size: 26px; font-weight: 900; color: #0f172a; letter-spacing: 2px; font-family: monospace; margin-bottom: 12px;">' + code + '</div>',
      '      <div style="font-size: 12px; color: #475569; margin-bottom: 6px;">Your Dedicated Referral Link:</div>',
      '      <div style="background: #ffffff; border: 1px dashed #94a3b8; border-radius: 6px; padding: 10px 14px; word-break: break-all; font-family: monospace; font-size: 13px; color: #2563eb; font-weight: 600; margin-bottom: 16px;">',
      '        ' + referralUrl,
      '      </div>',
      '      <a href="' + portalUrl + '" target="_blank" style="display: inline-block; background: #10b981; color: #ffffff; text-decoration: none; padding: 11px 24px; border-radius: 8px; font-size: 13.5px; font-weight: 800; box-shadow: 0 4px 12px rgba(16,185,129,0.3);">',
      '        Open Partner Portal &rarr;',
      '      </a>',
      '    </div>',
      '    <div style="background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 10px; padding: 18px; margin-bottom: 22px;">',
      '      <div style="font-size: 13px; font-weight: 800; color: #065f46; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px;">💰 Your Commission Bounties</div>',
      '      <table style="width: 100%; border-collapse: collapse; font-size: 13.5px;">',
      '        <tr>',
      '          <td style="padding: 6px 0; color: #047857; font-weight: 600;">FlexiTap Plus Activation:</td>',
      '          <td style="padding: 6px 0; color: #065f46; font-weight: 800; text-align: right; font-size: 15px;">₱3,000.00</td>',
      '        </tr>',
      '        <tr>',
      '          <td style="padding: 6px 0; color: #047857; font-weight: 600;">FlexiTap Pro Activation:</td>',
      '          <td style="padding: 6px 0; color: #065f46; font-weight: 800; text-align: right; font-size: 15px;">₱6,000.00</td>',
      '        </tr>',
      '      </table>',
      '    </div>',
      '    <table style="width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 22px; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px;">',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 10px 14px; color: #64748b; width: 140px;">Payout Rail:</td><td style="padding: 10px 14px; color: #0f172a; font-weight: 600;">' + payoutSummary + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 10px 14px; color: #64748b;">Account Name:</td><td style="padding: 10px 14px; color: #0f172a; font-weight: 600;">' + acctName + '</td></tr>',
      '      <tr><td style="padding: 10px 14px; color: #64748b;">Account / Mobile #:</td><td style="padding: 10px 14px; color: #0f172a; font-weight: 600;">' + acctNum + '</td></tr>',
      '    </table>',
      '    <div style="background: #f8fafc; border-left: 3px solid #3b82f6; padding: 14px 16px; margin-bottom: 22px; font-size: 12.5px; color: #475569; line-height: 1.55;">',
      '      <strong style="color: #1e293b;">How Payouts Work:</strong>',
      '      <ul style="margin: 6px 0 0; padding-left: 18px;">',
      '        <li>All referral activations undergo a standard <strong>30-day verification hold</strong> to confirm store onboarding and terminal sync.</li>',
      '        <li>Approved commissions are disbursed on the <strong>1st and 15th</strong> of each month directly to your registered payout account.</li>',
      '        <li>Self-referrals (using bounties on your own store accounts or purchasing with your own funds) are strictly prohibited under our Partner Terms.</li>',
      '      </ul>',
      '    </div>',
      '    <p style="font-size: 13px; color: #64748b; line-height: 1.5; margin: 0 0 16px;">',
      '      Have questions or need help onboarding a merchant? Simply reply directly to this email or contact us at <a href="mailto:info@flexitapapp.com" style="color: #2563eb; text-decoration: none;">info@flexitapapp.com</a>.',
      '    </p>',
      '  </div>',
      '  <div style="background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; line-height: 1.5;">',
      '    &copy; 2026 FlexiTap POS &bull; <a href="https://www.flexitapapp.com" style="color: #64748b; text-decoration: none;">www.flexitapapp.com</a> &bull; Philippine Partner Desk<br>',
      '    Manila, Philippines &bull; Dedicated Solutions &amp; POS Systems',
      '  </div>',
      '</div>'
    ].join('\n');

    // 2. Internal Team Notification Email to info@flexitapapp.com (NO PWA LINK)
    var teamHtml = [
      '<div style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">',
      '  <div style="background: #1e1b4b; padding: 24px; text-align: center;">',
      '    <span style="display: inline-block; background: rgba(52,211,153,0.2); color: #34d399; font-size: 11px; font-weight: 800; letter-spacing: 1px; text-transform: uppercase; padding: 4px 12px; border-radius: 20px; border: 1px solid rgba(52,211,153,0.3); margin-bottom: 8px;">',
      '      New Partner Registration',
      '    </span>',
      '    <h2 style="color: #ffffff; margin: 0; font-size: 22px; font-weight: 800;">New Affiliate Signed Up</h2>',
      '    <p style="color: #c7d2fe; margin: 4px 0 0; font-size: 13px;">Philippine Partner &amp; Referral Program</p>',
      '  </div>',
      '  <div style="padding: 24px;">',
      '    <table style="width: 100%; border-collapse: collapse; font-size: 13.5px; margin-bottom: 20px;">',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b; width: 150px;">Partner Full Name:</td><td style="padding: 8px 0; color: #0f172a; font-weight: 700;">' + name + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Referral Code:</td><td style="padding: 8px 0; color: #2563eb; font-weight: 800; font-family: monospace; font-size: 15px;">' + code + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Email Address:</td><td style="padding: 8px 0; color: #2563eb; font-weight: 600;"><a href="mailto:' + email + '" style="color: #2563eb; text-decoration: none;">' + email + '</a></td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Phone (PH):</td><td style="padding: 8px 0; color: #0f172a;">' + phone + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Payout Method:</td><td style="padding: 8px 0; color: #059669; font-weight: 700;">' + payoutSummary + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Account Name:</td><td style="padding: 8px 0; color: #0f172a;">' + acctName + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Account / Number:</td><td style="padding: 8px 0; color: #0f172a;">' + acctNum + '</td></tr>',
      '      <tr style="border-bottom: 1px solid #f1f5f9;"><td style="padding: 8px 0; color: #64748b;">Referral Link:</td><td style="padding: 8px 0; color: #475569; font-size: 12px; word-break: break-all;">' + referralUrl + '</td></tr>',
      '      <tr><td style="padding: 8px 0; color: #64748b;">Registration Time:</td><td style="padding: 8px 0; color: #64748b;">' + new Date().toLocaleString('en-US', { timeZone: 'Asia/Manila', dateStyle: 'full', timeStyle: 'short' }) + ' PHT</td></tr>',
      '    </table>',
      '    <div style="text-align: center; margin-top: 18px;">',
      '      <a href="https://flexitapapp.com/dev-portal.html" target="_blank" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 11px 22px; border-radius: 8px; font-size: 13.5px; font-weight: 700; text-decoration: none; box-shadow: 0 4px 12px rgba(37,99,235,0.3);">',
      '        View in Dev Portal Admin &rarr;',
      '      </a>',
      '    </div>',
      '  </div>',
      '  <div style="background: #f1f5f9; padding: 14px 24px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0;">',
      '    FlexiTap Operations Desk &bull; Automated Partner Notification',
      '  </div>',
      '</div>'
    ].join('\n');

    // Dispatch Welcome Email to Affiliate
    try {
      fetch(GOOGLE_TICKET_WEBHOOK_URL, {
        method: 'POST',
        mode: 'no-cors',
        headers: { 'Content-Type': 'text/plain;charset=utf-8' },
        body: JSON.stringify({
          notification_type: 'affiliate_welcome_signup',
          recipient_email: partner.email,
          subject: '[Welcome to FlexiTap Partners] Your Referral Code is Ready: ' + code,
          store_name: partner.full_name || partner.name || 'Partner',
          details: 'New affiliate registered with referral code ' + code,
          html: affiliateHtml
        })
      }).catch(function (err) {
        console.warn('Affiliate welcome email webhook note:', err);
      });
    } catch (e) {
      console.warn('Affiliate welcome email dispatch exception:', e);
    }

    // Dispatch Internal Notification to info@flexitapapp.com
    try {
      fetch(GOOGLE_TICKET_WEBHOOK_URL, {
        method: 'POST',
        mode: 'no-cors',
        headers: { 'Content-Type': 'text/plain;charset=utf-8' },
        body: JSON.stringify({
          notification_type: 'affiliate_signup_team_alert',
          recipient_email: 'info@flexitapapp.com',
          subject: '[New Partner Signup] ' + name + ' (' + code + ') - FlexiTap Partner Program',
          store_name: name,
          details: 'New affiliate registered: ' + name + ' (' + partner.email + '), Code: ' + code,
          html: teamHtml
        })
      }).catch(function (err) {
        console.warn('Team partner alert webhook note:', err);
      });
    } catch (e) {
      console.warn('Team partner alert dispatch exception:', e);
    }
  }

  window.dispatchAffiliateSignupEmails = dispatchAffiliateSignupEmails;

})();
