/* Cache hors ligne : l'app s'ouvre tout de suite avec la dernière version gardée,
   puis va chercher la nouvelle en arrière-plan (visible à l'ouverture suivante,
   ou tout de suite avec le bouton « Mettre à jour l'application »).
   Seuls les fichiers du site passent ici : Supabase, documents et polices vont en direct.
   Pour retirer le cache un jour : remplacer ce fichier par
   self.addEventListener('install',()=>self.skipWaiting());
   self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(k=>Promise.all(k.map(n=>caches.delete(n)))).then(()=>self.registration.unregister())));  */
const C='feuille';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('fetch',e=>{
  const r=e.request;
  if(r.method!=='GET'||new URL(r.url).origin!==location.origin)return;
  const reseau=()=>fetch(r).then(res=>{
    if(res.ok&&res.type==='basic'){const copie=res.clone();caches.open(C).then(c=>c.put(r,copie)).catch(()=>{})}
    return res});
  e.respondWith(caches.match(r,{ignoreSearch:true}).then(hit=>{
    if(!hit)return reseau();
    e.waitUntil(reseau().catch(()=>{}));return hit
  }).catch(()=>fetch(r)));
});
