CREATE OR REPLACE PACKAGE PG_WEB_BASE as
--------------------------------------------------------------------------------
-- Last modification date: 03.09.24
--------------------------------------------------------------------------------
-- Common environment variables
--------------------------------------------------------------------------------
g_service_path varchar2(2000); -- Something like '/un4/'
g_procedure varchar2(255); -- Something like 'o'
g_parameter varchar2(30); -- Something like 'r'
type t_response is table of varchar2(32767) index by binary_integer;
g_response t_response; -- Response buffer
g_remote boolean; -- Write to g_response instead of htp.p()
--------------------------------------------------------------------------------
-- Variables used by Apache via OCI call
--------------------------------------------------------------------------------
web_response_buffer varchar2(32767); -- Response buffer
web_response_file_buffer blob; -- Seems not to be used
web_oci_call boolean:=false; -- Write to web_response_buffer instead of htp.p()
web_php_path varchar2(32767); -- Full path from URL
--------------------------------------------------------------------------------
procedure init_env_owa;
procedure init_env(p_path varchar2,p_proc varchar2,p_param varchar2);
procedure get_response(p_response in out nocopy t_response);
procedure say_response(p_response in out nocopy t_response);
procedure say_response;
--------------------------------------------------------------------------------
function decode_uri(p_text varchar2) return varchar2;
function text_html(p_text varchar2) return varchar2;
function text_json(p_name varchar2,p_text varchar2) return varchar2;
--------------------------------------------------------------------------------
function error_html return varchar2;
function error_json(p_lng boolean:=null)return varchar2;
--------------------------------------------------------------------------------
function get_parameter(p_procedure varchar2,p_position int:=null)return varchar2;
function get_url_path return varchar2;
--------------------------------------------------------------------------------
function log_params(r int,s int
,n1 varchar2:=null,v1 varchar2:=null
,n2 varchar2:=null,v2 varchar2:=null
,n3 varchar2:=null,v3 varchar2:=null
,n4 varchar2:=null,v4 varchar2:=null
,n5 varchar2:=null,v5 varchar2:=null
,n6 varchar2:=null,v6 varchar2:=null
,n7 varchar2:=null,v7 varchar2:=null
,n8 varchar2:=null,v8 varchar2:=null
,n9 varchar2:=null,v9 varchar2:=null
,n10 varchar2:=null,v10 varchar2:=null
,n11 varchar2:=null,v11 varchar2:=null
,n12 varchar2:=null,v12 varchar2:=null
,n13 varchar2:=null,v13 varchar2:=null
,n14 varchar2:=null,v14 varchar2:=null
,n15 varchar2:=null,v15 varchar2:=null
,n16 varchar2:=null,v16 varchar2:=null
,n17 varchar2:=null,v17 varchar2:=null
,n18 varchar2:=null,v18 varchar2:=null
,n19 varchar2:=null,v19 varchar2:=null
,n20 varchar2:=null,v20 varchar2:=null
,n21 varchar2:=null,v21 varchar2:=null
,n22 varchar2:=null,v22 varchar2:=null
,n23 varchar2:=null,v23 varchar2:=null
,n24 varchar2:=null,v24 varchar2:=null
,n25 varchar2:=null,v25 varchar2:=null
,n26 varchar2:=null,v26 varchar2:=null
,n27 varchar2:=null,v27 varchar2:=null
,n28 varchar2:=null,v28 varchar2:=null
,n29 varchar2:=null,v29 varchar2:=null
,n30 varchar2:=null,v30 varchar2:=null
)return varchar2;
--------------------------------------------------------------------------------
-- Log Add
-- Input:
--   p_wsid - web session id
--   p_params - web parameters
-- Output: tms_web_log.id
function log_add(p_wsid int,p_params varchar2:=null)return int;
function log_add(p_wsid int,r int
,n1 varchar2:=null,v1 varchar2:=null
,n2 varchar2:=null,v2 varchar2:=null
,n3 varchar2:=null,v3 varchar2:=null
,n4 varchar2:=null,v4 varchar2:=null
,n5 varchar2:=null,v5 varchar2:=null
,n6 varchar2:=null,v6 varchar2:=null
,n7 varchar2:=null,v7 varchar2:=null
,n8 varchar2:=null,v8 varchar2:=null
,n9 varchar2:=null,v9 varchar2:=null
,n10 varchar2:=null,v10 varchar2:=null
,n11 varchar2:=null,v11 varchar2:=null
,n12 varchar2:=null,v12 varchar2:=null
,n13 varchar2:=null,v13 varchar2:=null
,n14 varchar2:=null,v14 varchar2:=null
,n15 varchar2:=null,v15 varchar2:=null
,n16 varchar2:=null,v16 varchar2:=null
,n17 varchar2:=null,v17 varchar2:=null
,n18 varchar2:=null,v18 varchar2:=null
,n19 varchar2:=null,v19 varchar2:=null
,n20 varchar2:=null,v20 varchar2:=null
,n21 varchar2:=null,v21 varchar2:=null
,n22 varchar2:=null,v22 varchar2:=null
,n23 varchar2:=null,v23 varchar2:=null
,n24 varchar2:=null,v24 varchar2:=null
,n25 varchar2:=null,v25 varchar2:=null
,n26 varchar2:=null,v26 varchar2:=null
,n27 varchar2:=null,v27 varchar2:=null
,n28 varchar2:=null,v28 varchar2:=null
,n29 varchar2:=null,v29 varchar2:=null
,n30 varchar2:=null,v30 varchar2:=null
)return int;
--------------------------------------------------------------------------------
-- Log Set
-- Input:
--   p_id - tms_web_log.id
--   p_text - response text
--   p_cmnt - comment
procedure log_set(p_id int,p_text varchar2,p_cmnt varchar2:=null);
--------------------------------------------------------------------------------
-- HTTP Respond
-- Input:
--   p_text - response text
procedure http_respond(p_text varchar2);
--------------------------------------------------------------------------------
-- HTTP Respond
-- Input:
--   p_log_id - tms_web_log.id
--   p_rse_id - rse packet index
--   p_response - response text
procedure http_respond(p_log_id int,p_rse_id int,p_response varchar2:=null);
procedure http_respond(p_log_id int,p_rse_id int,p_response clob);
--------------------------------------------------------------------------------
procedure free_old_sessions(p_user_id int,p_wsid int);
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Login user
-- Input:
--   r - request id
--   a - application name
--   u - user name
--   p - password
-- Output (http):
--   { session : NN, user_id : MM, routes : [ R1, R2 ] }
-- Errors:
--   { error : SSS }
procedure login_user(r int,a varchar2,u varchar2,p varchar2);
--------------------------------------------------------------------------------
-- Login barcode
-- Input:
--   r - request id
--   a - application name
--   b - barcode
-- Output (http):
--   { session : NN, user_id : MM, routes : [ R1, R2 ] }
-- Errors:
--   { error : SSS }
procedure login_barcode(r int,a varchar2,b int);
--------------------------------------------------------------------------------
-- Refresh session
-- Input:
--   r - request id
--   s - session id
-- Output (http):
--   ajax.run(r, { });
-- Errors:
--   { error : SSS }
procedure refresh_session(r int,s int);
--------------------------------------------------------------------------------
-- Logout
-- Input:
--   r - request id
--   s - session id
-- Output (http):
--   ajax.run(r, { });
-- Errors:
--   { error : SSS }
procedure logout(r int,s int,closeday varchar2 := 'false');
--------------------------------------------------------------------------------
end;

