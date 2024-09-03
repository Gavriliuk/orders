CREATE OR REPLACE PACKAGE pg_orders_pwa as
--------------------------------------------------------------------------------
-- Last modification date: 03.09.24
--------------------------------------------------------------------------------
procedure refresh_database(p_session int);
procedure export_database(p_session int);
procedure test;
--------------------------------------------------------------------------------
end;

/

CREATE OR REPLACE PACKAGE BODY pg_orders_pwa as
--------------------------------------------------------------------------------
-- Last modification date: 03.09.24
--------------------------------------------------------------------------------
function date_format return varchar2 is begin return 'dd.mm.yyyy'; end;
function time_format return varchar2 is begin return 'dd.mm.yyyy hh24:mi:ss'; end;
--------------------------------------------------------------------------------
procedure clear_log is
 pragma autonomous_transaction;
begin
 delete from xdblog where dt<trunc(sysdate);
 commit;
end;
--------------------------------------------------------------------------------
procedure write_log(p_text varchar2)is
 procedure write_int(p_time date)is
  pragma autonomous_transaction;
 begin
  insert into xdblog (dt,description) values (p_time,p_text);
  commit;
 end;
begin
 dbms_output.put_line(current_timestamp||' '||p_text);
 write_int(sysdate);
end;
--------------------------------------------------------------------------------
-- Store response blocks
--------------------------------------------------------------------------------
procedure prepare_debitori is
 --
 vdata date:=trunc(sysdate);
 --
 v_user_id int;
 v_agent_id int;
 c_day1 constant int:=7;
 c_day2 constant int:=14;
 c_day3 constant int:=21;
 c_day4 constant int:=28;
 v_client int;
 vDataost DATE;
 v_sld number(20,3):=0;

 procedure clear_for_user is
  --pragma autonomous_transaction;
 begin
  delete from yrb_debtitori where user_id=v_user_id;
  delete from yrb_debtitori_detail where user_id=v_user_id;
  delete from xsldx;
  --commit;
 end;
 --
