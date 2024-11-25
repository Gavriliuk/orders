CREATE OR REPLACE package web_json as
--------------------------------------------------------------------------------
-- Last modification date: 23.11.24
--------------------------------------------------------------------------------
-- Used type declarations
type t_types is table of char(1) index by binary_integer;
type t_integers is table of integer index by binary_integer;
--
type t_fill_state is record
(
 node int, -- Zero-based index of the currently filling node
 type char(1), -- Currently filling value type (one from [c_type_object .. c_type_null])
 idx int, -- Zero-based array index of the currently filling array item
 parent_node int, -- Zero-based index of the parent node of the currently filling node
 parent_type char(1), -- Parent node value type ('O'/'A' when filling child nodes) 
 depth binary_integer, -- Zero-based hierarchical level of the filling node
 --
 types t_types, -- Stack of parent node value types
 nodes t_integers, -- Stack of parent node indices
 indices t_integers -- Stack of parent node array indices
);
--------------------------------------------------------------------------------
-- Start filling new JSON hierarchy
procedure create_top_node_object(p_state in out nocopy t_fill_state);
procedure create_top_node_array(p_state in out nocopy t_fill_state);
-- Begin/end subnodes
procedure begin_subnodes(p_state in out nocopy t_fill_state);
procedure end_subnodes(p_state in out nocopy t_fill_state);
-- Add object node to an object or an array
procedure add_subnode_object(p_state in out nocopy t_fill_state,p_name varchar2);
procedure add_subnode_object(p_state in out nocopy t_fill_state);
-- Add array node to an object or an array
procedure add_subnode_array(p_state in out nocopy t_fill_state,p_name varchar2);
procedure add_subnode_array(p_state in out nocopy t_fill_state);
-- Add string node to an object or an array
procedure add_subnode_string(p_state in out nocopy t_fill_state,p_name varchar2,p_value varchar2);
procedure add_subnode_string(p_state in out nocopy t_fill_state,p_value varchar2);
procedure add_subnode_optional_string(p_state in out nocopy t_fill_state,p_name varchar2,p_value varchar2);
procedure add_subnode_optional_string(p_state in out nocopy t_fill_state,p_value varchar2);
-- Add number node to an object or an array
procedure add_subnode_number(p_state in out nocopy t_fill_state,p_name varchar2,p_value number);
procedure add_subnode_number(p_state in out nocopy t_fill_state,p_value number);
procedure add_subnode_optional_number(p_state in out nocopy t_fill_state,p_name varchar2,p_value number);
procedure add_subnode_optional_number(p_state in out nocopy t_fill_state,p_value number);
-- Add boolean node to an object or an array
procedure add_subnode_boolean(p_state in out nocopy t_fill_state,p_name varchar2,p_value boolean);
procedure add_subnode_boolean(p_state in out nocopy t_fill_state,p_value boolean);
procedure add_subnode_optional_boolean(p_state in out nocopy t_fill_state,p_name varchar2,p_value boolean);
procedure add_subnode_optional_boolean(p_state in out nocopy t_fill_state,p_value boolean);
-- Get subnode id by name or by index
function get_subnode_id(p_parent int,p_name varchar2) return int;
function get_subnode_id(p_parent int,p_index int) return int;
-- Get subnode value by name or by index
function get_subnode_value(p_parent int,p_name varchar2) return varchar2;
function get_subnode_value(p_parent int,p_index int) return varchar2;
-- Convert WEB_JSON hierarchy to JSON expression
function stringify(p_decoration_depth binary_integer:=null) return varchar2;
procedure stringify(p_json out varchar2,p_decoration_depth binary_integer:=null);
procedure stringify(p_json out clob,p_decoration_depth binary_integer:=null);
-- Convert JSON expression to WEB_JSON hierarchy
procedure parse(p_json in varchar2);
procedure parse(p_json in clob);
-- Output CLOB using dbms_output dividing by up to 32767 chars
procedure local_output(p_clob clob);
-- Test all procedures and functions
procedure test_stringify;
procedure test_parse;
procedure test_roundtrip;
procedure test_create_nodes;
-- Delete and create table WEB_JSON
procedure create_table;
-- Declare used error codes
e_stringify_error exception;pragma exception_init(e_stringify_error,-20001);
e_parse_error exception;pragma exception_init(e_parse_error,-20002);
e_test_error exception;pragma exception_init(e_test_error,-20003);
--------------------------------------------------------------------------------
end;

/

CREATE OR REPLACE package body web_json as
--------------------------------------------------------------------------------
-- Last modification date: 23.11.24
--------------------------------------------------------------------------------
type t_stringify_state is record
(
 depth binary_integer, -- Zero-based hierarchical level of the parsing node
 decoration_depth binary_integer, -- Number of levels to decorate
 text varchar2(32767), -- Currently writing fragment of output JSON expression
 lob clob -- Whole output JSON expression
);
--
type t_parse_state is record
(
 fragment_pos binary_integer, -- Zero-based position of the parsing fragment of the input CLOB
 parsing_pos binary_integer, -- One-based position of the parsing character in the fragment
 token_pos binary_integer, -- One-based position of the parsing token in the fragment
 depth binary_integer, -- Zero-based hierarchical level of the parsing node
 expect binary_integer, -- Expected syntax element (one from [c_expect_value .. c_expect_colon])
 node int, -- Zero-based index of the currently parsing node
 parent_node int, -- Zero-based index of the parent node of the currently parsing node
 idx int, -- Zero-based array index of the currently parsing array item
 name varchar2(32767), -- Name of the currently parsing node
 value varchar2(32767), -- Value of the currently parsing node
 type char(1), -- Currently parsing value type (one from [c_type_object .. c_type_null])
 parent_type char(1), -- Parent node value type ('O'/'A' when parsing child nodes) 
 quote boolean, -- True if the currently parsing name or value is quoted
 escape boolean, -- True if the currently parsing character follows the backslash
 digit boolean, -- True if the currently parsing number value contains a digit
 sign boolean, -- True if the currently parsing number value starts with a sign
 dot boolean, -- True if the currently parsing number value contains a dot
 --
 types t_types, -- Stack of parent node value types
 nodes t_integers, -- Stack of parent node indices
 indices t_integers, -- Stack of parent node array indices
 --
 decoration_depth binary_integer:=0, -- Number of levels to decorate on stringify
 --
 test_source varchar2(32767) -- Currently testing JSON expression
);
-- Possible constant values for 't_fill_state.expect' variable
function expect_value return binary_integer is begin return 0; end; -- {[AZaz"'-09
function expect_name  return binary_integer is begin return 1; end; --   AZaz"' 09 _$
function expect_char  return binary_integer is begin return 2; end; --   AZaz"'-09,]}
function expect_digit return binary_integer is begin return 3; end; --         -09,]}
function expect_comma return binary_integer is begin return 4; end; --            ,]}
function expect_colon return binary_integer is begin return 5; end; -- :
-- Possible constant values for 't_fill_state.type' variable
function type_object  return char is begin return 'O'; end;
function type_array   return char is begin return 'A'; end;
function type_string  return char is begin return 'S'; end;
function type_number  return char is begin return 'N'; end;
function type_boolean return char is begin return 'B'; end;
function type_null    return char is begin return null; end;
-------------------------------------------------------------------------------
procedure create_top_node(p_state in out nocopy t_fill_state,p_type char,p_value varchar2:=null) is
begin
 p_state.depth:=0;
 p_state.node:=0;
 p_state.idx:=null;
 p_state.type:=p_type;
 p_state.parent_node:=null;
 p_state.parent_type:=null;
 --p_state.test_source:=null;
 p_state.types.delete;
 p_state.nodes.delete;
 p_state.indices.delete;
 execute immediate 'truncate table web_node';
 execute immediate 'insert into web_node (id,type,value) values (0,:1,:2)'
  using p_type,p_value;
