CREATE OR REPLACE PACKAGE pg_orders_pwa as
--------------------------------------------------------------------------------
-- Last modification date: 10.11.24
--------------------------------------------------------------------------------
procedure refresh_database(p_session int);
procedure export_database(p_session int);
procedure test;
--------------------------------------------------------------------------------
end;

/

CREATE OR REPLACE PACKAGE BODY pg_orders_pwa as
--------------------------------------------------------------------------------
-- Last modification date: 10.11.24
--------------------------------------------------------------------------------
function date_format return varchar2 is begin return 'yyyy-mm-dd'; end;
function time_format return varchar2 is begin return 'yyyy-mm-dd hh24:mi:ss'; end;
--------------------------------------------------------------------------------
procedure start_log(p_text varchar2)is
 procedure start_int is
  pragma autonomous_transaction;
 begin
  delete from xdblog where dt<trunc(sysdate);
  commit;
 end;
begin
 dbms_output.put_line(current_timestamp||' '||p_text);
 --start_int;
end;
--------------------------------------------------------------------------------
procedure write_log(p_start date,p_text varchar2)is
 procedure write_int(p_time date)is
  pragma autonomous_transaction;
 begin
  insert into xdblog (dt,description) values (p_time,p_text);
  commit;
 end;
begin
 dbms_output.put_line(lpad(round((sysdate-p_start)*86400),3)||' '||p_text);
 --write_int(sysdate);
end;
--------------------------------------------------------------------------------
-- Store response blocks
--------------------------------------------------------------------------------
procedure prepare_debitori(p_start date)is
 --
 vdata date:=trunc(sysdate);
 --
 v_user_id int;
 v_agent_id int;
 --c_day1 constant int:=7;
 --c_day2 constant int:=14;
 --c_day3 constant int:=21;
 --c_day4 constant int:=28;
 v_sold_date DATE;
 v_sld number(20,3):=0;

 procedure clear_for_user is
 begin
  delete from yrb_debtitori where user_id=v_user_id;
  delete from yrb_debtitori_detail where user_id=v_user_id;
  delete from xsldx;
  delete from xsld;
  delete from trgb_badolg;
  delete from ba_dolg;
 end;
 --