begin
 --write_log('prepare_debitori 1');
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
 --write_log('prepare_debitori 2');
 --
 DELETE FROM xsld;
 DELETE FROM trgb_badolg;
 DELETE FROM ba_dolg;
 --write_log('prepare_debitori 3');
 --
 insert into xsld(id,dep)
 select 'ruta',id_ruta from vms_order_route_agents where id_agent=v_agent_id and main_agent='P';
 --write_log('prepare_debitori 3a');
 insert into xsld(id,dep)
 select 'client',cod from vms_order_clients_gr where id_ruta in(select dep from xsld where id='ruta');
 --write_log('prepare_debitori 3b');
 --un$sld.make(vdata,'4','ADE',pCont=>'221 52 544 5393',pdep=>'select cod from VMS_ORDER_CLIENTS_GR where id_ruta in(select id_ruta from vms_order_route_agents where id_agent='||v_agent_id||' and main_agent=''P'')',pNrCM=>'201');
 un$sld.make(vdata,'4','ADE',pCont=>'221 52 544 5393',pdep=>'select dep from xsld where id=''client''',pNrCM=>'201');
 --write_log('prepare_debitori 4'); -- 2 min. => 15 sec.
 --un$sld.make(vdata,'7','AD',pCont=>'221 52 544 5393',pdep=>'select cod from VMS_ORDER_CLIENTS_GR where id_ruta in(select id_ruta from vms_order_route_agents where id_agent='||v_agent_id||' and main_agent=''P'')',pNrCM=>'201');
 un$sld.make(vdata,'7','AD',pCont=>'221 52 544 5393',pdep=>'select dep from xsld where id=''client''',pNrCM=>'201');
 --write_log('prepare_debitori 5'); -- 2 min. => 15 sec.
 --
 insert into xsld(id,dep,sc1,cont,cant,suma)
 select '5',x.dep,x.sc1,d.cont,m.tip,x.suma
 from xsld x,ytms_setare_debitoriD d,ytms_setare_debitoriM m
 where x.id='4' and x.dep=m.dep and x.cont=d.cont and d.dep=m.dep;
 --write_log('prepare_debitori 6');
 --
 update xsld set sc1=0 where id='5' and cant=1;
 --write_log('prepare_debitori 7');
 --
 delete xsld x where x.id='4' and x.dep in (select distinct y.dep from xsld y where y.id='5');
 --write_log('prepare_debitori 8');
 delete xsld x where x.id='4' and x.cont not in (2211,2214,5231);
 --write_log('prepare_debitori 9');
 --
 update xsld set sc1=0 where id='4';
 --write_log('prepare_debitori 10');
 --
 insert into xsld(id,cont,dep,sc1,suma)
 select '4',x.cont,x.dep,x.sc1,x.suma from xsld x where x.id='5';
 --write_log('prepare_debitori 11');
 --
 insert into xsld(id,dep,sc1,suma)
 select '1', a.dep,a.sc1,a.suma
 from (
  select x.dep,x.sc1,sum(x.suma)suma
  from xsld x
  where id='4'
  group by x.dep,x.sc1
 ) a where a.suma>0;
 --write_log('prepare_debitori 12');
 -- inseram numarul de zile(otsrochka)
 UPDATE xsld x SET div=(
  SELECT DISTINCT  zile_schema_deplata
  FROM (
   SELECT zile_schema_deplata,null zile_schema_deplata1,clientid
   FROM VCN0M_CONTRACTS_EXT M
   WHERE vdata BETWEEN M.datastart AND M.dataend
   AND M.contractid IN (SELECT cod FROM VMDB_DOCS WHERE sysfid=48355)
  ) A
  WHERE A.clientid=x.dep
 )
 WHERE ID='1';     
 --write_log('prepare_debitori 13');
 --i6em datu poslednei registratsii ostatkob
 SELECT NVL((SELECT MAX(dataend) FROM TMDB_DSLD WHERE cod=1/*dataend<=vdata*/),to_date('31.12.2018','dd.mm.yyyy')) INTO vDataost FROM dual;
 --write_log('prepare_debitori 14');
 --
 INSERT INTO trgb_badolg(dtdep,dtsc1,data,nrdoc,sumadt)
 select dtdep,dtsc1,data,nrdoc,sumadt
 from (
   Select dtdep,dtsc1,data,nrdoc,sumadt
   from (
     --
     Select dtdep,dtsc1,data,nrdoc,sumadt
     from (
       SELECT dtdep,dtsc1,DATA,nrdoc,SUM(suma_dt)sumadt
       ,(SELECT NVL(sum(suma),0) FROM xsld WHERE ID='1' AND dep=dtdep)sld
       FROM (
         select *
         from (
           SELECT c.dtdep,c.dtsc1,c.DATA,c.nrdoc,c.cod,SUM(c.suma)suma_dt
           FROM tmdb_cm c
           WHERE c.dt IN (2211,2214)
             AND c.ct IN (6111,6113,6121,6112,5342,6118,6119)
             and c.isvalid is null
             and c.sptype = 0
             AND c.DATA BETWEEN  vDataost+1 AND vdata
           GROUP BY c.dtdep,c.dtsc1,c.DATA,c.nrdoc,c.cod
         ) tt
         where tt.dtdep in (SELECT dep FROM xsld x2 WHERE x2.ID='1')
         --ORDER BY tt.dtdep, tt.dtsc1
       )
       GROUP BY dtdep,dtsc1,DATA,nrdoc
     )
     WHERE sld>=0 and sumadt>0
     --
     union
     --
     Select dtdep,dtsc1,data,nrdoc,sumadt
     from (
       SELECT dtdep,dtsc1,DATA,nrdoc,SUM(suma_dt)sumadt,0 sld
       FROM (
         SELECT c.dtdep,c.dtsc1,c.DATA,c.nrdoc,c.cod,SUM(c.suma)suma_dt
         FROM market_db_cmr c
         WHERE c.dt IN (2211,2214) AND c.ct IN (6111,6113,6121,6112,5342,6118)
           AND c.DATA BETWEEN TO_DATE('31.12.2012')+1 AND TO_DATE('31.12.2014')
           AND c.dtdep IN (SELECT dep FROM xsld WHERE ID='1')
           and dtnrcm in (select id from xnrset)
         GROUP BY c.dtdep, c.dtsc1,c.DATA, c.nrdoc, c.cod ORDER BY c.dtdep, c.dtsc1
       )
       GROUP BY  dtdep, dtsc1, DATA, nrdoc
     ) WHERE sumadt>0
     --
     union
     --
     select x.dep,null,to_date('31.12.2018'),1,x.suma from xsld x where id='1'
   )
   --ORDER BY dtdep,DATA desc,nrdoc,dtsc1
 );
 --write_log('prepare_debitori 15'); -- 12 sec.
 ------------ cautarea facturilor care vor acoperi soldul total pe client
 For k in (select dep,sc1,suma from xsld where id='1' )
 loop
  v_sld:=k.suma;
  --rashityvaem dolg i kidaem v tablicy
  FOR i IN ( SELECT * FROM trgb_badolg  where dtdep=k.dep and decode(k.sc1,0,k.sc1,dtsc1)=k.sc1 ORDER BY   DATA desc, nrdoc desc)
  LOOP
   If v_sld-i.sumadt>0 then
    INSERT INTO ba_dolg VALUES(i.dtdep, i.dtsc1, i.DATA, i.nrdoc,i.sumadt,201);
   end if;
   --
   If v_sld-i.sumadt<=0 then
    INSERT INTO ba_dolg VALUES(i.dtdep, i.dtsc1, i.DATA, i.nrdoc,v_sld,201);
    exit;
   end if;
   v_sld:=v_sld-i.sumadt;
  end loop;
 END LOOP;
 --write_log('prepare_debitori 16');
 --
 INSERT INTO xsld (ID,cont,dep,sc1,nrdoc,DATA,suma,div)
 SELECT  'doc' ID, 2211 cont, dtdep, dtsc1, nrdoc, DATA, dolg,
   (
     SELECT zile_schema_deplata
     FROM VCN0M_CONTRACTS_EXT M
     WHERE TO_DATE(vdata) BETWEEN M.datastart AND M.dataend
       AND M.clientid=b.dtdep AND M.contractid IN(SELECT cod FROM VMDB_DOCS WHERE sysfid=48355)
   ) dni_otsrochki
 FROM ba_dolg b
 WHERE b.dolg!=0;
 --write_log('prepare_debitori 17');
 --
 UPDATE xsld
 SET cant=(CASE WHEN to_date( trunc(sysdate))-data-nvl(div,0) between 1 and c_day1  THEN suma ELSE null END)
   ,price=(CASE WHEN to_date( trunc(sysdate))-data-nvl(div,0)  between c_day1+1 and c_day2  THEN suma ELSE null END)
   ,sumaval=(CASE WHEN to_date(trunc(sysdate))-data-nvl(div,0) between c_day2+1 and c_day3 THEN suma ELSE null END)
   ,sumagaap=(CASE WHEN to_date(trunc(sysdate))-data-nvl(div,0) between c_day3+1 and c_day4 THEN suma ELSE null END)
   ,cant1=(CASE WHEN to_date(trunc(sysdate))-data-nvl(div,0)>c_day4 THEN suma ELSE null END)
 WHERE ID='doc';
 --write_log('prepare_debitori 18');
 --
 insert into yrb_debtitori (id_client,id_punct,TOTAL,suma35,suma28,suma21,suma14,suma7,TOT_PLATA,TOTAL_DAT,ZILE,user_id)
 SELECT CLIENT, PUNCT, sum(TOTAL), sum(SUMA35), sum(SUMA28), sum(SUMA21), sum(SUMA14), sum(SUMA7), sum(TOT_PLATA), sum(TOT_PLATA)+sum(TOTAL)
   ,nvl((SELECT div FROM xsld c WHERE c.id='doc' and c.dep=a.client/* and c.sc1=a.punct*/   AND ROWNUM=1),14),v_user_id  
 from (
   select sc0 CLIENT,sc1 PUNCT, 
     sum( nvl(sum1,0))+sum(nvl(sum2,0))+sum(nvl(sum3,0))+sum(nvl(sum4,0))+sum(nvl(sum5,0)) TOTAL,
     -- (SELECT SUM(suma) FROM vsld4 v  WHERE v.dep=x.sc0)  TOTAL,
     SUM(NVL(sum0,0))-SUM(NVL(sum1,0))-SUM(NVL(sum2,0))-SUM(NVL(sum3,0))-SUM(NVL(sum4,0))-SUM(NVL(sum5,0)) TOT_PLATA,
     sum( nvl(sum5,0)) SUMA35,
     sum( nvl(sum4,0)) SUMA28,
     sum( nvl(sum3,0)) SUMA21,
     sum( nvl(sum2,0)) SUMA14,
     sum( nvl(sum1,0)) SUMA7,
     sum(cant0) zile
 from (          
   SELECT dep sc0,0 sc1,sum(suma) sum0,SUM(cant) sum1,SUM(price) sum2,SUM(sumaval) sum3,SUM(sumagaap) sum4,SUM(cant1) sum5, null cant0
   FROM xsld
   WHERE ID='doc'
   GROUP BY cont,dep           
 ) x 
 GROUP BY sc0,sc1) a
 --where nvl(TOTAL,0)>0            
 GROUP BY Client, punct; 
 --write_log('prepare_debitori 19');
 --
 insert into yrb_debtitori_detail (CLIENT,ID_PUNCT,NRDOC,DOC_NAME,DATA,NRMANUAL,CONT,DOC_S7,DOC_S14,DOC_S21,DOC_S28,DOC_S35,SUM_PLATA,SUM_DAT_EXP,SUM_TOT_DOC,user_id)
 select dep,sc1, nrdoc, case when cont=2211 and nrdoc is not null then 'Factura'  else 'Sold' end DOC_NAME ,data, nrmanual, cont, doc1_1, doc2_1, doc3_1, doc4_1, doc5_1,doc0_1,
   sum_dat_exp, NVL(sum_dat_exp,0)+NVL(doc0_1,0),v_user_id
 from (
   SELECT dep, sc1, nrdoc,TRUNC(DATA) DATA,(SELECT nrmanual FROM TMDB_DOCS WHERE cod=x.nrdoc) nrmanual
     ,to_number(cont) cont
     ,(select suma from XSLD S where nvl(S.nrdoc,0)=nvl(x.nrdoc,0) and S.dep=x.dep and S.sc1=x.sc1 AND S.CONT=2211 AND ID='SUMADT')  suma_fact
     ,cant doc1_1, price doc2_1, sumaval doc3_1, sumagaap doc4_1, cant1 doc5_1, nvl(suma,0)-nvl(cant,0)-nvl(price,0)-nvl(sumaval,0)-nvl(sumagaap,0)-nvl(cant1,0) as doc0_1 
     ,NVL(cant,0)+NVL(price,0)+NVL(sumaval,0)+NVL(sumagaap,0)+NVL(cant1,0) sum_dat_exp
   FROM xsld x
   WHERE ID='doc'
   ORDER BY DATA desc,nrdoc desc
 )a; 
 --