end;
--
procedure create_top_node_object(p_state in out nocopy t_fill_state) is
begin
 create_top_node(p_state,type_object);
end;
--
procedure create_top_node_array(p_state in out nocopy t_fill_state) is
begin
 create_top_node(p_state,type_array);
end;
--
procedure begin_subnodes(p_state in out nocopy t_fill_state) is
begin
 if p_state.type is null or p_state.type not in (type_object,type_array) then
  raise_application_error(-20002,'Error adding subnodes: invalid parent type: "'||p_state.type||'"');
 end if;
 --
 if p_state.depth>0 then
  p_state.types(p_state.depth):=p_state.parent_type;
  p_state.nodes(p_state.depth):=p_state.parent_node;
  p_state.indices(p_state.depth):=p_state.idx;
 end if;
 --
 p_state.idx:=case when p_state.type=type_array then 0 end;
 p_state.parent_node:=p_state.node;
 p_state.parent_type:=p_state.type;
 p_state.type:=null;
 --
 p_state.depth:=p_state.depth+1;
end;
--
procedure end_subnodes(p_state in out nocopy t_fill_state) is
begin
 if p_state.depth<1 then
  raise_application_error(-20002,'Error ending subnodes: invalid depth: '||p_state.depth);
 end if;
 --
 p_state.depth:=p_state.depth-1;
 --
 p_state.type:=null;
 p_state.parent_type:=case when p_state.depth>0 then p_state.types(p_state.depth) end;
 p_state.parent_node:=case when p_state.depth>0 then p_state.nodes(p_state.depth) end;
 p_state.idx:=case when p_state.depth>0 then p_state.indices(p_state.depth) end;
end;
--
procedure add_subnode(p_state in out nocopy t_fill_state,p_name varchar2,p_value varchar2,p_type char) is
begin
 if p_state.depth<1 then
  raise_application_error(-20002,'Error adding subnode: invalid depth: '||p_state.depth);
 end if;
 --
 if p_name is null then
  if p_state.parent_type<>type_array then
   raise_application_error(-20002,'Error adding array value: invalid parent type: "'||p_state.parent_type||'"');
  end if;
 else
  if p_state.parent_type<>type_object then
   raise_application_error(-20002,'Error adding object value: invalid parent type: "'||p_state.parent_type||'"');
  end if;
 end if;
 --
 p_state.node:=p_state.node+1;
 p_state.type:=p_type;
 execute immediate 'insert into web_node (id,parent_id,idx,type,name,value) values(:1,:2,:3,:4,:5,:6)'
  using p_state.node,p_state.parent_node,p_state.idx,p_type,p_name,p_value;
 --
 if p_name is null then
  p_state.idx:=p_state.idx+1;
 end if;
end;
--
procedure add_object_subnode(p_state in out nocopy t_fill_state,p_name varchar2,p_value varchar2,p_type char) is
begin
 if p_name is null then
  raise_application_error(-20002,'Error adding object value: name is null');
 end if;
 --
 add_subnode(p_state,p_name,p_value,p_type);
end;
--
procedure add_array_subnode(p_state in out nocopy t_fill_state,p_value varchar2,p_type char) is
begin
 add_subnode(p_state,null,p_value,p_type);
end;
--
procedure add_subnode_object(p_state in out nocopy t_fill_state,p_name varchar2) is
begin
 add_object_subnode(p_state,p_name,null,type_object);
end;
--
procedure add_subnode_object(p_state in out nocopy t_fill_state) is
begin
 add_array_subnode(p_state,null,type_object);
end;
--
procedure add_subnode_array(p_state in out nocopy t_fill_state,p_name varchar2) is
begin
 add_object_subnode(p_state,p_name,null,type_array);
end;
--
procedure add_subnode_array(p_state in out nocopy t_fill_state) is
begin
 add_array_subnode(p_state,null,type_array);
end;
--
procedure add_subnode_string(p_state in out nocopy t_fill_state,p_name varchar2,p_value varchar2) is
begin
 add_object_subnode(p_state,p_name,p_value,type_string);
end;
--
procedure add_subnode_string(p_state in out nocopy t_fill_state,p_value varchar2) is
begin
 add_array_subnode(p_state,p_value,type_string);
end;
--
procedure add_subnode_optional_string(p_state in out nocopy t_fill_state,p_name varchar2,p_value varchar2) is
begin
 if length(p_value)>0 then
  add_object_subnode(p_state,p_name,p_value,type_string);
 end if;
end;
--
procedure add_subnode_optional_string(p_state in out nocopy t_fill_state,p_value varchar2) is
begin
 if length(p_value)>0 then
  add_array_subnode(p_state,p_value,type_string);
 end if;
end;
--
procedure add_subnode_number(p_state in out nocopy t_fill_state,p_name varchar2,p_value number) is
begin
 add_object_subnode(p_state,p_name,p_value,type_number);
end;
--
procedure add_subnode_number(p_state in out nocopy t_fill_state,p_value number) is
begin
 add_array_subnode(p_state,p_value,type_number);
end;
--
procedure add_subnode_optional_number(p_state in out nocopy t_fill_state,p_name varchar2,p_value number) is
begin
 if p_value<>0 then
  add_object_subnode(p_state,p_name,p_value,type_number);
 end if;
end;
--
procedure add_subnode_optional_number(p_state in out nocopy t_fill_state,p_value number) is
begin
 if p_value<>0 then
  add_array_subnode(p_state,p_value,type_number);
 end if;
end;
--
procedure add_subnode_boolean(p_state in out nocopy t_fill_state,p_name varchar2,p_value boolean) is
begin
 add_object_subnode(p_state,p_name,case when p_value then 'true' else 'false' end,type_boolean);
end;
--
procedure add_subnode_boolean(p_state in out nocopy t_fill_state,p_value boolean) is
begin
 add_array_subnode(p_state,case when p_value then 'true' else 'false' end,type_boolean);