begin
 write_log(p_start,'prepare_debitori begin');
 v_user_id:=sys_context('envun4','param_userid');
 --
 if v_user_id is null then
  msg('param_userid is null');
 end if;
 --
 begin
  select id into v_agent_id from vms_order_agents where cod_user=v_user_id;
 exception when no_data_found then
  msg('param_userid "'||v_user_id||'" is not found in vms_order_agents');
 end;
 --
 clear_for_user;
 --
 insert into xsld (id,dep)
 select 'ruta',id_ruta from vms_order_route_agents where id_agent=v_agent_id and main_agent='P';
 --write_log(p_start,'prepare_debitori 2');
 --
 insert into xsld (id,dep)
 select 'client',cod from vms_order_clients_gr where id_ruta in(select dep from xsld where id='ruta');
 write_log(p_start,'prepare_debitori 3');
 --
 un$sld.make(vdata,'4','ADE',pCont=>'221 52 544 5393',pdep=>'select dep from xsld where id=''client''',pNrCM=>'201');
 write_log(p_start,'prepare_debitori 4'); -- 2 min. => 15 sec.
 --
 un$sld.make(vdata,'7','AD',pCont=>'221 52 544 5393',pdep=>'select dep from xsld where id=''client''',pNrCM=>'201');
 write_log(p_start,'prepare_debitori 5'); -- 2 min. => 15 sec.
 --
 insert into xsld (id,dep,sc1,cont,cant,suma)
 select '5',x.dep,x.sc1,d.cont,m.tip,x.suma
 from xsld x,ytms_setare_debitoriD d,ytms_setare_debitoriM m
 where x.id='4' and x.dep=m.dep and x.cont=d.cont and d.dep=m.dep;
 --write_log(p_start,'prepare_debitori 6');
 --
 update xsld set sc1=0 where id='5' and cant=1;
 --write_log(p_start,'prepare_debitori 7');
 --
 delete xsld x where x.id='4' and x.dep in (select y.dep from xsld y where y.id='5');
 --write_log(p_start,'prepare_debitori 8');
 delete xsld x where x.id='4' and x.cont not in (2211,2214,5231);
 --write_log(p_start,'prepare_debitori 9');
 --
 update xsld set sc1=0 where id='4';
 --write_log(p_start,'prepare_debitori 10');
 --
 insert into xsld (id,cont,dep,sc1,suma)
 select '4',x.cont,x.dep,x.sc1,x.suma from xsld x where x.id='5';
 --write_log(p_start,'prepare_debitori 11');
 --
 insert into xsld (id,dep,sc1,suma)
 select '1', a.dep,a.sc1,a.suma
 from
 (
  select x.dep,x.sc1,sum(x.suma)suma
  from xsld x
  where id='4'
  group by x.dep,x.sc1
 ) a where a.suma>0;
 --write_log(p_start,'prepare_debitori 12');
 -- inseram numarul de zile(otsrochka)
 update xsld x set div=
 (
  select distinct zile_schema_deplata
  from
  (
   select zile_schema_deplata,null zile_schema_deplata1,clientid
   from vcn0m_contracts_ext m
   where vdata between m.datastart and m.dataend
   and m.contractid in (select cod from vmdb_docs where sysfid=48355)
  ) a
  where a.clientid=x.dep
 )
 where id='1';     
 --write_log(p_start,'prepare_debitori 13');
 --i6em datu poslednei registratsii ostatkob
 select nvl((select max(dataend) from tmdb_dsld where cod=1/*dataend<=vdata*/),to_date('31.12.2018','dd.mm.yyyy')) into v_sold_date from dual;
 write_log(p_start,'prepare_debitori 14');
 --
 insert into trgb_badolg(dtdep,dtsc1,data,nrdoc,sumadt)
 select dtdep,dtsc1,data,nrdoc,sumadt
 from
 (
   Select dtdep,dtsc1,data,nrdoc,sumadt
   from
   (
     --
     select dtdep,dtsc1,data,nrdoc,sumadt
     from
     (
       select dtdep,dtsc1,data,nrdoc,sum(suma_dt)sumadt
        ,(select nvl(sum(suma),0) from xsld where id='1' and dep=dtdep)sld
       from
       (
         select *
         from
         (
           select c.dtdep,c.dtsc1,c.data,c.nrdoc,c.cod,sum(c.suma)suma_dt
           from tmdb_cm c
           where c.dt in (2211,2214)
             and c.ct in (6111,6113,6121,6112,5342,6118,6119)
             and c.isvalid is null
             and c.sptype=0
             and c.data between v_sold_date+1 and vdata
           group by c.dtdep,c.dtsc1,c.data,c.nrdoc,c.cod
         ) tt
         where tt.dtdep in (select dep from xsld where id='1')
         --order by tt.dtdep, tt.dtsc1
       )
       group by dtdep,dtsc1,data,nrdoc
     )
     where sld>=0 and sumadt>0
     --
     union
     --
     select dtdep,dtsc1,data,nrdoc,sumadt
     from
     (
       select dtdep,dtsc1,data,nrdoc,sum(suma_dt)sumadt,0 sld
       from
       (
         select c.dtdep,c.dtsc1,c.data,c.nrdoc,c.cod,sum(c.suma)suma_dt
         from market_db_cmr c
         where c.dt in (2211,2214) and c.ct in (6111,6113,6121,6112,5342,6118)
           and c.data between to_date('31.12.2012')+1 and to_date('31.12.2014')
           and c.dtdep in (select dep from xsld where id='1')
           and dtnrcm in (select id from xnrset)
         group by c.dtdep,c.dtsc1,c.data,c.nrdoc,c.cod
         --order by c.dtdep,c.dtsc1
       )
       group by dtdep,dtsc1,data,nrdoc
     ) where sumadt>0
     --
     union
     --
     select x.dep,null,to_date('31.12.2018'),1,x.suma from xsld x where id='1'
   )
   --ORDER BY dtdep,DATA desc,nrdoc,dtsc1
 );
 write_log(p_start,'prepare_debitori 15'); -- 12 sec.
 ------------ cautarea facturilor care vor acoperi soldul total pe client
 for k in (select dep,sc1,suma from xsld where id='1')
 loop
  v_sld:=k.suma;
  --rashityvaem dolg i kidaem v tablicy
  for i in
  (
   select *
   from trgb_badolg
   where dtdep=k.dep and decode(k.sc1,0,k.sc1,dtsc1)=k.sc1
   order by data desc,nrdoc desc
  )
  loop
   if v_sld-i.sumadt>0 then
    insert into ba_dolg values (i.dtdep,i.dtsc1,i.data,i.nrdoc,i.sumadt,201);
   end if;
   --
   if v_sld-i.sumadt<=0 then
    insert into ba_dolg values (i.dtdep,i.dtsc1,i.data,i.nrdoc,v_sld,201);
    exit;
   end if;
   --
   v_sld:=v_sld-i.sumadt;
  end loop;
 end loop;
 --write_log(p_start,'prepare_debitori 16');
 --
 insert into xsld (id,cont,dep,sc1,nrdoc,data,suma,div)
 select 'doc',2211,dtdep,dtsc1,nrdoc,data,dolg,
  (
   select zile_schema_deplata
   from vcn0m_contracts_ext m
   where to_date(vdata) between m.datastart and m.dataend
     and m.clientid=b.dtdep and m.contractid in (select cod from vmdb_docs where sysfid=48355)
  ) dni_otsrochki
 from ba_dolg b
 where b.dolg<>0;
 --write_log(p_start,'prepare_debitori 17');
 --
 update xsld set nrcm=to_date(trunc(sysdate))-data-nvl(div,0) where id='doc';
 update xsld set cant    =suma where id='doc' and nrcm between 1 and 7;
 update xsld set price   =suma where id='doc' and nrcm between 8 and 14;
 update xsld set sumaval =suma where id='doc' and nrcm between 15 and 21;
 update xsld set sumagaap=suma where id='doc' and nrcm between 22 and 28;
 update xsld set cant1   =suma where id='doc' and nrcm>28;
 --write_log(p_start,'prepare_debitori 18');
 --
 insert into yrb_debtitori (id_client,id_punct,total,suma35,suma28,suma21,suma14,suma7,tot_plata,total_dat,zile,user_id)
 select client, punct, sum(total), sum(suma35), sum(suma28), sum(suma21), sum(suma14), sum(suma7), sum(tot_plata), sum(tot_plata)+sum(total)
  ,nvl((select div from xsld c where c.id='doc' and c.dep=a.client/* and c.sc1=a.punct*/   and rownum=1),14),v_user_id  
 from
 (
  select sc0 client,sc1 punct 
   ,sum( nvl(sum1,0))+sum(nvl(sum2,0))+sum(nvl(sum3,0))+sum(nvl(sum4,0))+sum(nvl(sum5,0)) total
   ,sum(nvl(sum0,0))-sum(nvl(sum1,0))-sum(nvl(sum2,0))-sum(nvl(sum3,0))-sum(nvl(sum4,0))-sum(nvl(sum5,0)) tot_plata
   ,sum(nvl(sum5,0)) suma35
   ,sum(nvl(sum4,0)) suma28
   ,sum(nvl(sum3,0)) suma21
   ,sum(nvl(sum2,0)) suma14
   ,sum(nvl(sum1,0)) suma7
   ,sum(cant0) zile
  from
  (
   select dep sc0,0 sc1,sum(suma) sum0,sum(cant) sum1,sum(price) sum2,sum(sumaval) sum3,sum(sumagaap) sum4,sum(cant1) sum5,null cant0
   from xsld
   where id='doc'
   group by /*cont,*/dep
  ) x 
  group by sc0,sc1
 ) a
 --where nvl(TOTAL,0)>0            
 group by client,punct;
 --write_log(p_start,'prepare_debitori 19');
 --
 insert into yrb_debtitori_detail (client,id_punct,nrdoc,doc_name,data,nrmanual,cont,doc_s7,doc_s14,doc_s21,doc_s28,doc_s35,sum_plata,sum_dat_exp,sum_tot_doc,user_id)
 select dep,sc1,nrdoc,case when cont=2211 and nrdoc is not null then 'Factura' else 'Sold' end doc_name
  ,data,nrmanual,cont,doc1_1,doc2_1,doc3_1,doc4_1,doc5_1,doc0_1,sum_dat_exp,nvl(sum_dat_exp,0)+nvl(doc0_1,0),v_user_id
 from
 (
  select dep,sc1,nrdoc,trunc(data) data,(select nrmanual from tmdb_docs where cod=x.nrdoc) nrmanual
   ,to_number(cont) cont
   ,(select suma from xsld s where nvl(s.nrdoc,0)=nvl(x.nrdoc,0) and s.dep=x.dep and s.sc1=x.sc1 and s.cont=2211 and id='SUMADT') suma_fact
   ,cant doc1_1,price doc2_1,sumaval doc3_1,sumagaap doc4_1,cant1 doc5_1,nvl(suma,0)-nvl(cant,0)-nvl(price,0)-nvl(sumaval,0)-nvl(sumagaap,0)-nvl(cant1,0) as doc0_1 
   ,nvl(cant,0)+nvl(price,0)+nvl(sumaval,0)+nvl(sumagaap,0)+nvl(cant1,0) sum_dat_exp
  from xsld x
  where id='doc'
  order by data desc,nrdoc desc
 )a;
 --
 write_log(p_start,'prepare_debitori done');