end;
--------------------------------------------------------------------------------
procedure prepare_sld is
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
  select 'p',id_ruta,cod from VMS_ORDER_CLIENTS_GR
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
 prepare_sld_puncts;
 --write_log('prepare_sld_puncts');
 prepare_sld_turnover;
 --write_log('prepare_sld_turnover');
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
 for c in (select cod1,denumirea
   from tms_syss
   where tip='S' and cod=27 and cod1>0
     and cod1 in (select tipclient from vms_order_clients
       where cod in (select dep from xsld where id='p'))
   order by cod1)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.cod1);
   web_json.add_subnode_string(p_state,'n',nvl(c.denumirea,'^market '||c.cod1));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log('store_markets');
end;
--------------------------------------------------------------------------------
procedure store_cities(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'cities');
 web_json.begin_subnodes(p_state);
 for c in (select cod1,denumirea
   from tms_syss
   where tip='S' and cod=12 and cod1>0
   and cod1 in (select distinct oras from vms_order_clients where oras is not null)
   order by cod1)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.cod1);
   web_json.add_subnode_string(p_state,'n',nvl(c.denumirea,'^city '||c.cod1));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log('store_cities');
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
 for r in (select id_ruta id,clc_ruta_t route
   from vms_order_route_agents
   where id_agent=v_agent_id and main_agent='P'
   order by id)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',r.id);
   web_json.add_subnode_string(p_state,'n',nvl(r.route,'^route '||r.id));
   --
   web_json.add_subnode_array(p_state,'p');
   web_json.begin_subnodes(p_state);
   for p in (select a.cod cod_tocki,a.name,a.parent_cod
    ,(select tipclient_s_27 from vms_univ_org s5 where s5.cod=a.cod and rownum=1) tipclient
    ,(select mp_persincr_univ from vms_univ_org s5 where s5.cod=a.cod and rownum=1) univ
    ,(select oras from vms_univ_org s5 where s5.cod=a.cod and rownum=1) oras
    ,(select adress from vms_univ_org s5 where s5.cod=a.cod and rownum=1) jur_adress
    ,(select addr_fact from vms_univ_org s5 where s5.cod=a.cod and rownum=1) fact_adress
    ,(select telefon from vms_univ_org s5 where s5.cod=a.cod and rownum=1) telefon
    ,null tel_pers_contact
    ,(select telprim from vms_univ_org s5 where s5.cod=a.cod and rownum=1) telprim
    ,(select cvalacc3 from vms_univ_org s5 where s5.cod=a.cod and rownum=1) priznak1
    ,(select max(codprice||'/'||codgrp) from tcn0m_contracts,tmdb_docs v
      where clientid=nvl(a.parent_cod ,a.cod) and sysdate between datastart and dataend and contractid=v.cod and v.nrset=v_nrset
     )pricelist_id
    --,null pricelistce_id
    ,(select max(avanspp) from tcn0m_contracts, vmdb_docs v
      where clientid=a.parent_cod and sysdate between datastart and dataend and contractid=v.cod and sysfid = 48355) discount
    ,(select max(ZILE_SCHEMA_DEPLATA) from tcn0m_contracts,vmdb_docs v
       where clientid=a.parent_cod  and sysdate between datastart and dataend and contractid=v.cod and sysfid = 48355) zile
    ,nvl((select distinct round(TOTAL_DAT*100) from yrb_debtitori where id_punct = a.cod and user_id = v_user_id  ),0) TOTAL_DAT
    ,nvl((select distinct round(TOT_PLATA*100) from yrb_debtitori where id_punct = a.cod and user_id = v_user_id),0) TOT_PLATA
    ,nvl((select distinct round(TOTAL*100) from yrb_debtitori where id_punct =a.cod and user_id = v_user_id),0) TOTAL
    ,nvl((select distinct round(suma7*100)  from yrb_debtitori where id_punct = a.cod and user_id = v_user_id),0) suma7
    ,nvl((select distinct round(suma14*100)  from yrb_debtitori where id_punct = a.cod and user_id = v_user_id ),0) suma14
    ,nvl((select distinct round(suma21*100)  from yrb_debtitori where id_punct = a.cod and user_id = v_user_id),0) suma21
    ,nvl((select distinct round(suma28*100)  from yrb_debtitori where id_punct = a.cod and user_id = v_user_id),0) suma28
    ,nvl((select distinct round(suma35*100) from yrb_debtitori where id_punct = a.cod and user_id = v_user_id),0) suma35
    from (
     select * from (
      select cod,client name,parent_cod,null jur_adress,0 tot_exp,null fact_adress,null priznak1,'Activ' status,id_ruta
      from VMS_ORDER_CLIENTS_GR
      where parent_cod is not null
      union all
      select cod,client name,parent_cod,null jur_adress,0 tot_exp,null fact_adress,null priznak1,'Activ' status,id_ruta
      from VMS_ORDER_CLIENTS_GR
      where parent_cod is null
     )
     where id_ruta=r.id
    ) a
   )
   loop
    web_json.add_subnode_object(p_state);
    web_json.begin_subnodes(p_state);
     --
     web_json.add_subnode_number(p_state,'i',p.cod_tocki);
     web_json.add_subnode_string(p_state,'n',nvl(p.name,'^punct '||p.parent_cod));
     --web_json.add_subnode_number(p_state,'market',/*p.tipclient*/0); -- Kanal sbyta
     web_json.add_subnode_optional_number(p_state,'sector',p.univ); -- Municipiu
     web_json.add_subnode_optional_number(p_state,'city',p.oras);
     web_json.add_subnode_optional_string(p_state,'legal',p.jur_adress);
     web_json.add_subnode_optional_string(p_state,'actual',p.fact_adress);
     --web_json.add_subnode_string(p_state,'phone',v_phone);
     web_json.add_subnode_optional_number(p_state,'extra',p.priznak1); -- abc
     web_json.add_subnode_optional_string(p_state,'pl',p.pricelist_id);
     --web_json.add_subnode_optional_string(p_state,'plce',p.pricelistce_id);
     web_json.add_subnode_optional_number(p_state,'discount',case when p.discount>0 then round(least(p.discount,100)*100) end);
     web_json.add_subnode_optional_number(p_state,'delay',p.zile); -- Otsrochka
     web_json.add_subnode_optional_number(p_state,'tot_dat',p.TOTAL_DAT); -- Kredit na nachalo mesaca
     web_json.add_subnode_optional_number(p_state,'tot_plata',p.TOT_PLATA); -- Obschij dolg na nachalo mesaca
     --web_json.add_subnode_number(p_state,'total',/*p.total*/(round(v_dat_tot,2)*100)); 
     web_json.add_subnode_optional_number(p_state,'s1',p.suma7); -- Kredit na tekuschuyu datu
     web_json.add_subnode_optional_number(p_state,'s2',p.suma14 ); -- Obschij dolg na tekuschuyu datu
     web_json.add_subnode_optional_number(p_state,'s3',p.suma21 ); -- Prosrocheno na tekuschuyu datu
     web_json.add_subnode_optional_number(p_state,'s4',p.suma28);
     web_json.add_subnode_optional_number(p_state,'s5',p.suma35);
     --web_json.add_subnode_number(p_state,'slecit',0);
     --web_json.add_subnode_number(p_state,'prn_lecit',0);
     --
    web_json.end_subnodes(p_state);
   end loop;
   web_json.end_subnodes(p_state);
   --
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log('store_routes');
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
 --write_log('datorii_client');
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
 --write_log('store_branches');
