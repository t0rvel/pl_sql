create or replace PACKAGE BODY pkg_cap_import

is

-----------------------------------------------------------------------------------------------------------------------------------------------------
--  Package Body Constants ...
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
-- Constant Values --
--
pkg_name            constant   system_log.program_name%type  := 'cap_import.';
transaction_id      constant number                                  := 216;

-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        fn_get_prod_agency_id--
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        Get producer id from dragon_partner based on co3 code passed by datasource.
--
--
--   %PARAM    in_session_id
--             in_co3_code

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
function fn_get_prod_agency_id
(
in_session_id                 in object.object_id%type,
in_co3_code                   in varchar2
)
return number as

-- variables
v_prod_agency_id              number := 0;

--constants
c_procedure_name              constant    system_log.program_name%type      := pkg_name||'fn_get_prod_agency_id';

BEGIN
pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Begin search for Existing Producer');

    select partner_id into v_prod_agency_id from dragon_partner where co3_code = in_co3_code;
      pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Return Producer ID ID Is:' || v_prod_agency_id);

return v_prod_agency_id;

    exception when others then return 0;

end fn_get_prod_agency_id;
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        fn_get_user_id--
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        Get user_id from dragon_user based on user name passed by datasource.
--
--
--   %PARAM    in_user_name
--             in_session_id

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
function fn_get_user_id
(
in_user_name                    in varchar2,
in_session_id                 in object.object_id%type,
in_partner_id                 in object.object_id%type
)
return number as

-- variables
v_user_id                     number := 0;

--constants
c_procedure_name              constant    system_log.program_name%type      := pkg_name||'fn_get_user_id';

BEGIN
pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Begin search for UW/UA/Producer');

    select max(user_id) into v_user_id from dragon_user where user_full_name = in_user_name and partner_id = in_partner_id;
      pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Return UW/UA/producer ID Is:' || v_user_id);

return v_user_id;

    exception when others then return 0;

end fn_get_user_id;

-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        fn_get_customer_id--
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        Get customer_id from dragon_custmer.
--
--
--   %PARAM    account_name
--             address_one
--             city
--             jurisdiction
--             zipcode

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
function fn_get_customer_id
(
jurisdiction                  in varchar2, 
account_name                  in varchar2, 
address_one                   in varchar2, 
city                          in varchar2, 
zipcode                       in number
)
return number as

-- variables
v_existing_customer           number := 0;

BEGIN

    select min(customer_id) into v_existing_customer from cap_st.dragon_customer where
                customer_name = account_name and mailing_address_line_1 = address_one
                and mailing_city = city and customer_jurisdiction = jurisdiction
                and substr(mailing_zip_code, 1, 5) = lpad(zipcode, 5, '0'); -- get only 5 digit zip!

return v_existing_customer;

    exception when others then return 0;

end fn_get_customer_id;


-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        fn_get_user_id_by_email--
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        Get user_id from dragon_user based on email passed by datasource.
--
--
--   %PARAM    in_email
--             in_partner_id

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
function fn_get_user_id_by_email
(
in_email                        in varchar2,
in_partner_id                   in object.object_id%type
)
return number as

-- variables
v_user_id                     number := 0;

--constants
c_procedure_name              constant    system_log.program_name%type      := pkg_name||'fn_get_user_id';

BEGIN
pkg_os_logging.sp_log(1, transaction_id, c_procedure_name, 'Begin search for UW/UA/Producer');

    select max(user_id) into v_user_id from dragon_user where  partner_id = in_partner_id and email = in_email and actor_type_id = 1;
      pkg_os_logging.sp_log(1, transaction_id, c_procedure_name, 'Return UW/UA/producer ID Is:' || v_user_id);

return v_user_id;

    exception when others then return 0;

end fn_get_user_id_by_email;

-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        fn_get_state_enum--
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        Get state code enum from state code passed by datasource.
--
--
--   %PARAM    in_state_code
--             in_session_id

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
function fn_get_state_enum
(
in_state_code     in lookup_list_value.lookup_text%type,
in_session_id     in        object.object_id%type
)
return number as

-- variables
v_enum                    number := 0;

--constants
c_procedure_name         constant       system_log.program_name%type                := pkg_name||'fn_get_state_enum';

BEGIN
pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Begin function');

  select lookup_enum into v_enum from lookup_list_value where lookup_list_id = gListJurisdiction and lookup_text = in_state_code and lookup_enum <= 52; -- lookup_list_id and in state code and US only
  pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Return enum is: ' || v_enum);

return v_enum;

    exception when others then return 0;

end fn_get_state_enum;
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        workbench_send_mail
--
--   %USAGE
--       Oracle stock email functionality plus added csv
--
--   %ALGORITHM
--        Send an email with success / fail attachments.
--        
--      

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
procedure workbench_send_mail (p_to        IN VARCHAR2,
                                       p_cc        IN VARCHAR2 DEFAULT NULL,
                                       p_from      IN VARCHAR2,
                                       p_smtp_host IN VARCHAR2,
                                       p_smtp_port IN NUMBER DEFAULT 25,
                                       p_start_date IN VARCHAR2,
                                       p_end_date   IN VARCHAR2,
                                       run_count    IN number DEFAULT 0)
AS

v_message_type      VARCHAR2(100) := 'text/plain';
v_header          	VARCHAR2(300) := 'PolicyNumber' || ',' || 'ExpirationDate' || ',' || 'ImportFile';

conn                utl_smtp.connection;

TYPE attach_info IS RECORD (
     attach_name     VARCHAR2(100),
     data_type       VARCHAR2(40) DEFAULT 'text/csv',
     attach_content  CLOB DEFAULT empty_clob());

TYPE array_attachments IS TABLE OF attach_info;

attachments array_attachments := array_attachments();

n_offset            NUMBER;
n_amount            NUMBER        := 1900;
v_crlf              VARCHAR2(5)   := CHR(13) || CHR(10);

v_body              varchar2(4000);

cursor success_subs is
select distinct(feed_policy_number), variable_value, src_file, import_date from feed_from_uwwb where node_name = 
    'policyexpdate_renewal_of' and subid is not null and (trunc(import_date) = trunc(sysdate) or (trunc(import_date) = trunc(sysdate) -1)); -- all created today, or possibly yesterday depending on runtime of proc.

cursor failed_subs is
select distinct(feed_policy_number), variable_value, src_file, import_date from feed_from_uwwb where node_name = 
    'policyexpdate_renewal_of' and subid is null and (trunc(import_date) = trunc(sysdate) or (trunc(import_date) = trunc(sysdate) -1)); -- all created today, or possibly yesterday depending on runtime of proc.

  PROCEDURE process_recipients(p_mail_conn IN OUT UTL_SMTP.connection,
                               p_list      IN     VARCHAR2)
  AS
    l_tab pkg_string_api.t_split_array;
  BEGIN
    IF TRIM(p_list) IS NOT NULL THEN
      l_tab := pkg_string_api.split_text(p_list);
      FOR i IN 1 .. l_tab.COUNT LOOP
        UTL_SMTP.rcpt(p_mail_conn, TRIM(l_tab(i)));
      END LOOP;
    END IF;
  END;



BEGIN

        v_body := '  The total import count for this run was: ' || to_char(run_count) || v_crlf ||
            '  Start Date being: ' || p_start_date || v_crlf ||
            '  End Date being: ' || p_end_date || v_crlf;


  attachments.extend(2);

  DBMS_LOB.CREATETEMPORARY(
    lob_loc => attachments(1).attach_content,
    cache => true,
    dur => dbms_lob.call
  );

  DBMS_LOB.OPEN(
    lob_loc => attachments(1).attach_content,
    open_mode => dbms_lob.lob_readwrite
  );

  DBMS_LOB.CREATETEMPORARY(
    lob_loc => attachments(2).attach_content,
    cache => true,
    dur => dbms_lob.call
  );

  DBMS_LOB.OPEN(
    lob_loc => attachments(2).attach_content,
    open_mode => dbms_lob.lob_readwrite
  );

  attachments(1).attach_name := 'Success_Data_' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS')  || '.csv';
  attachments(2).attach_name := 'Failed_Data_' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || '.csv';

  attachments(1).data_type := 'text/csv';
  attachments(2).data_type := 'text/csv';


-- Open the SMTP connection ...
    conn := utl_smtp.open_connection(p_smtp_host,p_smtp_port);
    utl_smtp.helo(conn, p_smtp_host);
    utl_smtp.mail(conn, p_from);
    utl_smtp.rcpt(conn, p_to);
    
    process_recipients(conn, p_to);
    process_recipients(conn, p_cc);
    
  -- Open data
    utl_smtp.open_data(conn);

  -- Message info

    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('To: ' || p_to || v_crlf));
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || v_crlf));
    if TRIM(p_cc) IS NOT NULL THEN
        utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('CC: ' || REPLACE(p_cc, ',', ';') || v_crlf));
    end if;
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('From: ' || p_from || v_crlf));
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('Subject: ' || 'Workbench Import Report: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || v_crlf));
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('MIME-Version: 1.0' || v_crlf));
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('Content-Type: multipart/mixed; boundary="SECBOUND"' || v_crlf || v_crlf));

  -- Message body
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('--SECBOUND' || v_crlf));
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('Content-Type: ' || v_message_type || v_crlf || v_crlf));
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw(v_body || v_crlf)); -- body of email



    attachments(1).attach_content := attachments(1).attach_content || v_header || v_crlf;
    attachments(2).attach_content := attachments(2).attach_content || v_header || v_crlf;
    
    -- success code
    for s in success_subs loop 
        dbms_lob.Append(attachments(1).attach_content,  s.feed_policy_number ||','||s.variable_value ||','||s.src_file||v_crlf);
    end loop;
    -- fail code
    for f in failed_subs loop 
        dbms_lob.Append(attachments(2).attach_content,  f.feed_policy_number ||','||f.variable_value ||','||f.src_file||v_crlf);
    end loop;	


     -- Attachment Part
    FOR i IN attachments.FIRST .. attachments.LAST
    LOOP
    -- Attach info
        utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('--SECBOUND' || v_crlf));
        utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('Content-Type: ' || attachments(i).data_type
                            || ' name="'|| attachments(i).attach_name || '"' || v_crlf));
        utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('Content-Disposition: attachment; filename="'
                            || attachments(i).attach_name || '"' || v_crlf || v_crlf));

    -- Attach body
        n_offset := 1;
        WHILE n_offset < dbms_lob.getlength(attachments(i).attach_content)
        LOOP
            utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw(dbms_lob.substr(attachments(i).attach_content, n_amount, n_offset)));
            n_offset := n_offset + n_amount;
        END LOOP;
        utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('' || v_crlf));
    END LOOP;

  -- Last boundry
    utl_smtp.write_raw_data(conn, utl_raw.cast_to_raw('--SECBOUND--' || v_crlf));


  -- Close data
    utl_smtp.close_data(conn);
    utl_smtp.quit(conn);

    if dbms_lob.isopen(attachments(1).attach_content) = 1 then
        dbms_lob.close(attachments(1).attach_content);
    end if;

    dbms_lob.freetemporary(attachments(1).attach_content);

    if dbms_lob.isopen(attachments(2).attach_content) = 1 then
        dbms_lob.close(attachments(2).attach_content);
    end if;

    dbms_lob.freetemporary(attachments(2).attach_content);

  EXCEPTION
    WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
      BEGIN
        UTL_SMTP.QUIT(conn);
        EXCEPTION
          WHEN UTL_SMTP.TRANSIENT_ERROR OR UTL_SMTP.PERMANENT_ERROR THEN
            NULL; -- When SMTP server unavailable, we don't have connection to server and QUIT call will throw.
      END;
      pkg_os_log.sp_log_error( 2048, 2048, 'workbench_send_mail', 'ERROR '|| sqlerrm);
--      raise_application_error(-20000,'Failed to send mail due to the following error:  blah='||blah||' '|| sqlerrm);   --todo recreate oracle job
    WHEN others then
      BEGIN
        UTL_SMTP.QUIT(conn);
        EXCEPTION
          WHEN UTL_SMTP.TRANSIENT_ERROR OR UTL_SMTP.PERMANENT_ERROR THEN
            NULL; -- When SMTP server unavailable, we don't have connection to server and QUIT call will throw.
      END;
      pkg_os_log.sp_log_error( 2048, 2048, 'workbench_send_mail', 'ERROR '|| sqlerrm);

END workbench_send_mail;
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        sp_import_forte
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        This procedure creates Submission / PTP / Customer objects and sets data from Forte excel sheet that is imported into Datasource ST table:
--        Datasource is: CAP_ST.SUBMISSION_IMPORTS
--
--   %PARAM    in_session_id            -

--
-----------------------------------------------------------------------------------------------------------------------------------------------------

procedure sp_import_forte

as

--xforms
     in_object_cache               pkg_os_object_cache.t_object_cache; -- just declare
     io_message_list               pkg_os_message.t_message_list; -- just declare
-- xforms

-- variables
v_new_submission_id                     object.object_id%type;
v_datamart_tf                           char   := 'F';
v_xref_Current_ptp                      object.object_id%type;
vSecondPTP                              object.object_id%type;
v_dateStructFullExp                     varchar2(50); -- full variable will be used to structure a date in proper format
v_dateStructExp                         varchar2(50); -- appended variable will be used to structure a date in proper format
v_dateStructFullEff                     varchar2(50); -- full variable will be used to structure a date in proper format
v_dateStructEff                         varchar2(50); -- appended variable will be used to structure a date in proper format
v_sub_trx_id                            object.object_id%type;
v_coverage_id                           object.object_id%type;
v_cvg_token_element                     varchar2(50);
v_eil_token_element                     varchar2(50);
v_sub_shared_att                        object.object_id%type;
v_sub_shared_att_existing               object.object_id%type;
v_found_submission_id                   object.object_id%type := null;
io_action_outcome_id outcome.outcome_id%type;
-- UW variables
v_underwriter_id                       object.object_id%type;
v_inc_token                            number := 1;
v_new_dragon_useru_id                  object.object_id%type;

