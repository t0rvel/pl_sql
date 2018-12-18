create or replace PACKAGE pkg_cap_import
  IS
-----------------------------------------------------------------------------------------------------------------------------------------------------
--   Package Constants ...
-----------------------------------------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   Object Types
--
-----------------------------------------------------------------------------------------------------------------------------------------------------

gObjTypeSubmission             constant object_type.object_type_id%type := 5;
gObjTypeSubmissionEntity       constant object_type.object_type_id%type := 2308914;
gObjTypeSubAdd                 constant object_type.object_type_id%type := 2309014;
gObjTypeDragonUser             constant object_type.object_type_id%type := 309;
gObjTypePartner                constant object_type.object_type_id%type := 63;
gObjTypeDragUserAddress        constant object_type.object_type_id%type :=2623046;
-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   Lookup Lists
--
-----------------------------------------------------------------------------------------------------------------------------------------------------

gListJurisdiction             constant lookup_list.lookup_list_id%type := 5050401;

-----------------------------------------------------------------------------------------------------------------------------------------------------
--
--   Variables
--
-----------------------------------------------------------------------------------------------------------------------------------------------------

g_Incl_BusinessName           constant business_variable.business_variable_id%type := 29238814;
g_SubLinesIncl                constant business_variable.business_variable_id%type := 27354305;
g_ptp_PrimaryEx               constant business_variable.business_variable_id%type := 31915925;
g_renPolNumIfNotDrg           constant business_variable.business_variable_id%type := 32807925;
g_polExpDate                  constant business_variable.business_variable_id%type := 499;
g_polEffDate                  constant business_variable.business_variable_id%type := 504;
g_Vertical                    constant business_variable.business_variable_id%type := 31919625;
g_Segment                     constant business_variable.business_variable_id%type := 31917125;
g_RH_Ren_Indicator            constant business_variable.business_variable_id%type := 33810625;
g_PTP_RH_Ren_Ind              constant business_variable.business_variable_id%type := 33802525; -- Rockhill Renewal
g_ObjectState                 constant business_variable.business_variable_id%type := 210153;
g_partner_obj                 constant number := 118;
g_xReference_UW               constant business_variable.business_variable_id%type := 26590807;
g_xReference_UA               constant business_variable.business_variable_id%type := 32932625;
g_xRef_Prod_Ag                constant business_variable.business_variable_id%type := 26590907;
g_xRef_Producer               constant business_variable.business_variable_id%type := 26590707;
g_xRef_AccountInfo            constant business_variable.business_variable_id%type := 27360105;
gOK                           constant number := 22;
gCO3_code                     constant business_variable.business_variable_id%type := 31975625;
gBrokerRate                   constant business_variable.business_variable_id%type := 29428314;
g_premium                     constant business_variable.business_variable_id%type := 212314; -- Policy Premium Renewal - Pro-Rata Coverage Total
g_premium_before_tria         constant business_variable.business_variable_id%type := 32277125; -- Policy Premium before TRIA Premium Adjustment
gUnderwritingCom              constant business_variable.business_variable_id%type := 32340225; -- rating notes
gCvgCGL                       constant business_variable.business_variable_id%type := 31925425; -- General Liability Coverage?
gCvgPL                        constant business_variable.business_variable_id%type := 31925525; -- Professional Liability Coverage?
gCvgCPL                       constant business_variable.business_variable_id%type := 32214025; -- Contractor Pollution Liability Coverage?
gCvgTPL                       constant business_variable.business_variable_id%type := 32287225; -- Transportation Pollution Liability Coverage?
gCvgPPL                       constant business_variable.business_variable_id%type := 33783625; -- Products Pollution Liability Coverage?
gCvgEIL                       constant business_variable.business_variable_id%type := 32214625; -- Environmental Impairment Liability Coverage?
g_PTP_ID                      constant business_variable.business_variable_id%type := 2276904; --ptp
gRateMod                      constant business_variable.business_variable_id%type := 33030425; -- Show Rating Modifications Checked?



-- address
g_addressLn1                  constant business_variable.business_variable_id%type := 29325214;
g_addressLn2                  constant business_variable.business_variable_id%type := 210417;
g_addCity                     constant business_variable.business_variable_id%type := 29326314;
g_AddCounty                   constant business_variable.business_variable_id%type := 210422;
g_AddState                    constant business_variable.business_variable_id%type := 210419;
g_AddZip                      constant business_variable.business_variable_id%type := 29327414;
g_phnNmbr                     constant business_variable.business_variable_id%type := 29092806;

-- person

gFirstName                    constant business_variable.business_variable_id%type := 5122;
gLastName                     constant business_variable.business_variable_id%type := 5124;
gAgencyList                   constant business_variable.business_variable_id%type := 32736625;
gDefVert                      constant business_variable.business_variable_id%type := 31902625;
gDefSeg                       constant business_variable.business_variable_id%type := 31919325;
gDragonActorType              constant business_variable.business_variable_id%type := 21689501;
gEmail                        constant business_variable.business_variable_id%type := 211461;

procedure sp_import_forte;

procedure sp_import_uwwb;

function fn_get_state_enum
(
in_state_code                 in lookup_list_value.lookup_text%type,
in_session_id                 in        object.object_id%type
)
return number;

function fn_get_user_id
(
in_user_name                  in varchar2,
in_session_id                 in object.object_id%type,
in_partner_id                 in object.object_id%type
)
return number;

function fn_get_user_id_by_email
(
in_email                      in varchar2,
in_partner_id                 in object.object_id%type
)
return number;

function fn_get_prod_agency_id
(
in_session_id                 in object.object_id%type,
in_co3_code                   in varchar2
)
return number;

function fn_get_customer_id
(
jurisdiction                  in varchar2, 
account_name                  in varchar2, 
address_one                   in varchar2, 
city                          in varchar2, 
zipcode                       in number 
)
return number;

PROCEDURE workbench_send_mail (
p_to        IN VARCHAR2,
p_cc        IN VARCHAR2 DEFAULT NULL,
p_from      IN VARCHAR2,
p_smtp_host IN VARCHAR2,
p_smtp_port IN NUMBER DEFAULT 25,
p_start_date IN VARCHAR2,
p_end_date   IN VARCHAR2,
run_count    IN number DEFAULT 0);

end pkg_cap_import;