end;
--------------------------------------------------------------------------------
procedure store_products(p_state in out nocopy web_json.t_fill_state) is
 v_tree_marfa_id0 int:=1;--sys_context('envun4','tree_marfa_id0');
 v_mainpricelist_id int:=sys_context('envun4','mainpricelist_id');
 v_mainpricelist_grp int:=sys_context('envun4','mainpricelist_grp');
 --
 procedure products_add(p_gr1 int,p_gr2 int,cnt int,pg2id1 int) is
 begin
  for g3 in (select id1,coment,group2
    from tms_sysgrph where id0=1 and id1=pg2id1
    and group2<>0 and group3=0 and group1=p_gr1
    order by coment,id1)
  loop
   for p in (select distinct  u.cod cod ,u.denumirea ,u.clc_um_baz_t um,0 pretv, 
     (select PRODP4 from vms_mpt where cod = u.cod) cant
     from vms_univtree2 t,vms_order_products u,vtpr1d_perprlist pr
     where /*1=1*/t.id0=v_tree_marfa_id0 and t.g1=p_gr1 and t.id2=g3.id1
     and u.cod=t.sc 
     and pr.sc=u.cod  /*and  u.cod in(select  id from test_110)*/ and trunc(sysdate) between pr.datastart and pr.dataend and cnt =0   
     order by denumirea,cod)
   loop
    web_json.add_subnode_object(p_state);
    web_json.begin_subnodes(p_state);
     web_json.add_subnode_number(p_state,'i',trim(p.cod));
     web_json.add_subnode_string(p_state,'n',trim(nvl(trim(p.denumirea),'^product '||p.cod)));
     web_json.add_subnode_optional_number(p_state,'p',trim(round(p.pretv*100)));
     web_json.add_subnode_optional_number(p_state,'c',trim(p.cant*100));
     web_json.add_subnode_optional_string(p_state,'u',trim(p.um));
     --
     web_json.add_subnode_array(p_state,'r');
     web_json.begin_subnodes(p_state);
     for pr in (select codprice||'/'||codgrp id,round(pretv*100)price
       from tpr1d_perprlist
       where sc=p.cod and trunc(sysdate) between datastart and dataend
       order by 1)
     loop
      web_json.add_subnode_object(p_state);
      web_json.begin_subnodes(p_state);
       web_json.add_subnode_string(p_state,'i',trim(pr.id));
       web_json.add_subnode_string(p_state,'r',trim(pr.price));
      web_json.end_subnodes(p_state);
     end loop;
     web_json.end_subnodes(p_state);
    web_json.end_subnodes(p_state);
   end loop;
  end loop;
 end;
 --