-- UA variables
v_uassistant_id                       object.object_id%type;
v_ua_inc_token                        number := 1;
v_new_dragon_usera_id                 object.object_id%type;


-- Producing Agency Variables
v_prod_agency_id                      object.object_id%type;
v_new_prod_agency_id                  object.object_id%type;

-- Producer Variables
v_producer_id                         object.object_id%type;
v_new_producer_id                     object.object_id%type;

-- proc constants
c_procedure_name         constant       system_log.program_name%type                := pkg_name||'sp_import_forte';
c_env_prim_val           constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 19925; -- lookup list id = 5301305 Insurance Line
c_env_exes_val           constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 15125; -- lookup list id = 5301305 Insurance Line
cl_ptp_primary           constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 1; -- constant list value enum of lookup list id 5391225 Primary or Excess?
cl_ptp_excess            constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 2; -- constant list value enum of lookup list id 5391225 Primary or Excess?
c_vertical               constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 6125; -- constant list value enum for vertical Specialty Casualty of lookup list id 5392025 Vertical
c_segment                constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 2125; --constant list value enum for segment Environmental of lookup list id 5391625 Segment
c_rh_ind_val             constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 1;  --constant list value enum for boolean indicator Yes of lookup list id 5053501 Boolean Indicator
c_renewal_pending        constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 54425; -- constant list value enum for object state list id 50170 Object State List
c_actor_type_UW          constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 5; -- constant list value enum for list 5048301 Dragon Actor Type UW
c_actor_type_UA          constant       LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 8205; -- constant list value enum for list 5048301 Dragon Actor Type UA

-- Customer variables
v_customer                              object.object_id%type;

-- variable lists
l_submission_entity                     pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_submission_address                    pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_dragon_user_address                   pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_partner_address                       pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_ptp_list                              pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
v_token_table                           pkg_os_token.t_string_table;
v_cvg_token_table                       pkg_os_token.t_string_table;
v_eil_token_table                       pkg_os_token.t_string_table;

excess_primary_polnum                   varchar2(500);

v_existing_customer                     number;
in_session_id object.object_id%type := 0;
v_renewal_uw_id  object.object_id%type := pkg_os_object_io.fn_object_bv_get(3551, transaction_id, 1218, 34004625); -- _Reference_Default Renewal User
--eil vars
v_eil_ind       number := 0;

cursor import_subs is
select * from submission_imports
where ptp_id is null
order by accountname asc, policynbr desc, policyexpdate asc; -- run first data if duplicate based on exp date


begin

pkg_cap_renewal.create_session(in_session_id, v_renewal_uw_id);
--pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Begin procedure');

for loop_subs in import_subs loop -- open cursor and begin to loop none monoline cpl submissions

v_found_submission_id := null; -- reset found submission
v_existing_customer   := null; -- reset existing customer
v_new_producer_id     := null; -- reset new producer
v_eil_ind             := 0; -- reset monoline EIL indicator


-- eil logic begin
pkg_os_token.sp_tokenize_string(REGEXP_REPLACE(loop_subs.product, ' ', ''), ';', v_eil_token_table);
if v_eil_token_table.count > 0 then -- if we have tokens!

    for eil in v_eil_token_table.first..v_eil_token_table.last loop -- loop tokens that exist
      v_eil_token_element := v_eil_token_table(eil);

                          if v_eil_token_element = 'CPL' then

                             v_eil_ind := 2;

                          elsif v_eil_token_element = 'PL' then

                             v_eil_ind := 2;

                          elsif v_eil_token_element = 'CGL' then

                             v_eil_ind := 2;

                          elsif v_eil_token_element = 'TPL' then

                             v_eil_ind := 2;

                          elsif v_eil_token_element = 'PPL' then

                             v_eil_ind := 2;

                          elsif v_eil_token_element = 'SSPL' and v_eil_token_table.count = 1 then
                          
                            v_eil_ind := 2;
                          
                          elsif v_eil_token_element in ('SSPL', 'SSLLA', 'SSLLB', 'SSLLC', 'SSLLD', 'SSLL') then

                            if v_eil_ind != 2 then -- first check if we set EIL indicator for other coverage parts.
                               v_eil_ind := 1;
                            end if;

                          else
                            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Unrecognized Token ' || v_eil_token_element);

                          end if;


    end loop; -- loop tokens that exist

end if; -- end if tokens exist.
-- eil logic end

-- check for duplicate policy numbers resulting from datasources

update cap_st.submission_imports
set ptp_id = 
  (select max(ptp_id) from submission_imports where ptp_id is not null and policynbr = loop_subs.policynbr) 
where exists 
  (select max(ptp_id) from cap_st.submission_imports where ptp_id is not null and  policynbr = loop_subs.policynbr)
and ptp_id is null and policynbr = loop_subs.policynbr;

update cap_st.submission_imports  
set submission_id = 
  (select max(submission_id) from submission_imports where submission_id is not null and policynbr = loop_subs.policynbr) 
where exists 
  (select max(submission_id) from cap_st.submission_imports where submission_id is not null and  policynbr = loop_subs.policynbr)
and submission_id is null and policynbr = loop_subs.policynbr;

commit;
-- check for duplicate policy numbers resulting from datasources

      select max(policynbr) into excess_primary_polnum from cap_st.submission_imports where accountname = loop_subs.accountname and submission_id is null;
      pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Max policy # ' ||  excess_primary_polnum);

if excess_primary_polnum is not null then
-- main exception handle begin
begin
select submission_id into v_found_submission_id from cap_st.dragon_submission where import_policynbr = excess_primary_polnum;  -- add check to see if policy nbr has been imported
--pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Found SUB ID ' ||  v_found_submission_id);
  exception when no_data_found then