end;
--------------------------------------------------------------------------------
procedure prepare_sld(p_start date)is
 --
 procedure prepare_sld_puncts is
  v_user_id int;
  v_agent_id int;
 begin
  v_user_id:=sys_context('envun4','param_userid');
  --
  begin
   select id into v_agent_id from vms_order_agents where cod_user=v_user_id /*and um='P'*/;
  exception when no_data_found then
   msg('Agent USERID='||v_user_id||' not found');
  end;
  --
  delete from xsld;
  --
  insert into xsld (id,sc)
  select 'r',id_ruta from vms_order_route_agents
  where id_agent=v_agent_id and trunc(sysdate)<datae+31;
  --
  insert into xsld (id,sc,dep)
  select 'p',id_ruta,cod from vms_order_clients_gr
  where  id_ruta is not null and id_ruta in(select id_ruta from vms_order_route_agents where id_agent=v_agent_id and main_agent='P' );
 end;
 --
 procedure prepare_sld_turnover is
  v_cont_ff int:=2211;
  v_cont_tr int:=2214;
  v_cont_vinz1 int := 6111;
  v_cont_vinz2 int := 6112;
  v_cont_tva int:=sys_context('envun4','VCONT_TVA');
  --v_id_tree int:=sys_context('envun4','TREE_MARFA_ID0');
 begin
  ----
  insert into xsld(id,dep,sc1,suma)
  select 't',dep,sc1,sum(nvl(suma,0))
  from (
   select dtsc1 dep
   ,(select prodgr_s_38 from tms_mpt where cod=a.ctsc)sc1
   --,(select id2 from tms_sysgrp where id0=v_id_tree and sc=a.ctsc)sc1
   ,nvl(suma,0)+nvl((select suma from vmdb_cmr
     where nrdoc=a.nrdoc and ct=v_cont_tva and codfcdebaza=a.cod),0)suma
   from vmdb_cmr a
   where dt in (v_cont_ff,v_cont_tr) and ct in (v_cont_vinz1,v_cont_vinz2)
     and dtsc1 in (select dep from xsld where id='p')
     and data between trunc(sysdate,'MM') and trunc(sysdate)
     and dtnrcm=101
  )
  group by dep,sc1;
 end;
 --
