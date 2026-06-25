/* ============================================================
   incus-scripts — site.js
   Search, filter, copy-to-clipboard, provider switcher,
   mobile drawer, search overlay, filter sheet, bottom action bar.
   Pure ES6, no deps, no build step.
   ============================================================ */

(function () {
  'use strict';

  // ──────────────────────────── Provider ────────────────────────────
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
    syncProviderSelects();
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

  function syncProviderSelects() {
    document.querySelectorAll('#provider-select, #drawer-provider').forEach((sel) => {
      if (sel.value !== currentProvider) sel.value = currentProvider;
    });
  }

  // ──────────────────────────── Copy to clipboard ────────────────────────────
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-copy]');
    if (!btn) return;
    const text = btn.getAttribute('data-copy');
    if (!text) return;
    const done = () => {
      const orig = btn.dataset.origText || btn.textContent;
      btn.dataset.origText = orig;
      btn.textContent = '✓ Copied';
      btn.classList.add('copied');
      setTimeout(() => {
        btn.textContent = orig;
        btn.classList.remove('copied');
      }, 1600);
    };
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text).then(done).catch(() => fallbackCopy(text, done));
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
    try { document.execCommand('copy'); cb && cb(); } catch (e) {}
    document.body.removeChild(ta);
  }

  // ──────────────────────────── Provider selects ────────────────────────────
  document.querySelectorAll('#provider-select, #drawer-provider').forEach((sel) => {
    if (sel) {
      sel.value = currentProvider;
      sel.addEventListener('change', (e) => setProvider(e.target.value));
    }
  });

  // ──────────────────────────── Mobile drawer ────────────────────────────
  const burger = document.getElementById('nav-burger');
  const drawer = document.getElementById('drawer');
  const drawerBackdrop = document.getElementById('drawer-backdrop');
  const drawerClose = document.getElementById('drawer-close');

  function openDrawer() {
    if (!drawer) return;
    drawer.classList.add('open');
    drawerBackdrop && drawerBackdrop.classList.add('open');
    drawer.setAttribute('aria-hidden', 'false');
    burger && burger.setAttribute('aria-expanded', 'true');
    document.body.style.overflow = 'hidden';
  }
  function closeDrawer() {
    if (!drawer) return;
    drawer.classList.remove('open');
    drawerBackdrop && drawerBackdrop.classList.remove('open');
    drawer.setAttribute('aria-hidden', 'true');
    burger && burger.setAttribute('aria-expanded', 'false');
    document.body.style.overflow = '';
  }
  burger && burger.addEventListener('click', () => {
    drawer.classList.contains('open') ? closeDrawer() : openDrawer();
  });
  drawerClose && drawerClose.addEventListener('click', closeDrawer);
  drawerBackdrop && drawerBackdrop.addEventListener('click', closeDrawer);
  // Close drawer when navigating to an anchor inside it
  document.querySelectorAll('#drawer-nav [data-mobile-nav]').forEach((a) => {
    a.addEventListener('click', () => {
      setTimeout(closeDrawer, 80);
    });
  });

  // ──────────────────────────── Search overlay (mobile) ────────────────────────────
  const searchToggle = document.getElementById('search-toggle');
  const searchOverlay = document.getElementById('search-overlay');
  const searchOverlayInput = document.getElementById('search-overlay-input');
  const searchOverlayClose = document.getElementById('search-overlay-close');
  const searchOverlayResults = document.getElementById('search-overlay-results');
  const drawerSearchBtn = document.getElementById('drawer-search-btn');

  function openSearchOverlay() {
    if (!searchOverlay) return;
    searchOverlay.classList.add('open');
    searchOverlay.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
    // Sync value from desktop search if present
    const desktopSearch = document.getElementById('search');
    if (desktopSearch && searchOverlayInput) {
      searchOverlayInput.value = desktopSearch.value;
    }
    if (searchOverlayInput) {
      setTimeout(() => searchOverlayInput.focus(), 100);
    }
    renderSearchResults(searchOverlayInput ? searchOverlayInput.value : '');
  }
  function closeSearchOverlay() {
    if (!searchOverlay) return;
    searchOverlay.classList.remove('open');
    searchOverlay.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  }

  searchToggle && searchToggle.addEventListener('click', openSearchOverlay);
  searchOverlayClose && searchOverlayClose.addEventListener('click', closeSearchOverlay);
  drawerSearchBtn && drawerSearchBtn.addEventListener('click', () => {
    closeDrawer();
    setTimeout(openSearchOverlay, 200);
  });
  // Esc to close
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (searchOverlay && searchOverlay.classList.contains('open')) closeSearchOverlay();
      else if (drawer && drawer.classList.contains('open')) closeDrawer();
      else if (filterSheet && filterSheet.classList.contains('open')) closeFilterSheet();
    }
  });

  // ──────────────────────────── Filter sheet (mobile) ────────────────────────────
  const filterMobileBtn = document.getElementById('filter-mobile-btn');
  const filterSheet = document.getElementById('filter-sheet');
  const filterSheetBackdrop = document.getElementById('filter-sheet-backdrop');
  const filterSheetClose = document.getElementById('filter-sheet-close');
  const filterSheetBody = document.getElementById('filter-sheet-body');

  function openFilterSheet() {
    if (!filterSheet) return;
    populateFilterSheet();
    filterSheet.classList.add('open');
    filterSheetBackdrop && filterSheetBackdrop.classList.add('open');
    filterSheet.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
  }
  function closeFilterSheet() {
    if (!filterSheet) return;
    filterSheet.classList.remove('open');
    filterSheetBackdrop && filterSheetBackdrop.classList.remove('open');
    filterSheet.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  }

  function populateFilterSheet() {
    if (!filterSheetBody) return;
    if (filterSheetBody.dataset.populated) {
      // Just update active states
      filterSheetBody.querySelectorAll('.sheet-cat').forEach((b) => {
        b.classList.toggle('active', b.dataset.category === activeCategory);
      });
      return;
    }
    const cats = Array.from(document.querySelectorAll('.filter-btn')).map((btn) => ({
      name: btn.dataset.category,
      count: (btn.querySelector('.filter-count') || {}).textContent || '',
    }));
    filterSheetBody.innerHTML = '<div class="sheet-categories">' +
      cats.map((c) => `<button class="sheet-cat ${c.name === activeCategory ? 'active' : ''}" data-category="${c.name.replace(/"/g, '&quot;')}">
        <span>${c.name}</span><span class="sheet-cat-count">${c.count}</span>
      </button>`).join('') + '</div>';
    filterSheetBody.dataset.populated = '1';
    filterSheetBody.addEventListener('click', (e) => {
      const btn = e.target.closest('.sheet-cat');
      if (!btn) return;
      const cat = btn.dataset.category;
      // Trigger the existing filter logic
      const desktopBtn = document.querySelector(`.filter-btn[data-category="${cat.replace(/"/g, '\\"')}"]`);
      if (desktopBtn) desktopBtn.click();
      closeFilterSheet();
    });
  }

  filterMobileBtn && filterMobileBtn.addEventListener('click', openFilterSheet);
  filterSheetClose && filterSheetClose.addEventListener('click', closeFilterSheet);
  filterSheetBackdrop && filterSheetBackdrop.addEventListener('click', closeFilterSheet);

  // ──────────────────────────── Search (desktop + overlay) ────────────────────────────
  const searchInput = document.getElementById('search');
  const appGrid = document.getElementById('app-grid');
  let q = '';
  let activeCategory = 'All';

  if (searchInput || searchOverlayInput) {
    function visibleCards() {
      if (!appGrid) return;
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
      updateMobileFilterCount();
      return count;
    }

    function updateMobileFilterCount() {
      const el = document.getElementById('filter-mobile-count');
      if (!el) return;
      if (activeCategory === 'All') {
        el.textContent = '';
      } else {
        const btn = document.querySelector(`.filter-btn[data-category="${activeCategory.replace(/"/g, '\\"')}"]`);
        const n = btn ? (btn.querySelector('.filter-count') || {}).textContent : '';
        el.textContent = activeCategory === 'All' ? '' : activeCategory;
      }
    }

    function renderSearchResults(query) {
      if (!searchOverlayResults) return;
      if (!appGrid) return;
      const ql = query.trim().toLowerCase();
      if (!ql) {
        searchOverlayResults.innerHTML = '<div class="search-overlay-empty"><h3>Start typing…</h3><p>Search by app name or description.</p></div>';
        return;
      }
      const cards = Array.from(appGrid.querySelectorAll('.app-card'));
      const matches = cards.filter((card) => {
        const name = (card.dataset.name || '').toLowerCase();
        const desc = (card.dataset.desc || '').toLowerCase();
        return name.includes(ql) || desc.includes(ql);
      }).slice(0, 30);

      if (!matches.length) {
        searchOverlayResults.innerHTML = `<div class="search-overlay-empty"><h3>No results for "${esc(query)}"</h3><p>Try a different keyword.</p></div>`;
        return;
      }
      searchOverlayResults.innerHTML = matches.map((card) => {
        const href = card.getAttribute('href');
        const name = card.dataset.name;
        const cat = card.dataset.category;
        const iconEl = card.querySelector('.app-card-icon');
        const iconHTML = iconEl ? iconEl.outerHTML : '';
        return `<a class="search-overlay-result" href="${href}">
          <div class="search-overlay-result-icon">${iconEl ? iconEl.innerHTML : ''}</div>
          <div class="search-overlay-result-text">
            <div class="search-overlay-result-name">${esc(name)}</div>
            <div class="search-overlay-result-cat">${esc(cat)}</div>
          </div>
        </a>`;
      }).join('');
    }

    function esc(s) {
      return String(s).replace(/[&<>"']/g, (c) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
      }[c]));
    }

    function onSearchInput(val) {
      q = val;
      // Mirror between desktop and overlay
      if (searchInput && searchInput.value !== val) searchInput.value = val;
      if (searchOverlayInput && searchOverlayInput.value !== val) searchOverlayInput.value = val;
      if (appGrid) visibleCards();
      if (searchOverlay && searchOverlay.classList.contains('open')) renderSearchResults(val);
    }

    if (searchInput) {
      searchInput.addEventListener('input', (e) => onSearchInput(e.target.value));
    }
    if (searchOverlayInput) {
      searchOverlayInput.addEventListener('input', (e) => onSearchInput(e.target.value));
    }

    // "/" focuses search (desktop) — but NOT on mobile (would force open mobile kb)
    document.addEventListener('keydown', (e) => {
      if (e.key === '/' && searchInput && document.activeElement !== searchInput && !e.metaKey && !e.ctrlKey) {
        e.preventDefault();
        searchInput.focus();
        searchInput.select();
      }
      if (e.key === 'Escape' && document.activeElement === searchInput) {
        searchInput.value = '';
        onSearchInput('');
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
      const btn = document.querySelector(`.filter-btn[data-category="${cat.replace(/"/g, '\\"')}"]`);
      if (btn) btn.click();
    } else {
      updateMobileFilterCount();
    }
  }

  // ──────────────────────────── Smooth scroll-reveal ────────────────────────────
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