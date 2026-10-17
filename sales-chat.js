/**
 * FlexiTap POS - Elevated Sales & Inquiries Live Chat Widget
 * -------------------------------------------------------------
 * Features:
 * - Omnichannel live chat connecting directly to Dev Portal Support Desk
 * - Instant 24/7 Smart FAQ & Hardware Knowledge Base Responder
 * - Interactive 3-step Venue & Terminal Qualification micro-flow
 * - Real-time two-way messaging via Supabase Realtime (support_sessions / support_messages)
 * - Cross-page session & conversation persistence via localStorage
 * - Web Audio API synthesized notification chimes (zero external sound file dependencies)
 * - Automated lead capture into Supabase 'leads' table and Google Apps Script email webhook
 */

(function () {
  'use strict';

  // Prevent multiple initializations if script is included twice
  if (window.__FLEXITAP_SALES_CHAT_INITIALIZED__) return;
  window.__FLEXITAP_SALES_CHAT_INITIALIZED__ = true;

  // Supabase Configuration
  const SUPABASE_URL = 'https://ezaqdnnecfkmqjdzigrf.supabase.co';
  const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6YXFkbm5lY2ZrbXFqZHppZ3JmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczOTE0NDEsImV4cCI6MjA5Mjk2NzQ0MX0.QoJryCMZwf_haqFZVr4LGaJqQR0Ux7yMyzvr2xLiJQE';
  const GOOGLE_WEBHOOK_URL = 'https://script.google.com/macros/s/AKfycbzJu1CEi1qhT-k7Qc_tisMN7vXbbCuGymgiMMk_K6PGIMnrUHkIrYEuQFMCviZfaYvoQw/exec';

  let sbClient = null;
  function getSupabase() {
    if (sbClient) return sbClient;
    if (window.supabaseClient) {
      sbClient = window.supabaseClient;
      return sbClient;
    }
    if (window.supabase && typeof window.supabase.createClient === 'function') {
      sbClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      return sbClient;
    }
    return null;
  }

  // Local Storage Keys
  const STORAGE_KEYS = {
    SESSION_ID: 'flexitap_chat_session_id',
    VISITOR_INFO: 'flexitap_chat_visitor_info',
    MESSAGES: 'flexitap_chat_messages',
    IS_OPEN: 'flexitap_chat_is_open',
    LAST_READ: 'flexitap_chat_last_read'
  };

  // State Management
  let state = {
    isOpen: false,
    sessionId: null,
    visitor: { name: '', email: '', phone: '', venue: '', stations: '' },
    messages: [],
    realtimeChannel: null,
    isTyping: false,
    qualificationStep: 0,
    qualificationData: {}
  };

  // Load state from localStorage
  function loadPersistedState() {
    try {
      state.sessionId = localStorage.getItem(STORAGE_KEYS.SESSION_ID) || null;
      const v = localStorage.getItem(STORAGE_KEYS.VISITOR_INFO);
      if (v) state.visitor = JSON.parse(v);
      const m = localStorage.getItem(STORAGE_KEYS.MESSAGES);
      if (m) state.messages = JSON.parse(m);
      state.isOpen = localStorage.getItem(STORAGE_KEYS.IS_OPEN) === 'true';
    } catch (e) {
      console.warn('FlexiTap Chat: Error loading localStorage state', e);
    }
  }

  function persistState() {
    try {
      if (state.sessionId) localStorage.setItem(STORAGE_KEYS.SESSION_ID, state.sessionId);
      if (state.visitor) localStorage.setItem(STORAGE_KEYS.VISITOR_INFO, JSON.stringify(state.visitor));
      if (state.messages) localStorage.setItem(STORAGE_KEYS.MESSAGES, JSON.stringify(state.messages.slice(-50)));
      localStorage.setItem(STORAGE_KEYS.IS_OPEN, state.isOpen ? 'true' : 'false');
    } catch (e) {
      console.warn('FlexiTap Chat: Error persisting localStorage state', e);
    }
  }

  // Web Audio API Synthesized Chime (Crisp notification sound)
  function playNotificationChime() {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const now = ctx.currentTime;

      // Note 1 (D5 - 587.33 Hz)
      const osc1 = ctx.createOscillator();
      const gain1 = ctx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(587.33, now);
      gain1.gain.setValueAtTime(0.12, now);
      gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(now);
      osc1.stop(now + 0.35);

      // Note 2 (A5 - 880.00 Hz)
      const osc2 = ctx.createOscillator();
      const gain2 = ctx.createGain();
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(880.00, now + 0.12);
      gain2.gain.setValueAtTime(0.15, now + 0.12);
      gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.55);
      osc2.connect(gain2);
      gain2.connect(ctx.destination);
      osc2.start(now + 0.12);
      osc2.stop(now + 0.55);
    } catch (err) {
      // AudioContext could be blocked by browser autoplay policy before user interaction
    }
  }

  // Inject Self-Contained Styles
  function injectStyles() {
    if (document.getElementById('flexitap-chat-styles')) return;
    const style = document.createElement('style');
    style.id = 'flexitap-chat-styles';
    style.textContent = `
      /* FlexiTap Sales Chat Widget Styles - Dynamically Fluid Across All Screen Sizes */
      #ft-chat-launcher {
        position: fixed;
        bottom: clamp(20px, 2.5vh, 32px);
        right: clamp(20px, 2.5vw, 32px);
        width: clamp(56px, 4.2vw, 68px);
        height: clamp(56px, 4.2vw, 68px);
        border-radius: 50%;
        background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
        border: 2px solid rgba(255, 255, 255, 0.22);
        color: #ffffff;
        box-shadow: 0 10px 32px rgba(37, 99, 235, 0.45), 0 4px 14px rgba(0,0,0,0.35);
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 99999;
        transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.25s ease;
        outline: none;
      }
      #ft-chat-launcher:hover {
        transform: scale(1.08);
        box-shadow: 0 16px 40px rgba(37, 99, 235, 0.6), 0 6px 18px rgba(0,0,0,0.4);
      }
      #ft-chat-launcher:active {
        transform: scale(0.96);
      }
      .ft-launcher-pulse {
        position: absolute;
        top: 2px;
        right: 2px;
        width: 14px;
        height: 14px;
        border-radius: 50%;
        background: #10b981;
        border: 2px solid #090d16;
        box-shadow: 0 0 10px #10b981;
        animation: ftPulse 2s infinite;
      }
      @keyframes ftPulse {
        0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7); }
        70% { transform: scale(1.05); box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
        100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
      }
      .ft-launcher-badge {
        position: absolute;
        top: -4px;
        left: -4px;
        background: #ef4444;
        color: #ffffff;
        font-size: 11px;
        font-weight: 800;
        padding: 2px 7px;
        border-radius: 10px;
        border: 2px solid #090d16;
        display: none;
      }

      /* Chat Window - Fluid Tablet & Desktop Size */
      #ft-chat-window {
        position: fixed;
        bottom: clamp(84px, 9vh, 112px);
        right: clamp(20px, 2.5vw, 32px);
        width: clamp(380px, 28vw, 480px);
        height: clamp(540px, 72vh, 720px);
        max-height: calc(100dvh - 100px);
        background: #090d16;
        border: 1px solid rgba(255, 255, 255, 0.16);
        border-radius: clamp(18px, 1.8vw, 24px);
        box-shadow: 0 28px 70px rgba(0, 0, 0, 0.8), 0 0 2px rgba(255, 255, 255, 0.25);
        display: none;
        flex-direction: column;
        overflow: hidden;
        z-index: 99998;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        color: #f8fafc;
        animation: ftFadeInUp 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      }
      @keyframes ftFadeInUp {
        from { opacity: 0; transform: translateY(16px) scale(0.98); }
        to { opacity: 1; transform: translateY(0) scale(1); }
      }

      /* Header */
      .ft-chat-header {
        background: rgba(15, 23, 42, 0.95);
        backdrop-filter: blur(12px);
        padding: clamp(14px, 1.6vh, 18px) clamp(16px, 1.6vw, 22px);
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .ft-header-brand {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .ft-avatar {
        width: 36px;
        height: 36px;
        border-radius: 10px;
        background: linear-gradient(135deg, #1e293b, #0f172a);
        border: 1px solid rgba(59, 130, 246, 0.4);
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
        font-size: 18px;
      }
      .ft-avatar-status {
        position: absolute;
        bottom: -2px;
        right: -2px;
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: #10b981;
        border: 2px solid #090d16;
      }
      .ft-header-title {
        font-size: 13.5px;
        font-weight: 800;
        color: #ffffff;
        letter-spacing: -0.2px;
      }
      .ft-header-sub {
        font-size: 11px;
        color: #94a3b8;
        display: flex;
        align-items: center;
        gap: 4px;
      }
      .ft-header-actions {
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .ft-header-btn {
        background: transparent;
        border: none;
        color: #94a3b8;
        width: 28px;
        height: 28px;
        border-radius: 6px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 16px;
        transition: background 0.15s, color 0.15s;
      }
      .ft-header-btn:hover {
        background: rgba(255, 255, 255, 0.08);
        color: #ffffff;
      }

      /* Body */
      .ft-chat-body {
        flex: 1;
        padding: 16px;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
        gap: 12px;
        background: radial-gradient(circle at top right, rgba(37, 99, 235, 0.05) 0%, rgba(9, 13, 22, 0.95) 100%);
      }
      .ft-chat-body::-webkit-scrollbar {
        width: 5px;
      }
      .ft-chat-body::-webkit-scrollbar-track {
        background: transparent;
      }
      .ft-chat-body::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.15);
        border-radius: 4px;
      }

      /* Messages */
      .ft-msg {
        max-width: 84%;
        padding: 11px 14px;
        border-radius: 14px;
        font-size: 12.8px;
        line-height: 1.48;
        word-break: break-word;
        box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
        animation: ftFadeIn 0.2s ease;
      }
      @keyframes ftFadeIn {
        from { opacity: 0; transform: translateY(6px); }
        to { opacity: 1; transform: translateY(0); }
      }
      .ft-msg.bot {
        align-self: flex-start;
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.1);
        color: #f1f5f9;
        border-bottom-left-radius: 3px;
      }
      .ft-msg.agent {
        align-self: flex-start;
        background: linear-gradient(135deg, rgba(37, 99, 235, 0.18), rgba(30, 64, 175, 0.25));
        border: 1px solid rgba(59, 130, 246, 0.45);
        color: #ffffff;
        border-bottom-left-radius: 3px;
      }
      .ft-msg.agent-badge {
        font-size: 10px;
        font-weight: 800;
        text-transform: uppercase;
        color: #60a5fa;
        margin-bottom: 4px;
        display: flex;
        align-items: center;
        gap: 4px;
      }
      .ft-msg.visitor {
        align-self: flex-end;
        background: linear-gradient(135deg, #2563eb, #1d4ed8);
        border: 1px solid rgba(255, 255, 255, 0.2);
        color: #ffffff;
        border-bottom-right-radius: 3px;
      }
      .ft-msg-ts {
        font-size: 9.5px;
        color: rgba(255, 255, 255, 0.5);
        margin-top: 4px;
        display: block;
        text-align: right;
      }

      /* Quick Option Chips */
      .ft-chips-container {
        display: flex;
        flex-direction: column;
        gap: 7px;
        margin-top: 4px;
      }
      .ft-chip-btn {
        background: rgba(59, 130, 246, 0.08);
        border: 1px solid rgba(59, 130, 246, 0.3);
        color: #93c5fd;
        padding: 9px 12px;
        border-radius: 9px;
        font-size: 12px;
        font-weight: 600;
        text-align: left;
        cursor: pointer;
        transition: all 0.15s ease;
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .ft-chip-btn:hover {
        background: rgba(59, 130, 246, 0.2);
        border-color: #3b82f6;
        color: #ffffff;
        transform: translateX(3px);
      }
      .ft-chip-btn.accent {
        background: rgba(16, 185, 129, 0.1);
        border-color: rgba(16, 185, 129, 0.35);
        color: #34d399;
      }
      .ft-chip-btn.accent:hover {
        background: rgba(16, 185, 129, 0.22);
        border-color: #10b981;
        color: #ffffff;
      }

      /* Micro-Forms & Interactive Cards */
      .ft-chat-card {
        background: rgba(15, 23, 42, 0.7);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 12px;
        padding: 12px;
        margin-top: 6px;
      }
      .ft-form-input {
        width: 100%;
        padding: 9px 11px;
        margin-bottom: 8px;
        background: #0f172a;
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 7px;
        color: #ffffff;
        font-size: 12px;
        box-sizing: border-box;
        outline: none;
        transition: border-color 0.15s;
      }
      .ft-form-input:focus {
        border-color: #3b82f6;
      }
      .ft-form-submit {
        width: 100%;
        padding: 9px;
        background: #10b981;
        border: none;
        border-radius: 7px;
        color: #ffffff;
        font-size: 12px;
        font-weight: 700;
        cursor: pointer;
        transition: background 0.15s;
      }
      .ft-form-submit:hover {
        background: #059669;
      }

      /* Typing indicator */
      .ft-typing-indicator {
        display: none;
        align-self: flex-start;
        padding: 8px 12px;
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        gap: 4px;
        align-items: center;
      }
      .ft-typing-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #94a3b8;
        animation: ftBlink 1.4s infinite both;
      }
      .ft-typing-dot:nth-child(2) { animation-delay: 0.2s; }
      .ft-typing-dot:nth-child(3) { animation-delay: 0.4s; }
      @keyframes ftBlink {
        0%, 80%, 100% { opacity: 0.2; transform: scale(0.8); }
        40% { opacity: 1; transform: scale(1.1); }
      }

      /* Footer Input Bar */
      .ft-chat-footer {
        padding: 10px 14px;
        background: rgba(15, 23, 42, 0.95);
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        display: flex;
        gap: 8px;
        align-items: center;
      }
      .ft-chat-input {
        flex: 1;
        background: #090d16;
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 9999px;
        padding: 10px 16px;
        color: #ffffff;
        font-size: 12.5px;
        outline: none;
        transition: border-color 0.15s;
      }
      .ft-chat-input:focus {
        border-color: #3b82f6;
      }
      .ft-chat-input::placeholder {
        color: #64748b;
      }
      .ft-chat-send-btn {
        width: 36px;
        height: 36px;
        border-radius: 50%;
        background: #2563eb;
        border: none;
        color: #ffffff;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: background 0.15s, transform 0.15s;
        flex-shrink: 0;
      }
      .ft-chat-send-btn:hover {
        background: #1d4ed8;
        transform: scale(1.05);
      }
      .ft-chat-send-btn:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }

      /* Adaptive Mobile & Tablet Media Queries */
      @media (max-width: 640px) {
        #ft-chat-window {
          position: fixed;
          bottom: 0 !important;
          left: 0 !important;
          right: 0 !important;
          width: 100% !important;
          max-width: 100% !important;
          height: min(88dvh, 620px) !important;
          max-height: 90dvh !important;
          border-radius: 22px 22px 0 0 !important;
          border-left: none !important;
          border-right: none !important;
          border-bottom: none !important;
          box-shadow: 0 -10px 40px rgba(0, 0, 0, 0.85);
        }
        #ft-chat-launcher {
          bottom: 18px;
          right: 18px;
          width: 54px;
          height: 54px;
        }
        .ft-chat-header {
          padding: 14px 18px;
        }
        .ft-chat-body {
          padding: 16px;
          gap: 12px;
        }
        .ft-msg {
          max-width: 88%;
          font-size: 14px;
          line-height: 1.5;
        }
        .ft-chat-input, .ft-form-input {
          font-size: 16px !important; /* Prevents auto-zoom on iOS Safari */
        }
        .ft-chip-btn {
          min-height: 44px;
          padding: 12px 16px;
          font-size: 13.5px;
        }
        .ft-chat-footer {
          padding: 12px 16px;
        }
      }

      @media (min-width: 641px) and (max-width: 1024px) {
        #ft-chat-window {
          width: clamp(380px, 46vw, 440px);
          height: clamp(520px, 68vh, 620px);
        }
        .ft-msg {
          font-size: 13.5px;
        }
      }

      @media (min-width: 1025px) {
        .ft-msg {
          font-size: 14px;
          line-height: 1.55;
          padding: 13px 17px;
        }
        .ft-chip-btn {
          font-size: 13.5px;
          padding: 11px 16px;
        }
        .ft-chat-input {
          font-size: 14px;
          padding: 12px 18px;
        }
      }
    `;
    document.head.appendChild(style);
  }

  // Remove any legacy chat buttons or panels
  function cleanupLegacyElements() {
    const oldBtn = document.getElementById('chat-btn');
    if (oldBtn) oldBtn.remove();
    const oldPanel = document.getElementById('sales-chat-panel');
    if (oldPanel) oldPanel.remove();
  }

  // Build the DOM structure
  function buildChatUI() {
    cleanupLegacyElements();

    // Launcher button
    const launcher = document.createElement('button');
    launcher.id = 'ft-chat-launcher';
    launcher.setAttribute('aria-label', 'Open FlexiTap Sales & Inquiry Chat');
    launcher.title = 'FlexiTap Sales & Inquiries Desk';
    launcher.innerHTML = `
      <div class="ft-launcher-pulse" id="ft-launcher-pulse"></div>
      <div class="ft-launcher-badge" id="ft-launcher-badge">1</div>
      <span id="ft-launcher-icon" style="font-size: 24px; line-height: 1;">💬</span>
    `;

    // Window container
    const chatWindow = document.createElement('div');
    chatWindow.id = 'ft-chat-window';
    chatWindow.innerHTML = `
      <div class="ft-chat-header">
        <div class="ft-header-brand">
          <div class="ft-avatar">
            ⚡
            <div class="ft-avatar-status"></div>
          </div>
          <div>
            <div class="ft-header-title">FlexiTap Sales &amp; Inquiries</div>
            <div class="ft-header-sub">
              <span>●</span> Online • Replies in ~2m
            </div>
          </div>
        </div>
        <div class="ft-header-actions">
          <button class="ft-header-btn" id="ft-btn-reset" title="Restart Conversation">↺</button>
          <button class="ft-header-btn" id="ft-btn-close" title="Close Chat">&times;</button>
        </div>
      </div>

      <div class="ft-chat-body" id="ft-chat-messages">
        <!-- Messages will be appended here -->
      </div>

      <div class="ft-typing-indicator" id="ft-typing-indicator">
        <span style="font-size: 11px; color: #94a3b8; margin-right: 4px;">Staff typing</span>
        <div class="ft-typing-dot"></div>
        <div class="ft-typing-dot"></div>
        <div class="ft-typing-dot"></div>
      </div>

      <form class="ft-chat-footer" id="ft-chat-form">
        <input type="text" class="ft-chat-input" id="ft-chat-input" placeholder="Ask about hardware, pricing, offline..." autocomplete="off" />
        <button type="submit" class="ft-chat-send-btn" id="ft-chat-send" title="Send message">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <line x1="22" y1="2" x2="11" y2="13"></line>
            <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
          </svg>
        </button>
      </form>
    `;

    document.body.appendChild(launcher);
    document.body.appendChild(chatWindow);

    // Event Listeners
    launcher.addEventListener('click', toggleChat);
    document.getElementById('ft-btn-close').addEventListener('click', toggleChat);
    document.getElementById('ft-btn-reset').addEventListener('click', resetConversation);
    document.getElementById('ft-chat-form').addEventListener('submit', handleUserInput);
  }

  // Toggle Chat Visibility
  function toggleChat() {
    state.isOpen = !state.isOpen;
    const win = document.getElementById('ft-chat-window');
    const icon = document.getElementById('ft-launcher-icon');
    const launcher = document.getElementById('ft-chat-launcher');
    const badge = document.getElementById('ft-launcher-badge');

    if (launcher) launcher.classList.toggle('ft-open', state.isOpen);

    if (state.isOpen) {
      win.style.display = 'flex';
      icon.innerHTML = '&times;';
      icon.style.fontSize = '';
      if (badge) badge.style.display = 'none';
      scrollToBottom();
      const input = document.getElementById('ft-chat-input');
      if (input && window.innerWidth > 640) setTimeout(() => input.focus(), 150);
    } else {
      win.style.display = 'none';
      icon.innerHTML = '💬';
      icon.style.fontSize = '';
    }
    persistState();
  }

  function scrollToBottom() {
    const box = document.getElementById('ft-chat-messages');
    if (box) {
      setTimeout(() => {
        box.scrollTop = box.scrollHeight;
      }, 50);
    }
  }

  function formatTime(isoOrDate) {
    const d = isoOrDate ? new Date(isoOrDate) : new Date();
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  // Render a message
  function renderMessage(msg) {
    const box = document.getElementById('ft-chat-messages');
    if (!box) return;

    const div = document.createElement('div');
    div.className = `ft-msg ${msg.sender}`;

    let headerHtml = '';
    if (msg.sender === 'agent') {
      headerHtml = `<div class="ft-msg agent-badge">🛡️ ${msg.staffName || 'FlexiTap Sales Engineer'}</div>`;
    }

    div.innerHTML = `
      ${headerHtml}
      <div class="ft-msg-content">${msg.text}</div>
      <span class="ft-msg-ts">${formatTime(msg.ts)}</span>
    `;

    box.appendChild(div);
    scrollToBottom();
  }

  // Append & Persist Message
  function addMessage(sender, text, options = {}) {
    const msg = {
      sender,
      text,
      ts: new Date().toISOString(),
      staffName: options.staffName || null
    };
    state.messages.push(msg);
    renderMessage(msg);
    persistState();

    if (sender === 'agent' && !state.isOpen) {
      const badge = document.getElementById('ft-launcher-badge');
      if (badge) {
        badge.style.display = 'block';
        badge.innerText = '1';
      }
      playNotificationChime();
    }
  }

  // Welcome Greeting & Quick Options
  function renderInitialGreeting() {
    if (state.messages.length > 0) {
      // Re-render saved messages
      state.messages.forEach(renderMessage);
      return;
    }

    // Default first greeting
    addMessage('bot', `
      👋 <strong>Welcome to FlexiTap POS!</strong>
      <br>Our engineering and sales desk is standing by. How can we configure your counter setup today?
      <div class="ft-chips-container" style="margin-top: 10px;">
        <button class="ft-chip-btn accent" onclick="window.FlexiTapChat.startLiveChat()">
          💬 Chat Live with an Engineer
        </button>
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.startQualification()">
          🏢 Find My Setup (Venue / Terminals)
        </button>
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.showPricingFAQ()">
          💳 VIP Pricing &amp; 100% Guarantee
        </button>
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.showBookingModal()">
          📅 Book a 1-on-1 Live Walkthrough
        </button>
      </div>
    `);
  }

  // Reset conversation
  function resetConversation() {
    if (!confirm('Restart sales conversation and clear history?')) return;
    state.messages = [];
    state.qualificationStep = 0;
    state.qualificationData = {};
    const box = document.getElementById('ft-chat-messages');
    if (box) box.innerHTML = '';
    renderInitialGreeting();
    persistState();
  }

  // Knowledge Base / Smart FAQ Intent Matcher
  function matchSmartFAQ(query) {
    const q = query.toLowerCase();

    // 1. Hardware & BYOD
    if (q.includes('printer') || q.includes('epson') || q.includes('star') || q.includes('thermal') || q.includes('receipt')) {
      return `
        <strong>🖨️ Printer &amp; Hardware Support:</strong><br>
        FlexiTap supports industry-standard thermal receipt &amp; kitchen printers over <strong>LAN (Ethernet), Wi-Fi, Bluetooth, and USB</strong> (ESC/POS protocol). Works with Star Micronics (TSP100/143, mC-Print), Epson TM-T88 / TM-m30, Bixolon, and Sunmi integrated printers. No proprietary printer lock-in!
      `;
    }

    if (q.includes('ipad') || q.includes('tablet') || q.includes('android') || q.includes('device') || q.includes('byod') || q.includes('hardware') || q.includes('windows')) {
      return `
        <strong>📱 Bring Your Own Device (BYOD):</strong><br>
        FlexiTap runs on off-the-shelf tablets and computers:
        <br>• <strong>Apple iPads</strong> (iOS 14+)
        <br>• <strong>Android Tablets</strong> (Android 9+)
        <br>• <strong>Windows Touch PCs</strong> (Windows 10/11)
        <br>Stop leasing locked hardware for thousands per year. Bring your existing tablets or order our pre-configured countertop bundles.
      `;
    }

    // 2. Offline Speed & Reliability
    if (q.includes('offline') || q.includes('internet') || q.includes('sync') || q.includes('down') || q.includes('wifi') || q.includes('network')) {
      return `
        <strong>⚡ True Offline-First Architecture:</strong><br>
        Orders write locally to device storage in milliseconds. If your internet fails during dinner rush, your register, kitchen ticket routing, and receipt printing continue uninterrupted. Once connection restores, data synchronizes to the cloud seamlessly.
      `;
    }

    // 3. Pricing & Founders Pass
    if (q.includes('price') || q.includes('pricing') || q.includes('cost') || q.includes('fee') || q.includes('rate') || q.includes('vip') || q.includes('annual')) {
      return `
        <strong>💳 Founders VIP Annual Pass:</strong><br>
        • <strong>Plus ($290/yr):</strong> Up to 5 terminals, KDS kitchen screens, customer loyalty &amp; online portal.<br>
        • <strong>Pro ($590/yr):</strong> Unlimited terminals, custom table floor plans, ingredient recipe inventory &amp; 24/7 remote support.<br>
        <em>Includes a 7-day 100% money-back live shift guarantee. Fixed rate for life!</em>
      `;
    }

    // 4. Kitchen Display System (KDS)
    if (q.includes('kds') || q.includes('kitchen') || q.includes('cook') || q.includes('screen') || q.includes('display')) {
      return `
        <strong>🍳 Real-Time Kitchen Display System (KDS):</strong><br>
        Turn any inexpensive Android or iPad tablet into a high-visibility kitchen bumping screen with color-coded timers, ticket splitting, and expo line audio chimes. Included free in Founders Pass!
      `;
    }

    // 5. Booking / Demo
    if (q.includes('demo') || q.includes('walkthrough') || q.includes('schedule') || q.includes('call') || q.includes('meeting')) {
      return `
        <strong>📅 Book a 1-on-1 Walkthrough:</strong><br>
        Schedule a 15-minute screen-share with our core engineering desk. We'll simulate your exact venue floor plan and order workflow.
        <br><br>
        <button class="ft-chip-btn accent" onclick="window.FlexiTapChat.showBookingModal()">
          📅 Open Demo Scheduler
        </button>
      `;
    }

    return null;
  }

  // Qualification Micro-Flow
  function startQualification() {
    state.qualificationStep = 1;
    addMessage('bot', `
      <strong>🏢 Step 1 of 3: What type of venue do you operate?</strong>
      <div class="ft-chips-container" style="margin-top: 8px;">
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickVenue('Cafe / Coffee / Bakery')">☕ Cafe / Bakery</button>
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickVenue('Restaurant / Bar / QSR')">🍽️ Restaurant / Bar</button>
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickVenue('Food Truck / Pop-Up / Event')">🚚 Food Truck / Pop-Up</button>
        <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickVenue('Retail / Boutique / Grocery')">🛍️ Retail / Boutique</button>
      </div>
    `);
  }

  function pickVenue(venue) {
    state.qualificationData.venue = venue;
    state.qualificationStep = 2;
    addMessage('visitor', venue);
    setTimeout(() => {
      addMessage('bot', `
        <strong>🖥️ Step 2 of 3: How many registers or display stations do you need?</strong>
        <div class="ft-chips-container" style="margin-top: 8px;">
          <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickStations('1 Counter Register')">1 Single Counter Station</button>
          <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickStations('2-4 Multi-Screen + Kitchen KDS')">2-4 Registers + Kitchen KDS</button>
          <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickStations('5+ Enterprise / Multi-Room')">5+ Multi-Station Setup</button>
        </div>
      `);
    }, 200);
  }

  function pickStations(stations) {
    state.qualificationData.stations = stations;
    state.qualificationStep = 3;
    addMessage('visitor', stations);
    setTimeout(() => {
      addMessage('bot', `
        <strong>📱 Step 3 of 3: What is your device preference?</strong>
        <div class="ft-chips-container" style="margin-top: 8px;">
          <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickHardware('Bring Our Own iPads / Android Tablets')">Bring My Own Tablets (Save Money)</button>
          <button class="ft-chip-btn" onclick="window.FlexiTapChat.pickHardware('Need Complete Countertop Hardware Bundle')">Need Pre-Configured Hardware Bundle</button>
        </div>
      `);
    }, 200);
  }

  function pickHardware(hardware) {
    state.qualificationData.hardware = hardware;
    addMessage('visitor', hardware);

    const isLarge = state.qualificationData.stations.includes('5+') || state.qualificationData.stations.includes('2-4');
    const recommendedTier = isLarge ? 'Founders VIP Pro ($590/year)' : 'Founders VIP Plus ($290/year)';

    setTimeout(() => {
      addMessage('bot', `
        ✅ <strong>Custom Setup Recommendation:</strong><br>
        • <strong>Venue:</strong> ${state.qualificationData.venue}<br>
        • <strong>Stations:</strong> ${state.qualificationData.stations}<br>
        • <strong>Hardware:</strong> ${state.qualificationData.hardware}<br>
        • <strong>Recommended Tier:</strong> <span style="color:#34d399; font-weight:800;">${recommendedTier}</span><br>
        • <strong>Estimated Savings:</strong> ~$1,400/yr vs. Toast / Square terminal subscriptions.
        <div class="ft-chat-card" style="margin-top: 10px;">
          <div style="font-size: 11.5px; font-weight: 700; color: #93c5fd; margin-bottom: 6px;">📩 Send custom spec &amp; VIP offer to your email:</div>
          <form onsubmit="window.FlexiTapChat.submitLeadFromCard(event)">
            <input type="text" id="ft-lead-name" class="ft-form-input" placeholder="Your Name / Business Name" required />
            <input type="email" id="ft-lead-email" class="ft-form-input" placeholder="Business Email (owner@venue.com)" required />
            <input type="tel" id="ft-lead-phone" class="ft-form-input" placeholder="Phone Number (Optional)" />
            <button type="submit" class="ft-form-submit">Lock In Founders Rate &amp; Connect</button>
          </form>
        </div>
      `);
    }, 300);
  }

  // Handle lead submission from card
  async function submitLeadFromCard(e) {
    e.preventDefault();
    const name = document.getElementById('ft-lead-name').value.trim();
    const email = document.getElementById('ft-lead-email').value.trim();
    const phone = document.getElementById('ft-lead-phone').value.trim();
    const btn = e.target.querySelector('button');
    btn.innerText = 'Connecting...';
    btn.disabled = true;

    state.visitor.name = name;
    state.visitor.email = email;
    state.visitor.phone = phone;
    state.visitor.venue = state.qualificationData.venue || '';
    state.visitor.stations = state.qualificationData.stations || '';
    persistState();

    const specSummary = `Lead Qualification: ${state.visitor.venue} | ${state.visitor.stations} | ${state.qualificationData.hardware || 'BYOD'}`;

    // Record into Supabase 'leads' table
    await saveLeadToDatabase({
      businessName: name,
      email: email,
      phone: phone,
      message: specSummary
    });

    // Create live support session so Dev Portal can reply
    await initLiveChatSession(specSummary);

    addMessage('visitor', `My contact details: ${name} (${email}${phone ? ', Tel: ' + phone : ''})`);
    addMessage('bot', `
      🎉 <strong>Thank you, ${name}!</strong>
      <br>Your configuration is locked in and your inquiry is routed to our live sales &amp; engineering desk.
      <br><br>You can now type any questions directly below — a team member will reply here in real-time!
    `);
  }

  // Start live chat directly
  function startLiveChat() {
    if (state.visitor.name && state.visitor.email) {
      addMessage('bot', `
        🟢 <strong>You are connected to Live Support!</strong>
        <br>Type your message below and a sales engineer will answer directly.
      `);
      initLiveChatSession('Live Chat connected from website');
      return;
    }

    addMessage('bot', `
      <strong>Connect to a Live Sales Engineer:</strong>
      <div class="ft-chat-card" style="margin-top: 8px;">
        <div style="font-size: 11.5px; font-weight: 700; color: #93c5fd; margin-bottom: 6px;">Please enter your details to connect:</div>
        <form onsubmit="window.FlexiTapChat.submitContactForChat(event)">
          <input type="text" id="ft-direct-name" class="ft-form-input" placeholder="Your Name / Business" required />
          <input type="email" id="ft-direct-email" class="ft-form-input" placeholder="Email Address" required />
          <input type="tel" id="ft-direct-phone" class="ft-form-input" placeholder="Phone Number (Optional)" />
          <button type="submit" class="ft-form-submit">Start Live Conversation</button>
        </form>
      </div>
    `);
  }

  async function submitContactForChat(e) {
    e.preventDefault();
    const name = document.getElementById('ft-direct-name').value.trim();
    const email = document.getElementById('ft-direct-email').value.trim();
    const phone = document.getElementById('ft-direct-phone').value.trim();
    const btn = e.target.querySelector('button');
    btn.innerText = 'Connecting...';
    btn.disabled = true;

    state.visitor.name = name;
    state.visitor.email = email;
    state.visitor.phone = phone;
    persistState();

    await saveLeadToDatabase({
      businessName: name,
      email: email,
      phone: phone,
      message: 'Direct live chat started from website'
    });

    await initLiveChatSession('Live Chat inquiry started');

    addMessage('visitor', `Hi, I'm ${name} (${email}). I have a question about FlexiTap.`);
    addMessage('bot', `
      🟢 <strong>Connected!</strong>
      <br>Our engineering desk has received your session notification. Feel free to type your question below!
    `);
  }

  // Save to Supabase 'leads' table and trigger email notification
  async function saveLeadToDatabase({ businessName, email, phone, message }) {
    const sb = getSupabase();
    if (sb) {
      try {
        await sb.from('leads').insert([{
          business_name: businessName,
          contact_email: email,
          contact_phone: phone,
          message: message,
          status: 'new'
        }]);
      } catch (err) {
        console.warn('FlexiTap Chat: Error saving lead to Supabase', err);
      }
    }

    // Google Apps Script Webhook Notification
    try {
      if (GOOGLE_WEBHOOK_URL) {
        fetch(GOOGLE_WEBHOOK_URL, {
          method: 'POST',
          mode: 'no-cors',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            notification_type: 'sales_inquiry_lead',
            store_name: businessName,
            recipient_email: 'info@flexitapapp.com',
            contact_email: email,
            contact_phone: phone,
            subject: `[New Sales Inquiry] ${businessName} (${email})`,
            details: message,
            timestamp: new Date().toISOString()
          })
        }).catch(() => {});
      }
    } catch (e) {
      // Ignore background notification error
    }
  }

  // Initialize or Attach to Supabase support_sessions
  async function initLiveChatSession(initialNote = '') {
    const sb = getSupabase();
    if (!sb) return;

    try {
      // 1. Look for existing open session for this visitor
      const visitorEmail = state.visitor.email || `visitor-${Math.random().toString(36).substring(2, 9)}@flexitap.guest`;
      let session = null;

      if (state.sessionId) {
        const { data: existing } = await sb
          .from('support_sessions')
          .select('*')
          .eq('id', state.sessionId)
          .eq('status', 'open')
          .single();
        if (existing) session = existing;
      }

      if (!session && state.visitor.email) {
        const { data: byEmail } = await sb
          .from('support_sessions')
          .select('*')
          .eq('merchant_email', state.visitor.email)
          .eq('status', 'open')
          .order('updated_at', { ascending: false })
          .limit(1);
        if (byEmail && byEmail.length > 0) session = byEmail[0];
      }

      // 2. Create session if missing
      if (!session) {
        const storeLabel = state.visitor.name ? `Lead: ${state.visitor.name}` : `Lead: Website Visitor`;
        const { data: created, error } = await sb
          .from('support_sessions')
          .insert([{
            store_name: storeLabel,
            merchant_email: visitorEmail,
            status: 'open',
            updated_at: new Date().toISOString()
          }])
          .select()
          .single();

        if (error) {
          console.warn('FlexiTap Chat: Error creating support_session', error);
          return;
        }
        session = created;
      }

      state.sessionId = session.id;
      persistState();

      // 3. Subscribe to Realtime messages for this session
      subscribeToRealtimeSession(session.id);

      // 4. If initialNote provided and not yet sent, send it as initial lead context
      if (initialNote) {
        await sb.from('support_messages').insert([{
          session_id: session.id,
          sender_id: state.visitor.email || 'lead',
          sender_role: 'lead',
          message: initialNote
        }]);
      }
    } catch (err) {
      console.warn('FlexiTap Chat: Error in initLiveChatSession', err);
    }
  }

  // Subscribe to Realtime support_messages
  function subscribeToRealtimeSession(sessionId) {
    const sb = getSupabase();
    if (!sb || !sessionId) return;

    if (state.realtimeChannel) {
      try { sb.removeChannel(state.realtimeChannel); } catch (e) {}
    }

    state.realtimeChannel = sb
      .channel(`sales-desk-${sessionId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'support_messages',
        filter: `session_id=eq.${sessionId}`
      }, (payload) => {
        if (!payload.new) return;
        const newMsg = payload.new;

        // If sent by agent, display it
        if (newMsg.sender_role === 'agent') {
          // Check if message already displayed
          const exists = state.messages.some(m => m.text === newMsg.message && Math.abs(new Date(m.ts) - new Date(newMsg.created_at)) < 3000);
          if (!exists) {
            addMessage('agent', newMsg.message, {
              staffName: newMsg.sender_name || 'FlexiTap Sales Desk'
            });
          }
        }
      })
      .subscribe();
  }

  // Handle Freeform User Input
  async function handleUserInput(e) {
    e.preventDefault();
    const input = document.getElementById('ft-chat-input');
    const text = input.value.trim();
    if (!text) return;
    input.value = '';

    // Render visitor message
    addMessage('visitor', text);

    // 1. Check Smart FAQ Intent
    const faqAnswer = matchSmartFAQ(text);
    if (faqAnswer) {
      setTimeout(() => {
        addMessage('bot', faqAnswer);
      }, 350);
      return;
    }

    // 2. If visitor asked for human or unknown question, forward to Live Chat
    if (!state.sessionId) {
      // Prompt for contact info
      setTimeout(() => {
        addMessage('bot', `
          I want to ensure you get an exact answer from our engineering desk.
          <br><br>Could you share your name and email so a team member can assist you directly?
          <div class="ft-chat-card" style="margin-top: 8px;">
            <form onsubmit="window.FlexiTapChat.submitContactForChat(event)">
              <input type="text" id="ft-direct-name" class="ft-form-input" placeholder="Your Name" required />
              <input type="email" id="ft-direct-email" class="ft-form-input" placeholder="Your Email (owner@cafe.com)" required />
              <button type="submit" class="ft-form-submit">Connect with Engineering</button>
            </form>
          </div>
        `);
      }, 400);
      return;
    }

    // 3. Active session exists: Post to Supabase support_messages
    const sb = getSupabase();
    if (sb && state.sessionId) {
      try {
        await sb.from('support_messages').insert([{
          session_id: state.sessionId,
          sender_id: state.visitor.email || 'lead',
          sender_role: 'lead',
          message: text
        }]);

        // Update updated_at on session to bubble it up in Dev Portal
        await sb.from('support_sessions').update({
          updated_at: new Date().toISOString()
        }).eq('id', state.sessionId);

      } catch (err) {
        console.warn('FlexiTap Chat: Error sending message to Supabase', err);
      }
    }
  }

  // Show pricing FAQ in chat
  function showPricingFAQ() {
    addMessage('bot', `
      <strong>💳 Founders VIP Annual Pass:</strong><br>
      • <strong>Plus ($290/yr):</strong> Up to 5 terminals, KDS kitchen screens, customer loyalty &amp; online portal.<br>
      • <strong>Pro ($590/yr):</strong> Unlimited terminals, custom table floor plans, ingredient recipe inventory &amp; 24/7 remote standby.<br>
      <em>Includes 7-day 100% money-back live shift guarantee. Fixed for life with zero terminal leasing fees!</em>
      <div style="margin-top: 8px;">
        <button class="ft-chip-btn accent" onclick="window.FlexiTapChat.startLiveChat()">
          💬 Ask a Sales Question
        </button>
      </div>
    `);
  }

  // Trigger Demo Booking Modal if present on page, or show link
  function showBookingModal() {
    if (typeof window.openCalendarBooking === 'function') {
      window.openCalendarBooking();
      return;
    }
    const modal = document.getElementById('booking-modal');
    if (modal) {
      modal.style.display = 'flex';
      return;
    }
    // Fallback: direct scheduling link
    addMessage('bot', `
      <strong>📅 Schedule a Live 1-on-1 Walkthrough:</strong><br>
      Choose a date and time that fits your schedule, or email our engineering lead directly at <a href="mailto:info@flexitapapp.com" style="color:#60a5fa; font-weight:700;">info@flexitapapp.com</a>.
      <br><br>
      <a href="index.html#demo" style="display:inline-block; padding:8px 14px; background:#2563eb; color:#ffffff; border-radius:8px; font-weight:700; text-decoration:none; font-size:12px;">📅 Go to Demo Scheduler</a>
    `);
  }

  // Global API attached to window for HTML onclick callbacks
  window.FlexiTapChat = {
    toggle: toggleChat,
    startQualification,
    pickVenue,
    pickStations,
    pickHardware,
    submitLeadFromCard,
    startLiveChat,
    submitContactForChat,
    showPricingFAQ,
    showBookingModal,
    reset: resetConversation
  };

  // Legacy global wrapper for backwards compatibility
  window.toggleSalesChat = toggleChat;

  // Initialize on DOM ready
  function init() {
    loadPersistedState();
    injectStyles();
    buildChatUI();
    renderInitialGreeting();

    if (state.isOpen) {
      const win = document.getElementById('ft-chat-window');
      const icon = document.getElementById('ft-launcher-icon');
      const launcher = document.getElementById('ft-chat-launcher');
      if (launcher) launcher.classList.add('ft-open');
      if (win) win.style.display = 'flex';
      if (icon) {
        icon.innerHTML = '&times;';
        icon.style.fontSize = '';
      }
    }

    // If an existing session was saved, reconnect Realtime
    if (state.sessionId) {
      subscribeToRealtimeSession(state.sessionId);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