begin
 web_json.add_subnode_array(p_state,'products');
 web_json.begin_subnodes(p_state);
 for g1 in (select id1,coment,group1
   from tms_sysgrph where id0=v_tree_marfa_id0 and group2=0 --and id1=2
   order by coment,id1)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',g1.id1);
   web_json.add_subnode_string(p_state,'n',nvl(g1.coment,'^group1 '||g1.id1));
   --
   web_json.add_subnode_array(p_state,'g');
   web_json.begin_subnodes(p_state);
   for g2 in (select decode(id1,0,999,id1) id1_1,id1,coment,group2
     from tms_sysgrph where id0=v_tree_marfa_id0
     and group2<>0 and group3=0 and group1=g1.group1
     order by coment,id1)
   loop
    web_json.add_subnode_object(p_state);
    web_json.begin_subnodes(p_state);
     web_json.add_subnode_number(p_state,'i',g2.id1_1);
     web_json.add_subnode_string(p_state,'n',nvl(g2.coment,'^group2 '||g2.id1));
     web_json.add_subnode_array(p_state,'p');
     web_json.begin_subnodes(p_state);
      products_add(g1.group1,g2.group2,0,g2.id1);
     web_json.end_subnodes(p_state);
    web_json.end_subnodes(p_state);
   end loop;
   web_json.end_subnodes(p_state);
   --
   web_json.add_subnode_array(p_state,'p');
   web_json.begin_subnodes(p_state);
    products_add(g1.group1,0,0,0);
   web_json.end_subnodes(p_state);
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log('store_products');
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
 --write_log('store_remnants');
