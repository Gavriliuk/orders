CREATE OR REPLACE package pg_web_orders_pwa authid current_user as
--------------------------------------------------------------------------------
-- Last modification date: 02.02.25
--------------------------------------------------------------------------------
procedure local_service(p_request varchar2:=null);
procedure remote_service(p_path varchar2,p_proc varchar2,p_param varchar2,p_request varchar2,p_response in out pg_web_base.t_response);
procedure test_service(p_request varchar2:=null);
procedure test;
--------------------------------------------------------------------------------
end;
/

CREATE OR REPLACE package body pg_web_orders_pwa as
--------------------------------------------------------------------------------
-- Last modification date: 02.02.25
--------------------------------------------------------------------------------
-- HTTP Respond
-- Input:
--   p_log_id - tms_web_log.id
--   p_response - responce text
procedure http_respond(p_log_id int,p_response clob)is
 c_max_portion constant binary_integer:=32760;
 v_length int:=nvl(dbms_lob.getlength(p_response),0);
 v_portion varchar2(32767);
 v_offset int:=1;
 v_divide int;
begin
 pg_web_base.log_set(p_log_id,dbms_lob.substr(p_response,4000),'size='||v_length);
 while v_offset+c_max_portion<=v_length loop
  v_portion:=dbms_lob.substr(p_response,offset=>v_offset);
  v_divide:=instr(v_portion,chr(10),-1);
  if v_divide=0 then
   raise_application_error(-20000,'JSON line is too long after position '||v_offset);
  end if;
  v_portion:=substr(v_portion,1,v_divide-1);
  pg_web_base.http_respond(v_portion);
  v_offset:=v_offset+v_divide;
 end loop;
 --
 if v_offset<=v_length then
  pg_web_base.http_respond(dbms_lob.substr(p_response,offset=>v_offset));
 end if;
end;
--------------------------------------------------------------------------------
function log_add(p_request varchar2:=null,p_session int:=null)return int is
 v_parameter varchar2(4000):=substr('?'||pg_web_base.g_parameter||'='||substr(p_request,1,4000),1,4000);
begin
 return pg_web_base.log_add(p_session,v_parameter);
end;
--------------------------------------------------------------------------------
function check_session
(
 p_session int
,p_log_id int
)return int is
 v_session int;
 v_user_id int;
 v_app_info varchar2(255);
 --
 v_format constant char:='p';
 v_app_name constant varchar2(30):='orders-pwa';
 v_username constant varchar2(30):=web_json.get_subnode_value(0,'usr');
 v_url_path constant varchar2(1000):=pg_web_base.get_url_path;
 --
 procedure create_new_session is
  v_password varchar2(30):=web_json.get_subnode_value(0,'pwd');
 begin
  v_user_id:=pg_orders_web.login_username(v_app_name,v_username,v_password);
  --
  v_app_info:='{user_id:'||v_user_id||
    ',user_name:"'||v_username||'",app:"'||v_app_name||'",format:"'||v_format||'"}';
  --
  v_session:=ss$web$session.session_create(v_user_id
    ,v_username,v_app_name,v_app_info,v_url_path,v_format);
 end;
 --
 procedure log_upd is
  pragma autonomous_transaction;
 begin
  update tms_web_log set wsid=v_session,info=v_app_info where id=p_log_id;
  commit;
 end;
 --
begin
 if p_session>0 then
  for c in (select * from sst$web$https where id=p_session) loop
   if v_username=c.user_name and v_app_info=c.app_info and v_format=c.format then
    v_session:=p_session;
    v_user_id:=c.user_id;
    v_app_info:=c.app_info;
   end if;
  end loop;
 end if;
 --
 if v_session is null or v_user_id is null or v_app_info is null then
  create_new_session;
 end if;
 --
 log_upd;
 --
 if v_username<>'test' then
  pg_web_base.free_old_sessions(v_user_id,v_session);
 end if;
 --
 pg_orders_web.init_session(v_session,v_user_id);
 --
 bg_policy.initfilter_nrset_tree('');
 --
 return v_session;
end;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
procedure service(p_request varchar2:=null)is
 v_log_id int;
 v_logged boolean:=false;
 v_command varchar2(30);
 v_converted varchar2(32767);
 v_response clob;
 v_session_in int;
 v_session int;
 v_user_id int;