if v_found_submission_id is null then
--dbms_output.put_line('Working on policy #' || loop_subs.policynbr || ' check policy number is  ' ||excess_primary_polnum);
--dbms_output.put_line(' ');
    -- Workflow at this point begins Submission creation from  Carrier Page (117002) to New Submission for Primary and Excess
          -- exception handle no data found existing customer
          begin

          --select customer_id into v_existing_customer from cap_st.dragon_customer where account_number = 26952 and customer_name in (
          --select accountname from cap_st.submission_imports where accountname = loop_subs.accountname);
          -- commented out original customer selection, modified with address check and if too many addresses, pick min or oldest of the two.

                select min(customer_id) into v_existing_customer from cap_st.dragon_customer where
                customer_name = loop_subs.accountname and mailing_address_line_1 = loop_subs.accountmailingaddress1
                and mailing_city = loop_subs.accountcity and customer_jurisdiction = loop_subs.accountstatecode
                and substr(mailing_zip_code, 1, 5) = lpad(loop_subs.accountzip5, 5, '0'); -- get only 5 digit zip!

            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Creating sub to existing customer ' ||  v_existing_customer);
            pkg_os_object.sp_object_create(in_session_id, transaction_id, gObjTypeSubmission, v_existing_customer, v_new_submission_id); -- create new submission


          exception when no_data_found then
            pkg_os_object.sp_object_create(in_session_id, transaction_id, gObjTypeSubmission, null, v_new_submission_id); -- create new submission
            
          when others then continue;

          end; -- end exception handle for no data found existing customer.


         -- pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'New Primary Submission ID created is: ' || v_new_submission_id);
          if loop_subs.policyisexcessind = 'N' then
            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_SubLinesIncl, c_env_prim_val); -- Set primary
        --    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set as Primary ' || c_env_prim_val);
          elsif loop_subs.policyisexcessind = 'Y' then
            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_SubLinesIncl, c_env_exes_val); -- Set Excess
        --    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set as Primary ' || c_env_exes_val);
          elsif loop_subs.policyisexcessind = 'T' then
            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_SubLinesIncl, concat(concat(c_env_prim_val , ','),  c_env_exes_val)); -- Set Excess
       --     pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set as Tied ' || concat(concat(c_env_prim_val , ',') , c_env_exes_val));
          end if;
        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_RH_Ren_Indicator, 1); -- Rock Hill Renewal Indicator
        commit;
      --    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'RockHill Ren Indicator ' || c_rh_ind_val);
        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_ObjectState, c_renewal_pending); -- Renewal Pending
      --    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Renewal Pending ' || c_renewal_pending);

          --eil set
          if v_eil_ind = 1 then
            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_SubLinesIncl, 14825); -- Set EIL
      --      pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set as EIL ' || 14825);
          end if;
          --eil end set

          -- get submission trx id
          v_sub_trx_id := pkg_os_object_io.fn_object_bv_path_get(in_session_id, transaction_id, v_new_submission_id, '31915725');
        --    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Submission Trx ID is: ' || v_sub_trx_id);


          -- Set UW and UA on Sub and PTP refs, if existing, else create them, update datamart, and set! --> Primary

              -- underwriter has , between first name and last name in datasource we remove with regexp to pass to our fn to search, we will use , to tokenize below.
              v_underwriter_id := fn_get_user_id(REGEXP_REPLACE(loop_subs.underwritername, '[^0-9A-Za-z]', ' '), in_session_id, 118); -- UW is child of 118 carrier
              v_uassistant_id  := fn_get_user_id(REGEXP_REPLACE(loop_subs.underwriterasstname, '[^0-9A-Za-z]', ' '), in_session_id, 118); -- UWA is child of 118 carrier

              if v_underwriter_id > 0 then -- UW

                 pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'UW found, ID is ' || v_underwriter_id);

                 pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_xReference_UW, v_underwriter_id); -- Set xRef UW id to UW Id which was found (Submission)

              end if; -- UW

              if v_uassistant_id > 0 then --UA

                 pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'UW Assistant found, ID is ' || v_uassistant_id);

                 pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_xReference_UA, v_uassistant_id); -- Set xRef UW Assistant id to UW Id which was found (Submission)

              end if; --UA

          -- Set UW and UA on Sub and PTP refs, if existing, else create them, update datamart, and set! --> Primary

        -- get all submission entity objects and set variables from datasource
        pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_new_submission_id, gObjTypeSubmissionEntity, l_submission_entity);

        if l_submission_entity.count > 0 then
          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Submission entity exists!: ');

          for ise in l_submission_entity.first..l_submission_entity.last loop -- set variables to each submission entity that may exist.

            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Account Name for Primary: ' || loop_subs.accountname);
            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_entity(ise), g_Incl_BusinessName, loop_subs.accountname); -- Account Name

          end loop;

        end if;

        -- get all submission addresses and set variables from datasource
        pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_new_submission_id, gObjTypeSubAdd, l_submission_address);

        if l_submission_address.count > 0 then
          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Submission addresses exist!: ');

          for isa in l_submission_address.first..l_submission_address.last loop -- set variables to each submission address that may exist.

              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set AddrLn 1 for Primary: ' || loop_subs.ACCOUNTMAILINGADDRESS1);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_addressLn1, loop_subs.ACCOUNTMAILINGADDRESS1); -- AccountMailingAddress1

              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set AddrLn 2 for Primary: ' || loop_subs.ACCOUNTMAILINGADDRESS2);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_addressLn2, loop_subs.ACCOUNTMAILINGADDRESS2); -- AccountMailingAddress2

              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set City for Primary: ' || loop_subs.ACCOUNTCITY);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_addCity, loop_subs.ACCOUNTCITY); -- AccountCity

              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Zip for Primary: ' || loop_subs.ACCOUNTZIP5);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_AddZip, lpad(loop_subs.ACCOUNTZIP5, 5, '0')); -- AccountZip5

              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set State for Primary: ' || loop_subs.ACCOUNTSTATECODE);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_AddState, fn_get_state_enum(loop_subs.ACCOUNTSTATECODE, in_session_id)); -- AccountStateCode

              --pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set County for Primary: ' || loop_subs.ACCOUNTCOUNTY); removed from original file
              --pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_AddCounty,
              --pkg_cap_generic.county(fn_get_state_enum(loop_subs.ACCOUNTSTATECODE, in_session_id), substr(loop_subs.ACCOUNTZIP5,1,5))); -- AccountCounty

              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Phone # Primary: ' || loop_subs.ACCOUNTPHONENBR);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), g_phnNmbr, loop_subs.ACCOUNTPHONENBR); -- Account Phone Number

              -- set the primary and mailing address to the last submission address object. patch 1

               pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 29366714, l_submission_address(isa)); -- Primary Address ref
               pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 29366814, l_submission_address(isa)); -- Mailing Address ref
               pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting both Mailing and Primary to final iteration' || l_submission_address(isa));

          end loop;

        end if;

            -- Workflow at this point ends Submission creation from  Carrier Page (117002) to New Submission for Primary and Excess

            -- Workflow at this point begins From New Submission (943025) page to Account Selection if duplicate,
            -- Native Command 1: (943325) clear_submission Context Object = Submission (5)
              pkg_cap_submission.clear_submission(in_session_id, transaction_id, v_new_submission_id);
            -- Workflow at this point ends From New Submission (943025) page to Account Selection if duplicate,

            -- Workflow at this point begins from Matching Accounts page to "New Account" button landing on Producer selection page 943425
            --Native Command 1: (943625) ALSubmissionCreateParentCustomer Context Object = Submission (5)
            if v_existing_customer is null then-- check if customer needs to be created or not.
              io_action_outcome_id := pkg_os_constant.gOutcome_OK;
              pkg_base_submission.sp_subm_create_new_customer(in_session_id, transaction_id, 943625, v_new_submission_id, io_action_outcome_id); -- 943625 is action id, 22 is outcome last param we pass default in 22
            end if; -- end if customer existing
            -- set customer ref on PTP patch 1
              v_customer := pkg_os_object_io.fn_object_bv_path_get(in_session_id, transaction_id, v_new_submission_id, '29253114');
                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Customer ID is: ' || v_customer);

                  -- we need to loop ptps here as well to set reference account info

                  declare

                  -- create cursor for ptps xRefAccountInfo
                  cursor cust_get_ptp is
                  select * from cap_st.object where parent_object_id in (select object_id from cap_st.object where parent_object_id = v_new_submission_id  -- Submission
                    and object_type_id = 3173725 --- sub trx
                    ) and object_type_id = 2276904; -- PTP

                    begin
                      for custo_ptp in cust_get_ptp loop
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, g_xRef_AccountInfo, v_customer); -- Set Customer
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, g_Vertical, c_vertical); -- Set Vertical = 6125 Specialty Casualty
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, g_Segment, c_segment); -- Set Segment = 2125 Environmental
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, 31925325, 9); -- Set ptp trx type = 9
                      end loop;
                    end;

                  -- stop looping ptps here as well to set reference account info

              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_customer, 210153, 75); -- Set Customer to active
            -- Workflow at this point ends from Matching Accounts page to "New Account" button landing on Producer selection page 943425

            --workflow at this point begins for choosing a new producer patch 1 adds submission shared attributes
            -- reset shared existing or new to null each round.
            v_sub_shared_att_existing := null;
            v_sub_shared_att          := null;
            begin -- exception handle no data found
              select object_id into v_sub_shared_att_existing from cap_st.object where parent_object_id = v_customer and object_type_id = 3173825;
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 31908925, v_sub_shared_att_existing); -- Set existing shared attribute on sub
              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting Shared Att: ' || v_sub_shared_att || 'bv id  31908925 for new sub id' ||  v_new_submission_id);
            exception when no_data_found then -- only create submission shared when one does not exist.

              pkg_os_object.sp_object_create(in_session_id, transaction_id, 3173825, v_customer, v_sub_shared_att);

            -- set shared att as ref on sub patch 1 sets ref on sub
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 31908925, v_sub_shared_att); -- Set shared att as ref on Sub
                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'New Sub Shared Att is: ' || v_sub_shared_att);
                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting Shared Att: ' || v_sub_shared_att || 'bv id  31908925 for new sub id' ||  v_new_submission_id);
            end;
            -- Now we check if producing agency exist. Like UW, else we create and set. Producing Agency logic begins here

            v_prod_agency_id := fn_get_prod_agency_id(in_session_id, lpad(loop_subs.co3_producer_code, 5, '0'));

            if v_prod_agency_id > 0 then
              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Producing Agency ID Is: ' || v_prod_agency_id);

                -- Set producing agency ref to Submission and PTP refs!
                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_xRef_Prod_Ag, v_prod_agency_id); -- Submission
                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Primary Seting Submission and PTP Refs with Producing Agency ID: ' || v_prod_agency_id);


            end if;

            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Running Native Command : create_policy_objects action id' || 943925);
            pkg_cap_submission.create_policy_objects(in_session_id, transaction_id, v_new_submission_id); -- action ID for this native command create_policy_objects is 943925
            -- workflow at this point ends for choosing a new producing agency

            -- begin setting producer xref!
            v_producer_id := fn_get_user_id(concat(concat(loop_subs.producernamefirst, ' '), loop_subs.producernamelast), in_session_id, v_prod_agency_id); -- see if producer exists!
            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Producer ID is: ' || v_producer_id);

            if v_producer_id > 0 then
              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Producer ID exists: ' || v_producer_id);

              -- Set Producer Ref that was found for PTP and Sub
                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_xRef_Producer, v_producer_id); -- Submission

            else
              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Producer ID does not exist: ' || v_producer_id);
              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Begin creating a dragon user.. for producer role');

                -- logic determines if new producer belongs to an existing producing agency
                if v_prod_agency_id > 0 then
                  pkg_os_object.sp_object_create(in_session_id, transaction_id, gObjTypeDragonUser, v_prod_agency_id, v_new_producer_id); -- create producer set to existing producing agency above
                    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'New Producer Created ID is ' || v_new_producer_id || ' child of existing producing agency ' || v_prod_agency_id);



                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_producer_id, gFirstName, loop_subs.producernamefirst); -- Producer first name
                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_producer_id, gLastName, loop_subs.producernamelast); -- Producer last name
                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_producer_id, gEmail, loop_subs.producer_email); -- Producer email

                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_producer_id, g_ObjectState, 75); -- Producer set to alive patch 1

                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_producer_id, gDragonActorType, 1); -- Producer set to producer type patch 1
                end if; -- end if setting bvs for new producer
                -- Set new Producer Ref that was created for PTP and Sub
                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_xRef_Producer, v_new_producer_id); -- Submission

                pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_new_prod_agency_id, 2309114, l_partner_address); -- Partner Address patch 1 2309114 is partner address object type
                -- set dragon partner address variables! -- patch 1
                if l_partner_address.count > 0 then
                  pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Dragon Partner Address objects exist!');

                    for pa in l_partner_address.first..l_partner_address.last loop

                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_partner_address(pa), g_addressLn1, loop_subs.produceraddress1); -- producer address ln 1
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Producer Address Ln1 ' || loop_subs.produceraddress1);

                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_partner_address(pa), g_addressLn2, loop_subs.produceraddress2); -- producer address ln 2
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Producer Address Ln2 ' || loop_subs.produceraddress2);

                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_partner_address(pa), g_addCity, loop_subs.producercity); -- producer city
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Producer City ' || loop_subs.producercity);

                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_partner_address(pa), g_AddZip, lpad(loop_subs.producerzip5, 5, '0')); -- producer zip5
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Producer Zip ' || loop_subs.producerzip5);

                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id,l_partner_address(pa), g_AddState, fn_get_state_enum(loop_subs.producerstatecode, in_session_id)); -- ProducerStateCode
                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set Producer State: ' || loop_subs.producerstatecode);

                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_partner_address(pa), g_AddCounty,
                        pkg_cap_generic.county(fn_get_state_enum(loop_subs.producerstatecode, in_session_id), substr(loop_subs.producerzip5,1,5))); -- ProducerCounty
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Set producer County: ' || loop_subs.producercounty);

                        -- set reference primary address on Producing Agency patch 1
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_prod_agency_id, 29367214, l_partner_address(pa)); -- Set Partner Address as primary

                    end loop;

                end if;

            end if;
            -- end set producer xref!

            -- native commands for "Choose Contacts button" enter choose contacts wf

              -- Native Command 1 set_partner_assignments action id = 953525
                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Running Native Command: set_partner_assignments');
                  pkg_cap_partner.set_partner_assignments(in_session_id, transaction_id, v_sub_trx_id);

              /* native command 3 on the page action 1062625 (3 native commands) add_endorsements_and_subjectivities_env exclude old TPL logic! this is for primary not for excess!
              -- commenting out as user will land on the page and generate these native commands
               -- pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Running Native Command: add_endorsements_and_subjectivities_env');
                  --pkg_cap_additional_insured.set_ptp_ai_documents(in_session_id, transaction_id, v_ptp);

                    --pkg_cap_endorsements.add_endorsements(in_session_id, transaction_id, v_xref_Current_ptp);

                 -- pkg_cap_subjectivities.add_subjectivities(in_session_id, transaction_id, v_ptp); */

              -- end choose contacts wf land on page 1062625

              -- PTP logic begins
              declare

                  -- create cursor for ptps
                  cursor get_ptp is
                  select * from cap_st.object where parent_object_id in (select object_id from cap_st.object where parent_object_id = v_new_submission_id  -- Submission
                    and object_type_id = 3173725 --- sub trx
                    ) and object_type_id = 2276904; -- PTP

                    v_indicator       number; -- primary or excess?

                    r_sub_imp         cap_st.submission_imports%rowtype;

                    v_policy_nbr      varchar2(500); -- conditional duplicate account

                         in_object_cache               pkg_os_object_cache.t_object_cache; -- just declare for doc render
                         io_message_list               pkg_os_message.t_message_list; -- just declare for doc render


              begin

                for loop_ptp in get_ptp loop -- begin looping ptps

                --conditional duplicate account
                select max(policynbr) into v_policy_nbr from submission_imports where accountname = loop_subs.accountname and ptp_id is null and instr(policynbr, 'P', 1) = 4; -- distinct non inserted primary

                    select business_variable_value into v_indicator from cap_st.object_bv_value where object_id = loop_ptp.object_id and business_variable_id = 31915925; -- Policy list Primary or Excess?

                      if v_indicator = 1 then -- primary
                        --conditional duplicate account
                        begin -- exception handle
                        select * into r_sub_imp from cap_st.submission_imports where accountname = loop_subs.accountname and policynbr = v_policy_nbr and rownum = 1; --instr(policynbr, 'P', 1) = 4; -- get primary record

                          -- structure date variable to use below expiration based on whether primary or excess
                          v_dateStructFullEff := regexp_replace(r_sub_imp.policyeffdate, '/', ''); -- rexexp removes alpha character from excel datasource
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Eff Date structure no alpha is: ' || v_dateStructFullEff);

                          v_dateStructEff := substr(v_dateStructFullEff, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, ' Eff Date structure year is: ' || v_dateStructEff);

                          v_dateStructEff := v_dateStructEff || substr(v_dateStructFullEff, 1, 2); -- pull the month and appended to year position 1, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Eff Date structure year + mth is: ' || v_dateStructEff);

                          v_dateStructEff := v_dateStructEff || substr(v_dateStructFullEff, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Eff Date structure year + mth + day is: ' || v_dateStructEff);

                          -- structure date variable to use below effective based on primary or excess.
                          v_dateStructFullExp := regexp_replace(r_sub_imp.policyexpdate, '/', ''); -- rexexp removes alpha character from excel datasource
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Exp Date structure no alpha is: ' || v_dateStructFullExp);

                          v_dateStructExp := substr(v_dateStructFullExp, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, ' Exp Date structure year is: ' || v_dateStructExp);

                          v_dateStructExp := v_dateStructExp || substr(v_dateStructFullExp, 1, 2); -- pull the month and appended to year position 1, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Exp Date structure year + mth is: ' || v_dateStructExp);

                          v_dateStructExp := v_dateStructExp || substr(v_dateStructFullExp, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Exp Date structure year + mth + day is: ' || v_dateStructExp);
                          
                          --dbms_output.put_line('setting ptp to ' || loop_ptp.object_id || ' setting submission to ' ||  v_new_submission_id || ' for acctname ' || loop_subs.accountname || ' and policynbr ' || v_policy_nbr);

                          update cap_st.submission_imports set ptp_id = loop_ptp.object_id where accountname = loop_subs.accountname and policynbr = v_policy_nbr; -- and instr(policynbr, 'P', 1) = 4;-- set the primary ptp
                          update cap_st.submission_imports set submission_id = v_new_submission_id where accountname = loop_subs.accountname and policynbr = v_policy_nbr; -- and instr(policynbr, 'P', 1) = 4;-- set the primary submission id

                          commit;
                        exception when others then continue; -- continue
                        
                        end;
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_ptp_PrimaryEx, cl_ptp_primary); -- Set primary lookup on PTP
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_renPolNumIfNotDrg, r_sub_imp.policynbr); -- Set Renewal Policy Number IF NOT Dragon Renewal on PTP
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_polEffDate, to_char(to_date(v_dateStructExp, 'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS')); -- datasource exp is effective dragon
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_polExpDate, to_char(add_months(to_date(v_dateStructExp, 'YYYYMMDDHH24MISS'), 12),'YYYYMMDDHH24MISS')); -- set exp, datasource exp + 12
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_Vertical, c_vertical); -- Set Vertical = 6125 Specialty Casualty
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_Segment, c_segment); -- Set Segment = 2125 Environmental
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, gBrokerRate, (r_sub_imp.commissionbrokerrate*100)); -- Broker Rate on PTP
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_premium, r_sub_imp.total_premium); -- Premium on PTP Policy Premium Renewal - Pro-Rata Coverage Total
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_premium_before_tria, r_sub_imp.total_premium); -- Policy Premium before TRIA Premium Adjustment -- fix patch 1
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, gUnderwritingCom, pkg_os_long_string.fn_create_long_string(in_session_id,transaction_id,r_sub_imp.rating_notes)); -- Underwriting Comments Memo -- set long string!
                        --pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_PTP_RH_Ren_Ind, 1); -- Rock Hill Renewal Indicator gets set by action rule
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, gRateMod, c_rh_ind_val); -- Rate Modification

                        if v_underwriter_id > 0 then -- UW
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xReference_UW, v_underwriter_id); -- Set xRef UW id to UW Id which was found (PTP)
                        end if;

                        if v_uassistant_id > 0 then --UA
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xReference_UA, v_uassistant_id); -- Set xRef UW Assistant id to UW Id which was found (PTP)
                        end if; --UA

                        if v_prod_agency_id > 0 then
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xRef_Prod_Ag, v_prod_agency_id); -- PTP
                        end if;

                        if v_producer_id > 0 then
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xRef_Producer, v_producer_id); -- PTP
                        else
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xRef_Producer, v_new_producer_id); -- PTP
                        end if;


                        r_sub_imp := null; -- clear the record

                        -- run init rules on ptp primary

                        declare -- get all of the bvs for this object type and product

                            cursor init_rules_p1 is
                            select * from cap_st.action_rule a where a.rule_context_object_type_id = 2276904 and a.insurance_line_id = 19925 and a.action_id = 953525; -- New submission init rules, primary ins line, object type ptp

                                v_bv_table			          pkg_os_token.t_string_table;
                                v_bv_path				          varchar2(200);
                                v_business_variable_id	  business_variable.business_variable_id%type;

                                v_count_bv_table          number := 0;
                                v_loop_times              number := 0;
                                v_build_path              varchar2(500);
                                v_ctr                     number := 1;
                                v_object_to_set           number := null;

                          begin

                              for bv_to_set_p1 in init_rules_p1 loop

                                v_bv_path := pkg_os_token.fn_strip_suffix(bv_to_set_p1.action_rule_bv_path, pkg_os_constant.bv_path_segmentor); -- strip off the object-type information.

                                pkg_os_token.sp_tokenize_string(v_bv_path, '.', v_bv_table);
                                v_business_variable_id := v_bv_table(v_bv_table.last);

                                v_count_bv_table := v_bv_table.count; -- how many in token table?

                                v_loop_times := v_count_bv_table - 1; -- we want to iterate through our loop less than total, since last token member is BV, also only iterate if a path exists.

                                for i in v_bv_table.first..v_bv_table.last loop -- loop bv table

                                  if v_loop_times > v_ctr then

                                    v_build_path :=  v_build_path || v_bv_table(i) || '.' ; -- concat the string with . and the token element
                                    v_ctr := v_ctr + 1; -- increment so we don't go endless.

                                  elsif v_loop_times = v_ctr then

                                    v_build_path :=  v_build_path || v_bv_table(i) ; -- concat the string without . and the token element as this is the last one.
                                    v_object_to_set := pkg_os_object_io.fn_object_bv_path_get(1, 1, loop_ptp.object_id, v_build_path);
                                    v_ctr := v_ctr + 1; -- increment so we don't go endless.

                                  end if;

                                end loop; -- stop looping bv table

                                    if v_object_to_set is null then
                                      --setting with ptp
                                      pkg_os_object_io.sp_object_bv_set(1,1, loop_ptp.object_id, v_business_variable_id, pkg_os_exp.fn_evaluate_expression(1, 1, loop_ptp.object_id, bv_to_set_p1.rule_expression));

                                      --dbms_output.put_line('PTP ' || v_object_to_set || ' ' || v_business_variable_id);

                                    else

                                      pkg_os_object_io.sp_object_bv_set(1,1, v_object_to_set, v_business_variable_id, pkg_os_exp.fn_evaluate_expression(1, 1, loop_ptp.object_id, bv_to_set_p1.rule_expression));

                                      --dbms_output.put_line('NonPTP ' || v_object_to_set || ' ' || v_business_variable_id);

                                    end if;

                                   v_ctr          := 1;    -- reset counter
                                   v_build_path   := null; -- reset build path
                                   v_object_to_set := null;-- reset object

                              end loop;
                          commit; -- commit this rule bv set.
                          end;
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_PTP_RH_Ren_Ind, 1); -- set RH ren on PTP
                        -- end running init rules on ptp primary
                        -- render docs
                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Primary Docs Creation? ' || loop_subs.policyisexcessind);
                        io_action_outcome_id := pkg_os_constant.gOutcome_OK;
                        pkg_os_action_document.sp_render_documents( in_session_id, transaction_id, in_object_cache, io_message_list, 1135525, loop_ptp.object_id, 2276904, pkg_os_constant.gObjState_Alive, io_action_outcome_id);
                        pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1, 1135525, 1135525, loop_ptp.object_id, 2, in_object_cache); -- run post rules action id 1135525 for render

                        -- action id = 1135525 , native command = OSDocumentRenderDocuments
                        pkg_cap_document_generation_cs.create_uw_worksheet_job(in_session_id, transaction_id, loop_ptp.object_id, 1135625);
                        commit;
                        dbms_lock.sleep(20); -- wait 20 seconds.
                        pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1, 1135825, 1135825, loop_ptp.object_id, 1, in_object_cache); -- render docs change parent
                        io_action_outcome_id := pkg_os_constant.gOutcome_OK;
                       -- action id = 1135625 , native command = create_uw_worksheet_job
                       -- Update Risk Evaluation Parent to Shared Attribute Object = action ID 1135825
                        -- end render docs

                            -- begin set coverage parts final step
                            v_coverage_id := pkg_os_object_io.fn_object_bv_path_get(in_session_id, transaction_id, loop_ptp.object_id, '21761001.31916625'); -- Get Coverage ID to set coverage parts!
                            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Coverage ID is: ' || v_coverage_id);

                            pkg_os_object_io.sp_object_bv_set(1, 1, v_coverage_id, 33187825, null); -- CPL 092 for non monoline set to null

                            pkg_os_token.sp_tokenize_string(REGEXP_REPLACE(loop_subs.product, ' ', ''), ';', v_cvg_token_table);

                            if v_cvg_token_table.count > 0 then
                              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'We have cvg tokens ');

                                for ci in v_cvg_token_table.first..v_cvg_token_table.last loop
                                  v_cvg_token_element := v_cvg_token_table(ci);

                                    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Current Token is: ' || v_cvg_token_element);

                                      if v_cvg_token_element = 'CPL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting CPL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, gCvgCPL, 1); -- Set cvg = yes

                                          if v_cvg_token_table.count = 1 then
                                            pkg_os_object_io.sp_object_bv_set(1, 1, v_coverage_id, 33187825, 1); -- CPL 092 for monoline set to 1
                                          end if;


                                      elsif v_cvg_token_element = 'PL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting PL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, gCvgPL, 1); -- Set cvg = yes

                                      elsif v_cvg_token_element = 'CGL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting CGL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, gCvgCGL, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element = 'TPL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting TPL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, gCvgTPL, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element = 'PPL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting PPL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, gCvgPPL, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element in ('SSPL', 'SSLLA', 'SSLLB', 'SSLLC', 'SSLLD', 'SSLL') then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting EIL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, gCvgEIL, 1); -- Set cvg = yes


                                      else
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Unrecognized Token ' || v_cvg_token_element);

                                      end if;

                                end loop;


                            end if;
                            v_cvg_token_table.delete;

                        -- end set coverage parts final step

                      elsif v_indicator = 2 then -- excess
                        -- conditional duplicate account
                        select max(policynbr) into v_policy_nbr from submission_imports where accountname = loop_subs.accountname and ptp_id is null and instr(policynbr, 'E', 2) = 4;
                        -- conditional duplicate account
                        -- exception handle
                        begin
                        select * into r_sub_imp from cap_st.submission_imports where accountname = loop_subs.accountname and policynbr = v_policy_nbr and rownum = 1; --instr(policynbr, 'E', 2) = 4; -- get excess record

                          -- structure date variable to use below expiration based on whether primary or excess
                          v_dateStructFullEff := regexp_replace(r_sub_imp.policyeffdate, '/', ''); -- rexexp removes alpha character from excel datasource
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Eff Date structure no alpha is: ' || v_dateStructFullEff);

                          v_dateStructEff := substr(v_dateStructFullEff, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, ' Eff Date structure year is: ' || v_dateStructEff);

                          v_dateStructEff := v_dateStructEff || substr(v_dateStructFullEff, 1, 2); -- pull the month and appended to year position 1, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Eff Date structure year + mth is: ' || v_dateStructEff);

                          v_dateStructEff := v_dateStructEff || substr(v_dateStructFullEff, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Eff Date structure year + mth + day is: ' || v_dateStructEff);

                          -- structure date variable to use below effective based on primary or excess.
                          v_dateStructFullExp := regexp_replace(r_sub_imp.policyexpdate, '/', ''); -- rexexp removes alpha character from excel datasource
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Exp Date structure no alpha is: ' || v_dateStructFullExp);

                          v_dateStructExp := substr(v_dateStructFullExp, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, ' Exp Date structure year is: ' || v_dateStructExp);

                          v_dateStructExp := v_dateStructExp || substr(v_dateStructFullExp, 1, 2); -- pull the month and appended to year position 1, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Exp Date structure year + mth is: ' || v_dateStructExp);

                          v_dateStructExp := v_dateStructExp || substr(v_dateStructFullExp, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                          pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Exp Date structure year + mth + day is: ' || v_dateStructExp);

                          update cap_st.submission_imports set ptp_id = loop_ptp.object_id where accountname = loop_subs.accountname and policynbr = v_policy_nbr;-- and instr(policynbr, 'E', 2) = 4;-- set the excess ptp
                          update cap_st.submission_imports set submission_id = v_new_submission_id where accountname = loop_subs.accountname and policynbr = v_policy_nbr;-- and instr(policynbr, 'E', 2) = 4;-- set the excess submission id

                          commit;
                        exception when others then continue;
                        end;
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_ptp_PrimaryEx, cl_ptp_excess); -- Set excess lookup on PTP
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_renPolNumIfNotDrg, r_sub_imp.policynbr); -- Set Renewal Policy Number IF NOT Dragon Renewal on PTP
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_polEffDate, to_char(to_date(v_dateStructExp, 'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS')); -- datasource exp is effective dragon
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_polExpDate, to_char(add_months(to_date(v_dateStructExp, 'YYYYMMDDHH24MISS'), 12),'YYYYMMDDHH24MISS')); -- set exp, datasource exp + 12
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_Vertical, c_vertical); -- Set Vertical = 6125 Specialty Casualty
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_Segment, c_segment); -- Set Segment = 2125 Environmental
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, gBrokerRate, (r_sub_imp.commissionbrokerrate*100)); -- Broker Rate on PTP
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_premium, r_sub_imp.total_premium); -- Premium on PTP Policy Premium Renewal - Pro-Rata Coverage Total
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_premium_before_tria, r_sub_imp.total_premium); -- Policy Premium before TRIA Premium Adjustment -- fix patch 1
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, gUnderwritingCom, pkg_os_long_string.fn_create_long_string(in_session_id,transaction_id,r_sub_imp.rating_notes)); -- Underwriting Comments Memo -- set long string!
                        --pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_PTP_RH_Ren_Ind, 1); -- Rock Hill Renewal Indicator gets set by action rule
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, gRateMod, c_rh_ind_val); -- Rate Modification

                        if v_underwriter_id > 0 then -- UW
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xReference_UW, v_underwriter_id); -- Set xRef UW id to UW Id which was found (PTP)
                        end if;

                        if v_uassistant_id > 0 then --UA
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xReference_UA, v_uassistant_id); -- Set xRef UW Assistant id to UW Id which was found (PTP)
                        end if; --UA

                        if v_prod_agency_id > 0 then
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xRef_Prod_Ag, v_prod_agency_id); -- PTP
                        end if;

                        if v_producer_id > 0 then
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xRef_Producer, v_producer_id); -- PTP
                        else
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_xRef_Producer, v_new_producer_id); -- PTP
                        end if;

                        r_sub_imp := null; -- clear the record

                              -- run init rules on ptp excess

                              declare -- get all of the bvs for this object type and product

                                  cursor init_rules_e1 is
                                  select * from cap_st.action_rule a where a.rule_context_object_type_id = 2276904 and a.insurance_line_id = 15125 and a.action_id = 953525; -- New submission init rules, excess ins line, object type ptp

                                      v_bv_table			          pkg_os_token.t_string_table;
                                      v_bv_path				          varchar2(200);
                                      v_business_variable_id	  business_variable.business_variable_id%type;

                                      v_count_bv_table          number := 0;
                                      v_loop_times              number := 0;
                                      v_build_path              varchar2(500);
                                      v_ctr                     number := 1;
                                      v_object_to_set           number := null;

                                begin

                                  for bv_to_set_e1 in init_rules_e1 loop

                                      v_bv_path := pkg_os_token.fn_strip_suffix(bv_to_set_e1.action_rule_bv_path, pkg_os_constant.bv_path_segmentor); -- strip off the object-type information.

                                      pkg_os_token.sp_tokenize_string(v_bv_path, '.', v_bv_table);
                                      v_business_variable_id := v_bv_table(v_bv_table.last);

                                      v_count_bv_table := v_bv_table.count; -- how many in token table?

                                      v_loop_times := v_count_bv_table - 1; -- we want to iterate through our loop less than total, since last token member is BV, also only iterate if a path exists.

                                      for i in v_bv_table.first..v_bv_table.last loop -- loop bv table

                                        if v_loop_times > v_ctr then

                                            v_build_path :=  v_build_path || v_bv_table(i) || '.' ; -- concat the string with . and the token element
                                            v_ctr := v_ctr + 1; -- increment so we don't go endless.

                                        elsif v_loop_times = v_ctr then

                                            v_build_path :=  v_build_path || v_bv_table(i) ; -- concat the string without . and the token element as this is the last one.
                                            v_object_to_set := pkg_os_object_io.fn_object_bv_path_get(1, 1, loop_ptp.object_id, v_build_path);
                                            v_ctr := v_ctr + 1; -- increment so we don't go endless.

                                        end if;

                                      end loop; -- stop looping bv table

                                        if v_object_to_set is null then
                                          --setting with ptp
                                          pkg_os_object_io.sp_object_bv_set(1,1, loop_ptp.object_id, v_business_variable_id, pkg_os_exp.fn_evaluate_expression(1, 1, loop_ptp.object_id, bv_to_set_e1.rule_expression));

                                          --dbms_output.put_line('PTP ' || v_object_to_set || ' ' || v_business_variable_id);

                                        else

                                          pkg_os_object_io.sp_object_bv_set(1,1, v_object_to_set, v_business_variable_id, pkg_os_exp.fn_evaluate_expression(1, 1, loop_ptp.object_id, bv_to_set_e1.rule_expression));

                                          --dbms_output.put_line('NonPTP ' || v_object_to_set || ' ' || v_business_variable_id);

                                        end if;

                                           v_ctr          := 1;    -- reset counter
                                           v_build_path   := null; -- reset build path
                                           v_object_to_set := null;-- reset object

                                    end loop;
                                commit; -- commit this rule bv set.
                                end;
                              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, loop_ptp.object_id, g_PTP_RH_Ren_Ind, 1); -- set RH ren on PTP
                              -- end running init rules on ptp excess
                              if loop_subs.policyisexcessind = 'Y' then
                              -- render docs for standalone Excess, if we have Tied Prim/Ex we do not want to render duplicate docs. Thus excess renders only when standalone.

                                -- render docs
                                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Excess Docs Creation? ' || loop_subs.policyisexcessind);
                                io_action_outcome_id := pkg_os_constant.gOutcome_OK;
                                pkg_os_action_document.sp_render_documents( in_session_id, transaction_id, in_object_cache, io_message_list, 1135525, loop_ptp.object_id, 2276904, pkg_os_constant.gObjState_Alive, io_action_outcome_id);
                                pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1, 1135525, 1135525, loop_ptp.object_id, 2, in_object_cache); -- run post rules action id 1135525 for render

                                -- action id = 1135525 , native command = OSDocumentRenderDocuments
                                pkg_cap_document_generation_cs.create_uw_worksheet_job(in_session_id, transaction_id, loop_ptp.object_id, 1135625);
                                commit;
                                dbms_lock.sleep(20); -- wait 20 seconds.
                                pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1, 1135825, 1135825, loop_ptp.object_id, 1, in_object_cache); -- render docs change parent
                                io_action_outcome_id := pkg_os_constant.gOutcome_OK;
                               -- action id = 1135625 , native command = create_uw_worksheet_job
                               -- Update Risk Evaluation Parent to Shared Attribute Object = action ID 1135825
                                -- end render docs

                              end if;
                           -- begin set coverage parts final step
                            v_coverage_id := pkg_os_object_io.fn_object_bv_path_get(in_session_id, transaction_id, loop_ptp.object_id, '21761001.31916625'); -- Get Coverage ID to set coverage parts!
                            pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Coverage ID is: ' || v_coverage_id);

                            pkg_os_object_io.sp_object_bv_set(1, 1, v_coverage_id, 33187825, null); -- CPL 092 for non monoline set to null

                            pkg_os_token.sp_tokenize_string(REGEXP_REPLACE(loop_subs.product, ' ', ''), ';', v_cvg_token_table);

                            if v_cvg_token_table.count > 0 then
                              pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'We have cvg tokens ');

                                for ci in v_cvg_token_table.first..v_cvg_token_table.last loop
                                  v_cvg_token_element := v_cvg_token_table(ci);

                                    pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Current Token is: ' || v_cvg_token_element);

                                      if v_cvg_token_element = 'CPL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting CPL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, 33723925, 1); -- Set cvg = yes

                                          if v_cvg_token_table.count = 1 then
                                            pkg_os_object_io.sp_object_bv_set(1, 1, v_coverage_id, 33187825, 1); -- CPL 092 for monoline set to 1
                                          end if;


                                      elsif v_cvg_token_element = 'PL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting PL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, 33733725, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element = 'CGL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting CGL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, 33728625, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element = 'TPL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting TPL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, 33731625, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element = 'PPL' then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting PPL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, 33867525, 1); -- Set cvg = yes


                                      elsif v_cvg_token_element in ('SSPL', 'SSLLA', 'SSLLB', 'SSLLC', 'SSLLD', 'SSLL') then
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Setting EIL ' || v_cvg_token_element);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_coverage_id, 33790625, 1); -- Set cvg = yes


                                      else
                                        pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Unrecognized Token ' || v_cvg_token_element);

                                      end if;

                                end loop;


                            end if;
                            v_cvg_token_table.delete;

                        -- end set coverage parts final step

                      else

                        dbms_output.put_line('Indicator Unknown');

                      end if;


                end loop; -- stop looping ptps

              -- Native command 2 submission_underwrite action id = 974625
                pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Running Native Command: submission_underwrite');
                  io_action_outcome_id := pkg_os_constant.gOutcome_OK;
                  pkg_cap_underwrite_rules.submission_underwrite(in_session_id, transaction_id, v_new_submission_id, io_action_outcome_id);

              end;

              -- PTP logic ends

              -- delete all lists!
              l_submission_entity.delete;
              l_submission_address.delete;
              l_dragon_user_address.delete;
              commit;
