const xsw={cache:'offline'}

//self.addEventListener('install',function(event){console.log('install',event)})

//self.addEventListener('activate',function(event){console.log('activate',event)})

self.addEventListener('fetch',event=>event.respondWith(fetch(event.request).then(response=>{
 const clone=response.clone()
 if(event.request.method=='GET'){
  if(!xsw.api)xsw.api=self.serviceWorker.scriptURL.substr(0,self.serviceWorker.scriptURL.lastIndexOf('/'))+'/api/'
  if(event.request.url.substr(0,xsw.api.length)!=xsw.api)caches.open(xsw.cache).then(cache=>cache.put(event.request,clone))
 }
 return response
}).catch(error=>caches.match(event.request).then(response=>response.clone()))
))