end;
--------------------------------------------------------------------------------
procedure store_doctypes(p_state in out nocopy web_json.t_fill_state) is
begin
 web_json.add_subnode_array(p_state,'doctypes');
 web_json.begin_subnodes(p_state);
 for c in (select cod1,denumirea
   from tms_syss
   where tip='Z' and cod=2002 and cod1>0 and number1=8
   order by cod1)
 loop
  web_json.add_subnode_object(p_state);
  web_json.begin_subnodes(p_state);
   web_json.add_subnode_number(p_state,'i',c.cod1);
   web_json.add_subnode_string(p_state,'n',nvl(c.denumirea,'^doctype '||c.cod1));
  web_json.end_subnodes(p_state);
 end loop;
 web_json.end_subnodes(p_state);
 --write_log('store_doctypes');
end;
--------------------------------------------------------------------------------
procedure refresh_database(p_session int) is
 v_state web_json.t_fill_state;
begin
 --dbms_output.put_line(current_timestamp||' refresh_database('||p_session||') BEGIN');
 clear_log;
 --write_log('refresh_database('||p_session||') begin');
 --
 web_json.create_top_node_object(v_state);
 web_json.begin_subnodes(v_state);
 --
 if p_session is not null then
  web_json.add_subnode_number(v_state,'session',p_session);
 end if;
 --
 prepare_debitori;
 prepare_sld;
 --
 store_markets(v_state);
 store_cities(v_state);
 store_routes(v_state);
 datorii_client(v_state);
 --punct_vinzare_short(v_state);
 --punct_vinzare(v_state);
 store_branches(v_state);
 store_products(v_state);
 --new_price_algoritm(v_state);
 store_remnants(v_state);
 store_doctypes(v_state);
 --new_sold_make(v_state);
 --rep_plan_vinz(v_state);
 --
 web_json.end_subnodes(v_state);
 --write_log('refresh_database('||p_session||') end');
 --dbms_output.put_line(current_timestamp||' refresh_database('||p_session||') END');