--xform
pkg_os_xformer.sp_object_transform( in_session_id, transaction_id,  in_object_cache, io_message_list,962225, v_new_submission_id, 5, io_action_outcome_id); -- run submission and account xforms
--xform
-- start updating datamarts per creation!
pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Update New Submission dragon submission' || v_new_submission_id);
     pkg_os_datamart.sp_datamart_update_row -- update submission datamart after creation / bv sets are done for a specific object!
     (
          in_session_id,
          transaction_id,
          v_new_submission_id,
          v_datamart_tf
     );


pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Update New producer, dragon_user' || v_new_producer_id);
    pkg_os_datamart.sp_datamart_update_row -- update producer  in Dragon user datamart after creation / bv sets are done for a specific object!
     (
          in_session_id,
          transaction_id,
          v_new_producer_id,
          v_datamart_tf
     );

pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Update New customer, dragon_customer' || v_customer);
    pkg_os_datamart.sp_datamart_update_row -- update customer  in Dragon user datamart after creation / bv sets are done for a specific object!
     (
          in_session_id,
          transaction_id,
          v_customer,
          v_datamart_tf
     );

commit;
--dbms_output.put_line('setting import_policynbr to .. ' || loop_subs.policynbr || ' for subid ' || v_new_submission_id);
--dbms_output.put_line('setting import_policynbr to .. ' || excess_primary_polnum || ' for subid ' || v_new_submission_id);
update cap_st.dragon_submission set import_policynbr = excess_primary_polnum where submission_id = v_new_submission_id;  -- set to policy number we chose as unique. Rather than iteration as duplicates could cause issue with update of correct pol #
commit;

