create or replace package body pkg_feed_from_uwwb as

  procedure sp_translate_by_merge

  is
    
  begin
    
    -- begin logic for object type and name of bv
    merge into feed_from_uwwb ffuwwb
    using business_variable bv
    on (ffuwwb.variable_id = bv.business_variable_id)
    when matched then
    update set ffuwwb.object_type_id = bv.container_object_type_id, ffuwwb.dragon_var_name = bv.business_variable_name;
    commit; --test5
    
    update feed_from_uwwb
    set object_type_id = -1 where object_type_id is null;
    commit; --test5
    -- end logic for object type of bv
    
    -- logic to update workbench coverage part boolean to enumeration
    update feed_from_uwwb
    set variable_value = '1' where variable_value = 'TRUE';
    commit; --test5
    -- end logic to update workbench coverage part boolean to enumeration
    
    -- begin logic for forms translation
    
    merge into feed_from_uwwb ffuwwb
    using uwwb_form_mappings ufm
    on (ffuwwb.variable_value = ufm.uwwb_form_code)
    when matched then
    update set ffuwwb.translated_form_code = nvl(ufm.dragon_form_code, 'N/A');
    commit; --test5
      -- form drop flags
        -- issuance only indicator
        merge into feed_from_uwwb ffuwwb
        using uwwb_form_mappings ufm
        on (ffuwwb.variable_value = ufm.uwwb_form_code)
        when matched then
        update set ffuwwb.form_issue_only = nvl(ufm.issuance_only_indicator, 'N/A');
        commit; --test5
        -- drop at renewal indicator
        merge into feed_from_uwwb ffuwwb
        using uwwb_form_mappings ufm
        on (ffuwwb.variable_value = ufm.uwwb_form_code)
        when matched then
        update set ffuwwb.drop_at_renewal = nvl(ufm.drop_at_renewal_indicator, 'N/A');
        commit; --test5
      -- form drop flags
    
    -- end logic for forms translation

    -- start fillin translation
        update feed_from_uwwb ffuwwb set ffuwwb.fillin_type = (select ufm.dragon_form_code from uwwb_form_mappings ufm where ffuwwb.fillin_type = ufm.uwwb_form_code);
        commit; --test5
    -- end fillin translation
    
           -- begin class code logic
         
          declare
          cursor
          feed is select distinct(feed_policy_number) from feed_from_uwwb where imported is null and picked_up is null;
          
          cursor primary_class_codes (in_policy_number in varchar2) is
          select * from feed_from_uwwb
          where node_type in ('basic_info') and node_name in ('primaryclass', 'primaryclassdescription', 'secondaryclass', 'secondaryclassdescription', 'naicscode', 'product') 
          and feed_policy_number = in_policy_number;
          
          v_prim_class        varchar2(500);
          v_prim_class_desc   varchar2(500);
          v_sec_class         varchar2(500);
          v_sec_class_desc    varchar2(500);
          v_naics             varchar2(500);
          v_product           varchar2(500);
          
          v_primary_enum      number;
          v_prim_feed_num     varchar2(500);
          begin
          
          for feeds in feed loop
          
          v_prim_class := null; 
          v_prim_class_desc := null; 
          v_sec_class := null; 
          v_sec_class_desc := null; 
          v_naics := null; 
          v_product := null; 
          v_primary_enum := null;
          v_prim_feed_num := null;
          -- test4
              for loop_code in primary_class_codes (feeds.feed_policy_number) loop
              
                  if loop_code.node_name = 'primaryclass' then
                      v_prim_class := loop_code.variable_value;
                  elsif loop_code.node_name = 'primaryclassdescription' then
                      v_prim_class_desc := loop_code.variable_value;
                  elsif loop_code.node_name = 'secondaryclass' then
                      v_sec_class := loop_code.variable_value;
                  elsif loop_code.node_name = 'secondaryclassdescription' then
                      v_sec_class_desc := loop_code.variable_value;
                  elsif loop_code.node_name = 'naicscode' then
                      v_naics := loop_code.variable_value;
                  elsif loop_code.node_name = 'product' then
                      v_product := loop_code.variable_value;
                      v_prim_feed_num := loop_code.feed_policy_number;
                  end if;
                  
               end loop;    -- end loop codes   
                  
                  /*logic for primary class enum*/
                  ---------------------------------
                  begin
                  
                  select class_codes_primary_tech_id into v_primary_enum from class_codes_primary_tech
                  where description = v_prim_class_desc and short_code = v_prim_class and insurance_line_id = v_product;
                  
                  if v_primary_enum is not null then 
                    update feed_from_uwwb
                        set primary_class_enum = v_primary_enum, variable_value = v_primary_enum
                      where 
                        node_name in ('primaryclass', 'primaryclassdescription') and feed_policy_number = v_prim_feed_num;
                        
                    commit;
                  end if;
                  
                  exception when others then dbms_output.put_line('No data found for class code.');
                  end;
                  
            end loop;   -- end loop submissions
              
      
          
          commit;
          end;
    
          declare
          
          cursor
          feed is select distinct(feed_policy_number) from feed_from_uwwb where imported is null and picked_up is null;
          
          cursor secondary_class_codes (in_policy_number in varchar2) is
          select * from feed_from_uwwb
          where node_type in ('basic_info') and node_name in ('primaryclass', 'primaryclassdescription', 'secondaryclass', 'secondaryclassdescription', 'naicscode', 'product') and 
          feed_policy_number = in_policy_number;
          
          v_prim_class        varchar2(500);
          v_prim_class_enum   number;
          v_sec_class         varchar2(500);
          v_sec_class_desc    varchar2(500);
          v_naics             varchar2(500);
          v_product           varchar2(500);
          
          v_secondary_enum    number;
          v_sec_feed_num      varchar2(500);
          
          begin
          
          for feeds in feed loop
          
          v_prim_class        := null;
          v_prim_class_enum   := null;
          v_sec_class         := null;
          v_sec_class_desc    := null;
          v_naics             := null;
          v_product           := null;
          
          v_secondary_enum    := null;
          v_sec_feed_num      := null;
          --test4
              for loop_code in secondary_class_codes (feeds.feed_policy_number) loop
              
                  if loop_code.node_name = 'primaryclass' then
                      v_prim_class := loop_code.variable_value;
                  elsif loop_code.node_name = 'primaryclassdescription' then
                      v_prim_class_enum := loop_code.primary_class_enum;
                  elsif loop_code.node_name = 'secondaryclass' then
                      v_sec_class := loop_code.variable_value;
                  elsif loop_code.node_name = 'secondaryclassdescription' then
                      v_sec_class_desc := loop_code.variable_value;
                  elsif loop_code.node_name = 'naicscode' then
                      v_naics := loop_code.variable_value;
                  elsif loop_code.node_name = 'product' then
                      v_product := loop_code.variable_value;
                      v_sec_feed_num := loop_code.feed_policy_number;
                  end if;
               end loop; -- end loop codes
                  
                  /*logic for secondary class enum*/
                  ---------------------------------
                  begin
                  
                  select class_codes_secondary_tech_id into v_secondary_enum from CLASS_CODES_SECONDARY_TECH
                  where description = v_sec_class_desc and naics_code = v_naics and primary_class_code_id = v_prim_class_enum and short_description = v_sec_class;
                  
                  if v_secondary_enum is not null then 
                    update feed_from_uwwb
                        set sec_class_enum = v_secondary_enum, variable_value = v_secondary_enum
                      where 
                        node_name in ('secondaryclass', 'secondaryclassdescription') and feed_policy_number = v_sec_feed_num;

                     commit;
                  end if;
                  
                  exception when others then dbms_output.put_line('No data found for class code.');

                  end;
              
          end loop; -- end loop submissions
          
           
          commit;     
          end; 
          -- end secondary class code
    
          -- end class code logic
    
    -- set enumerations general
    declare
    
      cursor gen_enum is
      select variable_id, variable_value, feed_policy_number from feed_from_uwwb where variable_id 
      not in (31916925, 31917125, 31919625, 27354305, 31925325, 26509507, 210423, 32115525, 34184825, 32231025, 32231125) and pkg_os_bv.fn_bv_path_data_type_get(variable_id) = 1 and (feed_policy_number in
      (select distinct(feed_policy_number) from feed_from_uwwb where imported is null)); -- lists only!
        -- omit product, segment, vertical, submissionincludedlines, trx type, carrier these are handled in xml, Hazard Group. 210423 country handled in pl sql. 
        -- 34184825 is Retro Inceptions, exclude as Workbench passes us delimited enums handled by the creation process.
        -- 32231025, 32231125 class codes.
      v_enum    number;
      v_lookup_text     lookup_list_value.lookup_text%type; --test13
    begin
        
        for ges in gen_enum loop
          v_lookup_text := null; --test13
          v_lookup_text := ges.variable_value; --test13
          begin -- exception handle
          
          if regexp_like(ges.variable_value, '^[^a-zA-Z]*$') then
              select lookup_enum into v_enum from lookup_list_value where lookup_enum = ges.variable_value and lookup_list_id in (
                select lookup_list_id from business_variable where business_variable_id = ges.variable_id and logical_data_type_id = 1); -- run this, only for lists.
          else
              select lookup_enum into v_enum from lookup_list_value where (lookup_text = ges.variable_value or lookup_text_short = ges.variable_value) and lookup_list_id in ( -- added lookup text short, some use txt some short.
                select lookup_list_id from business_variable where business_variable_id = ges.variable_id and logical_data_type_id = 1); -- run this, only for lists. 
          end if;
            
            update feed_from_uwwb set variable_value = v_enum where variable_id = ges.variable_id and feed_policy_number =  ges.feed_policy_number and variable_value = v_lookup_text; --test13 and variable_value = v_lookup_text;
            commit; --test13
          exception when others then
            update feed_from_uwwb set variable_value = null
              where variable_id = ges.variable_id and feed_policy_number =  ges.feed_policy_number;
            continue; 
          end; -- exception handle
        
        end loop;
        
    end; 
    
    -- end set enumerations general
    
      -- set xReferences
      declare
      
          cursor xRef is
          select variable_id, variable_value, object_type_id, feed_policy_number from feed_from_uwwb where object_type_id = 0 and feed_policy_number in(
          select distinct(feed_policy_number) from feed_from_uwwb where imported is null)
          order by feed_policy_number, variable_id desc;
          
          cursor producer_info (in_policy_number in varchar2) is 
          select * from feed_from_uwwb where node_type in ('producer', 'basic_info') and feed_policy_number = in_policy_number;
          
          v_prod_agency_id      object.object_id%type;
          producer_contact_new  object.object_id%type;
          contact_name_first    varchar2(500);
          contact_name_last     varchar2(500);
          contact_email         varchar2(500);
          phone                 object_bv_value.business_variable_value%type;
          vertical              number;
          segment_num           number;    
          v_datamart_tf         char   := 'F';
          
      begin
          
          for x in xRef loop -- loop xReference
          
          contact_name_first := null;
          contact_name_last := null;
          contact_email := null;
          phone := null;
          vertical := null;
          segment_num := null;
          producer_contact_new := null;
          
            if x.variable_id = 26590807  then -- underwriter translation
              update feed_from_uwwb set variable_value = pkg_cap_import.fn_get_user_id(x.variable_value, 1, 118) where variable_id = 26590807 and feed_policy_number = x.feed_policy_number;
              
            elsif x.variable_id = 26590907 then -- producing agency translation via co3 code
              update feed_from_uwwb set variable_value = pkg_cap_import.fn_get_prod_agency_id(1, x.variable_value) where variable_id = 26590907 and feed_policy_number = x.feed_policy_number;
              v_prod_agency_id := pkg_cap_import.fn_get_prod_agency_id(1, x.variable_value); 
              
             --test5
              if v_prod_agency_id = 0 then -- no prod agency, purge the email.
                update feed_from_uwwb set variable_value = null where variable_id = 26590707 and feed_policy_number = x.feed_policy_number;
              end if;
              --test5
              
            elsif x.variable_id = 26590707 and (pkg_cap_import.fn_get_user_id_by_email(x.variable_value , v_prod_agency_id) != 0 or pkg_cap_import.fn_get_user_id_by_email(x.variable_value , v_prod_agency_id) is not null) then -- translate the producer contact with name an email.
              update feed_from_uwwb set variable_value = pkg_cap_import.fn_get_user_id_by_email(x.variable_value , v_prod_agency_id) where variable_id = 26590707 and feed_policy_number = x.feed_policy_number;
              
            elsif x.variable_id = 26590707 and v_prod_agency_id != 0 and (pkg_cap_import.fn_get_user_id_by_email(x.variable_value , v_prod_agency_id) = 0 or pkg_cap_import.fn_get_user_id_by_email(x.variable_value , v_prod_agency_id) is null) then
              
              pkg_os_object.sp_object_create(1, 309903, 309, v_prod_agency_id, producer_contact_new); -- create producer set to existing producing agency above
              v_prod_agency_id := null; --test5
              for pi in producer_info (x.feed_policy_number) loop -- loop datasource for producer data
              
                    if pi.node_name = 'brokercontactname' then
                      contact_name_first := substr(pi.variable_value, 0, instr(pi.variable_value, ' ') - 1 );
                      contact_name_last := substr(pi.variable_value, instr(pi.variable_value, ' ') + 1, length(pi.variable_value));
                    elsif pi.node_name = 'brokercontactemail' then
                      contact_email := pi.variable_value;
                    elsif pi.node_name = 'brokerphone' then
                      phone := pi.variable_value;
                    elsif pi.variable_id = 31917125 then -- segment
                      segment_num := pi.variable_value;
                    elsif pi.variable_id = 31919625 then-- vertical
                      vertical := pi.variable_value;
                    end if;
                    
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 210153, 75); -- object state alive
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 21689501, 1); -- actor type = producer
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 5122, contact_name_first); -- first name
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 5124, contact_name_last); -- last name
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 211461, contact_email); -- email
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 211932, phone); -- phone number
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 31902625, vertical); -- vertical
                  pkg_os_object_io.sp_object_bv_set(1, 1, producer_contact_new, 31919325, segment_num); -- segment
              
              end loop; -- loop pi producer info for producer data
              
              update feed_from_uwwb set variable_value = producer_contact_new where variable_id = 26590707 and feed_policy_number = x.feed_policy_number;
              pkg_os_datamart.sp_datamart_update_row(1, 1, producer_contact_new, v_datamart_tf); -- update producer  in Dragon user datamart after creation / bv sets are done for a specific object!
              commit; --test4
            end if;
            
            
          end loop; -- loop xReference end
      
        
      end;
      -- end set xReferences
      
      --stop duplication of forms, set translated code to the fillin type of forms node.
      
            declare
                
                cursor subs_to_update is
                select distinct(feed_policy_number) from feed_from_uwwb where imported is null;
                
                cursor fillins_unique (in_policy_number in varchar2) is
                select distinct(fillin_type) from feed_from_uwwb where feed_policy_number = in_policy_number and fillin_type is not null;
                
                cursor forms_to_flag (in_policy_number in varchar2) is
                select * from feed_from_uwwb where node_type = 'form' and node_name = 'formnums' and fillin_type is null and feed_policy_number = in_policy_number;
            
            
            begin
                for subs in subs_to_update loop
                
                    for fis in fillins_unique (subs.feed_policy_number) loop
                        
                        for ftp in forms_to_flag (subs.feed_policy_number) loop
                            
                            if fis.fillin_type = ftp.translated_form_code then -- if the fillin type, exists as translated form code for the form, and non fillin type nodes, we flag it so the form does not double create.
                                
                                update feed_from_uwwb set fillin_type = ftp.translated_form_code where node_type = 'form' 
                                    and node_name = 'formnums' and fillin_type is null and feed_policy_number = subs.feed_policy_number and translated_form_code = ftp.translated_form_code;
                                commit;
                            end if;
                        
                        end loop;
                        
                    end loop;
                    
                end loop;
            end;
      
      --stop duplication of forms, set translated code to the fillin type of forms node.
      
      --ERP MPL yes --test6
        declare
        cursor sub_to_update is
                select distinct(feed_policy_number) from feed_from_uwwb where imported is null;
                
        cursor erp_to_update (in_policy_number in varchar2) is
                select * from feed_from_uwwb where feed_policy_number = in_policy_number and variable_id in (31916925, 31924625); -- product, paper type
        
        v_paper     number;
        v_product   number;
        
        begin
            for subs in sub_to_update loop
            v_paper := null; -- clear per sub
            v_product := null; -- clear per sub
            
                for erps in erp_to_update (subs.feed_policy_number) loop
                
                    if erps.variable_id = 31916925 then --product
                        v_product := erps.variable_value;
                    elsif erps.variable_id = 31924625 then
                        v_paper := erps.variable_value;
                    end if;
                        
                        if v_product = 20625 and v_paper = 2 then -- MPL Non admitted
                            update feed_from_uwwb set variable_value = 1 where variable_id = 34228725 and feed_policy_number = subs.feed_policy_number;
                            commit;
                        end if;
                        
                end loop;
            
            end loop;
        end;
        -- ERP MPL yes --test6
        
        -- test10
        merge into feed_from_uwwb ffuwwb
        using uwwb_form_mappings ufm
        on (ffuwwb.variable_value = ufm.uwwb_form_code)
        when matched then
        update set ffuwwb.translated_form_code = nvl(ufm.dragon_form_code, 'N/A') where node_name = 'exclude_form_code';
        commit; --test5
        -- test10

  end sp_translate_by_merge;

end pkg_feed_from_uwwb;