/

CREATE OR REPLACE PACKAGE BODY PG_WEB_BASE as
--------------------------------------------------------------------------------
-- Last modification date: 03.09.24
--------------------------------------------------------------------------------
function c_amp return varchar2 is begin return chr(38);end;
--------------------------------------------------------------------------------
procedure init_env_owa is
begin
 if owa.num_cgi_vars is not null then
  g_service_path:=owa_util.get_owa_service_path;
  g_procedure:=lower(owa_util.get_procedure);
  g_parameter:=get_parameter(g_procedure);
  g_remote:=false;
 end if;
end;
--------------------------------------------------------------------------------
procedure init_env(p_path varchar2,p_proc varchar2,p_param varchar2)is
begin
 g_service_path:=p_path;
 g_procedure:=p_proc;
 g_parameter:=p_param;
 g_response.delete;
 g_remote:=true;
end;
--------------------------------------------------------------------------------
procedure get_response(p_response in out nocopy t_response)is
begin
 p_response.delete;
 for v_index in 1..g_response.count loop
  p_response(v_index):=g_response(v_index);
 end loop;
 g_response.delete;
end;
--------------------------------------------------------------------------------
procedure say_response(p_response in out nocopy t_response)is
begin
 for v_index in 1..p_response.count loop
  --begin
   say(p_response(v_index));
  --exception when others then
  -- raise_application_error(-20000, 'Line '||v_index||' length '||length(p_response(v_index))||': '||sqlerrm);
  --end;
 end loop;