end if; -- end if found submission
end; -- end main exception handle
end if; -- end if checking whether to create for same account
end loop; -- end import submissions loop.

l_submission_entity.delete;
l_submission_address.delete;
l_dragon_user_address.delete;

end sp_import_forte;
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   %NAME
--        sp_import_uwwb
--
--   %USAGE
--        Not specified.
--
--   %ALGORITHM
--        This procedure creates Submission / PTP / Customer objects and sets data from workbench xml sheet that is imported into Datasource ST table:
--        Datasource is: CAP_ST.FEED_FROM_UWWB
--
--   %PARAM                -

--
-----------------------------------------------------------------------------------------------------------------------------------------------------
procedure sp_import_uwwb

as

v_datamart_tf                           char   := 'F';
in_session_id                           object.object_id%type := 0;
v_renewal_uw_id                         object.object_id%type := pkg_os_object_io.fn_object_bv_get(3551, transaction_id, 1218, 34004625); -- _Reference_Default Renewal User
c_procedure_name                        constant       system_log.program_name%type                := pkg_name||'sp_import_uwwb';
io_action_outcome_id                    outcome.outcome_id%type;
v_token_table                           pkg_os_token.t_string_table;
v_doc_token_table                       pkg_os_token.t_string_table; --testingveldoc

type t_rec is                           table of number index by binary_integer;
v_rec                                   t_rec;


-- xforms
in_object_cache                         pkg_os_object_cache.t_object_cache; -- just declare
io_message_list                         pkg_os_message.t_message_list; -- just declare
-- xforms

--constants
c_renewal_pending                       constant LOOKUP_LIST_VALUE.LOOKUP_ENUM%type          := 54425; -- constant list value enum for object state list id 50170 Object State List

-- variable lists
l_submission_entity                     pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_submission_address                    pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_cascade_types                         pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
l_cascade_types_fi                      pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;

--Submission variables
v_new_submission_id                     object.object_id%type;
sub_trx_id                              object.object_id%type;

-- customer variables
v_customer                              object.object_id%type;
v_existing_customer                     number;
jurisdiction                            varchar2(10);
account_name                            varchar2(500);
address_one                             varchar2(500);
city                                    varchar2(500);
--zipcode                                 number;
zipcode                                 varchar2(100);

-- shared attributes variables
v_sub_shared_att                        object.object_id%type;
v_sub_shared_att_existing               object.object_id%type;

-- UW / producer variables
v_underwriter_id                        object.object_id%type;

-- main variables
v_ptp_id                                object.object_id%type;
v_policy_commercial                     object.object_id%type;
v_policy_tech                           object.object_id%type;

--email
run_count                               number;
start_date                              varchar2(100);
end_date                                varchar2(100);
--email

--auto exclude --test10
autox_attach_list               pkg_os_object.t_object_list := pkg_os_object.gnull_object_list; --test10
ax_code                        object_bv_value.business_variable_value%type; --test10
--auto exclude --test10
log_text                        varchar2(1000) := 'Renewal Imported from UWWB';
-- main cursor
cursor
feed is select distinct(feed_policy_number) from feed_from_uwwb where imported is null and picked_up is null; --where feed_policy_number = 'SGC0001558'; this has TMC and TMC excess for test purposes.

-- cursors for mapping
cursor
bv_mapped_to_set (in_object_type_id in number, xRef in number,in_policy_number in varchar2) is select * from feed_from_uwwb where object_type_id in (in_object_type_id, xRef) and feed_policy_number = in_policy_number order by variable_id asc;

-- cursor to match coverages for product selection, used only once for a specific case.
cursor
bv_mapped_to_set2 (in_object_type_id in number, xRef in number,in_policy_number in varchar2) is select * from feed_from_uwwb where object_type_id in (in_object_type_id, xRef) and feed_policy_number = in_policy_number order by variable_id asc;


-- cursor for customer creation
cursor create_customer (in_node_type in varchar2, in_policy_number in varchar2) is
select * from feed_from_uwwb where variable_id in (210419, 29238814, 29325214, 29326314, 29327414) and node_type = in_node_type and feed_policy_number = in_policy_number  order by variable_id asc;

-- types to set
cursor cascade_type (in_policy_number in varchar2) is 
select distinct(object_type_id) from feed_from_uwwb where feed_policy_number = in_policy_number and object_type_id not in (-1);

-- types to set
cursor cascade_type_fi (in_policy_number in varchar2) is -- only run for fillin bvs
select object_type_id, variable_value, fillin_type, endtnum from feed_from_uwwb where node_type = 'fill_in' and feed_policy_number = in_policy_number and object_type_id not in (-1);

-- forms
cursor form_to_create (in_policy_number in varchar2) is
select translated_form_code, fillin_type from feed_from_uwwb where feed_policy_number = in_policy_number and fillin_type is not null and node_type = 'form'; --test9

-- 1-M object creation and setting bvs non forms
cursor set_multiplicity (in_policy_number in varchar2) is
select ffw.feed_policy_number, ffw.object_type_id, ffw.variable_id, ffw.variable_value, ffw.node_type, ffw.imported, ffw.picked_up, ojr.related_object_type_id 
    from feed_from_uwwb ffw
    inner join object_relationship ojr on ojr.object_type_id = ffw.object_type_id
    where ojr.object_relationship_type_id = 1 and case when regexp_like(variable_value, ';') then 'T' else 'F' end = 'T' and ffw.node_type not in ('form', 'fill_in') and ffw.feed_policy_number = in_policy_number; --test5 remove "fill in" as well as form.

-- 1-M object creation and setting bvs non forms
cursor set_multiplicity_oneval (in_policy_number in varchar2) is
select ffw.feed_policy_number, ffw.object_type_id, ffw.variable_id, ffw.variable_value, ffw.node_type, ffw.imported, ffw.picked_up, ojr.related_object_type_id 
    from feed_from_uwwb ffw
    inner join object_relationship ojr on ojr.object_type_id = ffw.object_type_id
    where ojr.object_relationship_type_id = 1 and ffw.node_type not in ('form', 'fill_in') and ffw.feed_policy_number = in_policy_number; --test5 remove "fill in" as well as form.

-- non UI driven forms, and none fill in.
cursor forms_no_input (in_policy_number in varchar2) is
select * from feed_from_uwwb where node_type = 'form' and node_name = 'formnums' and fillin_type is null 
and feed_policy_number = in_policy_number and translated_form_code not in ('E-PL-7012 (04/17)', 'E-PL-7013 (04/17)', 'E-PL-7014 (04/17)', 'E-PL-7015 (04/17)', 'E-PL-7000 (07/17)');

--test10 auto exclude forms requirement
cursor auto_exclude (in_policy_number in varchar2) is
select * from feed_from_uwwb where node_name = 'exclude_form_code' 
and feed_policy_number = in_policy_number;
--test10 auto exclude forms requirement

begin

    io_action_outcome_id := pkg_os_constant.gOutcome_OK;
    pkg_cap_renewal.create_session(in_session_id, v_renewal_uw_id);
    v_ptp_id := null;
    
    -- Creation logic start
    
    --for email
    for i in feed loop
        run_count := feed%ROWCOUNT;
    end loop;
    start_date := TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
    --for email