begin
 write_log(p_start,'prepare_sld begin');
 prepare_sld_puncts;
 write_log(p_start,'prepare_sld_puncts done');
 prepare_sld_turnover;
 write_log(p_start,'prepare_sld_turnover done');
end;
--------------------------------------------------------------------------------
/*procedure prepare_debitori is
begin
 pg_orders_web_xml.prepare_debitori;
 write_log('prepare_debitori');
end;
--------------------------------------------------------------------------------
procedure prepare_sld is
begin
 pg_orders_web_xml.prepare_sld;
 write_log('prepare_sld');
end;*/
--------------------------------------------------------------------------------
procedure store_markets(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'markets');
 web_json.begin_subnodes(p_state);
 for c in (select distinct tipclient,clc_tipclient_t
   from vms_order_clients
   where cod in (select dep from xsld where id='p')
   order by tipclient)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.tipclient);
   web_json.add_subnode_string(p_state,'n',nvl(c.clc_tipclient_t,'^market '||c.tipclient));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_markets');
end;
--------------------------------------------------------------------------------
procedure store_cities(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'cities');
 web_json.begin_subnodes(p_state);
 for c in (select distinct oras,clc_oras_t
   from vms_order_clients
   where oras is not null
   order by oras)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.oras);
   web_json.add_subnode_string(p_state,'n',nvl(c.clc_oras_t,'^city '||c.oras));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_cities');
end;
--------------------------------------------------------------------------------
procedure store_routes(p_state in out nocopy web_json.t_fill_state) is
 v_user_id int:=sys_context('envun4','param_userid');
 v_agent_id int;
 v_obj_id int;
 v_nrset int;
begin
 select id into v_agent_id from vms_order_agents where cod_user=v_user_id;
 select obj_id into v_obj_id from xusers where cod=v_user_id;
 select 30||nvl(to_number(min(value)),0) into v_nrset from a$adp$v where obj_id=v_obj_id and name='FILTRU';
 --
 web_json.add_subnode_array(p_state,'routes');
 web_json.begin_subnodes(p_state);
 for r in (select distinct id_ruta,clc_ruta_t
   from vms_order_route_agents
   where id_agent=v_agent_id and main_agent='P'
   order by id_ruta)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',r.id_ruta);
   web_json.add_subnode_string(p_state,'n',nvl(r.clc_ruta_t,'^route '||r.id_ruta));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_routes');
end;
--------------------------------------------------------------------------------
procedure datorii_client(p_state in out nocopy web_json.t_fill_state) is
 v_user_id int:=sys_context('envun4','param_userid');
 v_agent int;
