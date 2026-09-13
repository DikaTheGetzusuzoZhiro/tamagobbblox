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
  TAMA.user={get(){return localStorage.getItem('tama_username')||''},set(v){localStorage.setItem('tama_username',v)}};
  TAMA.modals={init(){
    document.addEventListener('click',e=>{
      const c=e.target.closest('[data-close]');
      if(c){const el=TAMA.q('#'+c.dataset.close);el?.classList.add('hidden');}
      const zoom=e.target.closest('[data-zoom-src]');
      if(zoom){TAMA.lightbox.open(zoom.dataset.zoomSrc, zoom.alt||'Gambar');}
      const lb=e.target.closest('#imageLightbox');
      if(lb && (e.target===lb || e.target.closest('[data-lightbox-close]'))){TAMA.lightbox.close();}
    });
    document.addEventListener('keydown',e=>{if(e.key==='Escape')TAMA.lightbox.close();});
    if(!TAMA.q('#imageLightbox')){
      const el=document.createElement('div');
      el.id='imageLightbox';
      el.className='image-lightbox hidden';
      el.setAttribute('role','dialog');
      el.setAttribute('aria-modal','true');
      el.innerHTML='<button class="image-lightbox-close" type="button" data-lightbox-close aria-label="Tutup">×</button><img class="image-lightbox-img" alt="Gambar diperbesar">';
      document.body.appendChild(el);
    }
  }};
  TAMA.lightbox={
    open(src,alt){const el=TAMA.q('#imageLightbox');const img=el?.querySelector('.image-lightbox-img');if(!el||!img||!src)return;img.src=src;img.alt=alt||'Gambar diperbesar';el.classList.remove('hidden');document.body.classList.add('lightbox-open');},
    close(){const el=TAMA.q('#imageLightbox');if(el){el.classList.add('hidden');const img=el.querySelector('.image-lightbox-img');if(img)img.src='';}document.body.classList.remove('lightbox-open');}
  };
})();