--dbms_output.put_line('session is: ' || in_session_id);
pkg_os_object_io.sp_object_bv_set(in_session_id, 777, 1218, 34245425, 50576345116); -- Set PL renewal UW user on xRef.

for feeds in feed loop -- start looping the feed
update cap_st.feed_from_uwwb set picked_up = 'T' where picked_up is null;

v_existing_customer   := 0; -- reset existing customer
        
        -- existing customer logic start
        for customer in create_customer ('account', feeds.feed_policy_number) loop -- check if customer needs to be created or not.
          
          if customer.variable_id = 210419 then
            jurisdiction := pkg_os_lookup.fn_lookup_list_text_get(5050401,customer.variable_value);
          elsif customer.variable_id = 29238814 then
            account_name :=  customer.variable_value;
          elsif customer.variable_id = 29325214 then
            address_one := customer.variable_value;
          elsif customer.variable_id = 29326314 then
            city := customer.variable_value;
          elsif customer.variable_id = 29327414 then
            zipcode := lpad(customer.variable_value, 5, 0);
          end if;
        
        end loop; 
        v_existing_customer := fn_get_customer_id(jurisdiction, account_name, address_one, city, zipcode);
        -- existing customer logic end
        
        -- create submission start
        if v_existing_customer = 0 or v_existing_customer is null then
          pkg_os_object.sp_object_create(in_session_id, transaction_id, gObjTypeSubmission, null, v_new_submission_id); -- create new submission without customer parent
        else 
          pkg_os_object.sp_object_create(in_session_id, transaction_id, gObjTypeSubmission, v_existing_customer, v_new_submission_id); -- create new submission as child of existing account.
        end if;
        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, g_ObjectState, c_renewal_pending); -- Renewal Pending
        -- create submission end
        
        -- set variables for submission start
          for bvs in bv_mapped_to_set (gObjTypeSubmission, 0, feeds.feed_policy_number) loop
              
              if pkg_os_bv.fn_bv_path_data_type_get(bvs.variable_id) = 13 then -- if the variable is a "Set type" then we need to append.
                
                if pkg_os_object_io.fn_object_bv_get(in_session_id, transaction_id, v_new_submission_id, bvs.variable_id) is null then -- variable is initially null set it.
                
                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, bvs.variable_id, bvs.variable_value); -- Set primary
                  
                else -- append to existing.
                
                  pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, bvs.variable_id, 
                    concat(concat(pkg_os_object_io.fn_object_bv_get(in_session_id, transaction_id, v_new_submission_id, bvs.variable_id),','), bvs.variable_value)); 
                    
                end if;
                
              else -- else just set it.
                --dbms_output.put_line('setting id: ' || bvs.variable_id);
                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, bvs.variable_id, bvs.variable_value); -- Set primary
                
              end if; -- end check for variable data type.
                          
          end loop;
          
          sub_trx_id := pkg_os_object_io.fn_object_bv_path_get(in_session_id, transaction_id, v_new_submission_id, '31915725');
          
          
          -- submission entity logic starts here
              -- get all submission entity objects and set variables from datasource
              pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_new_submission_id, gObjTypeSubmissionEntity, l_submission_entity);
                      if l_submission_entity.count > 0 then
                      
                        for bvs in bv_mapped_to_set (2303814, 0, feeds.feed_policy_number) loop -- 2303814 = Entity Object Type, which SubmissionEntity is TypeOf.
                        
                            for ise in l_submission_entity.first..l_submission_entity.last loop -- set variables to each submission entity that may exist.
                                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_entity(ise), bvs.variable_id, bvs.variable_value);
                            end loop;
                            
                        end loop;
                        
                      end if;
          -- submission entity logic ends here
          
          -- submission address logic starts here
          pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_new_submission_id, gObjTypeSubAdd, l_submission_address);
              if l_submission_address.count > 0 then
              
                for bvs in bv_mapped_to_set (405, 0, feeds.feed_policy_number) loop -- 2303814 = Address Object Type, which SubmissionAddress is TypeOf.
                
                    for isa in l_submission_address.first..l_submission_address.last loop -- set variables to each submission address that may exist.
                        
                        if bvs.variable_id = 29327414 then -- zip padding
                          --pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), bvs.variable_id, lpad(bvs.variable_value, 5, 0));
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), bvs.variable_id, bvs.variable_value);
                        elsif bvs.variable_id = 210423 then -- USA passed from workbench, just set to 1 for dragon setting.
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), bvs.variable_id, 1); -- Enum 1 for US, if other countires are needed, function needed.
                        else
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_submission_address(isa), bvs.variable_id, bvs.variable_value);
                        end if;
                        
                        -- for jurisdiction to work, set state to new submission generic references.
                        if bvs.variable_id = 210419 then
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 21759701, bvs.variable_value); -- Generic Object - List - Jurisdiction
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 29482546, bvs.variable_value); -- Submission - List - Submission Product Jurisdiction
                        end if;
                        
                        -- end for jurisdiction to work, set state to new submission generic references.
                                  
                        -- set the primary and mailing address to the last submission address object.
                         pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 29366714, l_submission_address(isa)); -- Primary Address ref
                         pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 29366814, l_submission_address(isa)); -- Mailing Address ref
          
                    end loop;
                    
                end loop;
      
              end if;
        
          -- submission address logic ends here
          
        -- set variables for submission end
        
        --base native commands start
          pkg_cap_submission.clear_submission(in_session_id, transaction_id, v_new_submission_id);
          
          if v_existing_customer = 0 or v_existing_customer is null then
            pkg_base_submission.sp_subm_create_new_customer(in_session_id, transaction_id, 943625, v_new_submission_id, io_action_outcome_id); -- 943625 is action id, 22 is outcome last param we pass default in 22
          end if;
          
          v_customer := pkg_os_object_io.fn_object_bv_path_get(in_session_id, transaction_id, v_new_submission_id, '29253114');
          -- add the customer to our binary index table we need it
          v_rec(12) := v_customer;
          
          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_customer, 210153, 75); -- Set Customer to activ
        -- base native commands end
        
        -- shared attributes logic start
            v_sub_shared_att_existing := null;
            v_sub_shared_att          := null;
            
            begin -- exception handle no data found
            
              select object_id into v_sub_shared_att_existing from cap_st.object where parent_object_id = v_customer and object_type_id = 3173825;
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 31908925, v_sub_shared_att_existing); -- Set existing shared attribute on sub
              
              exception when others then -- update to catch all instead of no_data_found
              pkg_os_object.sp_object_create(in_session_id, transaction_id, 3173825, v_customer, v_sub_shared_att);
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_submission_id, 31908925, v_sub_shared_att);
              
            end; -- end exception handle no data found.
            
            for bvs in bv_mapped_to_set (3172525, 0, feeds.feed_policy_number) loop -- sub shared att is type of shared attributes, use 3172525 for initial sets.
              pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, nvl(v_sub_shared_att_existing, v_sub_shared_att), bvs.variable_id, bvs.variable_value);
            end loop;
            
        -- shared attributes logic end
        
        -- create policy objects
          pkg_cap_submission.create_policy_objects(in_session_id, transaction_id, v_new_submission_id); -- action ID for this native command create_policy_objects is 943925
        -- end create policy objects
        --start set partner assignment
          pkg_cap_partner.set_partner_assignments(in_session_id, transaction_id, sub_trx_id);
        --end set partner assignment
        
        -- customer ptp logic start
                  declare
                  
                  v_dateStructFull                     varchar2(100); -- full variable will be used to structure a date in proper format
                  v_dateStructAppended                 varchar2(100); -- appended variable will be used to structure a date in proper format
                  
                  in_object_cache                      pkg_os_object_cache.t_object_cache; 
                  
                      -- create cursor for ptps xRefAccountInfo
                      cursor cust_get_ptp is
                      select * from cap_st.object where parent_object_id in (select object_id from cap_st.object where parent_object_id = v_new_submission_id  -- Submission
                        and object_type_id = 3173725 --- sub trx
                        ) and object_type_id = 2276904; -- PTP

                    begin
                      for custo_ptp in cust_get_ptp loop -- loop customer ptp objects start
                      
 
                        v_ptp_id := custo_ptp.object_id;
                        v_policy_commercial := pkg_os_object_io.fn_object_bv_path_get(1,1, v_ptp_id, '21761001'); -- get policy commercial
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, g_xRef_AccountInfo, v_customer); -- Set Customer to Account info ref on PTP.
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, 31925325, 9); -- Set ptp trx type = 9
                         
                          for bvs in bv_mapped_to_set (3174425, 3174425, feeds.feed_policy_number) loop -- set variables that are PTP specific
                            if bvs.variable_id = 31916925 and bvs.variable_value = 20625 then --MPL
                            
                                for sec_bv in  bv_mapped_to_set2 (24, 24, feeds.feed_policy_number) loop -- determine paper type.
                                    if sec_bv.variable_id = 31924625 and sec_bv.variable_value = 1 then
                                        pkg_os_object_io.sp_object_bv_set(in_session_id, 10001, custo_ptp.object_id, 211636, 98725); -- MPL CIC Admitted
                                        --dbms_output.put_line('set adm');
                                    elsif sec_bv.variable_id = 31924625 and sec_bv.variable_value = 2 then
                                        pkg_os_object_io.sp_object_bv_set(in_session_id, 10001, custo_ptp.object_id, 211636, 98625); -- MPL CSIC Surplus Lines
                                        --dbms_output.put_line('set surp');
                                    end if;
                                end loop;
                                
                            end if;
                          end loop; -- this is specific to choosing the right paper type and product at the same time for everything else to run accordingly.
                          
                          for bvs in bv_mapped_to_set (2276904, 0, feeds.feed_policy_number) loop -- set variables that are PTP specific
                            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, bvs.variable_id, bvs.variable_value);
                          end loop;
                          
                          for bvs in bv_mapped_to_set (24, 0, feeds.feed_policy_number) loop -- set variables that are Policy specific since PTP object is type of policy. loop start
                          
                              if pkg_os_bv.fn_bv_path_data_type_get(bvs.variable_id) = 6 then -- if the variable is a "Date type" then we need to structure it.
                              
                                v_dateStructFull := regexp_replace(bvs.variable_value, '/', ''); -- rexexp removes alpha character from datasource
                                v_dateStructAppended := substr(v_dateStructFull, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                                v_dateStructAppended := v_dateStructAppended || substr(v_dateStructFull, 1, 2); -- pull the month and appended to year position 1, 2 characters
                                v_dateStructAppended := v_dateStructAppended || substr(v_dateStructFull, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters

                                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, bvs.variable_id, to_char(to_date(v_dateStructAppended, 'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS')); -- set all variables of date type accordingly.
                                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, g_polEffDate, pkg_os_object_io.fn_object_bv_get(in_session_id, transaction_id, custo_ptp.object_id, 33660825)); -- 504 not in data source, hardcode
                                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, g_polExpDate, to_char(add_months(to_date(v_dateStructAppended, 'YYYYMMDDHH24MISS'), 12),'YYYYMMDDHH24MISS')); -- add 12 making it one year term
                                
                                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, 32291525, pkg_os_exp.fn_evaluate_expression(in_session_id, transaction_id, v_new_submission_id, 9600025)); -- evaluate target date, hardcode.
                               
                               elsif pkg_os_bv.fn_bv_path_data_type_get(bvs.variable_id) = 11 then -- if the variable is a "Memo 400" then we need to create the long string..
                                    pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, bvs.variable_id, pkg_os_long_string.fn_create_long_string(in_session_id, transaction_id, bvs.variable_value)); -- Long string!.
                               else -- not date, set to without format.
                                pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, custo_ptp.object_id, bvs.variable_id, bvs.variable_value);
                               
                               end if; 
                               
                          end loop; -- looping policy image variables end
                          
                      pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 953525, 953525, custo_ptp.object_id, 1, in_object_cache); 
                      pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 953525, 953525, custo_ptp.object_id, 2, in_object_cache);          
                      end loop; -- loop customer ptp objects end
                    end;
        -- customer ptp logic end
        
        -- cascade set variables start
          declare
                  c_dateStructFull                     varchar2(100); -- full variable will be used to structure a date in proper format
                  c_dateStructAppended                 varchar2(100); -- appended variable will be used to structure a date in proper format
                  
                  v_current_ptp                       object.object_id%type;
                  in_object_cache                     pkg_os_object_cache.t_object_cache; -- just declare
                  v_product                           number;
          begin
            for cbv in cascade_type (feeds.feed_policy_number) loop
              -- generate a list of objects per type!
              pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_customer, cbv.object_type_id, l_cascade_types);
              if l_cascade_types.count > 0 then
              
                for cas in bv_mapped_to_set (cbv.object_type_id, 0, feeds.feed_policy_number) loop
                    for i in l_cascade_types.first..l_cascade_types.last loop

                        -- formatting for various types of bv check start
                        if pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 6 then -- if the variable is a "Date type" then we need to structure it.
                            c_dateStructFull := regexp_replace(cas.variable_value, '/', ''); -- rexexp removes alpha character from datasource
                            c_dateStructAppended := substr(c_dateStructFull, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                            c_dateStructAppended := c_dateStructAppended || substr(c_dateStructFull, 1, 2); -- pull the month and appended to year position 1, 2 characters
                            c_dateStructAppended := c_dateStructAppended || substr(c_dateStructFull, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types(i), cas.variable_id, to_char(to_date(c_dateStructAppended, 'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS'));
                            
                        elsif  cas.variable_id = 29327414 then -- zip padding
                          --pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types(i), cas.variable_id, lpad(cas.variable_value, 5, 0));
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types(i), cas.variable_id, cas.variable_value);
                          
                        elsif cas.variable_id = 210423 then -- USA passed from workbench, just set to 1 for dragon setting.
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types(i), cas.variable_id, 1); -- Enum 1 for US, if other countires are needed, function needed.
                        
                        elsif pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 13 then -- if the variable is a "Set type" then we need to append.
                          continue;
                          
                        elsif pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 11 then -- if the variable is a "Memo 400" then we need to create the long string..
                           pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types(i), cas.variable_id, pkg_os_long_string.fn_create_long_string(in_session_id, transaction_id, cas.variable_value)); -- Long string!.
                        
                        elsif cas.node_name = 'ratingbasis_projected' then -- exposure 
                          pkg_os_object_io.sp_object_bv_path_set(1, 133, v_ptp_id, '31908925.31907425.31905125', cas.variable_value);
                        
                        elsif cas.node_name = 'ratingbasis_previous' then-- exposure information
                          pkg_os_object_io.sp_object_bv_path_set(1, 133, v_ptp_id, '31908925.31907125.31905125', cas.variable_value);
                        
                        elsif cas.node_name = 'hazardgroup_projected' then-- exposure information
                          pkg_os_object_io.sp_object_bv_path_set(1, 133, v_ptp_id, '31908925.31907425.32115525', cas.variable_value);
                            --dbms_output.put_line('Setting projected to: ' || cas.variable_value);
                            
                        elsif cas.node_name = 'hazardgroup_previous' then-- exposure information
                          pkg_os_object_io.sp_object_bv_path_set(1, 133, v_ptp_id, '31908925.31907125.32115525', cas.variable_value);
                            --dbms_output.put_line('Setting previous to: ' || cas.variable_value);
                            
                        else -- just set!
                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types(i), cas.variable_id, cas.variable_value);
                          
                        end if; 
                        -- formatting for various types of bv check end
                        
                    end loop; -- loop the object which is type of..
                end loop; -- loop variables to set
                
              end if; -- only loop if we have a count per type
              
              l_cascade_types.delete; -- clear per iteration of cascade type.
              
            end loop; -- loop cursor of types to pull objects into
            
            v_current_ptp := pkg_os_object_io.fn_object_bv_get(1,1, v_new_submission_id, 32175025);
            v_product := pkg_os_object_io.fn_object_bv_get(1,1, v_current_ptp, 26806004);
            --dbms_output.put_line('product is: ' || v_product);
            if v_product = 20525 then --assoc node
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1090325, 1090325, v_current_ptp, 1, in_object_cache); -- account pg pre
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1152325, 1152325, v_current_ptp, 1, in_object_cache); -- assoc node pre
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1090325, 1090325, v_current_ptp, 2, in_object_cache); -- account pg post
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1152325, 1152325, v_current_ptp, 2, in_object_cache); -- assoc node post
            elsif v_product = 20725 then -- tmc node
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1090325, 1090325, v_current_ptp, 1, in_object_cache); -- account pg pre
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1152425, 1152425, v_current_ptp, 1, in_object_cache); -- tmc node pre
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1090325, 1090325, v_current_ptp, 2, in_object_cache); -- account pg post
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1152425, 1152425, v_current_ptp, 2, in_object_cache); -- tmc node post
            elsif v_product = 20625 then -- MPL node
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1090325, 1090325, v_current_ptp, 1, in_object_cache); -- account pg pre
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1161025, 1161025, v_current_ptp, 1, in_object_cache); -- tmc node pre
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1090325, 1090325, v_current_ptp, 2, in_object_cache); -- account pg post
              pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1161025, 1161025, v_current_ptp, 2, in_object_cache); -- tmc node post
            end if;
          end;
        -- cascade set variables end
        
        -- forms work start
            
            -- no input forms
            declare
                no_input_form_object           object.object_id%type;
                no_input_doc_template_id       document_template.document_template_id%type;
                in_object_cache                pkg_os_object_cache.t_object_cache; -- just declare
                auto_attach_list               pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
                auto_code                      object_bv_value.business_variable_value%type;
                
                create_yn                      varchar2(10);
            begin
                -- set endorsements up, for the non created endorsements
                
                pkg_cap_endorsements.add_endorsements(in_session_id, 7012, v_ptp_id);
                pkg_cap_endorsements.set_optional_endorsement_value(in_session_id, 7012, v_ptp_id);
                pkg_cap_endorsements.add_endorsement_tree_node(in_session_id, 7012, v_ptp_id, in_object_cache);
                commit;
                
                pkg_os_object_search.sp_object_children_of_type_get(in_session_id, 7012, v_ptp_id, 325, auto_attach_list); -- get list of auto attach


                -- set endorsements up, for the non created endorsements
                for nis in forms_no_input (feeds.feed_policy_number) loop
                    no_input_form_object := null;
                    create_yn := 'T';
                    
                    if auto_attach_list.count > 0 then -- do we have auto attach records?
                    for autos in auto_attach_list.first..auto_attach_list.last loop 
                        auto_code := pkg_os_object_io.fn_object_bv_get(in_session_id, 7012, auto_attach_list(autos), 26640907); -- get code.
                        
                            if auto_code = nis.translated_form_code then
                                create_yn := 'F';
                                exit;
                            end if; -- if the codes don't match create.
                            
                    end loop; -- end check for auto attach.
                    
                    end if; -- do we have auto attach records?
                    
                    if create_yn = 'T' then
                    
                                        pkg_os_object.sp_object_create(1,700, 325, v_ptp_id, no_input_form_object);
                            
                                        begin -- exception handle for docid
                                          select distinct(document_template_id) into no_input_doc_template_id from document_template where document_template_code = nis.translated_form_code;
                                          --dbms_output.put_line('doc id is : ' || doc_template_id || ' object id is ' || form_object || ' parent being ' || v_ptp_id);
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, 216, no_input_form_object, 26658801, no_input_doc_template_id); -- Document Template - Document Rendering Template ID
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, 216, no_input_form_object, 212276, no_input_doc_template_id); -- Text_100 - Document Rendering Template
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, 216, no_input_form_object, 31817646, no_input_doc_template_id); -- Optional Document List
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, 216, no_input_form_object, 31817746, 1); -- Is optional?
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, 216, no_input_form_object, 200818, 7902); -- Content = Endorsement
                                          pkg_os_object_io.sp_object_bv_set(in_session_id, 216, no_input_form_object, 26551907, 1); -- Doc included?
                                          commit;
                            
                                        exception when others then
                                          continue;
                                        end; --- end exception handle for docid 
                    end if;
                    
                end loop;
            auto_attach_list.delete;

            end;
            
            -- no input forms
        
        declare
        
          form_object           object.object_id%type;
          form_object_create    object.object_id%type;
          doc_template_id       document_template.document_template_id%type;
          in_object_cache       pkg_os_object_cache.t_object_cache; -- just declare
          doc_code              object_bv_value.business_variable_value%type;
          
          fi_auto_attach_list               pkg_os_object.t_object_list := pkg_os_object.gnull_object_list;
          fi_auto_code                      object_bv_value.business_variable_value%type;
          fi_create_yn                      varchar2(10);
          v_retro_ctr            number := 0; --test5

        begin
                -- set endorsements up, for the non created endorsements
                
                pkg_cap_endorsements.add_endorsements(in_session_id, 7012, v_ptp_id);
                pkg_cap_endorsements.set_optional_endorsement_value(in_session_id, 7012, v_ptp_id);
                pkg_cap_endorsements.add_endorsement_tree_node(in_session_id, 7012, v_ptp_id, in_object_cache);
                commit;
                -- set endorsements up, for the non created endorsements
                
                pkg_os_object_search.sp_object_children_of_type_get(in_session_id, 7012, v_ptp_id, 325, fi_auto_attach_list);
        
        for forms in form_to_create (feeds.feed_policy_number) loop
        
            form_object := null; 
            fi_create_yn := 'T';
            
            if fi_auto_attach_list.count > 0 then
            
                for fi_autos in fi_auto_attach_list.first..fi_auto_attach_list.last loop
                fi_auto_code := pkg_os_object_io.fn_object_bv_get(in_session_id,7012, fi_auto_attach_list(fi_autos), 26640907);
                    if fi_auto_code = forms.fillin_type then
                    --dbms_output.put_line('count is: ' || fi_auto_code);
                        fi_create_yn := 'F';
                        form_object := fi_auto_attach_list(fi_autos);
                        exit;
                    end if;                
                end loop;
            
            end if; -- do we have auto attach records?
            
            if fi_create_yn = 'T' then -- code does not exist, create it.
                   pkg_os_object.sp_object_create(1,701, 325, v_ptp_id, form_object);
              
                    
                    begin -- exception handle for docid
                      select distinct(document_template_id) into doc_template_id from document_template where document_template_code = forms.fillin_type;
                      --dbms_output.put_line('doc id is : ' || doc_template_id || ' object id is ' || form_object || ' parent being ' || v_ptp_id);
                      pkg_os_object_io.sp_object_bv_set(in_session_id, 216, form_object, 26658801, doc_template_id); -- Document Template - Document Rendering Template ID
                      pkg_os_object_io.sp_object_bv_set(in_session_id, 216, form_object, 212276, doc_template_id); -- Text_100 - Document Rendering Template
                      pkg_os_object_io.sp_object_bv_set(in_session_id, 216, form_object, 31817646, doc_template_id); -- Optional Document List
                      pkg_os_object_io.sp_object_bv_set(in_session_id, 216, form_object, 31817746, 1); -- Is optional?
                      pkg_os_object_io.sp_object_bv_set(in_session_id, 216, form_object, 200818, 7902); -- Content = Endorsement
                      pkg_os_object_io.sp_object_bv_set(in_session_id, 216, form_object, 26551907, 1); -- Doc included?
                      commit;
        
                    exception when others then
                      continue;
                    end; --- end exception handle for docid 
                    
              end if;
                -- set endorsements up, for the non created endorsements
                
                pkg_cap_endorsements.add_endorsements(in_session_id, 7012, v_ptp_id);
                pkg_cap_endorsements.set_optional_endorsement_value(in_session_id, 7012, v_ptp_id);
                pkg_cap_endorsements.add_endorsement_tree_node(in_session_id, 7012, v_ptp_id, in_object_cache);
                
                -- set endorsements up, for the non created endorsements
              
            pkg_os_wf_rules.sp_initialization_rules(in_session_id, 1216, 1004425, 1004425, v_ptp_id, 2, in_object_cache); -- run post rules!
            
              doc_code := pkg_os_object_io.fn_object_bv_get(1,1, form_object, 26640907);
              if forms.fillin_type = 'E-AM-3003 (11/17)' then --test5
                v_retro_ctr := v_retro_ctr + 1;
              end if;

                        -- cascade set variables start for fill ins
                              declare
                                      c_dateStructFull                     varchar2(100); -- full variable will be used to structure a date in proper format
                                      c_dateStructAppended                 varchar2(100); -- appended variable will be used to structure a date in proper format

                                      --v_current_ptp                       object.object_id%type;
                                      in_object_cache                     pkg_os_object_cache.t_object_cache; -- just declare
                                      v_product                           number;
                                      v_create_children_count             number;
                                      v_iterator                          number := 1;
                                      v_created_fillin_child              object.object_id%type;

                              begin
                              v_iterator                           := 1; -- reset per form.
                              for cbv in cascade_type_fi (feeds.feed_policy_number) loop

                                --retroactive only!!
                                if cbv.object_type_id = 3209725 and doc_code = cbv.fillin_type and v_retro_ctr = 1 then -- Retro Date Amendatory endorsement

                                    v_create_children_count := REGEXP_COUNT(cbv.variable_value, ';'); -- count of existing, subtract 1

                                    while v_iterator <= v_create_children_count loop

                                        pkg_os_object.sp_object_create(in_session_id, transaction_id, cbv.object_type_id, v_ptp_id, v_created_fillin_child);
                                        commit;
                                    v_iterator := v_iterator + 1;
                                    end loop;
                                --retroactive only!!
                                -- non retroactive only!!
                                 pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_ptp_id, cbv.object_type_id, l_cascade_types_fi);

                                elsif cbv.object_type_id not in (325, 3209725) and doc_code = cbv.fillin_type then -- ObjectDocument or Retro Date Amendatory endorsement
                                
                                    if cbv.object_type_id = 3179425 then --test5 removes PolicyChangeEnd(3179425)
                                        v_create_children_count := 0;
                                    else
                                        v_create_children_count := REGEXP_COUNT(cbv.variable_value, ';'); -- count of existing, subtract 1
                                    end if;--test5 removes PolicyChangeEnd(3179425)

                                    --v_create_children_count := REGEXP_COUNT(cbv.variable_value, ';'); -- count of existing, subtract 1

                                    while v_iterator <= v_create_children_count loop

                                        pkg_os_object.sp_object_create(in_session_id, transaction_id, cbv.object_type_id, form_object, v_created_fillin_child);
                                        commit;
                                    v_iterator := v_iterator + 1;
                                    end loop;

                                pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, form_object, cbv.object_type_id, l_cascade_types_fi);    
                                end if;
                                -- non retroactive only!!

                                  -- generate a list of objects per type!
                                  --pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_customer, cbv.object_type_id, l_cascade_types_fi);
                                  if l_cascade_types_fi.count > 0 then

                                    for cas in bv_mapped_to_set (cbv.object_type_id, 0, feeds.feed_policy_number) loop
                                        for i in l_cascade_types_fi.first..l_cascade_types_fi.last loop
                                            --dbms_output.put_line(feeds.feed_policy_number);
                                            --multiplicity forms start
                                            if REGEXP_COUNT(cas.variable_value, ';') >= 1 and cbv.object_type_id != 3179425 then -- do we have multiplicity? --test6 PolicyChangeEnd(3179425) is not 1-M..
                                                pkg_os_token.sp_tokenize_string(cas.variable_value, ';', v_doc_token_table); -- put our variable value into a token table.

                                                if v_doc_token_table.count > 0 then -- only if any exist, loop

                                                    for doctocs in v_doc_token_table.first..v_doc_token_table.last loop
                                                        begin
                                                        -- formatting for various types of bv check start
                                                        if pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 6 then -- if the variable is a "Date type" then we need to structure it.
                                                            c_dateStructFull := regexp_replace(v_doc_token_table(i), '/', ''); -- rexexp removes alpha character from datasource
                                                            c_dateStructAppended := substr(c_dateStructFull, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                                                            c_dateStructAppended := c_dateStructAppended || substr(c_dateStructFull, 1, 2); -- pull the month and appended to year position 1, 2 characters
                                                            c_dateStructAppended := c_dateStructAppended || substr(c_dateStructFull, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                                                            pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, to_char(to_date(c_dateStructAppended, 'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS'));

                                                        elsif  cas.variable_id = 29327414 then -- zip padding
                                                         -- pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, lpad(v_doc_token_table(i), 5, 0));
                                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, v_doc_token_table(i));

                                                        elsif cas.variable_id = 210423 then -- USA passed from workbench, just set to 1 for dragon setting.
                                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, 1); -- Enum 1 for US, if other countires are needed, function needed.

                                                        elsif pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 13 then -- if the variable is a "Set type" then we need to append.
                                                          continue;

                                                        elsif pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 11 then -- if the variable is a "Memo 400" then we need to create the long string..

                                                           pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, pkg_os_long_string.fn_create_long_string(in_session_id, transaction_id, v_doc_token_table(i))); -- Long string!.

                                                        else -- just set!
                                                          pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, v_doc_token_table(i));

                                                        end if; 
                                                        -- formatting for various types of bv check end
                                                        exception when others then
                                                        continue;
                                                        end;
                                                    end loop;

                                                end if;
                                                v_doc_token_table.delete;
                                            else -- else we do not have multiplicity.
                                            --multiplicity forms end
                                            
                                              if ((doc_code = cas.fillin_type) and (cbv.endtnum = cas.endtnum) and (pkg_os_object_io.fn_object_bv_get(1,1, l_cascade_types_fi(i), cas.variable_id) is null) and (cas.imported is null)) then -- if the code we created matches current iteration fillin type.. 
                                               
                                                    -- formatting for various types of bv check start
                                                    if pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 6 then -- if the variable is a "Date type" then we need to structure it.
                                                        c_dateStructFull := regexp_replace(cas.variable_value, '/', ''); -- rexexp removes alpha character from datasource
                                                        c_dateStructAppended := substr(c_dateStructFull, 5, 4); -- pull the year only as regexp formatted without alpha and build date string backwards position 5, 4 characters
                                                        c_dateStructAppended := c_dateStructAppended || substr(c_dateStructFull, 1, 2); -- pull the month and appended to year position 1, 2 characters
                                                        c_dateStructAppended := c_dateStructAppended || substr(c_dateStructFull, 3, 2); -- pull the day and appended to year + mth position 3, 2 characters
                                                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, to_char(to_date(c_dateStructAppended, 'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS'));

                                                    elsif  cas.variable_id = 29327414 then -- zip padding
                                                     -- pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, lpad(cas.variable_value, 5, 0));
                                                      pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, cas.variable_value);

                                                    elsif cas.variable_id = 210423 then -- USA passed from workbench, just set to 1 for dragon setting.
                                                      pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, 1); -- Enum 1 for US, if other countires are needed, function needed.

                                                    elsif pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 13 then -- if the variable is a "Set type" then we need to append.
                                                      continue;

                                                    elsif pkg_os_bv.fn_bv_path_data_type_get(cas.variable_id) = 11 then -- if the variable is a "Memo 400" then we need to create the long string..
                                                       pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, pkg_os_long_string.fn_create_long_string(in_session_id, transaction_id, cas.variable_value)); -- Long string!.

                                                    else -- just set!
                                                      pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, l_cascade_types_fi(i), cas.variable_id, cas.variable_value);

                                                    end if;
                                                    -- formatting for various types of bv check end
                                                    --test7
                                                    update feed_from_uwwb set imported = 'T' where feed_policy_number = feeds.feed_policy_number and variable_value = cas.variable_value and variable_id = cas.variable_id and fillin_type = cas.fillin_type and endtnum = cas.endtnum; --test9 adding and fillin_type = cas.fillin_type 
                                                    commit;
                                                    --test7
                                               end if;  -- end if the code we created matches current iteration fillin type..
                                            
                                            end if; -- end check for multiplicity.


                                        end loop; -- loop the object which is type of..
                                    end loop; -- loop variables to set

                                  end if; -- only loop if we have a count per type

                                  l_cascade_types_fi.delete; -- clear per iteration of cascade type.

                                end loop; -- loop cursor of types to pull objects into

                              end;
                            -- cascade set variables start for fill ins
        
        end loop;
        fi_auto_attach_list.delete;   
                
        end;
        -- forms work end
        
        -- cascade multiplicity start
        declare
        
        v_new_object_id                     object.object_id%type;
        
        begin
        
        for multis1 in set_multiplicity_oneval (feeds.feed_policy_number) loop
        v_new_object_id := null;
        
            if multis1.variable_id in (32976225, 32208725, 32976125) and INSTR(multis1.variable_value, ';') = 0 then --app dba, appka, oniselection no multi
            
                  if v_rec.exists(12) and multis1.related_object_type_id = 12 then -- if a customer object exists, and the object type to create a child of is customer
                  -- create the object type of interest of type which the variable belongs to, as child of object_relationship mapping object that we set in binary table.
                            
                    pkg_os_object.sp_object_create(in_session_id, transaction_id, multis1.object_type_id, v_rec(12), v_new_object_id);
                          
                    -- set the current value from our token table, to the newly created object.
                    pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_object_id, multis1.variable_id, multis1.variable_value);
                        
                    end if;
            end if;
        end loop;
        
        for multis in set_multiplicity (feeds.feed_policy_number) loop
        v_new_object_id := null;
            pkg_os_token.sp_tokenize_string(multis.variable_value, ';', v_token_table); -- put our variable value into a token table.
            
            if v_token_table.count > 0 then -- only if it exists, run
            
                for i in v_token_table.first..v_token_table.last loop -- loop each record
               
                    if v_rec.exists(12) and multis.related_object_type_id = 12 then -- if a customer object exists, and the object type to create a child of is customer
                        -- create the object type of interest of type which the variable belongs to, as child of object_relationship mapping object that we set in binary table.
                        
                        pkg_os_object.sp_object_create(in_session_id, transaction_id, multis.object_type_id, v_rec(12), v_new_object_id);
                      
                        -- set the current value from our token table, to the newly created object.
                        pkg_os_object_io.sp_object_bv_set(in_session_id, transaction_id, v_new_object_id, multis.variable_id, v_token_table(i));
                    
                    end if;
                
                end loop;

            
            end if;
        
        v_token_table.delete;    
        end loop;
        end;
        -- cascade multiplicity end
        
        --clear extra form
            pkg_cap_endorsements.add_endorsements(in_session_id, 703, v_ptp_id);
            pkg_cap_endorsements.set_optional_endorsement_value(in_session_id, 703, v_ptp_id);
            pkg_cap_endorsements.add_endorsement_tree_node(in_session_id, 703, v_ptp_id, in_object_cache);
            
        declare
        
            retro_code                              object_bv_value.business_variable_value%type;
            retro_list_clr1                         pkg_os_object.t_object_list := pkg_os_object.gnull_object_list; -- we need to clear one retro
            counter                                 number := 0;
        begin
        pkg_os_object_search.sp_object_children_of_type_get(in_session_id, transaction_id, v_ptp_id, 325, retro_list_clr1);
        if retro_list_clr1.count > 0 then
        
            for retros in retro_list_clr1.first..retro_list_clr1.last loop
                retro_code := pkg_os_object_io.fn_object_bv_get(1,1, retro_list_clr1(retros), 26640907);
                
                if retro_code = 'E-AM-3003-I (11/17)' then
                    counter := counter + 1;
                end if;
                
                if counter > 1 and retro_code = 'E-AM-3003-I (11/17)' then
                    pkg_os_object.sp_object_delete( in_session_id, transaction_id,  retro_list_clr1(retros), retro_list_clr1(retros), 325); -- clear retros extra.
                    --dbms_output.put_line('deleting.. ' || retro_list_clr1(retros) || ' code being ' || retro_code);
                    commit;
                end if;
                
            end loop;
            
        end if;
        retro_list_clr1.delete;
        end;
        --clear extra form
        
        --test10 auto exclude
                pkg_os_object_search.sp_object_children_of_type_get(in_session_id, 888, v_ptp_id, 325, autox_attach_list); -- test10
                for axs in auto_exclude (feeds.feed_policy_number) loop
                
                    for autoxs in autox_attach_list.first..autox_attach_list.last loop 
                        ax_code := pkg_os_object_io.fn_object_bv_get(in_session_id, 888, autox_attach_list(autoxs), 26640907); -- get code.
                        
                            if ax_code = axs.translated_form_code then
                                pkg_os_object_io.sp_object_bv_set(in_session_id, 888, autox_attach_list(autoxs), 26551907, 2); -- Doc excluded.
                                pkg_os_object_io.sp_object_bv_set(in_session_id, 888, autox_attach_list(autoxs), 32285625, 2); -- Override attach.
                                
                                commit;
                            end if; -- if the codes exclude.
                            
                    end loop; -- end check for auto attach.
                    
                end loop;
                autox_attach_list.delete;
         --test10 auto exclude
        
        --hardcode
        v_policy_tech := pkg_os_object_io.fn_object_bv_path_get(in_session_id, 4, v_ptp_id, '21761001.32114325'); -- get policy tech id.
            pkg_os_object_io.sp_object_bv_set(in_session_id, 4, v_policy_tech, 34182325, 1000000); -- Bodily Injury and Property Damage Coverage - Req GL Amt
        --hardcode
        