begin
 select id into v_agent from vms_order_agents where cod_user=v_user_id;
 --
 web_json.add_subnode_array(p_state,'datorii');
 web_json.begin_subnodes(p_state);
 --
 for p in (
  select id_client,(select client from vms_order_clients where cod=id_client) client_name,zile,user_id
   ,sum(suma7)suma7,sum(suma14)suma14 ,sum(suma21)suma21,sum(suma28)suma28,sum(suma35)suma35
   ,sum(total)total,sum(total_dat)total_dat,sum(tot_plata)tot_plata
  from yrb_debtitori where user_id=v_user_id
  group by id_client,zile,user_id
 )
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',p.id_client);
   web_json.add_subnode_string(p_state,'n',p.client_name);
   web_json.add_subnode_optional_number(p_state,'z',p.zile);
   web_json.add_subnode_optional_number(p_state,'u',p.user_id);
   web_json.add_subnode_optional_number(p_state,'s1',p.suma7);
   web_json.add_subnode_optional_number(p_state,'s2',p.suma14);
   web_json.add_subnode_optional_number(p_state,'s3',p.suma21);
   web_json.add_subnode_optional_number(p_state,'s4',p.suma28);
   web_json.add_subnode_optional_number(p_state,'s5',p.suma35);
   web_json.add_subnode_optional_number(p_state,'tot',p.total);
   web_json.add_subnode_optional_number(p_state,'tot_dat',p.total_dat);
   web_json.add_subnode_optional_number(p_state,'tot_plata',p.tot_plata);
  web_json.end_subnodes(p_state);
 end loop;
 --
 web_json.end_subnodes(p_state);
 --write_log(p_start,'datorii_client');
end;
--------------------------------------------------------------------------------
procedure store_puncts(p_state in out nocopy web_json.t_fill_state) is
 v_company_id int:=un$nrset.get_company_id(sys_context('envun4','param_nrsetdefault'));
 v_user_id int:=sys_context('envun4','param_userid');
 v_agent_id int;
begin
 select id into v_agent_id from vms_order_agents where cod_user=v_user_id;
 --
 web_json.add_subnode_array(p_state,'puncts');
 web_json.begin_subnodes(p_state);
 for p in (
  select m.cod,m.client,m.parent_cod,m.id_ruta,o.addr_fact
  ,nvl(o.adress,p.adress)address,nvl(o.telefon,p.telefon)telefon
  ,nvl(o.telprim,p.telprim)telprim,nvl(o.director,p.director)director
  from vms_order_clients_gr m,vms_org o,vms_org p,vms_order_route_agents a
  where m.id_ruta=a.id_ruta
    and m.nrset=a.nrset
    and o.cod=m.cod
    and p.cod(+)=m.parent_cod
    and a.id_agent=v_agent_id
    and a.nrset=v_company_id
    and sysdate between a.datas and a.datae
    and a.main_agent='P'
  order by m.cod
 )
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',p.cod);
   web_json.add_subnode_string(p_state,'n',p.client);
   web_json.add_subnode_number(p_state,'r',p.id_ruta);
   web_json.add_subnode_optional_number(p_state,'p',p.parent_cod);
   web_json.add_subnode_optional_string(p_state,'addr_fact',p.addr_fact);
   web_json.add_subnode_optional_string(p_state,'address',p.address);
   web_json.add_subnode_optional_string(p_state,'telefon',p.telefon);
   web_json.add_subnode_optional_string(p_state,'telprim',p.telprim);
   web_json.add_subnode_optional_string(p_state,'director',p.director);
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
end;
--------------------------------------------------------------------------------
procedure store_branches(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'branches');
 web_json.begin_subnodes(p_state);
 for c in (select cod1,denumirea
   from tms_syss
   where tip='S' and cod='38' and cod1>0
   order by cod1)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.cod1);
   web_json.add_subnode_string(p_state,'n',nvl(c.denumirea,'^branch '||c.cod1));
   --
   web_json.add_subnode_array(p_state,'p');
   web_json.begin_subnodes(p_state);
   for t in (select dep,round(suma*100)suma from xsld
    where id='t' and sc1=c.cod1 and round(suma*100)<>0
    order by dep)
   loop
    web_json.add_subnode_object(p_state);
    web_json.begin_subnodes(p_state);
     web_json.add_subnode_number(p_state,'i',t.dep);
     web_json.add_subnode_number(p_state,'a',t.suma);
    web_json.end_subnodes(p_state);
   end loop;
   web_json.end_subnodes(p_state);
   --
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_branches');
end;
--------------------------------------------------------------------------------
procedure store_groups(p_state in out nocopy web_json.t_fill_state) is
 v_tree_marfa_id0 int:=sys_context('envun4','tree_marfa_id0');