end;
--
procedure add_subnode_optional_boolean(p_state in out nocopy t_fill_state,p_name varchar2,p_value boolean) is
begin
 if p_value then
  add_object_subnode(p_state,p_name,'true',type_boolean);
 end if;
end;
--
procedure add_subnode_optional_boolean(p_state in out nocopy t_fill_state,p_value boolean) is
begin
 if p_value then
  add_array_subnode(p_state,'true',type_boolean);
 end if;
end;
--
function get_subnode_id(p_parent int,p_name varchar2) return int is
 v_result int;
begin
 execute immediate 'select min(id) from web_node where parent_id=:1 and name=:2'
  into v_result
  using p_parent,p_name;
 return v_result;
end;
--
function get_subnode_id(p_parent int,p_index int) return int is
 v_result int;
begin
 execute immediate 'select min(id) from web_node where parent_id=:1 and idx=:2'
  into v_result
  using p_parent,p_index;
 return v_result;
end;
--
function get_subnode_value(p_parent int,p_name varchar2) return varchar2 is
 v_result varchar2(4000);
begin
 execute immediate 'select min(value) from web_node where parent_id=:1 and name=:2'
  into v_result
  using p_parent,p_name;
 return v_result;
end;
--
function get_subnode_value(p_parent int,p_index int) return varchar2 is
 v_result varchar2(4000);
begin
 execute immediate 'select min(value) from web_node where parent_id=:1 and idx=:2'
  into v_result
  using p_parent,p_index;
 return v_result;
end;
-------------------------------------------------------------------------------
procedure write_all(p_state in out nocopy t_stringify_state) is
 --
 function decorate(p_id int) return boolean is
  v_result boolean:=p_state.depth<p_state.decoration_depth;
  v_count int;
 begin
  if p_state.decoration_depth>0 and not v_result then
   execute immediate 'select count(*) from web_node a where a.parent_id=:1'
    into v_count
    using p_id;
   v_result:=v_count>1;
  end if;
  return v_result;
 end;
 --
 procedure write_value(p_id int,p_type char,p_value varchar2);
 --
 procedure write_text(p_text varchar2) is
 begin
  if p_text is not null then
   if length(p_state.text)+length(p_text)>32767 then
    if p_state.lob is null then
     raise_application_error(-20001,'Output JSON text is too large: '||length(p_state.text)||'+'||length(p_text)||' |'||substr(p_text,1,100)||'|');
    end if;
    dbms_lob.writeappend(p_state.lob,length(p_state.text),p_state.text);
    p_state.text:=p_text;
   else
    p_state.text:=p_state.text||p_text;
   end if;
  end if;
 end;
 --
 procedure write_string(p_value varchar2) is
  v_out varchar2(32767);
  v_char char(1);
 begin
  for v_pos in 1..nvl(length(p_value),0) loop
   v_char:=substr(p_value,v_pos,1);
   case v_char
   when '\' then
    v_out:=v_out||'\\';
   when '"' then
    v_out:=v_out||'\"';
   when chr(10) then
    v_out:=v_out||'\n';
   when chr(13) then
    v_out:=v_out||'\r';
   when chr(9) then
    v_out:=v_out||'\t';
   when chr(12) then
    v_out:=v_out||'\f';
   when chr(8) then
    v_out:=v_out||'\b';
   else
    v_out:=v_out||v_char;
   end case;
  end loop;
  write_text('"'||v_out||'"');
 end;
 --
 procedure write_number(p_value varchar2) is
  v_out varchar2(32767);
 begin
  if p_value is null then
   v_out:='0';
  else
   v_out:=0+p_value;
   if substr(v_out,1,1)='.' then
    v_out:='0'||v_out;
   elsif substr(v_out,1,2)='-.' then
    v_out:='-0'||substr(v_out,2);
   end if;
  end if;
  write_text(v_out);
 end;
 --
 procedure write_boolean(p_value varchar2) is
 begin
  if lower(p_value)='true' then
   write_text('true');
  else
   write_text('false');
  end if;
 end;
 --
 procedure write_array(p_id int) is
  rc sys_refcursor;
  v_id int;
  v_type char(1);
  v_value varchar2(4000);
  v_comma boolean:=false;
  v_decorate boolean:=decorate(p_id);
 begin
  --say('write_array p_id=|'||p_id||'|');
  write_text('[');
  p_state.depth:=p_state.depth+1;
  open rc for 'select id,type,value from web_node where parent_id=:1 order by idx,id' using p_id;
  loop
   fetch rc into v_id,v_type,v_value;
   exit when rc%notfound;
   if v_decorate then
    write_text(rpad(chr(10),p_state.depth));
   end if;
   if v_comma then
    write_text(',');
   else
    v_comma:=true;
    if v_decorate then
     write_text(' ');
    end if;
   end if;
   write_value(v_id,v_type,v_value);
  end loop;
  if v_comma and v_decorate then
   write_text(rpad(chr(10),p_state.depth));
  end if;
  p_state.depth:=p_state.depth-1;
  write_text(']');
 end;
 --
 procedure write_object(p_id int) is
  rc sys_refcursor;
  v_id int;
  v_name varchar2(4000);
  v_type char(1);
  v_value varchar2(4000);
  v_comma boolean:=false;
  v_decorate boolean:=p_state.depth<p_state.decoration_depth;
 begin
  write_text('{');
  p_state.depth:=p_state.depth+1;
  open rc for 'select id,name,type,value from web_node where parent_id=:1 order by id' using p_id;
  loop
   fetch rc into v_id,v_name,v_type,v_value;
   exit when rc%notfound;
   if v_decorate then
    write_text(rpad(chr(10),p_state.depth));
   end if;
   if v_comma then
    write_text(',');
   else
    v_comma:=true;
    if v_decorate then
     write_text(' ');
    end if;
   end if;
   write_string(v_name);
   write_text(':');
   write_value(v_id,v_type,v_value);
  end loop;
  if v_comma and v_decorate then
   write_text(rpad(chr(10),p_state.depth));
  end if;
  p_state.depth:=p_state.depth-1;
  write_text('}');
 end;
 --
 procedure write_value(p_id int,p_type char,p_value varchar2) is
 begin
  --say('write_value p_id=|'||p_id||'| p_type=|'||p_type||'| p_value=|'||p_value||'|');
  case p_type
  when type_object then
   write_object(p_id);
  when type_array then
   write_array(p_id);
  when type_string then
   write_string(p_value);
  when type_number then
   write_number(p_value);
  when type_boolean then
   write_boolean(p_value);
  else
   write_text('null');
  end case;
 end;
 --
