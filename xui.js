const app={}

app.vm=new Vue({el:'#app',data:{d:{a:{lang:tr.prototype.lang,title:'Orders',signed:0,not:0
  ,data:{ts:'',msg:[],doc:[],lst:[],rep:[]}}
 ,p:{name:'',title:'',data:{}}
 ,m:{msgbox:{caption:'',text:'',ok:false},chgpwd:{ok:false},query:{caption:'',status:'',time:0,ok:false}}}}
,computed:{app:x=>app,langs:x=>tr.prototype.list}
,methods:{
 tr:d=>tr(''+d)
,lang:x=>tr.prototype.lang
,installed:x=>app.sw
,backuped:x=>localStorage.getItem('userdata.ts')
,session:s=>s?localStorage.setItem('userdata.session',Math.max(0,Number(s)||0)):Number(localStorage.getItem('userdata.session'))||0
,timeout:t=>t?localStorage.setItem('userdata.timeout',Math.max(30,Math.min(600,Number(t)||0))):Number(localStorage.getItem('userdata.timeout'))||300
,curD:x=>new Date(Math.floor((Date.now()-(new Date).getTimezoneOffset()*60000)/86400000)*86400000)
,nextD:d=>new Date(d.getTime()+86400000)
,prevD:d=>new Date(d.getTime()-86400000)
,txtD:d=>new Date(d).toJSON().slice(0,10)
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

app.lsdef={ts:'',msg:[],doc:[],lst:[],rep:[]}

app.backup=key=>{
 if(!key)return Object.keys(app.lsdef).forEach(key=>app.backup(key))
 const data=JSON.stringify(app.vm.d.a.data[key])
 const encoded=app.encode(data)
 localStorage.setItem('userdata.'+key,encoded)
}

app.restore=key=>{
 if(!key)return Object.keys(app.lsdef).forEach(key=>app.restore(key))
 const encoded=localStorage.getItem('userdata.'+key)
 if(encoded)try{
  const decoded=app.decode(encoded)
  const data=JSON.parse(decoded)
  app.vm.d.a.data[key]=data||app.lsdef[key]
  if(key=='msg')app.vm.d.a.not=data.filter(m=>!m.read).length
 }catch(e){
  app.err(e)
  app.vm.d.a.data[key]=app.lsdef[key]
 }
}

app.login=async(username,password)=>{
 app.vm.d.a.data=structuredClone(app.lsdef)
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
 app.vm.d.a.data=structuredClone(app.lsdef)
 app.vm.d.a.signed=false
 app.vm.d.p.data={}
 app.vm.d.p.name=''
 app.vm.d.p.title=''
 app.vm.d.p.username=''
 app.vm.d.p.password=''
}

app.showPage=(name,data)=>{
 //app.log('showPage',name,data)
 //app.log('showPage',name,(''+JSON.stringify(data)).substr(0,100))
 const setup=(title,index,key,value)=>{
  app.vm.d.p.name=name
  app.vm.d.p.data=data
  app.vm.d.p.title=tr(title)+(index?' #'+index:'')
  if(key)app.vm.d.p.data[key]=value
  if(name=='route')app.vm.d.p.title+=' : '+app.vm.d.a.data.lst.routes.filter(r=>r.i==index).pop().n
  if(name=='clients'&&index)app.vm.d.p.title+=' : '+app.vm.d.a.data.lst.puncts.filter(p=>p.i==index).pop().n
  if(name=='client')app.vm.d.p.title+=' : '+value.n
  if(name=='products'&&index)app.vm.d.p.title+=' : '+app.vm.d.a.data.lst.groups.filter(g=>g.i==index).pop().n
  if(name=='order'&&data.punct)app.vm.d.p.title+=' : '+app.vm.d.a.data.lst.puncts.filter(p=>p.i==data.punct).pop().n
 }
 //M.FloatingActionButton.getInstance(document.querySelectorAll('.fixed-action-btn')[0]).close()
 if(name=='serverdata')return setup('Server Data')
 if(app.pageServerDataStack.length)app.pageServerDataStack=[]
 if(name=='order')return setup(data.id?'Order':'New order',data.id)
 if(name=='orders')return setup('Orders to upload')
 if(name=='docs')return setup('Orders uploaded')
 if(name=='msgs')return setup('Messages')
 if(name=='routes')return setup('Routes')
 if(name=='route')return setup('Route',data.id)
 if(name=='clients')return setup(data&&data.id?'Stores':'Clients',data&&data.id)
 if(name=='client')return setup('Client',data.id,'punct',app.vm.d.a.data.lst.puncts.filter(p=>p.i==data.id).pop())
 if(name=='products')return setup('Products',data&&data.id)
 if(name=='setup')return setup('Settings')
 name='main'
 setup('Current state')
}

app.showSubPage=(name,id,values)=>{
 //app.log('showSubPage',name,id,values)
 //app.log('showSubPage',name,id,(''+JSON.stringify(values)).substr(0,100))
 const data={id:id,back:{name:app.vm.d.p.name,title:app.vm.d.p.title,id:app.vm.d.p.data&&app.vm.d.p.data.id,back:app.vm.d.p.data&&app.vm.d.p.data.back}}
 if(values)for(key in values)data[key]=values[key]
 app.showPage(name,data)
}

app.showSuperPage=()=>{
 if(!app.vm.d.p.data||!app.vm.d.p.data.back)app.showPage()
 app.showPage(app.vm.d.p.data.back.name,{id:app.vm.d.p.data.back.id,back:app.vm.d.p.data.back.back})
}

app.pageServerDataStack=[]

app.showPageServerData=(mode,key)=>{
 //app.log('app.showPageServerData('+mode+','+key+')')
 let data=null
 if(mode==-1&&app.pageServerDataStack.length)data=app.pageServerDataStack.pop()
 else if(mode==1){
  app.pageServerDataStack.push(app.vm.d.p.data)
  const title=Array.isArray(app.vm.d.p.data[0])?(app.vm.d.p.data[0][key].n||(app.vm.d.p.data[2]+'['+key+']')):key
  const spath=Array.isArray(app.vm.d.p.data[0])?('['+key+']'):('/'+key)
  data=[app.vm.d.p.data[0][key],title,app.vm.d.p.data[2]+spath]
 }else{
  app.pageServerDataStack=[]
  data=[app.vm.d.a.data.lst,tr('Current state'),'']
 }
 app.showPage('serverdata',data)
}

app.query=(request,caption,resolve)=>{
 const controller=new AbortController()
 const timeout=AbortSignal.timeout(app.vm.timeout()*1000);
 const uri='api/s?r='+encodeURIComponent(JSON.stringify(request))
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
 const signal=AbortSignal.any?AbortSignal.any([controller.signal,timeout]):controller.signal
 fetch(uri,{referrer:'',referrerPolicy:'no-referrer',signal:signal}).then(response=>{
  clearInterval(interval)
  if(!response.ok)throw Error('Not OK. '+response.status)
  return response.json()
 }).then(data=>{
  if(data.error)throw Error(data.error,{cause:data.trace})
  app.vm.d.m.query.status=tr('Transaction success')
  app.vm.d.m.query.ok=true
  resolve(data)
 }).catch(error=>{
  clearInterval(interval)
  app.err(error)
  if(error.cause)app.log(error.cause)
  app.vm.d.m.query.ok=true
  app.vm.d.m.query.status=tr('Error')+': '+error.message
  app.vm.d.m.query.trace=error.trace
 })
}

app.dbRefresh=x=>{
 const request={cmd:'dbrefresh',usr:app.username,pwd:app.password,session:app.vm.session()}
 app.query(request,'Refresh database',data=>{
  app.vm.session(data.session)
  app.vm.d.a.data.ts=new Date
  app.vm.d.a.data.lst=data||[]
  app.vm.d.a.not=data.msg&&data.msg.filter?data.msg.filter(m=>!m.read).length:0
  app.backup()
 })
}

app.dbExport=x=>{
}

app.newOrder=x=>{
 if(app.vm.d.p.name=='client')app.showSubPage('order',null,{punct:app.vm.d.p.data.id,date:app.vm.txtD(app.vm.nextD(app.vm.curD())),products:[]})
}

app.editOrder=id=>{
 const doc=app.vm.d.a.doc.filter(d=>d.id==id).pop()
 if(doc)app.showSubPage('order',id,{punct:doc.punct,products:doc.products})
}

app.orderNextDate=x=>{
 app.vm.d.p.data.date=app.vm.txtD(app.vm.nextD(app.vm.d.p.data.D))
 app.vm.$forceUpdate()
}

app.orderPrevDate=x=>{
 app.vm.d.p.data.date=app.vm.txtD(app.vm.prevD(app.vm.d.p.data.D))
 app.vm.$forceUpdate()
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

app.modifyTimeout=()=>{
 const t0=app.vm.timeout()
 const t1=prompt(tr('Network timeout limit')+':',t0);
 if(!t1)return
 app.vm.timeout(t1)
 if(t0!=app.vm.timeout())app.vm.$forceUpdate()
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