begin
 web_json.add_subnode_array(p_state,'groups');
 web_json.begin_subnodes(p_state);
 for g1 in (select id1,coment,group1
  from tms_sysgrph
  where id0=v_tree_marfa_id0
    and group2=0
    and length(coment)>1
  order by coment,id1)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',g1.id1);
   web_json.add_subnode_string(p_state,'n',nvl(g1.coment,'^group1 '||g1.id1));
   web_json.add_subnode_number(p_state,'p',0);
  web_json.end_subnodes(p_state);
  --
  for g2 in (select id1,coment,group2
   from tms_sysgrph
   where id0=v_tree_marfa_id0
     and group1=g1.group1
     and group2<>0
     and group3=0
   order by coment,id1)
  loop
   web_json.add_subnode_object(p_state);
   web_json.begin_subnodes(p_state);
    web_json.add_subnode_number(p_state,'i',g2.id1);
    web_json.add_subnode_string(p_state,'n',nvl(g2.coment,'^group2 '||g2.id1));
    web_json.add_subnode_number(p_state,'p',g1.id1);
   web_json.end_subnodes(p_state);
   --
   for g3 in (select id1,coment--,group3
    from tms_sysgrph
    where id0=v_tree_marfa_id0
      and group1=g1.group1
      and group2=g2.group2
      and group3<>0
      and group4=0
    order by coment,id1)
   loop
    web_json.add_subnode_object(p_state);
    web_json.begin_subnodes(p_state);
     web_json.add_subnode_number(p_state,'i',g3.id1);
     web_json.add_subnode_string(p_state,'n',nvl(g3.coment,'^group3 '||g3.id1));
     web_json.add_subnode_number(p_state,'p',g2.id1);
    web_json.end_subnodes(p_state);
   end loop;
  end loop;
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_groups');
end;
--------------------------------------------------------------------------------
procedure store_products(p_state in out nocopy web_json.t_fill_state) is
 v_tree_marfa_id0 int:=sys_context('envun4','tree_marfa_id0');
begin
 web_json.add_subnode_array(p_state,'products');
 web_json.begin_subnodes(p_state);
 for p in (select u.cod,u.denumirea,u.clc_um_baz_t,t.id1--,t.group1,t.group2,t.group3
  ,(select prodp4 from vms_mpt where cod=t.sc)cant
  from tms_sysgrp t,vms_order_products u
  where t.id0=v_tree_marfa_id0
    and u.cod=t.sc
    and exists (select null from tpr1d_perprlist where sc=t.sc and trunc(sysdate) between datastart and dataend)
  order by u.denumirea,u.cod)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',p.cod);
   web_json.add_subnode_string(p_state,'n',p.denumirea);
   web_json.add_subnode_string(p_state,'um',p.clc_um_baz_t);
   web_json.add_subnode_number(p_state,'cant',p.cant);
   web_json.add_subnode_number(p_state,'gr',p.id1);
   --web_json.add_subnode_number(p_state,'g1',p.group1);
   --web_json.add_subnode_number(p_state,'g2',p.group2);
   --web_json.add_subnode_number(p_state,'g3',p.group3);
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_products');
end;
--------------------------------------------------------------------------------
procedure store_remnants(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'remnants');
 web_json.begin_subnodes(p_state);
 for c in (select cod,clc_cod
   from vdepozite_orders
   where status='P'
   order by clc_cod)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.cod);
   web_json.add_subnode_string(p_state,'n',nvl(c.clc_cod,'^stock '||c.cod));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_remnants');
end;
--------------------------------------------------------------------------------
procedure store_doctypes(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'doctypes');
 web_json.begin_subnodes(p_state);
 for c in (select id,tip_doc from vms_order_tip_doc where prn_orders=8)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.id);
   web_json.add_subnode_string(p_state,'n',nvl(c.tip_doc,'^doctype '||c.id));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log(p_start,'store_doctypes');
end;
--------------------------------------------------------------------------------
procedure store_orders(p_state in out nocopy web_json.t_fill_state) is
 v_sysfid int:=sys_context('envun4','vsysf_pre_solicit');
 v_user_id int:=sys_context('envun4','param_userid');
 v_found boolean:=false;
begin
 for c in (select o.nrdoc,o.data_livr,o.client,o.tip
  from vmdb_web_orders o,tmdb_docs d,tmdb_docs_status s,vms_order_route_agents r,vms_order_agents a
  where o.nrdoc=d.cod and s.nrdoc=d.cod and r.id_ruta=o.ruta and a.id=r.id_agent
    and d.sysfid=v_sysfid and s.status=30 and s.val=1 and r.main_agent='P' and a.cod_user=v_user_id
  order by o.data_livr,o.client,o.tip,o.nrdoc)
 loop
  if not v_found then
   v_found:=true;
   web_json.add_subnode_array(p_state,'orders');
   web_json.begin_subnodes(p_state);
  end if;
  --
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.nrdoc);
   web_json.add_subnode_string(p_state,'dt',to_char(c.data_livr,date_format));
   web_json.add_subnode_number(p_state,'pt',c.client);
   web_json.add_subnode_number(p_state,'tp',c.tip);
  web_json.end_subnodes(p_state);
 end loop;
 --
 if v_found then
  web_json.end_subnodes(p_state);
 end if;
 --write_log(p_start,'store_orders');
