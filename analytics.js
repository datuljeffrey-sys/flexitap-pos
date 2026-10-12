/**
 * FlexiTap Hybrid Analytics Engine
 * Combines Native Supabase Event Telemetry with Google Analytics 4 (GA4)
 */

(function() {
  'use strict';

  const CONFIG = {
    supabaseUrl: 'https://ezaqdnnecfkmqjdzigrf.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6YXFkbm5lY2ZrbXFqZHppZ3JmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczOTE0NDEsImV4cCI6MjA5Mjk2NzQ0MX0.QoJryCMZwf_haqFZVr4LGaJqQR0Ux7yMyzvr2xLiJQE',
    // Set your Google Analytics 4 Measurement ID here or in window.FLEXITAP_GA_ID
    gaMeasurementId: (typeof window !== 'undefined' && window.FLEXITAP_GA_ID) ? window.FLEXITAP_GA_ID : 'G-XXXXXXXXXX',
    enableSupabase: true,
    enableGA: true
  };

  // Helper: Anonymous Session Identifier (No Cookies, persists per browser tab)
  function getSessionId() {
    try {
      let sid = sessionStorage.getItem('ft_analytics_sid');
      if (!sid) {
        sid = 'ft_s_' + Math.random().toString(36).substring(2, 10) + '_' + Date.now();
        sessionStorage.setItem('ft_analytics_sid', sid);
      }
      return sid;
    } catch (_) {
      return 'ft_anon_' + Date.now();
    }
  }

  // Helper: Detect Device / Operating System
  function detectPlatform() {
    const ua = (navigator.userAgent || '').toLowerCase();
    if (ua.includes('win')) return 'windows';
    if (ua.includes('android')) return 'android';
    if (ua.includes('iphone') || ua.includes('ipad') || ua.includes('ipod')) return 'ios';
    if (ua.includes('mac')) return 'mac';
    if (ua.includes('linux')) return 'linux';
    return 'other';
  }

  // Initialize GA4 if Measurement ID is provided and not default placeholder
  function initGA4() {
    if (!CONFIG.enableGA) return;
    const gaId = CONFIG.gaMeasurementId;
    
    // Always provide gtag stub to prevent reference errors
    window.dataLayer = window.dataLayer || [];
    window.gtag = window.gtag || function() { window.dataLayer.push(arguments); };

    if (gaId && gaId !== 'G-XXXXXXXXXX' && !document.getElementById('ga-script-tag')) {
      const script = document.createElement('script');
      script.id = 'ga-script-tag';
      script.async = true;
      script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(gaId);
      document.head.appendChild(script);

      window.gtag('js', new Date());
      window.gtag('config', gaId, { send_page_view: false });
    }
  }

  // Unified Analytics API
  const FlexiAnalytics = {
    config: CONFIG,

    track: async function(eventName, properties) {
      properties = properties || {};
      const platform = properties.platform || detectPlatform();
      const pagePath = window.location.pathname || '/';
      const pageTitle = document.title || '';

      // 1. Dispatch to Google Analytics 4 (if available)
      if (typeof window.gtag === 'function') {
        try {
          window.gtag('event', eventName, {
            event_category: properties.category || 'User Interaction',
            event_label: properties.label || pagePath,
            platform: platform,
            ...properties
          });
        } catch (gaErr) {
          console.debug('[GA4] Event dispatch notice:', gaErr);
        }
      }

      // 2. Dispatch to Supabase native site_analytics table
      if (CONFIG.enableSupabase) {
        try {
          const payload = {
            event_type: properties.event_type || 'custom',
            event_name: eventName,
            page_path: pagePath,
            page_title: pageTitle,
            platform: platform,
            referrer: document.referrer || '',
            session_id: getSessionId(),
            metadata: {
              screen_resolution: `${window.screen.width}x${window.screen.height}`,
              language: navigator.language || '',
              user_agent: navigator.userAgent || '',
              ...properties
            }
          };

          fetch(CONFIG.supabaseUrl + '/rest/v1/site_analytics', {
            method: 'POST',
            headers: {
              'apikey': CONFIG.supabaseAnonKey,
              'Authorization': 'Bearer ' + CONFIG.supabaseAnonKey,
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal'
            },
            body: JSON.stringify(payload)
          }).catch(function(err) {
            console.debug('[Supabase Analytics] Background send notice:', err);
          });
        } catch (sbErr) {
          console.debug('[Supabase Analytics] Exception:', sbErr);
        }
      }
    },

    trackPageView: function() {
      this.track('pageview', {
        event_type: 'pageview',
        platform: detectPlatform()
      });
    },

    trackDownloadClick: function(platform, label) {
      this.track('download_click', {
        event_type: 'download_click',
        platform: platform,
        label: label || (platform + ' download'),
        category: 'Downloads'
      });
    }
  };

  // Expose to window
  window.FlexiAnalytics = FlexiAnalytics;

  // Auto-run on DOM Ready
  function onReady() {
    initGA4();
    FlexiAnalytics.trackPageView();

    // Auto-hook elements with data-analytics attributes
    document.addEventListener('click', function(e) {
      const target = e.target.closest('[data-analytics]');
      if (!target) return;

      const action = target.getAttribute('data-analytics');
      const platform = target.getAttribute('data-platform') || detectPlatform();
      const label = target.getAttribute('data-label') || target.innerText.trim();

      if (action.startsWith('download-')) {
        const plat = action.replace('download-', '');
        FlexiAnalytics.trackDownloadClick(plat, label);
      } else {
        FlexiAnalytics.track(action, {
          event_type: 'click',
          platform: platform,
          label: label
        });
      }
    }, true);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }
})();
