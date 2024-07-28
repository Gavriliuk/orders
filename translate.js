(tr=function(data){
 tr.prototype.init=function(list){
  if(!Array.isArray(list)||!list.length)return
  tr.prototype.list=list
  tr.prototype.lang=''+list[0]
  tr.prototype.index=0
 }
 tr.prototype.set=function(lang){
  if(!tr.prototype.list)return lang
  tr.prototype.index=tr.prototype.list.findIndex(value=>value==lang)
  if(!lang||tr.prototype.index<0)lang=tr.prototype.list[tr.prototype.index=0]
  return tr.prototype.lang=lang
 }
 if(typeof data=='string'){
  if(!tr.prototype.data||tr.prototype.index<=0)return data
  const trans=tr.prototype.data[data]
  return (!trans||trans.length<tr.prototype.index)?data:trans[tr.prototype.index-1]||data
 }
 if(typeof data=='object'&&Array.isArray(data)){
  if(!tr.prototype.data)tr.prototype.data={}
  const key=''+data.shift()
  tr.prototype.data[key]=data
 }
})()
