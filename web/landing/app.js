// Simple intersection observer to reveal elements with animation classes
(function(){
  const observer = new IntersectionObserver((entries)=>{
    entries.forEach(entry=>{
      if(entry.isIntersecting){
        entry.target.classList.add('is-visible');
      }
    });
  },{threshold:0.12});

  document.querySelectorAll('.fade-up, .fade-in, .fade-left').forEach(el=>observer.observe(el));

  // Smooth scroll for nav links
  document.querySelectorAll('a[href^="#"]').forEach(a=>{
    a.addEventListener('click',function(e){
      const href=this.getAttribute('href');
      if(href.length>1){
        e.preventDefault();
        document.querySelector(href).scrollIntoView({behavior:'smooth',block:'start'});
      }
    });
  });

  // Theme toggle: initialize from localStorage or system preference
  const themeToggle = document.getElementById('theme-toggle');
  function applyTheme(theme){
    if(theme === 'dark'){
      document.documentElement.setAttribute('data-theme','dark');
      themeToggle && themeToggle.setAttribute('aria-pressed','true');
    } else {
      document.documentElement.removeAttribute('data-theme');
      themeToggle && themeToggle.setAttribute('aria-pressed','false');
    }
  }

  function initTheme(){
    const saved = localStorage.getItem('mc-theme');
    if(saved){ applyTheme(saved); return; }
    const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    applyTheme(prefersDark ? 'dark' : 'light');
  }

  themeToggle && themeToggle.addEventListener('click', ()=>{
    const isDark = document.documentElement.hasAttribute('data-theme');
    const newTheme = isDark ? 'light' : 'dark';
    applyTheme(newTheme);
    localStorage.setItem('mc-theme', newTheme);
  });

  // initialize theme on load
  initTheme();

  // Business card toggles
  function openCard(card){
    const btn = card.querySelector('.biz-toggle');
    const details = card.querySelector('.biz-details');
    card.classList.add('open');
    btn && btn.setAttribute('aria-expanded','true');
    details.hidden = false;
    setTimeout(()=> { details.style.maxHeight = details.scrollHeight + 'px'; }, 10);
  }
  function closeCard(card){
    const btn = card.querySelector('.biz-toggle');
    const details = card.querySelector('.biz-details');
    card.classList.remove('open');
    btn && btn.setAttribute('aria-expanded','false');
    details.style.maxHeight = details.scrollHeight + 'px';
    setTimeout(()=> { details.style.maxHeight = '0px'; }, 10);
    setTimeout(()=> { details.hidden = true; }, 310);
  }

  document.querySelectorAll('.biz-toggle').forEach(btn=>{
    btn.addEventListener('click', e=>{
      const card = btn.closest('.biz-card');
      const isOpen = card.classList.toggle('open');
      if(isOpen){ openCard(card); } else { closeCard(card); }
    });
  });

  // Expand / Collapse All
  const expandAllBtn = document.getElementById('expandAll');
  const collapseAllBtn = document.getElementById('collapseAll');
  expandAllBtn && expandAllBtn.addEventListener('click', ()=>{
    document.querySelectorAll('.biz-card').forEach(openCard);
  });
  collapseAllBtn && collapseAllBtn.addEventListener('click', ()=>{
    document.querySelectorAll('.biz-card').forEach(closeCard);
  });

  // subtle hero float animation trigger
  document.addEventListener('DOMContentLoaded', ()=>{
    document.querySelectorAll('.hero-illustration svg').forEach(svg=>svg.classList.add('float'));
  });

  // Header scroll effect (from provided code)
  const headerEl = document.getElementById('header');
  if(headerEl){
    window.addEventListener('scroll', ()=>{
      if(window.scrollY > 50) headerEl.classList.add('scrolled'); else headerEl.classList.remove('scrolled');
    });
  }

  // Demo modal handlers
  const demoModal = document.getElementById('demo-modal');
  const demoOpenBtns = document.querySelectorAll('#open-demo, #start-trial');
  const demoClose = document.getElementById('demo-close');
  const demoBackdrop = document.getElementById('demo-backdrop');
  const demoForm = document.getElementById('demo-form');
  const demoSuccess = document.getElementById('demo-success');

  let lastActiveElement = null;
  function openDemo(){ if(demoModal){ lastActiveElement = document.activeElement; demoModal.classList.add('open'); demoModal.setAttribute('aria-hidden','false'); document.body.style.overflow='hidden'; setTimeout(()=>{ document.getElementById('demo-name')?.focus(); }, 80); }}
  function closeDemo(){ if(demoModal){ demoModal.classList.remove('open'); demoModal.setAttribute('aria-hidden','true'); document.body.style.overflow=''; demoSuccess && (demoSuccess.style.display='none'); demoForm && (demoForm.style.display='block'); lastActiveElement && lastActiveElement.focus(); }}

  demoOpenBtns.forEach(b=>b && b.addEventListener('click', (e)=>{ e.preventDefault(); openDemo(); }));
  demoClose && demoClose.addEventListener('click', closeDemo);
  demoBackdrop && demoBackdrop.addEventListener('click', closeDemo);
  document.getElementById('demo-cancel') && document.getElementById('demo-cancel').addEventListener('click', closeDemo);

  // close modal via Escape key
  document.addEventListener('keydown', (e)=>{ if(e.key === 'Escape' && demoModal && demoModal.classList.contains('open')) closeDemo(); });

  if(demoForm){
    demoForm.addEventListener('submit', function(e){
      e.preventDefault();
      // simple form validation
      const email = document.getElementById('demo-email').value;
      if(!/\S+@\S+\.\S+/.test(email)){ alert('Please enter a valid email'); return; }
      // simulate submit
      demoForm.style.display='none'; demoSuccess.style.display='block';
      setTimeout(()=> closeDemo(), 1600);
    });
  }

  // FAQ accordion
  document.querySelectorAll('.faq-question').forEach(q=>{
    q.addEventListener('click', ()=>{
      const parent = q.closest('.faq-item');
      const ans = parent.querySelector('.faq-answer');
      const expanded = q.getAttribute('aria-expanded') === 'true';
      q.setAttribute('aria-expanded', String(!expanded));
      if(expanded){ ans.hidden = true; } else { ans.hidden = false; }
    });
  });

  // Newsletter submit
  const newsletterForm = document.getElementById('newsletter-form');
  if(newsletterForm){
    newsletterForm.addEventListener('submit', function(e){
      e.preventDefault();
      const emailEl = document.getElementById('newsletter-email');
      const email = emailEl.value.trim();
      if(!/\S+@\S+\.\S+/.test(email)){ alert('Please enter a valid email'); return; }
      emailEl.value = '';
      // show a toast or quick confirmation
      const ok = document.createElement('div'); ok.textContent='Subscribed — check your inbox'; ok.style.marginTop='8px'; ok.style.color='var(--accent-2)'; newsletterForm.parentNode.appendChild(ok);
      setTimeout(()=> ok.remove(), 3000);
    });
  }


  // Pricing toggle (accessible) - keyboard support + persistence
  const toggleContainer = document.querySelector('.pricing-toggle');
  const toggleBtns = Array.from(document.querySelectorAll('.toggle-btn'));
  function updatePrices(period){
    document.querySelectorAll('.price[data-monthly]').forEach(el=>{
      const monthly = el.getAttribute('data-monthly');
      const yearly = el.getAttribute('data-yearly');
      const val = period === 'monthly' ? monthly : yearly;
      const periodText = (val === 'Free' || val === 'Contact') ? '' : (period === 'monthly' ? '/mo' : '/yr');
      const valueEl = el.querySelector('.price-value');
      const periodEl = el.querySelector('.price-period');
      if(valueEl) valueEl.textContent = val;
      if(periodEl) periodEl.textContent = periodText;
    });
  }

  function setActivePeriod(period){
    toggleBtns.forEach(b=>{
      const active = b.dataset.period === period;
      b.classList.toggle('active', active);
      b.setAttribute('aria-pressed', active ? 'true' : 'false');
      if(active) b.focus();
    });
    updatePrices(period);
    try{ localStorage.setItem('mc-pricing-period', period); }catch(e){}
  }

  toggleBtns.forEach(btn=>{
    btn.addEventListener('click', ()=> setActivePeriod(btn.dataset.period));
    btn.addEventListener('keydown', (e)=>{
      if(e.key === 'Enter' || e.key === ' '){ e.preventDefault(); setActivePeriod(btn.dataset.period); }
    });
  });

  if(toggleContainer){
    toggleContainer.addEventListener('keydown', (e)=>{
      const focused = document.activeElement;
      const idx = toggleBtns.indexOf(focused);
      if(idx === -1) return;
      if(['ArrowRight','ArrowLeft','Home','End'].includes(e.key)){
        e.preventDefault();
        let newIdx = idx;
        if(e.key === 'ArrowRight') newIdx = (idx + 1) % toggleBtns.length;
        if(e.key === 'ArrowLeft') newIdx = (idx - 1 + toggleBtns.length) % toggleBtns.length;
        if(e.key === 'Home') newIdx = 0;
        if(e.key === 'End') newIdx = toggleBtns.length - 1;
        toggleBtns[newIdx].focus();
      }
    });
  }

  // initialize prices default (persistent if available)
  const saved = (function(){ try{ return localStorage.getItem('mc-pricing-period'); }catch(e){ return null; }})();
  setActivePeriod(saved || document.querySelector('.toggle-btn.active')?.dataset.period || 'monthly');

})();