end;
--------------------------------------------------------------------------------
procedure export_database(p_session int) is
 pragma autonomous_transaction;
 v_userid int:=sys_context('envun4','param_userid');
 v_sysfid int:=sys_context('envun4','vsysf_solicit');
 v_username varchar2(50);
 v_doc_node_id int;
 v_ids owa_text.int_arr;
 v_nrs owa_text.int_arr;
 v_created constant varchar2(30):=to_char(sysdate,time_format);
 v_state web_json.t_fill_state;
 v_l3_nrset number;
begin
 clear_log;
 --
 select nvl((select username from xusers where cod=v_userid),' ')
 into v_username from dual;
 --
 select to_number(value)
 into v_l3_nrset
 from a$adp$v
 where obj_id=(select obj_id from xusers where cod=v_userid/*342*/)
   and name='FILTRU';
 --
 v_doc_node_id:=web_json.get_subnode_id(0,'doc');
 for c in (select id from web_node where parent_id=v_doc_node_id order by id)
 loop
  declare
   v_doc_id int:=web_json.get_subnode_value(c.id,'id');
   v_doc_punct int:=web_json.get_subnode_value(c.id,'punct');
   v_doc_stock int:=web_json.get_subnode_value(c.id,'stock');
   v_doc_type int:=web_json.get_subnode_value(c.id,'type');
   v_doc_shipment date:=to_date(web_json.get_subnode_value(c.id,'shipment'),date_format);
   v_doc_delivery date:=to_date(web_json.get_subnode_value(c.id,'delivery'),date_format);
   v_doc_create timestamp:=to_date(web_json.get_subnode_value(c.id,'create'),time_format);
   v_doc_modify date:=to_date(web_json.get_subnode_value(c.id,'modify'),time_format);
   --v_doc_payorder int:=web_json.get_subnode_value(c.id,'pay');
   --v_doc_repaydebt int:=web_json.get_subnode_value(c.id,'repay');
   v_doc_extra varchar2(4000):=web_json.get_subnode_value(c.id,'extra');
   v_doc_sum float:=web_json.get_subnode_value(c.id,'sum');
   v_cmd_cl varchar2(20):=get_num(v_doc_extra);
   v_len int:=length(v_cmd_cl);
   v_l1_nrset number;
   v_nrset_complete number;
--   v_exist int;
   v_data_parent_id int;
   v_data_index int:=0;
   v_data_node_id int;
   v_data_product int;
   v_data_qty float;
   v_data_plus int;
   v_data_buc int;
--   v_blockat int;
   v_doc_nr int;
   v_auto number;
   v_sof number;
  begin
   --Creating a document with these values and storing the nrdoc in v_doc_nr
   envun4.envsetvalue('data$livr',v_doc_delivery);
   --
   begin
    select to_number(subset) into v_l1_nrset from vms_order_tip_doc where id=v_doc_type;
   exception when no_data_found then
    msg('Такого типа документа в бухгалтерской базе не существует! Свяжитесь с бухгалтерией!');
   end;
   --
   v_nrset_complete:=to_number(v_l1_nrset||0||v_l3_nrset);
   ---
   if v_len<5 then
    v_cmd_cl:=null; 
    v_len:=0;
   end if;
   --
--   select count(*)
--   into v_exist
--   from vmdb_web_orders
--   where punct=v_doc_punct
--     and trunc(CREATE_DATE_ORDERS)=trunc(v_doc_create)
--     --and doc_id_orderss=v_doc_id
--     and tip=v_doc_type
--     and nvl(dep,0)=nvl(v_doc_stock,0)
--     and trunc(data_livr)=trunc(v_doc_delivery);
   --