end;
--------------------------------------------------------------------------------
procedure refresh_database(p_session int) is
 v_state web_json.t_fill_state;
 v_start date:=sysdate;
begin
 --dbms_output.put_line(current_timestamp||' refresh_database('||p_session||') BEGIN');
 start_log('refresh_database('||p_session||') begin');
 --write_log(p_start,'refresh_database('||p_session||') begin');
 --
 web_json.create_top_node_object(v_state);
 web_json.begin_subnodes(v_state);
 --
 if p_session is not null then
  web_json.add_subnode_number(v_state,'session',p_session);
 end if;
 --
 prepare_debitori(v_start);
 prepare_sld(v_start);
 --
 store_markets(v_state);
 store_cities(v_state);
 store_routes(v_state);
 datorii_client(v_state);
 --punct_vinzare_short(v_state);
 --punct_vinzare(v_state);
 store_puncts(v_state);
 store_branches(v_state);
 store_groups(v_state);
 store_products(v_state);
 --new_price_algoritm(v_state);
 store_remnants(v_state);
 store_doctypes(v_state);
 store_orders(v_state);
 --new_sold_make(v_state);
 --rep_plan_vinz(v_state);
 --
 web_json.end_subnodes(v_state);
 write_log(v_start,'refresh_database('||p_session||') end');
end;
--------------------------------------------------------------------------------
procedure export_database(p_session int) is
 pragma autonomous_transaction;
 v_userid int:=sys_context('envun4','param_userid');
 v_sysfid int:=sys_context('envun4','vsysf_solicit');
 v_doc_date date:=trunc(sysdate);
 v_doc_dm varchar2(10):=to_char(v_doc_date,date_format);
 v_username varchar2(50);
 v_l3_nrset number;
 v_doc_node_id int;
 v_ids owa_text.int_arr;
 v_nrs owa_text.int_arr;
 v_exs owa_text.vc_arr;
 c_exp_days constant int:=3;
 --v_created constant varchar2(30):=to_char(sysdate,time_format);
 v_state web_json.t_fill_state;
 v_start date:=sysdate;