end;
--------------------------------------------------------------------------------
procedure say_response is
begin
 say_response(g_response);
end;
--------------------------------------------------------------------------------
function decode_uri(p_text varchar2) return varchar2 is
begin
 return convert(p_text,'cl8mswin1251','al32utf8');
exception when others then
 return p_text;
end;
--------------------------------------------------------------------------------
function text_html(p_text varchar2) return varchar2 is
begin
 return replace(replace(replace(
   p_text
   ,'"','\"')
--   ,chr(10),'\n"+'||chr(10)||'"')
   ,chr(10),'\n')
   ,chr(13),'');
end;
--------------------------------------------------------------------------------
function text_json(p_name varchar2,p_text varchar2) return varchar2 is
begin
 return p_name||':"'||text_html(p_text)||'"';
end;
--------------------------------------------------------------------------------
function error_html return varchar2 is
begin
 return text_html(sqlerrm);
end;
--------------------------------------------------------------------------------
function error_json(p_lng boolean:=null)return varchar2 is
 v_error_str varchar2(2048);
 v_ora_pos int;
begin
 v_error_str := substr(sqlerrm, 12, length(sqlerrm));
 v_ora_pos := instr(v_error_str, 'ORA-');
 if v_ora_pos > 0
 then
  v_error_str := substr(v_error_str, 1, v_ora_pos-2);
 end if;
 return '{'||chr(10)||
   ' '||text_json('error', v_error_str)||chr(10)||
   ','||text_json('error_full', sqlerrm)||chr(10)||
   ','||text_json('trace',rtrim(dbms_utility.format_error_backtrace,chr(10)))||chr(10)||
   case when p_lng then ',lng:'||nvl(sys_context('envun4','un$lang'),1)||chr(10) end||
   '}';
end;
--------------------------------------------------------------------------------
function get_parameter(p_procedure varchar2,p_position int:=null)return varchar2 is
 v_parameter varchar2(30);
begin
 select min(lower(argument_name))
 into v_parameter
 from user_arguments
 where p_procedure||'.' in(package_name||'.'||object_name||'.',object_name||'.')
 and position=nvl(p_position,1);
 --
 return v_parameter;
end;
--------------------------------------------------------------------------------
function get_url_path return varchar2 is
 v_path varchar2(4000);
begin
 if web_oci_call then
  v_path:=web_php_path;
 elsif g_service_path is not null or g_procedure is not null then
  v_path:=g_service_path||g_procedure;
 else
  v_path:=owa_util.get_owa_service_path||lower(owa_util.get_procedure);
 end if;
 return v_path;
end;
--------------------------------------------------------------------------------
function get_time return varchar2 is
begin
 return substr(to_char(systimestamp,'hh24:mi:ss.ff'),1,12);
