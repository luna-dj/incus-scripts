/* ============================================================
   incus-scripts — site.js
   Search, filter, copy-to-clipboard, provider switcher.
   Pure ES6, no deps, no build step.
   ============================================================ */

(function () {
  'use strict';

  // ---------- Provider switcher (Codeberg ↔ GitHub) ----------
  const PROVIDERS = {
    codeberg: {
      label: 'Codeberg',
      ct: (slug) => `https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/ct/${slug}.sh`,
      install: (slug) => `https://codeberg.org/luna-dj/incus-scripts/raw/branch/main/install/${slug}-install.sh`,
    },
    github: {
      label: 'GitHub',
      ct: (slug) => `https://raw.githubusercontent.com/luna-dj/incus-scripts/main/ct/${slug}.sh`,
      install: (slug) => `https://raw.githubusercontent.com/luna-dj/incus-scripts/main/install/${slug}-install.sh`,
    },
  };

  const STORAGE_KEY = 'incus-scripts.provider';
  const urlParams = new URLSearchParams(window.location.search);
  let currentProvider = urlParams.get('provider') || localStorage.getItem(STORAGE_KEY) || 'codeberg';

  function setProvider(p) {
    if (!PROVIDERS[p]) return;
    currentProvider = p;
    localStorage.setItem(STORAGE_KEY, p);
    updateInstallCommands();
    const sel = document.getElementById('provider-select');
    if (sel) sel.value = p;
  }

  function installCommand(slug) {
    return `bash <(curl -fsSL ${PROVIDERS[currentProvider].ct(slug)})`;
  }

  function updateInstallCommands() {
    document.querySelectorAll('[data-install-slug]').forEach((el) => {
      const slug = el.getAttribute('data-install-slug');
      const code = el.querySelector('code');
      const btn = el.querySelector('[data-copy]');
      const cmd = installCommand(slug);
      if (code) code.textContent = cmd;
      if (btn) btn.setAttribute('data-copy', cmd);
    });
  }

  // ---------- Copy to clipboard ----------
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-copy]');
    if (!btn) return;
    const text = btn.getAttribute('data-copy');
    if (!text) return;
    const done = () => {
      const orig = btn.textContent;
      btn.textContent = '✓ Copied';
      btn.classList.add('copied');
      setTimeout(() => {
        btn.textContent = orig;
        btn.classList.remove('copied');
      }, 1600);
    };
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(done).catch(() => {
        fallbackCopy(text, done);
      });
    } else {
      fallbackCopy(text, done);
    }
  });

  function fallbackCopy(text, cb) {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); cb && cb(); }
    catch (e) {}
    document.body.removeChild(ta);
  }

  // ---------- Provider select ----------
  const providerSelect = document.getElementById('provider-select');
  if (providerSelect) {
    providerSelect.value = currentProvider;
    providerSelect.addEventListener('change', (e) => {
      setProvider(e.target.value);
    });
  }

  // ---------- Search ----------
  const searchInput = document.getElementById('search');
  const appGrid = document.getElementById('app-grid');
  if (searchInput && appGrid) {
    let q = '';
    let activeCategory = 'All';

    function visibleCards() {
      const cards = Array.from(appGrid.querySelectorAll('.app-card'));
      const ql = q.trim().toLowerCase();
      let count = 0;
      cards.forEach((card) => {
        const name = (card.dataset.name || '').toLowerCase();
        const desc = (card.dataset.desc || '').toLowerCase();
        const cat = card.dataset.category || '';
        const matchQ = !ql || name.includes(ql) || desc.includes(ql);
        const matchC = activeCategory === 'All' || cat === activeCategory;
        const show = matchQ && matchC;
        card.style.display = show ? '' : 'none';
        if (show) count++;
      });
      const visibleEl = document.getElementById('visible-count');
      if (visibleEl) visibleEl.textContent = count;
      const empty = document.getElementById('app-grid-empty');
      if (empty) empty.style.display = count === 0 ? '' : 'none';
    }

    searchInput.addEventListener('input', (e) => {
      q = e.target.value;
      visibleCards();
    });

    // "/" focuses search (GitHub-style)
    document.addEventListener('keydown', (e) => {
      if (e.key === '/' && document.activeElement !== searchInput && !e.metaKey && !e.ctrlKey) {
        e.preventDefault();
        searchInput.focus();
        searchInput.select();
      }
      if (e.key === 'Escape' && document.activeElement === searchInput) {
        searchInput.value = '';
        q = '';
        visibleCards();
        searchInput.blur();
      }
    });

    // Category filters
    document.querySelectorAll('.filter-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        activeCategory = btn.dataset.category;
        visibleCards();
        // Update URL hash so it's bookmarkable
        if (activeCategory === 'All') {
          history.replaceState(null, '', window.location.pathname);
        } else {
          history.replaceState(null, '', `#cat=${encodeURIComponent(activeCategory)}`);
        }
      });
    });

    // Restore category from hash
    const hash = window.location.hash;
    if (hash && hash.startsWith('#cat=')) {
      const cat = decodeURIComponent(hash.slice(5));
      const btn = document.querySelector(`.filter-btn[data-category="${CSS.escape(cat)}"]`);
      if (btn) btn.click();
    }
  }

  // ---------- Smooth scroll-reveal for cards ----------
  if ('IntersectionObserver' in window && appGrid) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
            io.unobserve(entry.target);
          }
        });
      },
      { rootMargin: '50px' }
    );
    Array.from(appGrid.querySelectorAll('.app-card')).forEach((c, i) => {
      c.style.opacity = '0';
      c.style.transform = 'translateY(8px)';
      c.style.transition = `opacity .25s ease ${Math.min(i, 12) * 12}ms, transform .25s ease ${Math.min(i, 12) * 12}ms`;
      io.observe(c);
    });
  }
})();