begin
 declare
  v_type char(1);
  v_value varchar2(32767);
 begin
  begin
   execute immediate 'select type,value from web_node where id=0' into v_type,v_value;
  exception when no_data_found then
   return;
  end;
  --say('write_all v_value=|'||v_value||'|');
  p_state.depth:=0;
  p_state.decoration_depth:=nvl(p_state.decoration_depth,0);
  write_value(0,v_type,v_value);
  --
  if p_state.lob is not null and p_state.text is not null then
   dbms_lob.writeappend(p_state.lob,length(p_state.text),p_state.text);
   p_state.text:=null;
  end if;
 end;
end;
--
function stringify(p_decoration_depth binary_integer:=null) return varchar2 is
 v_json varchar2(32767);
begin
 stringify(v_json,p_decoration_depth);
 return v_json;
end;
--
procedure stringify(p_json out varchar2,p_decoration_depth binary_integer:=null) is
 v_state t_stringify_state;
begin
 v_state.decoration_depth:=p_decoration_depth;
 write_all(v_state);
 p_json:=v_state.text;
 --say('stringify json=|'||p_json||'|');
end;
--
procedure stringify(p_json out clob,p_decoration_depth binary_integer:=null) is
 v_state t_stringify_state;
begin
 v_state.decoration_depth:=p_decoration_depth;
 dbms_lob.createtemporary(v_state.lob,false);
 dbms_lob.open(v_state.lob,dbms_lob.lob_readwrite);
 write_all(v_state);
 p_json:=v_state.lob;
 --say('stringify json=|'||dbms_lob.substr(p_json)||'|');
 -- Caller should run dbms_lob.freetemporary(p_json);
end;
-------------------------------------------------------------------------------
procedure parse_init(p_state in out nocopy t_parse_state) is
begin
 p_state.fragment_pos:=0;
 p_state.token_pos:=0;
 p_state.depth:=0;
 p_state.expect:=expect_value;
 p_state.node:=0;
 p_state.name:=null;
 p_state.idx:=null;
 p_state.value:=null;
 p_state.type:=null;
 p_state.parent_node:=null;
 p_state.parent_type:=null;
 p_state.test_source:=null;
 p_state.quote:=false;
 p_state.escape:=false;
 p_state.digit:=false;
 p_state.sign:=false;
 p_state.dot:=false;
 --
 execute immediate 'delete from web_node';
 p_state.types.delete;
 p_state.nodes.delete;
 p_state.indices.delete;
end;
--
procedure init_name(p_state in out nocopy t_parse_state) is
begin
 p_state.name:=null;
 p_state.type:=null;
 p_state.value:=null;
 p_state.quote:=false;
 p_state.escape:=false;
end;
--
procedure init_value(p_state in out nocopy t_parse_state) is
begin
 p_state.type:=null;
 p_state.value:=null;
 p_state.quote:=false;
 p_state.escape:=false;
end;
--
function is_space(p_char char) return boolean is
begin
 return p_char in (chr(9),chr(10),chr(13),chr(32));
end;
--
function is_valid_char(p_char char,p_first boolean:=false) return boolean is
begin
 return p_char in ('_','$')
  or lower(p_char) between 'a' and 'z'
  or not p_first and p_char between '0' and '9';
end;
--
function is_valid_digit(p_state in out nocopy t_parse_state,p_char char,p_first boolean:=false) return boolean is
 v_result boolean:=false;
begin
 if p_char between '0' and '9' then
  v_result:=true;
  p_state.digit:=true;
  if p_first then
   p_state.sign:=false;
   p_state.dot:=false;
  end if;
 elsif not p_first and not p_state.dot and p_char='.' then
  v_result:=true;
  p_state.dot:=true;
  if p_first then
   p_state.digit:=false;
   p_state.sign:=false;
  end if;
 elsif p_first and not p_state.sign and p_char='-' then
  v_result:=true;
  p_state.digit:=false;
  p_state.sign:=true;
  p_state.dot:=false;
 end if;
 return v_result;
end;
--
procedure push_node(p_state in out nocopy t_parse_state) is
begin
 if p_state.depth>0 then
  p_state.types(p_state.depth):=p_state.parent_type;
  p_state.nodes(p_state.depth):=p_state.parent_node;
  p_state.indices(p_state.depth):=p_state.idx;
 end if;
 p_state.idx:=case when p_state.type=type_array then 0 end;
 p_state.parent_node:=p_state.node-1;
 p_state.parent_type:=p_state.type;
 p_state.depth:=p_state.depth+1;
end;
--
procedure pop_node(p_state in out nocopy t_parse_state) is
begin
 if p_state.depth<1 then
  raise_application_error(-20002,p_state.test_source||'Syntax error: invalid depth: '||p_state.depth);
 end if;
 p_state.depth:=p_state.depth-1;
 p_state.type:=p_state.parent_type;
 if p_state.depth>0 then
  p_state.parent_type:=p_state.types(p_state.depth);
  p_state.parent_node:=p_state.nodes(p_state.depth);
  p_state.idx:=p_state.indices(p_state.depth);
 end if;
end;
--
procedure add_node(p_state in out nocopy t_parse_state) is
begin
 execute immediate 'insert into web_node (id,parent_id,idx,type,name,value) values(:1,:2,:3,:4,:5,:6)'
  using p_state.node,p_state.parent_node,p_state.idx,p_state.type,p_state.name,p_state.value;
 p_state.node:=p_state.node+1;
end;
-- First char only (set v_type and new v_expect)
procedure parse_value(p_state in out nocopy t_parse_state,p_char char) is
begin
 --say('parse_value("'||p_char||'")');
 if p_state.value is not null or p_state.quote or p_state.escape then
  raise_application_error(-20002,p_state.test_source||'Syntax error: value is not null at pos '||p_state.token_pos);
 end if;
 --
 if p_char='{' then
  p_state.type:=type_object;
  add_node(p_state);
  push_node(p_state);
  p_state.expect:=expect_name;
  init_name(p_state);
 elsif p_char='[' then
  p_state.type:=type_array;
  add_node(p_state);
  push_node(p_state);
  init_name(p_state);
 elsif p_state.parent_type=type_array and p_state.idx=0 and p_char=']' then
  pop_node(p_state);
  p_state.expect:=expect_comma;
 elsif p_char='"' then
  p_state.type:=type_string;
  p_state.quote:=true;
  p_state.expect:=expect_char;
 elsif is_valid_char(p_char,true) then
  p_state.type:=type_string;
  p_state.value:=p_char;
  p_state.expect:=expect_char;
 elsif is_valid_digit(p_state,p_char,true) then
  p_state.type:=type_number;
  p_state.value:=p_char;
  p_state.expect:=expect_digit;
 else
  raise_application_error(-20002,p_state.test_source||'Syntax error: invalid value "'||p_char||'" at pos '||p_state.token_pos);
 end if;