end;
--------------------------------------------------------------------------------
function log_params(r int,s int
,n1 varchar2:=null,v1 varchar2:=null
,n2 varchar2:=null,v2 varchar2:=null
,n3 varchar2:=null,v3 varchar2:=null
,n4 varchar2:=null,v4 varchar2:=null
,n5 varchar2:=null,v5 varchar2:=null
,n6 varchar2:=null,v6 varchar2:=null
,n7 varchar2:=null,v7 varchar2:=null
,n8 varchar2:=null,v8 varchar2:=null
,n9 varchar2:=null,v9 varchar2:=null
,n10 varchar2:=null,v10 varchar2:=null
,n11 varchar2:=null,v11 varchar2:=null
,n12 varchar2:=null,v12 varchar2:=null
,n13 varchar2:=null,v13 varchar2:=null
,n14 varchar2:=null,v14 varchar2:=null
,n15 varchar2:=null,v15 varchar2:=null
,n16 varchar2:=null,v16 varchar2:=null
,n17 varchar2:=null,v17 varchar2:=null
,n18 varchar2:=null,v18 varchar2:=null
,n19 varchar2:=null,v19 varchar2:=null
,n20 varchar2:=null,v20 varchar2:=null
,n21 varchar2:=null,v21 varchar2:=null
,n22 varchar2:=null,v22 varchar2:=null
,n23 varchar2:=null,v23 varchar2:=null
,n24 varchar2:=null,v24 varchar2:=null
,n25 varchar2:=null,v25 varchar2:=null
,n26 varchar2:=null,v26 varchar2:=null
,n27 varchar2:=null,v27 varchar2:=null
,n28 varchar2:=null,v28 varchar2:=null
,n29 varchar2:=null,v29 varchar2:=null
,n30 varchar2:=null,v30 varchar2:=null
)return varchar2 is
 v_result varchar2(4000);
 --
 procedure param(p_name varchar2,p_value varchar2)is
 begin
  if p_name is not null then
   if substr(p_name,1,1)='?' then
    if p_value is not null or v_result is not null then
     v_result:=c_amp||substr(p_name,2)||'='||p_value||v_result;
    end if;
   else
    v_result:=c_amp||p_name||'='||p_value||v_result;
   end if;
  end if;
 end;
 --
begin
 param(n30,v30);
 param(n29,v29);
 param(n28,v28);
 param(n27,v27);
 param(n26,v26);
 param(n25,v25);
 param(n24,v24);
 param(n23,v23);
 param(n22,v22);
 param(n21,v21);
 param(n20,v20);
 param(n19,v19);
 param(n18,v18);
 param(n17,v17);
 param(n16,v16);
 param(n15,v15);
 param(n14,v14);
 param(n13,v13);
 param(n12,v12);
 param(n11,v11);
 param(n10,v10);
 param(n9,v9);
 param(n8,v8);
 param(n7,v7);
 param(n6,v6);
 param(n5,v5);
 param(n4,v4);
 param(n3,v3);
 param(n2,v2);
 param(n1,v1);
 if s is not null then
  param('s',s);
 end if;
 --
 return '?r='||r||v_result;
end;
--------------------------------------------------------------------------------
-- Log Add
-- Input:
--   p_wsid - web session id
--   p_params - web parameters
-- Output: tms_web_log.id
--------------------------------------------------------------------------------
function log_add(p_wsid int,p_params varchar2:=null)return int is
 pragma autonomous_transaction;
 --
 v_info varchar2(100);
 v_url varchar2(1000);
 v_session_deleted boolean:=false;
 v_user_id int;
 v_log_id int;
 --
-- procedure extract_user_id is
--  v_text varchar2(1000);
-- begin
--  if v_info is null then
--   msg('Session APP_INFO is null');
--  elsif lower(v_info) not like '{user_id:%,user_name:"%"}' then
--   msg('Session APP_INFO is wrong: '||v_info);
--  end if;
--  --
--  v_text:=substr(v_info,10,instr(v_info,',')-10);
--  begin
--   v_user_id:=v_text;
--  exception when others then
--   msg('Session APP_INFO is wrong, user_id is "'||v_text||'"');
--  end;
-- end;
 --
begin
 envun4.envsetvalue('web_start',get_time);
 init;
 envun4.init_env;
 --
 if p_wsid is null then
  envun4.envsetvalue('current_schema',sys_context('userenv','current_schema'));
 else
  begin
   select user_id,app_info into v_user_id,v_info from web_https where id=p_wsid;
   web_sessions.session_refresh(p_wsid);
  exception when no_data_found then
   v_session_deleted:=true;
  end;
 end if;
 --
 web_sessions.session_free_lost(3000); -- max timeout in minutes ~ 2 days
 --
 /*if p_wsid is not null and not v_session_deleted then
  v_session_deleted:=true;
  for c in (select null from web_https where id=p_wsid) loop
   v_session_deleted:=false;
  end loop;
 end if;*/
 --
 if substr(p_params,1,1)='?' then
  v_url:=substr(get_url_path||p_params,1,1000);
 else
  v_url:=substr(p_params,1,1000);
 end if;
 --
 delete from tms_web_log where dt<sysdate-7; -- Ticket#: 20100224101602
 --
 insert into tms_web_log (wsid,info,url)
 values (p_wsid,v_info,v_url)
 returning id into v_log_id;
 --
 commit;
 --
 begin
  if v_session_deleted then
   msg('Session '||p_wsid||' deleted',-20001);
  end if;
  --
  if p_wsid is not null then
   pg_orders_web.init_session(p_wsid,v_user_id);
  end if;
 exception when others then
  log_set(v_log_id,error_json);
  raise;
 end;
 --
 commit;
 --
 return v_log_id;
