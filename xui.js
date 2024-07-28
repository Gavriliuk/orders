const app={}

app.vm=new Vue({el:'#app',data:{d:{a:{lang:tr.prototype.lang,title:'Orders',signed:0,not:0,data:{ts:'',msg:[],doc:[],lst:[],rep:[]}},p:{name:'',title:'',data:{}}
 ,m:{msgbox:{caption:'',text:'',ok:false},chgpwd:{ok:false},query:{caption:'',status:'',time:0,ok:false}}}}
,computed:{app:x=>app,langs:x=>tr.prototype.list}
,methods:{
 tr:d=>tr(''+d)
,lang:x=>tr.prototype.lang
,installed:x=>app.sw
,backuped:x=>localStorage.getItem('userdata.ts')
,fmtD:d=>new Date(d).toLocaleString(tr.prototype.lang,{day:'numeric',month:'short',year:'numeric'})
,fmtdT:d=>new Date(d).toLocaleString(tr.prototype.lang,{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})
,fmtDT:d=>new Date(d).toLocaleString(tr.prototype.lang,{day:'numeric',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'})
}})

app.ts=()=>(new Date()).toTimeString().substr(0,8)
app.log=function(){console.log.apply(app,[].concat([app.ts()],[].slice.call(arguments)))}
app.wrn=function(){console.warn.apply(app,[].concat([app.ts()],[].slice.call(arguments)))}
app.err=function(){console.error.apply(app,[].concat([app.ts()],[].slice.call(arguments)))}
app.msg=text=>app.log(text)||M.toast({html:text,classes:'white black-text rounded'})
app.warn=text=>app.wrn(text)||M.toast({html:text,classes:'yellow red-text rounded'})
app.error=text=>app.err(text)||M.toast({html:text,classes:'red yellow-text rounded'})
app.hash=text=>text.split('').reduce((hash,char)=>{return char.charCodeAt(0)+(hash<<6)+(hash<<16)-hash},0)
app.lang=lang=>localStorage.setItem('language',tr.prototype.set(lang))||app.vm.$forceUpdate()

app.msgbox=(text,caption)=>{
 app.vm.d.m.msgbox.caption=caption
 app.vm.d.m.msgbox.text=text
 app.vm.d.m.msgbox.ok=null
 M.Modal.getInstance(document.getElementById('modal-msgbox')).open()
}

app.chgpwd=x=>{
 app.vm.d.m.chgpwd.ok=null
 const modal=M.Modal.getInstance(document.getElementById('modal-chgpwd'))
 modal.options.onCloseEnd=x=>{
  if(!app.vm.d.m.chgpwd.ok)return
  const pwd1=document.getElementById('change-password-1').value
  if(!pwd1.length)return setTimeout(x=>app.msgbox(tr('Empty password is not allowed')),100)
  const pwd2=document.getElementById('change-password-2').value
  if(pwd1!=pwd2)return setTimeout(x=>app.msgbox(tr('Entered passwords do not match')),100)
  if(pwd1==app.password)return
  localStorage.setItem('userhash',app.hash(app.username+'/'+(app.password=pwd1)))
  app.makeKey(app.hash(app.password+'userdata'+app.password.length))
 }
 modal.open()
}

app.confirm=(text,caption)=>{
 return new Promise(resolve=>{
  app.vm.d.m.msgbox.caption=caption
  app.vm.d.m.msgbox.text=text
  app.vm.d.m.msgbox.ok=false
  const modal=M.Modal.getInstance(document.getElementById('modal-msgbox'))
  modal.options.onCloseEnd=x=>resolve(app.vm.d.m.msgbox.ok)
  modal.open()
 })
}

app.b64encode=data=>btoa(Array.from(new TextEncoder().encode(data),byte=>String.fromCodePoint(byte),).join(""))
app.b64decode=text=>new TextDecoder().decode(Uint8Array.from(atob(text),m=>m.codePointAt(0)))

app.makeKey=value=>{
 app.key=[0,0,0,0]
 if(value<0){
  app.key[3]=128
  value+=0x80000000
 }
 for(let i=0;i<4;++i){
  app.key[i]+=value%256
  value=(value-app.key[i])>>8
 }
}

app.transform=(text)=>{
 let result=''
 for(let i=0;i<text.length;++i){
  let code=text.charCodeAt(i)
  if(code>=32)code=code^((app.key[(i>>4)%4]>>(i%3))%32)
  result+=String.fromCharCode(code)
 }
 return result
}

app.encode=text=>app.transform(app.b64encode(text))
app.decode=text=>app.b64decode(app.transform(text))

app.lskeys=['ts','msg','doc','lst','rep']

app.backup=key=>{
 if(!key)return app.lskeys.forEach(key=>app.backup(key))
 const data=JSON.stringify(app.vm.d.a.data[key])
 const encoded=app.encode(data)
 localStorage.setItem('userdata.'+key,encoded)
}

app.restore=key=>{
 if(!key)return app.lskeys.forEach(key=>app.restore(key))
 const encoded=localStorage.getItem('userdata.'+key)
 if(encoded)try{
  const decoded=app.decode(encoded)
  const data=JSON.parse(decoded)
  app.vm.d.a.data[key]=data
  if(key=='msg')app.vm.d.a.not=data.filter(m=>!m.read).length
 }catch(e){
  app.err(e)
  app.vm.d.a.data[key]=key=='ts'?'':[]
 }
}

app.login=async(username,password)=>{
 app.vm.d.a.data={ts:'',msg:[],doc:[]}
 app.makeKey(app.hash(password+'userdata'+password.length))
 username=username.toLowerCase()
 const userhash=app.hash(username+'/'+password)
 const prevuser=localStorage.getItem('username')
 const prevhash=localStorage.getItem('userhash')
 if(prevuser&&prevuser!=username){
  const result=await app.confirm('Delete previous user data?','New user detected')
  if(!result)
   return
 }else if(prevhash&&prevhash!=userhash){
  const result=await app.confirm('Delete existing user data?','Password is changed')
  if(!result)
   return
 }else{
  app.restore()
 }
 app.session=0
 app.username=username
 app.password=password
 localStorage.setItem('username',username)
 localStorage.setItem('userhash',userhash)
 app.showPage()
 app.vm.d.a.signed=true
 document.body.setAttribute('signed','')
}

app.logout=async ()=>{
 if(!await app.confirm(tr('Log out')+'?'))return
 document.body.removeAttribute('signed')
 app.vm.d.a.data={ts:'',msg:[],doc:[]}
 app.vm.d.a.signed=false
 app.vm.d.p.data={}
 app.vm.d.p.name=''
 app.vm.d.p.title=''
 app.vm.d.p.username=''
 app.vm.d.p.password=''
}

app.showPage=(name,data)=>{
 const setup=(title,data)=>{
  app.vm.d.p.name=name
  app.vm.d.p.title=tr(title)
  app.vm.d.p.data=data
 }
 if(name=='order')return data?setup('Document #'+data.id,data):setup('New document')
 if(name=='docs')return setup('Documents')
 if(name=='msgs')return setup('Messages')
 if(name=='clients')return setup('Clients')
 if(name=='setup')return setup('Settings')
 name='main'
 setup('Current state')
}

app.query=(request,caption,resolve)=>{
 const controller=new AbortController()
 const timeout=AbortSignal.timeout(30000);
 const signal=controller.signal
 const uri='api/o?r='+encodeURIComponent(JSON.stringify(request))
 app.vm.d.m.query.caption=tr(caption)
 app.vm.d.m.query.status=tr('Connection is in progress')
 app.vm.d.m.query.time=0
 app.vm.d.m.query.ok=false
 const started=Date.now()
 const interval=setInterval(x=>app.vm.d.m.query.time=Math.round((Date.now()-started)/1000),1000)
 const modal=M.Modal.getInstance(document.getElementById('modal-query'))
 modal.options.onCloseEnd=x=>{
  clearInterval(interval)
  if(!app.vm.d.m.query.ok)controller.abort()
 }
 modal.open()
 fetch(uri,{signal:AbortSignal.any([controller.signal,timeout])}).then(response=>{
  clearInterval(interval)
  if(!response.ok)throw new Error('Not OK. '+response.status)
  return response.json()
 }).then(data=>{
  app.vm.d.m.query.status=tr('Transaction success')
  app.vm.d.m.query.ok=true
  resolve(data)
 }).catch(error=>{
  clearInterval(interval)
  app.vm.d.m.query.ok=true
  app.vm.d.m.query.status=tr('Error')+': '+error.message
 })
}

app.dbRefresh=x=>{
 const request={cmd:'dbrefresh',usr:app.username,pwd:app.password}
 app.query(request,'Refresh database',data=>{
  app.vm.d.a.data.ts=data.ts
  app.vm.d.a.data.doc=data.doc
  app.vm.d.a.data.msg=data.msg
  app.vm.d.a.not=data.msg.filter(m=>!m.read).length
  app.backup()
 })
}

app.dbExport=x=>{
}

app.editOrder=id=>{
 app.showPage('order',{id:id})
}

app.showMsg=id=>{
 for(let i=0;i<app.vm.d.a.data.msg.length;++i)if(id?(app.vm.d.a.data.msg[i].id==id):!app.vm.d.a.data.msg[i].read){
  M.toast({html:app.vm.d.a.data.msg[i].t,classes:'yellow red-text rounded'})
  app.vm.d.a.data.msg[i].read=true
  app.vm.d.a.not=app.vm.d.a.data.msg.filter(m=>!m.read).length
  if(app.vm.d.p.name=='msgs')app.vm.$forceUpdate()
  app.backup('msg')
  break
 }
}

app.deleteMsg=id=>{
 for(let i=app.vm.d.a.data.msg.length-1;i>=0;--i)if(app.vm.d.a.data.msg[i].id==id)app.vm.d.a.data.msg.splice(i,1)
 app.backup()
}

app.install=async x=>{
 if(app.sw){
  const sw=app.sw
  delete app.sw
  sw.unregister()
 }
 if(!navigator.serviceWorker)return
 app.sw=await navigator.serviceWorker.register('/xsw.js',{scope:'/'})
 if(app.vm.d.p.name=='setup')app.vm.$forceUpdate()
}

app.uninstall=x=>{
 if(!app.sw)return
 const sw=app.sw
 delete app.sw
 sw.unregister()
 if(app.vm.d.p.name=='setup')app.vm.$forceUpdate()
}

onload=e=>{
 //app.log('window is loaded')
 M.Modal.init(document.querySelectorAll('.modal'))
 //M.Sidenav.init(document.querySelectorAll('.sidenav'))
 //M.FormSelect.init(document.querySelectorAll('select'))
 M.FloatingActionButton.init(document.querySelectorAll('.fixed-action-btn'),{hoverEnabled:false})
 setTimeout(e=>document.body.removeAttribute('init'),100)
 //setTimeout(e=>addEventListener('popstate',function(){app.go(document.location.href,true)},false),1)
 //if(navigator.serviceWorker)navigator.serviceWorker.getRegistrations().then(r=>{if(r.length)app.sw=r[0]})
 //if(navigator.serviceWorker)navigator.serviceWorker.register('/xsw.js',{scope:'/'}).then(r=>app.sw=r)
 app.install()
}