begin
 start_log('export_database('||p_session||')');
 --
 select nvl(min(username),' ') into v_username from xusers where cod=v_userid;
 --
 select to_number(value)
 into v_l3_nrset
 from a$adp$v
 where obj_id=(select obj_id from xusers where cod=v_userid/*342*/)
   and name='FILTRU';
 --
 v_doc_node_id:=web_json.get_subnode_id(0,'doc');
 -- v_doc_node_id can be null here: if so, no loop entries would be done
 for c in (select id from web_node where parent_id=v_doc_node_id order by id)
 loop
  declare
   v_doc_id int:=web_json.get_subnode_value(c.id,'id');
   v_doc_punct int:=web_json.get_subnode_value(c.id,'pt');
   --v_doc_stock int:=web_json.get_subnode_value(c.id,'stock');
   v_doc_type int:=web_json.get_subnode_value(c.id,'tp');
   v_doc_delivery date:=trunc(to_date(web_json.get_subnode_value(c.id,'dt'),date_format));
   --v_doc_shipment date:=to_date(web_json.get_subnode_value(c.id,'shipment'),date_format);
   --v_doc_create timestamp:=to_date(web_json.get_subnode_value(c.id,'create'),time_format);
   --v_doc_modify date:=to_date(web_json.get_subnode_value(c.id,'modify'),time_format);
   --v_doc_payorder int:=web_json.get_subnode_value(c.id,'pay');
   --v_doc_repaydebt int:=web_json.get_subnode_value(c.id,'repay');
   --v_doc_extra varchar2(4000):=web_json.get_subnode_value(c.id,'extra');
   --v_doc_sum float:=web_json.get_subnode_value(c.id,'sum');
   --v_cmd_cl varchar2(20):=get_num(v_doc_extra);
   --v_len int:=length(v_cmd_cl);
   v_l1_nrset number;
   v_nrset_complete number;
   v_data_parent_id int;
   v_data_index int:=0;
   v_data_node_id int;
   v_data_product int;
   v_data_qty float;
   --v_data_plus int;
   --v_data_buc int;
   v_doc_nr int;
   --v_auto number;
   --v_sof number;
  begin
   --Creating a document with these values and storing the nrdoc in v_doc_nr
   envun4.envsetvalue('data$livr',v_doc_date);
   --
   begin
    select to_number(subset) into v_l1_nrset from vms_order_tip_doc where prn_orders=8 and id=v_doc_type;
   exception when no_data_found then
    msg('Invalid order type: '||v_doc_type);
   end;
   --
   v_nrset_complete:=to_number(v_l1_nrset||0||v_l3_nrset);
   ---
   insert into tmdb_docs(datamanual,sysfid,userid,valuta,tip,at2,nrset)
   values (v_doc_date,v_sysfid,v_userid,upper('LEI'),upper('P'),2,v_nrset_complete)
   returning cod
   into v_doc_nr;
   --
   insert into vmdb_web_orders
   (
    nrdoc,data_livr,punct
    --,depozit
    ,tip
    --,contact_inf
    --,ap,automobil,sofer,CREATE_DATE_ORDERS,CMD_CLIENT,doc_id_orderss
   )
   values
   (
    v_doc_nr,v_doc_delivery,v_doc_punct
    --,decode(v_doc_stock,1,null,v_doc_stock)
    ,v_doc_type
    --,nvl(decode(v_len,0,v_doc_extra,substr(v_doc_extra,v_len+1)),v_doc_extra)
    --,v_doc_sum,v_auto,v_sof,v_doc_create,v_cmd_cl,v_doc_id
   );
   --
   v_data_parent_id:=web_json.get_subnode_id(v_doc_node_id,'p');
   loop
    v_data_node_id:=web_json.get_subnode_id(v_data_parent_id,v_data_index);
    exit when v_data_node_id is null;
    -- Extracting data record values
    v_data_product:=web_json.get_subnode_value(v_data_node_id,'i');
    v_data_qty:=web_json.get_subnode_value(v_data_node_id,'q');
    --v_data_buc:=web_json.get_subnode_value(v_data_node_id,'q_buc');
    --v_data_plus:=web_json.get_subnode_value(v_data_node_id,'r');
    -- Adding a record to the document data table with these values
    insert into vmdb_web_orders_data(nrdoc,product,cant)
    values (v_doc_nr,v_data_product,v_data_qty);
    --
    pkg_orders_docs.comanda_gfc(v_doc_nr,1);
    pkg_orders_docs.comanda_gfc_encashment(v_doc_nr);
    -- TODO: zapolneati eshe um producta
    v_data_index:=v_data_index+1;
   end loop;
   --
   --delete from VMDB_WEB_ORDERS_DATA
   --where nrdoc=v_doc_nr and pret_cu_tva=0;
   --
   pkg_orders_docs.comanda_gfc(v_doc_nr,1);
   pkg_orders_docs.comanda_gfc_encashment(v_doc_nr);
   --
   -- verificare gratuitati
   --pk_bc_promo.check_gratuitate(null,v_doc_nr,'orders'); 
   --
   --commit;
   --
   envun4.envsetvalue('data$livr',null);
   --
   v_ids(v_ids.count+1):=v_doc_id;
   v_nrs(v_nrs.count+1):=v_doc_nr;
   v_exs(v_exs.count+1):=to_char(v_doc_delivery+c_exp_days,date_format);
  end;
 end loop;
 --
 web_json.create_top_node_object(v_state);
 web_json.begin_subnodes(v_state);
  if p_session is not null then
   web_json.add_subnode_number(v_state,'session',p_session);
  end if;
  --
  web_json.add_subnode_array(v_state,'doc');
  web_json.begin_subnodes(v_state);
  for i in 1..v_ids.count loop
   web_json.add_subnode_object(v_state);
   web_json.begin_subnodes(v_state);
    web_json.add_subnode_number(v_state,'id',v_ids(i));
    web_json.add_subnode_number(v_state,'nr',v_nrs(i));
    web_json.add_subnode_string(v_state,'ex',v_exs(1));
    web_json.add_subnode_string(v_state,'dm',v_doc_dm);
   web_json.end_subnodes(v_state);
  end loop;
  web_json.end_subnodes(v_state);
  --
 web_json.end_subnodes(v_state);
 --
 commit;
end;
--------------------------------------------------------------------------------
procedure say(p_response clob)is
 c_max_portion constant binary_integer:=32760;
 v_length int:=nvl(dbms_lob.getlength(p_response),0);
 v_portion varchar2(32767);
 v_offset int:=1;
 v_divide int;
begin
 if v_length<=c_max_portion then
  v_portion:=dbms_lob.substr(p_response);
  pg_web_base.http_respond(v_portion);
 else
  while v_offset<=v_length loop
   v_portion:=dbms_lob.substr(p_response,c_max_portion,v_offset);
   v_divide:=instr(v_portion,chr(10),-1);
   if v_divide=0 then
    raise_application_error(-20000,'JSON line is too long after position '||v_offset);
   end if;
   v_portion:=substr(v_portion,1,v_divide-1);
   say(v_portion);
   v_offset:=v_offset+v_divide;
  end loop;
 end if;
end;
--------------------------------------------------------------------------------
procedure test is
 v_response clob;
begin
 refresh_database(0);
 select empty_clob into v_response from dual;
 web_json.stringify(v_response);
 say(v_response);
end;
--------------------------------------------------------------------------------
end;

/