end;
--------------------------------------------------------------------------------
function log_add(p_wsid int,r int
,n1 varchar2:=null,v1 varchar2:=null
,n2 varchar2:=null,v2 varchar2:=null
,n3 varchar2:=null,v3 varchar2:=null
,n4 varchar2:=null,v4 varchar2:=null
,n5 varchar2:=null,v5 varchar2:=null
,n6 varchar2:=null,v6 varchar2:=null
,n7 varchar2:=null,v7 varchar2:=null
,n8 varchar2:=null,v8 varchar2:=null
,n9 varchar2:=null,v9 varchar2:=null
,n10 varchar2:=null,v10 varchar2:=null
,n11 varchar2:=null,v11 varchar2:=null
,n12 varchar2:=null,v12 varchar2:=null
,n13 varchar2:=null,v13 varchar2:=null
,n14 varchar2:=null,v14 varchar2:=null
,n15 varchar2:=null,v15 varchar2:=null
,n16 varchar2:=null,v16 varchar2:=null
,n17 varchar2:=null,v17 varchar2:=null
,n18 varchar2:=null,v18 varchar2:=null
,n19 varchar2:=null,v19 varchar2:=null
,n20 varchar2:=null,v20 varchar2:=null
,n21 varchar2:=null,v21 varchar2:=null
,n22 varchar2:=null,v22 varchar2:=null
,n23 varchar2:=null,v23 varchar2:=null
,n24 varchar2:=null,v24 varchar2:=null
,n25 varchar2:=null,v25 varchar2:=null
,n26 varchar2:=null,v26 varchar2:=null
,n27 varchar2:=null,v27 varchar2:=null
,n28 varchar2:=null,v28 varchar2:=null
,n29 varchar2:=null,v29 varchar2:=null
,n30 varchar2:=null,v30 varchar2:=null
)return int is
begin
 return log_add(p_wsid,log_params(r,p_wsid
  ,n1,v1,n2,v2,n3,v3,n4,v4,n5,v5
  ,n6,v6,n7,v7,n8,v8,n9,v9,n10,v10
  ,n11,v11,n12,v12,n13,v13,n14,v14,n15,v15
  ,n16,v16,n17,v17,n18,v18,n19,v19,n20,v20
  ,n21,v21,n22,v22,n23,v23,n24,v24,n25,v25
  ,n26,v26,n27,v27,n28,v28,n29,v29,n30,v30));
end;
--------------------------------------------------------------------------------
-- Log Set
-- Input:
--   p_id - tms_web_log.id
--   p_text - response text
--   p_cmnt - comment
--------------------------------------------------------------------------------
procedure log_set(p_id int,p_text varchar2,p_cmnt varchar2:=null)is
 pragma autonomous_transaction;
 --
 v_log_id int:=p_id;
 v_text varchar2(4000):=substr(p_text,1,4000);
 v_cmnt varchar2(1000):=substr(p_cmnt,1,975);
begin
 update tms_web_log
 set text=v_text
   ,cmnt=nvl(v_cmnt,cmnt)||' orasid='||sys_context('USERENV','SID')
   ,sec=case when dt<>sysdate then (sysdate-dt)*86400 end
 where id=v_log_id;
 --
 commit;
end;
--------------------------------------------------------------------------------
function response_time return varchar2 is
begin
 return null;
 --return ',"'||sys_context('envun4','web_start')||'","'||get_time||'"';
end;
--------------------------------------------------------------------------------
-- HTTP Respond
-- Input:
--   p_text - response text
procedure http_respond(p_text varchar2)is
begin
 if web_oci_call then
  web_response_buffer:=web_response_buffer||p_text;
 elsif g_remote then
  g_response(g_response.count+1):=p_text;
 else
  htp.p(p_text);
 end if;