begin
 if p_request is null then
  v_logged:=true;
  v_log_id:=pg_web_base.log_add(null);
  msg('request is empty');
 end if;
 --
 v_converted:=convert(p_request,'CL8MSWIN1251','AL32UTF8');
 v_logged:=true;
 v_log_id:=log_add(v_converted);
 --
 web_json.parse(p_request);
 v_command:=web_json.get_subnode_value(0,'cmd');
 v_session_in:=web_json.get_subnode_value(0,'session');
 --
 if v_command='logout' then
  ss$web$session.session_free(v_session_in);
  declare
   v_state web_json.t_fill_state;
  begin
   web_json.create_top_node_object(v_state);
  end;
 else
  v_session:=check_session(v_session_in,v_log_id);
  --
  if v_session=v_session_in then
   v_session:=null;
  end if;
  --
  case v_command
  when 'dbrefresh' then
   pg_orders_pwa.refresh_database(v_session);
  when 'dbexport' then
   pg_orders_pwa.export_database(v_session);
  when 'dbreport-debt' then
   pg_orders_pwa.report_debt(v_session);
  when 'dbreport-plan' then
   pg_orders_pwa.report_plan(v_session);
  else
   msg('Unknown command: '''||v_command||'''');
  end case;
 end if;
 --
 web_json.stringify(v_response,2);
 http_respond(v_log_id,v_response);
exception when others then
 if v_log_id is null and not v_logged then
  begin
   v_log_id:=log_add(v_converted);
  exception when others then
   null;
  end;
 end if;
 --
 v_converted:=dbms_utility.format_error_backtrace; -- Reused var
 v_converted:=convert(v_converted,'AL32UTF8','CL8MSWIN1251');
 http_respond(v_log_id,
   '{'||chr(10)||
   ' "cmd":"'||v_command||'"'||chr(10)||
   ',"error":"'||replace(replace(convert(sqlerrm,'AL32UTF8','CL8MSWIN1251'),'"','\"'),chr(10),'\n')||'"'||chr(10)||
   ',"trace":['||chr(10)||
   '  "'||replace(replace(rtrim(v_converted,chr(10)),'"','\"'),chr(10),'"'||chr(10)||' ,"')||'"'||chr(10)||
   ' ]'||chr(10)||
   '}');
end;
--------------------------------------------------------------------------------
procedure local_service(p_request varchar2:=null) is
begin
 begin
  pg_web_base.init_env_owa;
 exception when others then
  pg_web_base.http_respond('{'||chr(10)||
   ' "error":"'||sqlerrm||'"'||chr(10)||
   ',"trace":['||chr(10)||
   '  "'||replace(replace(rtrim(convert(dbms_utility.format_error_backtrace,
     'AL32UTF8','CL8MSWIN1251'),chr(10)),'"','\"'),chr(10),'"'||chr(10)||' ,"')||'"'||chr(10)||
   ' ]'||chr(10)||
   '}');
  return;
 end;
 --
 service(p_request);
end;
--------------------------------------------------------------------------------
procedure remote_service(p_path varchar2,p_proc varchar2,p_param varchar2,p_request varchar2,p_response in out pg_web_base.t_response) is
begin
 pg_web_base.init_env(p_path,p_proc,p_param);
 --
 service(p_request);
 --
 pg_web_base.get_response(p_response);
end;
--------------------------------------------------------------------------------
procedure test_service(p_request varchar2:=null) is
 v_response pg_web_base.t_response;
begin
 pg_web_base.init_env('/orders','o','r');
 --
 service(p_request);
 --
 pg_web_base.get_response(v_response);
 --
 for i in 1..v_response.count loop
  say(v_response(i));
 end loop;
end;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
procedure test is
 v_title varchar2(100):='Oracle package pg_web_order_json test procedure';
 v_request varchar2(32767);
 v_session int:=123;
 --
 procedure test_dbrefresh is
  v_state web_json.t_fill_state;
 begin
  web_json.create_top_node_object(v_state);
  web_json.begin_subnodes(v_state);
   web_json.add_subnode_string(v_state,'cmd','dbrefresh');
   web_json.add_subnode_string(v_state,'username','test');
   web_json.add_subnode_string(v_state,'password','test');
  web_json.end_subnodes(v_state);
  web_json.stringify(v_request);
  say(v_request);
  service(v_request);
 end;
 --
 procedure test_dbexport is
  v_state web_json.t_fill_state;
  v_main_dep int:=sys_context('envun4','maindep');
 begin
  web_json.create_top_node_object(v_state);
  web_json.begin_subnodes(v_state);
   web_json.add_subnode_string(v_state,'cmd','putdocs');
   web_json.add_subnode_number(v_state,'session',v_session);
   web_json.add_subnode_string(v_state,'username','test');
   web_json.add_subnode_string(v_state,'password','test');
   -- docs begin
   web_json.add_subnode_array(v_state,'docs');
   web_json.begin_subnodes(v_state);
    -- doc 1
    web_json.add_subnode_object(v_state);
    web_json.begin_subnodes(v_state);
     web_json.add_subnode_number(v_state,'id',1);
     web_json.add_subnode_number(v_state,'punct',1);
     web_json.add_subnode_number(v_state,'stock',v_main_dep);
     web_json.add_subnode_number(v_state,'type',1);
     web_json.add_subnode_string(v_state,'shipping','11.12.2012');
     web_json.add_subnode_string(v_state,'delivery','12.12.2012');
     web_json.add_subnode_string(v_state,'create','10.12.2012 12:00:00');
     web_json.add_subnode_string(v_state,'modify','10.12.2012 16:00:00');
     -- doc data begin
     web_json.add_subnode_array(v_state,'d');
     web_json.begin_subnodes(v_state);
      -- product 1
      web_json.add_subnode_object(v_state);
      web_json.begin_subnodes(v_state);
       web_json.add_subnode_number(v_state,'p',1);
       web_json.add_subnode_number(v_state,'q',10);
       web_json.add_subnode_number(v_state,'r',5);
      web_json.end_subnodes(v_state);
      -- product 2
      web_json.add_subnode_object(v_state);
      web_json.begin_subnodes(v_state);
       web_json.add_subnode_number(v_state,'p',2);
       web_json.add_subnode_number(v_state,'q',20);
       web_json.add_subnode_number(v_state,'r',10);
      web_json.end_subnodes(v_state);
     web_json.end_subnodes(v_state);
     -- doc data end
    web_json.end_subnodes(v_state);
    -- doc 2
    web_json.add_subnode_object(v_state);
    web_json.begin_subnodes(v_state);
     web_json.add_subnode_number(v_state,'id',2);
     web_json.add_subnode_number(v_state,'punct',2);
     web_json.add_subnode_number(v_state,'stock',v_main_dep);
     web_json.add_subnode_number(v_state,'type',1);
     web_json.add_subnode_string(v_state,'shipping','11.12.2012');
     web_json.add_subnode_string(v_state,'delivery','12.12.2012');
     web_json.add_subnode_string(v_state,'create','10.12.2012 12:00:00');
     web_json.add_subnode_string(v_state,'modify','10.12.2012 16:00:00');
     -- doc data begin
     web_json.add_subnode_array(v_state,'d');
     web_json.begin_subnodes(v_state);
      -- product 1
      web_json.add_subnode_object(v_state);
      web_json.begin_subnodes(v_state);
       web_json.add_subnode_number(v_state,'p',1);
       web_json.add_subnode_number(v_state,'q',20);
       web_json.add_subnode_number(v_state,'r',10);
      web_json.end_subnodes(v_state);
      -- product 2
      web_json.add_subnode_object(v_state);
      web_json.begin_subnodes(v_state);
       web_json.add_subnode_number(v_state,'p',2);
       web_json.add_subnode_number(v_state,'q',40);
       web_json.add_subnode_number(v_state,'r',20);
      web_json.end_subnodes(v_state);
     web_json.end_subnodes(v_state);
     -- doc data end
    web_json.end_subnodes(v_state);
   web_json.end_subnodes(v_state);
   -- docs end
  web_json.end_subnodes(v_state);
  web_json.stringify(v_request,2);
  say(v_request);
  service(v_request);
 end;
 --
 procedure test_logout is
  v_state web_json.t_fill_state;
 begin
  web_json.create_top_node_object(v_state);
  web_json.begin_subnodes(v_state);
   web_json.add_subnode_string(v_state,'cmd','logout');
   web_json.add_subnode_number(v_state,'session',v_session);
  web_json.end_subnodes(v_state);
  web_json.stringify(v_request);
  say(v_request);
  service(v_request);
 end;
 --
begin
 if owa.num_cgi_vars is null then
  declare
   thepage htp.htbuf_arr;
   irows pls_integer;
  begin
   test_dbrefresh;
   test_dbexport;
   test_logout;
   htp.get_page(thepage,irows);
   for i in 1..thepage.count loop
    say(thepage(i));
   end loop;
  end;
 else
  pg_web_base.init_env_owa;
  --
  htp.p('<!doctype html public "-//w3c//dtd html 4.0 transitional//en">');
  htp.p('<html><head>');
  htp.p('<meta http-equiv="content-language" content="ru">');
  htp.p('<meta http-equiv="content-type" content="text/html; charset=windows-1251">');
  htp.p('<title>'||v_title||'</title>');
  htp.p('</head><body>');
  htp.p('<h1 style="text-align:center">'||v_title||'</h1>');
  begin
   test_dbrefresh;
   test_dbexport;
   test_logout;
  exception when others then
   htp.p('<h2 style="color:red">'||sqlerrm||'</h2>');
  end;
  htp.p('</body></html>');
 end if;
end;
--------------------------------------------------------------------------------
end;
/