--   begin
--    select nvl(bloc_manual_status,404)
--    into v_blockat
--    from vms_order_clients
--    where cod=(select nvl(parent_cod,cod) from vms_order_clients where cod=v_doc_punct);
--   exception when no_data_found then
--    v_blockat:=404;
--   end;
   --
--   if v_blockat<>1 then      
--    if v_exist=0 then
     insert into tmdb_docs(datamanual,sysfid,userid,valuta,tip,at2,nrset)
     values (trunc(v_doc_create),v_sysfid,v_userid,upper('LEI'),upper('P'),2,v_nrset_complete)
     returning cod
     into v_doc_nr;
     --Saving the order creating time
     insert into tmdb_docs_log (nrdoc,data,userid,username,action)
     values (v_doc_nr,v_doc_create,v_userid,v_username,'ORDER BEGIN');
     --Saving the order last modifying time
     insert into tmdb_docs_log (nrdoc,data,userid,username,action)
     values (v_doc_nr,v_doc_modify,v_userid,v_username,'ORDER MODIFY');
     --
     --begin
     -- select auto into v_auto from vms_order_clients where cod=v_doc_punct;
     --exception when no_data_found then
     -- v_auto:=0;
     --end;
     --
     --begin
     -- select cod_driver_s_14 into v_sof from VMDB_AUTO_DRIVER_RELATIONS where sc_auto=v_auto;
     --exception when no_data_found then
     -- v_sof:=0;
     --end;
     --
     insert into vmdb_web_orders (nrdoc,data_livr,punct,depozit,tip,contact_inf,ap,/*automobil,sofer,CREATE_DATE_ORDERS,*/CMD_CLIENT/*,doc_id_orderss*/)
     values (v_doc_nr,v_doc_delivery,v_doc_punct,decode(v_doc_stock,1,null,v_doc_stock),v_doc_type,nvl(decode(v_len,0,v_doc_extra,substr(v_doc_extra,v_len+1)),v_doc_extra),v_doc_sum,/*v_auto,v_sof,v_doc_create,*/v_cmd_cl/*,v_doc_id*/);
     --
     v_data_parent_id:=web_json.get_subnode_id(v_doc_node_id,'d');
     loop
      v_data_node_id:=web_json.get_subnode_id(v_data_parent_id,v_data_index);
      exit when v_data_node_id is null;
      -- Extracting data record values
      v_data_product:=web_json.get_subnode_value(v_data_node_id,'p');
      v_data_qty:=web_json.get_subnode_value(v_data_node_id,'q');
      v_data_buc:=web_json.get_subnode_value(v_data_node_id,'q_buc');
      --v_data_plus:=web_json.get_subnode_value(v_data_node_id,'r');
      -- Adding a record to the document data table with these values
      if v_data_buc is not null then
       insert into vmdb_web_orders_data(nrdoc,product/*cant_um,*/ /*,cant_buc*/)
       values (v_doc_nr,v_data_product/*,v_data_buc*/);
      else
       insert into vmdb_web_orders_data(nrdoc,product,/*cant_um,*/cant/*, cant_buc*/)
       values (v_doc_nr,v_data_product,v_data_qty/*,v_data_buc*/);
      end if;
      --
      pkg_orders_docs.comanda_gfc(v_doc_nr,1);
      pkg_orders_docs.comanda_gfc_encashment(v_doc_nr);
      -- TODO: zapolneati eshe um producta
      v_data_index:=v_data_index+1;
     end loop;
     --
     delete from VMDB_WEB_ORDERS_DATA
     where nrdoc=v_doc_nr and pret_cu_tva=0;
     --
     pkg_orders_docs.comanda_gfc(v_doc_nr,1);
     pkg_orders_docs.comanda_gfc_encashment(v_doc_nr);
     --
     -- verificare gratuitati
     --pk_bc_promo.check_gratuitate(null,v_doc_nr,'orders'); 
     --           
     commit;
     --
     envun4.envsetvalue('data$livr',null);
--    elsif v_exist>0 then 
--     select max(NRDOC)
--     into v_doc_nr 
--     from vmdb_web_orders
--     where punct=v_doc_punct
--       and trunc(CREATE_DATE_ORDERS)=trunc(v_doc_create)
--       --and doc_id_orderss=v_doc_id
--       and tip=v_doc_type
--       and nvl(dep,0)=nvl(v_doc_stock,0)
--       and trunc(data_livr)=trunc(v_doc_delivery);
--    end if; // v_exist=0 then
    --
    v_ids(v_ids.count+1):=v_doc_id;
    v_nrs(v_nrs.count+1):=v_doc_nr;
--   end if; // v_blockat<>1 then
   commit;
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
    web_json.add_subnode_string(v_state,'export',v_created);
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