end;
--------------------------------------------------------------------------------
-- HTTP Respond
-- Input:
--   p_log_id - tms_web_log.id
--   p_rse_id - rse packet index
--   p_response - response text
--------------------------------------------------------------------------------
procedure http_respond(p_log_id int,p_rse_id int,p_response varchar2:=null)is
 v_prefix varchar2(100):='rse.run('||p_rse_id||',';
 v_suffix varchar2(2):=');';
 v_response_time varchar2(100):=response_time;
begin
 if p_response is null then
  declare
   v_response varchar2(32767):=error_json;
  begin
   log_set(p_log_id,v_response);
   http_respond(v_prefix||v_response||response_time||v_suffix);
  end;
  --
  return;
 end if;
 --
 log_set(p_log_id,p_response);
 --
 if length(v_prefix)+length(p_response)+length(v_response_time)+length(v_suffix)>32767 then
  http_respond(v_prefix);
  http_respond(p_response);
  http_respond(v_response_time);
  http_respond(v_suffix);
 else
  http_respond(v_prefix||p_response||v_response_time||v_suffix);
 end if;
end;
--------------------------------------------------------------------------------
-- HTTP Respond
-- Input:
--   p_log_id - tms_web_log.id
--   p_rse_id - rse packet index
--   p_response - response text
--------------------------------------------------------------------------------
procedure http_respond(p_log_id int,p_rse_id int,p_response clob)is
 v_length int:=nvl(dbms_lob.getlength(p_response),0);
 v_offset int:=1;
 v_divide int;
 v_prefix varchar2(100):='rse.run('||p_rse_id||',';
 v_suffix varchar2(2):=');';
begin
 if nvl(dbms_lob.getlength(p_response),0)<=32767 then
  http_respond(p_log_id,p_rse_id,dbms_lob.substr(p_response));
  return;
 end if;
 --
 http_respond(v_prefix);
 --
 while v_offset<=v_length loop
  v_divide:=dbms_lob.instr(p_response,chr(10),v_offset);
  if v_divide=0 then
   http_respond(p_log_id,p_rse_id,dbms_lob.substr(p_response,v_length-v_offset+1,v_offset));
   exit;
  else
   http_respond(p_log_id,p_rse_id,dbms_lob.substr(p_response,v_divide-v_offset+1,v_offset));
   v_offset:=v_divide+1;
  end if;
 end loop;
 --
 http_respond(response_time||v_suffix);
end;
--------------------------------------------------------------------------------
-- Log Set Info
-- Input:
--   p_id - tms_web_log.id
--   p_info - info
--------------------------------------------------------------------------------
procedure log_set_info(p_id int,p_info varchar2)is
 pragma autonomous_transaction;
begin
 update tms_web_log set info=substr(p_info,1,100) where id=p_id;
 --
 commit;
end;
--------------------------------------------------------------------------------
-- Log Set Session ID
-- Input:
--   p_id - tms_web_log.id
--   p_wsid - web session id
--------------------------------------------------------------------------------
procedure log_set_session(p_id int,p_wsid int)is
 pragma autonomous_transaction;
begin
 update tms_web_log set wsid=p_wsid where id=p_id;
 --
 commit;
end;
--------------------------------------------------------------------------------
-- Free Old Sessions
-- Input:
--   p_user_id - tms_web_log.id
--   p_wsid - web session id
--------------------------------------------------------------------------------
procedure free_old_sessions(p_user_id int,p_wsid int)is
 --pragma autonomous_transaction;
begin
 for c in (select id from web_https where id<>p_wsid and user_id=p_user_id) loop
  web_sessions.session_free(c.id);
 end loop;
end;
--------------------------------------------------------------------------------
-- Login user
-- Input:
--   r - request id
--   a - application name
--   u - user name
--   p - password
-- Output (http):
--   { session : NN, user_id : MM, routes : [ R1, R2 ] }
-- Errors:
--   { error : SSS }
--------------------------------------------------------------------------------
procedure login_user(r int,a varchar2,u varchar2,p varchar2)is
 v_log_id int;
 v_user_id int;
 v_session int;
 v_app_info varchar2(100);
 v_response clob;
 v_config clob;