-- clear lists no memory leak!
l_submission_entity.delete;
l_submission_address.delete;
l_cascade_types.delete;
l_cascade_types_fi.delete;

-- end clear lists no memory leak!

-- start updating datamarts per creation!
--dbms_output.put_line('updating drg_sub id: ' || feeds.feed_policy_number);
pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Update New Submission dragon submission' || v_new_submission_id);
     pkg_os_datamart.sp_datamart_update_row -- update submission datamart after creation / bv sets are done for a specific object!
     (
          in_session_id,
          transaction_id,
          v_new_submission_id,
          v_datamart_tf
   );
pkg_os_logging.sp_log(in_session_id, transaction_id, c_procedure_name, 'Update New customer, dragon_customer' || v_customer);
    pkg_os_datamart.sp_datamart_update_row -- update customer  in Dragon user datamart after creation / bv sets are done for a specific object!
     (
          in_session_id,
          transaction_id,
          v_customer,
          v_datamart_tf
     );
-- IT Stuff start       
update cap_st.dragon_submission set import_policynbr = feeds.feed_policy_number where submission_id = v_new_submission_id;  -- set to policy number we chose as unique. Rather than iteration as duplicates could cause issue with update of correct pol #
        if v_new_submission_id is not null then
            update cap_st.feed_from_uwwb set imported = 'T' where feed_policy_number = feeds.feed_policy_number;  -- set indicator on feed_from_uwwb to imported 'T' so we do not pull it again.
        end if;
