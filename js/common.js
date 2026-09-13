(function(){
  window.TAMA = window.TAMA || {};
  const cfg = window.SUPABASE_CONFIG || {};
  if(window.SUPABASE_CONFIG_ERROR || !window.supabase || !cfg.url || !cfg.anonKey){
    window.TAMA.configError = true;
    window.TAMA.configMessage = window.SUPABASE_CONFIG_ERROR || 'Konfigurasi Supabase belum tersedia dari environment Vercel.';
  } else {
    window.TAMA.sb = window.supabase.createClient(cfg.url, cfg.anonKey);
  }
  TAMA.q = (s)=>document.querySelector(s);
  TAMA.qa = (s)=>[...document.querySelectorAll(s)];
  TAMA.escape = (s)=>String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  TAMA.rupiah=(n)=>new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(Number(n||0));
  TAMA.toast=(m)=>{const el=TAMA.q('#toast');if(!el)return;el.textContent=m;el.classList.add('show');clearTimeout(el._t);el._t=setTimeout(()=>el.classList.remove('show'),2600)};
  TAMA.theme={init(){const saved=localStorage.getItem('tama-theme'); if(saved==='dark')document.body.classList.add('dark'); const b=TAMA.q('#themeBtn'); if(b)b.addEventListener('click',()=>{document.body.classList.toggle('dark');localStorage.setItem('tama-theme',document.body.classList.contains('dark')?'dark':'light')})}};
  TAMA.user={get(){return localStorage.getItem('tama_username')||''},set(v){localStorage.setItem('tama_username',v); TAMA.user.updateChip()},updateChip(){const c=TAMA.q('#sessionChip');const u=TAMA.user.get();if(c){c.textContent=u?'@'+u:'';c.classList.toggle('hidden',!u)} }};
  TAMA.modals={init(){document.addEventListener('click',e=>{const c=e.target.closest('[data-close]');if(c){const el=TAMA.q('#'+c.dataset.close);el?.classList.add('hidden')}})}};
})();