begin
 v_log_id:=log_add(null,r,'a',a,'u',u,'p',p);
 --
 dbms_lob.createtemporary(v_response,true);
 --msg(700);
 --
 v_user_id:=pg_orders_web.login_username(a,u,p);
 v_app_info:='{user_id:'||v_user_id||',user_name:"'||u||'",app:"'||a||'"}';
 log_set_info(v_log_id,v_app_info);
 --
 v_session:=web_sessions.session_create(v_user_id,u,a,v_app_info,get_url_path);
 log_set_session(v_log_id,v_session);
 --
 if u<>'test' then
  free_old_sessions(v_user_id,v_session);
 end if;
 --
 pg_orders_web.init_session(v_session,v_user_id);
 --
 pg_orders_web.clob_add(v_response
  ,'{session:'||v_session||',user_id:'||v_user_id);
 v_config:=pg_orders_web.init_all;
 pg_orders_web.clob_add(v_response,v_config);
 pg_orders_web.clob_add(v_response,'}');
 --
 http_respond(v_log_id,r,v_response);
exception when others then
 http_respond(v_log_id,r,error_json(true));
end;
--------------------------------------------------------------------------------
-- Login barcode
-- Input:
--   r - request id
--   a - application name
--   b - barcode
-- Output (http):
--   { session : NN, user_id : MM, routes : [ R1, R2 ] }
-- Errors:
--   { error : SSS }
procedure login_barcode(r int,a varchar2,b int)is
 v_log_id int;
 v_user_id int;
 v_session int;
 v_user_name varchar2(30);
 v_app_info varchar2(100);
 v_response clob;
begin
 v_log_id:=log_add(null,r,'a',a,'b',b);

 --
 dbms_lob.createtemporary(v_response,true);
 --
 v_user_id:=pg_orders_web.login_barcode(a,b);
 v_user_name:=sys_context('envun4','param_username',30);
 v_app_info:='{user_id:'||v_user_id||
   ',user_name:"'||v_user_name||'",app:"'||a||'"}';
 log_set_info(v_log_id,v_app_info);
 --
 v_session:=web_sessions.session_create(v_user_id
   ,v_user_name,a,v_app_info,get_url_path);
 log_set_session(v_log_id,v_session);
 --
 free_old_sessions(v_user_id,v_session);
 --
 pg_orders_web.init_session(v_session,v_user_id);
 --
 pg_orders_web.clob_add(v_response
  ,'{session:'||v_session||',user_id:'||v_user_id);
 pg_orders_web.clob_add(v_response,pg_orders_web.init_all);
 pg_orders_web.clob_add(v_response,'}');
 --
 http_respond(v_log_id,r,v_response);
exception when others then
 http_respond(v_log_id,r,error_json(true));
end;
--------------------------------------------------------------------------------
-- Refresh session
-- Input:
--   r - request id
--   s - session id
-- Output (http):
--   { }
-- Errors:
--   { error : SSS }
--------------------------------------------------------------------------------
procedure refresh_session(r int,s int)is
 v_log_id int;
 --v_frame int;
 v_response varchar2(1000);
begin
 --v_log_id:=log_add(s,'?r='||r||chr(38)||'s='||s);
 v_log_id:=log_add(s,r);
 --
 --v_frame:=web_sessions.get_new_frame(s);
 for c in (select * from web_https where id=s) loop
  v_response:='{frame:'||c.last_frame||
    ',time:"'||to_char(c.last_time,'hh24:mi:ss')||'"}';
 end loop;
 --
 if v_response is null then
  msg('Session '||s||' is out of date');
 end if;
 --v_response:='{}';
 --
 http_respond(v_log_id,r,v_response);
exception when others then
 http_respond(v_log_id,r);
end;
--------------------------------------------------------------------------------
-- Logout
-- Input:
--   r - request id
--   s - session id
-- Output (http):
--   { }
-- Errors:
--   { error : SSS }
--------------------------------------------------------------------------------
procedure logout(r int,s int,closeday varchar2 := 'false')is
 v_log_id integer;
 v_response varchar2(1000);
 v_userid int;
begin
 --v_log_id:=log_add(s,'?r='||r||chr(38)||'s='||s);
 v_log_id:=log_add(s,r);
 --pg_orders_web.process_logout(s, closeday='true');
 --
 web_sessions.session_free(s);
 --
 v_response:='{}';
 --
 http_respond(v_log_id,r,v_response);
exception when others then
 http_respond(v_log_id,r);
end;
--------------------------------------------------------------------------------
end;

/