end;
-- First char only (set new v_expect)
procedure parse_name(p_state in out nocopy t_parse_state,p_char char) is
begin
 --say('parse_name("'||p_char||'")');
 if p_state.name is not null then
  raise_application_error(-20002,p_state.test_source||'Syntax error: name is not null at pos '||p_state.token_pos);
 end if;
 --
 if p_char='}' and p_state.node=p_state.parent_node+1 then
  pop_node(p_state);
  p_state.expect:=expect_comma;
 elsif p_char='"' then
  p_state.quote:=true;
  p_state.expect:=expect_char;
 else
  raise_application_error(-20002,p_state.test_source||'Syntax error: invalid name at pos='||p_state.token_pos);
 end if;
end;
--
procedure check_value(p_state in out nocopy t_parse_state) is
begin
 --say('check_value("'||p_state.value||'")');
 if p_state.value='null' then
  p_state.type:=type_null;
 elsif p_state.value='NaN' then
  p_state.value:='null';
  p_state.type:=type_null;
 elsif p_state.value in ('false','true') then
  p_state.type:=type_boolean;
 else
  raise_application_error(-20002,p_state.test_source||'Syntax error: unknown value "'||p_state.value||'" at pos '||p_state.token_pos);
 end if;
end;
-- Continue parsing name or value, adding to v_value
procedure parse_char(p_state in out nocopy t_parse_state,p_char char) is
begin
 --say('parse_char("'||p_char||'")');
 if p_state.quote then
  if p_state.escape then
   if p_char in ('\','"') then
    p_state.value:=p_state.value||p_char;
   elsif p_char='n' then
    p_state.value:=p_state.value||chr(10);
   elsif p_char='r' then
    p_state.value:=p_state.value||chr(13);
   elsif p_char='t' then
    p_state.value:=p_state.value||chr(9);
   elsif p_char='f' then
    p_state.value:=p_state.value||chr(12);
   elsif p_char='b' then
    p_state.value:=p_state.value||chr(8);
   else
    raise_application_error(-20002,p_state.test_source||'Syntax error: bad escaped character "'||p_char||'" at pos '||(p_state.fragment_pos+p_state.parsing_pos));
   end if;
   p_state.escape:=false;
  elsif p_char='"' then
   if p_state.type is null then
    p_state.name:=p_state.value;
    p_state.expect:=expect_colon;
   else
    add_node(p_state);
    p_state.expect:=expect_comma;
   end if;
  elsif p_char='\' then
   p_state.escape:=true;
  else
   p_state.value:=p_state.value||p_char;
  end if;
 else
  if p_state.value is not null and (is_space(p_char) or p_state.parent_type=type_object and p_char in (',','}') or p_state.parent_type=type_array and p_char in (',',']')) then
   check_value(p_state);
   --
   add_node(p_state);
   --
   if p_char=',' and p_state.parent_type=type_object then
    p_state.expect:=expect_name;
    init_name(p_state);
   elsif p_char=',' and p_state.parent_type=type_array then
    p_state.idx:=p_state.idx+1;
    p_state.expect:=expect_value;
    init_value(p_state);
   elsif p_char in ('}',']') then
    pop_node(p_state);
    p_state.expect:=expect_comma;
   else -- space
    p_state.expect:=expect_comma;
   end if;
  elsif is_valid_char(p_char) then
   p_state.value:=p_state.value||p_char;
  else
   raise_application_error(-20002,p_state.test_source||'Syntax error: invalid char "'||p_char||'" at pos '||p_state.token_pos);
  end if;
 end if;
end;
-- Continue parsing name or value, adding to v_value
procedure parse_digit(p_state in out nocopy t_parse_state,p_char char) is
begin
 if p_state.digit and (is_space(p_char) or p_state.parent_type=type_object and p_char in (',','}') or p_state.parent_type=type_array and p_char in (',',']')) then
  if p_state.dot and instr(p_state.value,'.')=length(p_state.value) then
   raise_application_error(-20002,p_state.test_source||'Syntax error: unterminated fractional number at pos '||p_state.token_pos);
  end if;
  --
  add_node(p_state);
  --
  if p_char=',' and p_state.parent_type=type_object then
   p_state.expect:=expect_name;
   init_name(p_state);
  elsif p_char=',' and p_state.parent_type=type_array then
   p_state.idx:=p_state.idx+1;
   p_state.expect:=expect_value;
   init_value(p_state);
  elsif p_char in ('}',']') then
   pop_node(p_state);
   p_state.expect:=expect_comma;
  else -- space
   p_state.expect:=expect_comma;
  end if;
 elsif is_valid_digit(p_state,p_char) then
  p_state.value:=p_state.value||p_char;
 else
  raise_application_error(-20002,p_state.test_source||'Syntax error: invalid digit "'||p_char||'" at pos '||p_state.token_pos);
 end if;
end;
--
procedure parse_comma(p_state in out nocopy t_parse_state,p_char char) is
begin
 --say('parse_comma p_char=|'||p_char||'|, p_state.parent_type=|'||p_state.parent_type||'|');
 if p_char= ',' then
  if p_state.parent_type=type_object then
   p_state.expect:=expect_name;
   init_name(p_state);
  elsif p_state.parent_type=type_array then
   p_state.idx:=p_state.idx+1;
   p_state.expect:=expect_value;
   init_name(p_state);
  else
   raise_application_error(-20002,p_state.test_source||'Syntax error: invalid parent type '||p_state.parent_type||' at pos '||p_state.token_pos);
  end if;
 elsif p_state.parent_type=type_object and p_char= '}' or p_state.parent_type=type_array and p_char= ']' then
  pop_node(p_state);
  --p_state.expect:=expect_comma;
 else
  raise_application_error(-20002,p_state.test_source||'Syntax error: invalid char "'||p_char||'" at pos '||p_state.token_pos);
 end if;
end;
--
procedure parse_colon(p_state in out nocopy t_parse_state,p_char char) is
begin
 if p_char<> ':' then
  raise_application_error(-20002,p_state.test_source||'Syntax error: colon expected at pos '||p_state.token_pos);
 end if;
 p_state.expect:=expect_value;
 init_value(p_state);
end;
--
procedure parse_fragment(p_state in out nocopy t_parse_state,p_json in varchar2) as
 v_length binary_integer:=length(p_json);
 v_char char(1);
begin
 p_state.parsing_pos:=0;
 while p_state.parsing_pos<v_length loop
  p_state.parsing_pos:=p_state.parsing_pos+1;
  v_char:=substr(p_json,p_state.parsing_pos,1);
  --say('pos='||(p_state.fragment_pos+p_state.parsing_pos)||', char="'||v_char||'", expect="'||p_state.expect||'"');
  if p_state.expect in (expect_value,expect_name,expect_comma,expect_colon) then
   -- Skip space if allowed
   if is_space(v_char) then
    continue;
   end if;
   -- Mark new token start pos
   p_state.token_pos:=p_state.fragment_pos+p_state.parsing_pos;
  end if;
  -- Start new value
  case p_state.expect
  when expect_value then
   parse_value(p_state,v_char);
  when expect_name then
   parse_name(p_state,v_char);
  when expect_char then
   parse_char(p_state,v_char);
  when expect_digit then
   parse_digit(p_state,v_char);
  when expect_comma then
   parse_comma(p_state,v_char);
  when expect_colon then
   parse_colon(p_state,v_char);
  end case;
 end loop;
end;
--
procedure parse_test(p_state in out nocopy t_parse_state) is
begin
 if p_state.depth>0 then
  raise_application_error(-20002,p_state.test_source||'Syntax error: final depth='||p_state.depth);
 end if;
 --
 if p_state.node=0 and p_state.expect=expect_char and not p_state.quote then
  parse_char(p_state,' ');
 elsif p_state.node=0 and p_state.expect=expect_digit then
  parse_digit(p_state,' ');
 end if;
 --
 if p_state.expect<>case when p_state.node=0 then expect_value else expect_comma end then
  raise_application_error(-20002,p_state.test_source||'Syntax error: invalid final state: '||p_state.expect);
 end if;
end;
--
procedure parse(p_json in varchar2) as
 v_state t_parse_state;
begin
 parse_init(v_state);
 parse_fragment(v_state,p_json);
 parse_test(v_state);
 --
 --say('Parse OK');
end;
--
procedure parse(p_json in clob) as
 v_length binary_integer:=dbms_lob.getlength(p_json);
 v_fragment varchar2(32767);
 v_state t_parse_state;
begin
 v_state.test_source:=null;
 parse_init(v_state);
 while v_state.fragment_pos<v_length loop
  v_fragment:=dbms_lob.substr(p_json,32767,v_state.fragment_pos+1);
  parse_fragment(v_state,v_fragment);
  v_state.fragment_pos:=v_state.fragment_pos+32767;
 end loop;
 parse_test(v_state);
end;
-------------------------------------------------------------------------------
procedure local_output(p_clob clob) is
 c_max_portion constant binary_integer:=32767;
 v_length int:=nvl(dbms_lob.getlength(p_clob),0);
 v_portion varchar2(32767);
 v_offset int:=1;
 v_divide int;
begin
 while v_offset+c_max_portion<=v_length loop
  v_portion:=dbms_lob.substr(p_clob,offset=>v_offset);
  v_divide:=instr(v_portion,chr(10),-1);
  if v_divide=0 then
   dbms_output.put_line(v_portion);
   dbms_output.put_line(chr(10)||'ERROR'||chr(10)||'JSON line is too long after position '||v_offset);
   return;
  end if;
  v_portion:=substr(v_portion,1,v_divide-1);
  dbms_output.put_line(v_portion);
  v_offset:=v_offset+v_divide;
 end loop;
 --
 if v_offset<=v_length then
  dbms_output.put_line(dbms_lob.substr(p_clob,offset=>v_offset));
 end if;
end;
-------------------------------------------------------------------------------
procedure test_stringify is
 --
 v_node_id int;
 --
 procedure add_top_node(p_type char,p_value varchar2) is
 begin
  v_node_id:=0;
  execute immediate 'truncate table web_node';
  execute immediate 'insert into web_node (id,type,value) values (0,:1,:2)' using p_type,p_value;
 end;
 --
 procedure add_node(p_parent_id int,p_idx int,p_type char,p_value varchar2) is
 begin
  v_node_id:=v_node_id+1;
  execute immediate 'insert into web_node (id,parent_id,idx,type,value) values (:1,:2,:3,:4,:5)' using v_node_id,p_parent_id,p_idx,p_type,p_value;
 end;
 --
 procedure add_node(p_parent_id int,p_name varchar2,p_type char,p_value varchar2) is
 begin
  v_node_id:=v_node_id+1;
  execute immediate 'insert into web_node (id,parent_id,name,type,value) values (:1,:2,:3,:4,:5)' using v_node_id,p_parent_id,p_name,p_type,p_value;
 end;
 --
 procedure check_json(p_expected varchar2) is
  v_actual varchar2(32767);
 begin
  stringify(v_actual);
  --say('check_json v_actual=|'||v_actual||'|');
  commit;
  if 0||p_expected<>0||v_actual then
   raise_application_error(-20003,'Stringify test error: expected/actual are'||chr(10)||'|'||p_expected||'|'||chr(10)||'|'||v_actual||'|');
  end if;
 end;
 --
 procedure test_stringify_single_value is
 begin
  execute immediate 'truncate table web_node';
  check_json(null);
  --
  add_top_node(type_null,null);
  check_json('null');
  --
  add_top_node(type_null,'null');
  check_json('null');
  --
  add_top_node(type_boolean,null);
  check_json('false');
  --
  add_top_node(type_boolean,'false');
  check_json('false');
  --
  add_top_node(type_boolean,'true');
  check_json('true');
  --
  add_top_node(type_number,null);
  check_json('0');
  --
  add_top_node(type_number,'0');
  check_json('0');
  --
  add_top_node(type_number,'.1');
  check_json('0.1');
  --
  add_top_node(type_number,'-.1');
  check_json('-0.1');
  --
  add_top_node(type_string,null);
  check_json('""');
  --
  add_top_node(type_string,'0');
  check_json('"0"');
  --
  add_top_node(type_string,'\a');
  check_json('"\\a"');
  --
  add_top_node(type_string,chr(8));
  check_json('"\b"');
  --
  add_top_node(type_array,null);
  check_json('[]');
  --
  add_top_node(type_object,null);
  check_json('{}');
  --
 end;
 --
 procedure test_stringify_multiple_values is
 begin
  add_top_node(type_array,null);
  add_node(0,0,type_number,'0');
  add_node(0,1,type_number,'1');
  add_node(0,2,type_number,'2');
  check_json('[0,1,2]');
  --1
  add_top_node(type_array,null);
  add_node(0,0,type_null,'null');
  add_node(0,1,type_boolean,'true');
  add_node(0,2,type_string,'x'||chr(9)||'y');
  check_json('[null,true,"x\ty"]');
  --
  add_top_node(type_array,null);
  add_node(0,0,type_number,'1');
  add_node(0,1,type_array,null);
  add_node(2,0,type_number,'2');
  add_node(0,2,type_object,null);
  add_node(4,'x',type_array,null);
  add_node(4,'y',type_object,null);
  check_json('[1,[2],{"x":[],"y":{}}]');
  --
  add_top_node(type_object,null);
  add_node(0,'x',type_number,'0');
  add_node(0,'y',type_number,'1');
  add_node(0,'z',type_number,'2');
  check_json('{"x":0,"y":1,"z":2}');
  --
  add_top_node(type_object,null);
  add_node(0,'x',type_null,'null');
  add_node(0,'y',type_boolean,'true');
  add_node(0,'z',type_string,'x'||chr(9)||'y');
  check_json('{"x":null,"y":true,"z":"x\ty"}');
  --
  add_top_node(type_object,null);
  add_node(0,'x',type_number,'1');
  add_node(0,'y',type_object,null);
  add_node(2,'a',type_number,'2');
  add_node(0,'z',type_array,null);
  add_node(4,0,type_object,null);
  add_node(4,1,type_array,null);
  check_json('{"x":1,"y":{"a":2},"z":[{},[]]}');
 end;
 --
begin
 test_stringify_single_value;
 test_stringify_multiple_values;
 --
 say('Stringify test OK');
end;
-------------------------------------------------------------------------------
procedure test_parse is
 v_state t_parse_state;
 --
 procedure parse_debug(p_text varchar2) is
 begin
  parse_init(v_state);
  v_state.test_source:='|'||p_text||'|'||chr(10);
  commit;
  parse_fragment(v_state,p_text);
  commit;
  parse_test(v_state);
 end;
 --
 procedure check_node_count(p_expected int) is
  v_actual int;
 begin
  execute immediate 'select count(*) from web_node' into v_actual;
  if v_actual<>p_expected then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node count expected='||p_expected||', actual='||v_actual);
  end if;
 end;
 --
 procedure check_top_node(p_type char,p_value varchar2) is
  v_type char(1);
  v_value varchar2(4000);
 begin
  execute immediate 'select type,value from web_node where id=0' into v_type,v_value;
  if 0||v_type<>0||p_type then
   raise_application_error(-20003,v_state.test_source||'Parse test error: top node type expected='''||p_type||''', actual='''||v_type||'''');
  elsif 0||v_value<>0||p_value then
   raise_application_error(-20003,v_state.test_source||'Parse test error: top node value expected='''||p_value||''', actual='''||v_value||'''');
  end if;
 end;
 --
 procedure check_node(p_id int,p_parent_id int,p_idx int,p_type char,p_name varchar2,p_value varchar2) is
  v_count int;
  v_parent_id int;
  v_idx int;
  v_type char(1);
  v_name varchar2(4000);
  v_value varchar2(4000);
 begin
  execute immediate 'select count(*) from web_node where id=:1' into v_count using p_id;
  if v_count<>1 then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node '||p_id||' not found');
  end if;
  --
  execute immediate 'select parent_id,idx,type,name,value from web_node where id=:1' into v_parent_id,v_idx,v_type,v_name,v_value using p_id;
  if 0||v_parent_id<>0||p_parent_id then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node '||p_id||' parent_id expected='''||p_parent_id||''', actual='''||v_parent_id||'''');
  elsif 0||v_idx<>0||p_idx then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node '||p_id||' array index expected='''||p_idx||''', actual='''||v_idx||'''');
  elsif 0||v_type<>0||p_type then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node '||p_id||' value type expected='''||p_type||''', actual='''||v_type||'''');
  elsif 0||v_name<>0||p_name then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node '||p_id||' name expected='''||p_name||''', actual='''||v_name||'''');
  elsif 0||v_value<>0||p_value then
   raise_application_error(-20003,v_state.test_source||'Parse test error: node '||p_id||' value expected='''||p_value||''', actual='''||v_value||'''');
  end if;
 end;
 --
 procedure test_parse_single_value is
 begin
  parse_debug(null);
  check_node_count(0);
  --
  parse_debug('0');
  check_node_count(1);
  check_top_node(type_number,'0');
  --
  parse_debug('null');
  check_node_count(1);
  check_top_node(type_null,'null');
  --
  parse_debug('NaN');
  check_node_count(1);
  check_top_node(type_null,'null');
  --
  parse_debug('true');
  check_node_count(1);
  check_top_node(type_boolean,'true');
  --
  parse_debug('false');
  check_node_count(1);
  check_top_node(type_boolean,'false');
  --
  parse_debug('""');
  check_node_count(1);
  check_top_node(type_string,null);
  --
  parse_debug('"\\\"\n\r\t\f\b"');
  check_node_count(1);
  check_top_node(type_string,'\"'||chr(10)||chr(13)||chr(9)||chr(12)||chr(8));
 end;
 --
 procedure test_parse_plain_array is
 begin
  parse_debug('[]');
  check_node_count(1);
  check_top_node(type_array,null);
  --
  parse_debug('[0]');
  check_node_count(2);
  check_top_node(type_array,null);
  check_node(1,0,0,type_number,null,'0');
  --
  parse_debug('[1,-10,2.5,-0.0]');
  check_node_count(5);
  check_top_node(type_array,null);
  check_node(1,0,0,type_number,null,'1');
  check_node(2,0,1,type_number,null,'-10');
  check_node(3,0,2,type_number,null,'2.5');
  check_node(4,0,3,type_number,null,'-0.0');
  --
  parse_debug('[null,NaN,true,false]');
  check_node_count(5);
  check_top_node(type_array,null);
  check_node(1,0,0,type_null,null,'null');
  check_node(2,0,1,type_null,null,'null');
  check_node(3,0,2,type_boolean,null,'true');
  check_node(4,0,3,type_boolean,null,'false');
  --
  parse_debug('["x","","\\","\""]');
  check_node_count(5);
  check_top_node(type_array,null);
  check_node(1,0,0,type_string,null,'x');
  check_node(2,0,1,type_string,null,null);
  check_node(3,0,2,type_string,null,'\');
  check_node(4,0,3,type_string,null,'"');
 end;
 --
 procedure parse_plain_object is
 begin
  parse_debug('{}');
  check_node_count(1);
  check_top_node(type_object,null);
  --
  parse_debug('{"x":"y"}');
  check_node_count(2);
  check_top_node(type_object,null);
  check_node(1,0,null,type_string,'x','y');
  --
  parse_debug('{"10":null}');
  check_node_count(2);
  check_top_node(type_object,null);
  check_node(1,0,null,type_null,'10','null');
  --
  parse_debug('{"true":false,"false":true}');
  check_node_count(3);
  check_top_node(type_object,null);
  check_node(1,0,null,type_boolean,'true','false');
  check_node(2,0,null,type_boolean,'false','true');
  --
  parse_debug('{"x\\y":NaN,"\"":"\t","null":-0}');
  check_node_count(4);
  check_top_node(type_object,null);
  check_node(1,0,null,type_null,'x\y','null');
  check_node(2,0,null,type_string,'"',chr(9));
  check_node(3,0,null,type_number,'null','-0');
 end;
 --
 procedure parse_mixed_hierarchy is
 begin
  parse_debug('[{},[],false]');
  check_node_count(4);
  check_top_node(type_array,null);
  check_node(1,0,0,type_object,null,null);
  check_node(2,0,1,type_array,null,null);
  check_node(3,0,2,type_boolean,null,'false');
  --
  parse_debug('{"x":{},"y":[],"z":false}');
  check_node_count(4);
  check_top_node(type_object,null);
  check_node(1,0,null,type_object,'x',null);
  check_node(2,0,null,type_array,'y',null);
  check_node(3,0,null,type_boolean,'z','false');
  --
  parse_debug('{"x":{},"y":[{"z":0},0]}');
  check_node_count(6);
  check_top_node(type_object,null);
  check_node(1,0,null,type_object,'x',null);
  check_node(2,0,null,type_array,'y',null);
  check_node(3,2,0,type_object,null,null);
  check_node(4,3,null,type_number,'z',0);
  check_node(5,2,1,type_number,null,0);
 end;
 --
begin
 test_parse_single_value;
 test_parse_plain_array;
 parse_plain_object;
 parse_mixed_hierarchy;
 --
 say('Parse test OK');
end;
-------------------------------------------------------------------------------
procedure test_roundtrip is
 --
 procedure test_json(p_expected varchar2) is
  v_actual varchar2(32767);
 begin
  parse(p_expected);
  stringify(v_actual);
  if 0||p_expected<>0||v_actual then
   raise_application_error(-20003,'Roundtrip test error: expected/actual are'||chr(10)||'|'||p_expected||'|'||chr(10)||'|'||v_actual||'|');
  end if;
 end;
 --
begin
 test_json('');
 test_json('0');
 test_json('true');
 test_json('null');
 test_json('-0.1');
 test_json('""');
 test_json('"x"');
 test_json('"x\tx"');
 test_json('"\"x\""');
 test_json('"/\\!/\\"');
 test_json('"null"');
 test_json('"true"');
 test_json('[]');
 test_json('{}');
 test_json('{"x":null,"y":true,"z":"x\ty"}');
 test_json('{"x\\y":null,"\"":"\t","null":-0}');
 --
 say('Roundtrip test OK');
end;
-------------------------------------------------------------------------------
procedure test_create_nodes is
 procedure check_json(p_expected varchar2) is
  v_actual varchar2(32767);
 begin
  stringify(v_actual);
  --say('check_json v_actual=|'||v_actual||'|');
  commit;
  if 0||p_expected<>0||v_actual then
   raise_application_error(-20003,'Create nodes test error: expected/actual are'||chr(10)||'|'||p_expected||'|'||chr(10)||'|'||v_actual||'|');
  end if;
 end;
 --
 procedure test_create_nodes_single is
  v_state t_fill_state;
 begin
  create_top_node(v_state,type_null,'null');
  check_json('null');
  --
  create_top_node(v_state,type_null,null);
  check_json('null');
  --
  create_top_node(v_state,type_boolean,null);
  check_json('false');
  --
  create_top_node(v_state,type_boolean,'false');
  check_json('false');
  --
  create_top_node(v_state,type_boolean,'true');
  check_json('true');
  --
  create_top_node(v_state,type_number,null);
  check_json('0');
  --
  create_top_node(v_state,type_number,'0');
  check_json('0');
  --
  create_top_node(v_state,type_number,'.1');
  check_json('0.1');
  --
  create_top_node(v_state,type_number,'-.1');
  check_json('-0.1');
  --
  create_top_node(v_state,type_string,null);
  check_json('""');
  --
  create_top_node(v_state,type_string,'0');
  check_json('"0"');
  --
  create_top_node(v_state,type_string,'\a');
  check_json('"\\a"');
  --
  create_top_node(v_state,type_string,chr(8));
  check_json('"\b"');
  --
  create_top_node(v_state,type_array,null);
  check_json('[]');
  --
  create_top_node(v_state,type_object,null);
  check_json('{}');
  --
 end;
 --
 procedure test_create_nodes_multiple is
  v_state t_fill_state;
 begin
  create_top_node_array(v_state);
  begin_subnodes(v_state);
  add_subnode_number(v_state,0);
  add_subnode_number(v_state,1);
  add_subnode_number(v_state,2);
  end_subnodes(v_state);
  check_json('[0,1,2]');
  --
  create_top_node_array(v_state);
  begin_subnodes(v_state);
  add_subnode(v_state,null,'null',type_null);
  add_subnode_boolean(v_state,true);
  add_subnode_string(v_state,'x'||chr(9)||'y');
  end_subnodes(v_state);
  check_json('[null,true,"x\ty"]');
  --
  create_top_node_array(v_state);
  begin_subnodes(v_state);
   add_subnode_number(v_state,1);
   add_subnode_array(v_state);
   begin_subnodes(v_state);
    add_subnode_number(v_state,2);
   end_subnodes(v_state);
   add_subnode_object(v_state);
   begin_subnodes(v_state);
    add_subnode_array(v_state,'x');
    add_subnode_object(v_state,'y');
   end_subnodes(v_state);
  end_subnodes(v_state);
  check_json('[1,[2],{"x":[],"y":{}}]');
  --
  create_top_node_object(v_state);
  begin_subnodes(v_state);
   add_subnode_number(v_state,'x',0);
   add_subnode_number(v_state,'y',1);
   add_subnode_number(v_state,'z',2);
  end_subnodes(v_state);
  check_json('{"x":0,"y":1,"z":2}');
  --
  create_top_node_object(v_state);
  begin_subnodes(v_state);
   add_subnode(v_state,'x','null',type_null);
   add_subnode_boolean(v_state,'y',true);
   add_subnode_string(v_state,'z','x'||chr(9)||'y');
  end_subnodes(v_state);
  check_json('{"x":null,"y":true,"z":"x\ty"}');
  --
  create_top_node_object(v_state);
  begin_subnodes(v_state);
   add_subnode_number(v_state,'x',1);
   add_subnode_object(v_state,'y');
   begin_subnodes(v_state);
    add_subnode_number(v_state,'a',2);
   end_subnodes(v_state);
   add_subnode_array(v_state,'z');
   begin_subnodes(v_state);
    add_subnode_object(v_state);
    add_subnode_array(v_state);
   end_subnodes(v_state);
  end_subnodes(v_state);
  check_json('{"x":1,"y":{"a":2},"z":[{},[]]}');
end;
 --
begin
 test_create_nodes_single;
 test_create_nodes_multiple;
 --
 say('Create nodes test OK');
end;
-------------------------------------------------------------------------------
procedure create_table is
 e_missing_tab exception;
 pragma exception_init(e_missing_tab,-942);
begin
 begin
  execute immediate 'truncate table web_node';
  execute immediate 'drop table web_node';
 exception when e_missing_tab then
  null;
 end;
 --
 begin
  execute immediate
   'create global temporary table web_node'||
   '('||
   'id int not null,'||
   'parent_id int,'||
   'idx int,'||
   'type char(1),'||
   'name varchar2(4000),'||
   'value varchar2(4000),'||
   'constraint web_node_pk primary key (id)'||
   ') on commit preserve rows';
  execute immediate
   'create index web_node_parent_id on web_node (parent_id)';
 end;
end;
-------------------------------------------------------------------------------
end;

/