update cap_st.feed_from_uwwb set ptp_id = v_ptp_id where feed_policy_number = feeds.feed_policy_number;
update cap_st.feed_from_uwwb set subid = v_new_submission_id where feed_policy_number = feeds.feed_policy_number;


commit;

-- xforms!
pkg_os_xformer.sp_object_transform( in_session_id, transaction_id,  in_object_cache, io_message_list, 962225, v_new_submission_id, 5, io_action_outcome_id);
-- xforms !
          
end loop;-- end looping the feed.
end_date := TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
-- Creation logic end

    --email
    declare
    
    from_email async_job_property.async_job_property_value%type;
    to_email   async_job_property.async_job_property_value%type;
    email_cc   async_job_property.async_job_property_value%type;
    email_host async_job_property.async_job_property_value%type;
    email_port async_job_property.async_job_property_value%type;
    
    cursor
    email_config is
    select * from async_job_property where async_job_definition_id = 23725;
    
    begin
    
    for configs in email_config loop
        if configs.async_job_property_id = 25425 then
          from_email :=  configs.async_job_property_value;
        elsif configs.async_job_property_id = 25525 then
         to_email := configs.async_job_property_value;  
        elsif configs.async_job_property_id = 25625 then
          email_host := configs.async_job_property_value;
        elsif configs.async_job_property_id = 25725 then
          email_port := configs.async_job_property_value;
        elsif configs.async_job_property_id = 25825 then
          email_cc := configs.async_job_property_value;
        end if;
    end loop;
    
    if run_count > 0 then

        workbench_send_mail(to_email, email_cc, from_email, email_host, email_port, 
            start_date, end_date, run_count);
            -- to, cc,cc,cc,cc (comma delimit), from, host, port default 25, start, end, count.
    end if;
    end;
    --email
    pkg_cap_generic.create_activity_log(in_session_id, transaction_id, v_new_submission_id, nvl(log_text,'Renewal Imported from UWWB'));
-- IT Stuff end
end sp_import_uwwb;


end pkg_cap_import;