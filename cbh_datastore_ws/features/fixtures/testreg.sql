--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: rdkit; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS rdkit WITH SCHEMA public;


--
-- Name: EXTENSION rdkit; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION rdkit IS 'Cheminformatics functionality for PostgreSQL.';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: cbh_chembl_id_generator_cbhcompoundid; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_chembl_id_generator_cbhcompoundid (
    id integer NOT NULL,
    structure_key character varying(50) NOT NULL,
    assigned_id character varying(12) NOT NULL,
    original_installation_key character varying(10) NOT NULL,
    current_batch_id integer NOT NULL
);


ALTER TABLE public.cbh_chembl_id_generator_cbhcompoundid OWNER TO chembl;

--
-- Name: make_new_id(character, character, character); Type: FUNCTION; Schema: public; Owner: chembl
--

CREATE FUNCTION make_new_id(structure_keyv character, id_key character, original_installation_keyv character) RETURNS SETOF cbh_chembl_id_generator_cbhcompoundid
    LANGUAGE plpgsql
    AS $$
---
--- Declare a rowtype so all input variables can be used as are
--- Expects the structure_keyv to be empty if this is a new secret compound
---
declare r cbh_chembl_id_generator_cbhcompoundid%rowtype;
declare new_id varchar(12):= id_key || random_string(3) || random_int_string(2) || random_string(2);
BEGIN
    LOOP
    for r in
---
---Empty values are not updated so it will create a new value. If the compound is
---Secret and you want a new batch you must send the old ID as the structure key - 
---secret compounds are stored with the UOX id in both columns
---
            UPDATE cbh_chembl_id_generator_cbhcompoundid SET current_batch_id=current_batch_id+1 WHERE structure_key = structure_keyv and structure_key != '' returning * 
            loop return next r;  
    END LOOP;
    IF found THEN
        RETURN;
    END IF;
    BEGIN
    IF structure_keyv='' THEN
        structure_keyv := new_id;
    END IF;
    RETURN QUERY INSERT INTO cbh_chembl_id_generator_cbhcompoundid ("structure_key", "assigned_id","current_batch_id",  "original_installation_key" ) values 
      (structure_keyv, new_id , 1, original_installation_keyv) returning *;
    RETURN;
    EXCEPTION WHEN unique_violation THEN
    END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.make_new_id(structure_keyv character, id_key character, original_installation_keyv character) OWNER TO chembl;

--
-- Name: random_int_string(integer); Type: FUNCTION; Schema: public; Owner: chembl
--

CREATE FUNCTION random_int_string(length integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  ---
  --- Set the chars to numbers
  ---
  chars text[] := '{0,1,2,3,4,5,6,7,8,9}';
  result text := '';
  i integer := 0;
begin
  if length < 0 then
    raise exception 'Given length cannot be less than 0';
  end if;
  for i in 1..length loop
    result := result || chars[1+random()*(array_length(chars, 1)-1)];
  end loop;
  return result;
end;
$$;


ALTER FUNCTION public.random_int_string(length integer) OWNER TO chembl;

--
-- Name: random_string(integer); Type: FUNCTION; Schema: public; Owner: chembl
--

CREATE FUNCTION random_string(length integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  ---
  --- Set the chars to capital letters
  ---
  chars text[] := '{A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}';
  result text := '';
  i integer := 0;
begin
  if length < 0 then
    raise exception 'Given length cannot be less than 0';
  end if;
  for i in 1..length loop
    result := result || chars[1+random()*(array_length(chars, 1)-1)];
  end loop;
  return result;
end;
$$;


ALTER FUNCTION public.random_string(length integer) OWNER TO chembl;

--
-- Name: action_type; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE action_type (
    action_type character varying(50) NOT NULL,
    description character varying(200) NOT NULL,
    parent_type character varying(50)
);


ALTER TABLE public.action_type OWNER TO chembl;

--
-- Name: activities; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE activities (
    activity_id integer NOT NULL,
    standard_relation character varying(50),
    published_value numeric,
    published_units character varying(100),
    standard_value numeric,
    standard_units character varying(100),
    standard_flag smallint,
    standard_type character varying(250),
    updated_by character varying(100),
    updated_on date,
    activity_comment character varying(4000),
    published_type character varying(250),
    manual_curation_flag integer DEFAULT 0,
    potential_duplicate smallint,
    published_relation character varying(50),
    original_activity_id integer,
    pchembl_value numeric(4,2),
    bao_endpoint character varying(11),
    uo_units character varying(10),
    qudt_units character varying(70),
    assay_id integer NOT NULL,
    data_validity_comment character varying(30),
    doc_id integer,
    molregno integer,
    record_id integer NOT NULL,
    CONSTRAINT activities_manual_curation_flag_check CHECK (((manual_curation_flag >= 0) AND (manual_curation_flag = ANY (ARRAY[0, 1, 2])))),
    CONSTRAINT activities_manual_curation_flag_check1 CHECK ((manual_curation_flag >= 0)),
    CONSTRAINT activities_original_activity_id_check CHECK ((original_activity_id >= 0)),
    CONSTRAINT activities_original_activity_id_check1 CHECK ((original_activity_id >= 0)),
    CONSTRAINT activities_potential_duplicate_check CHECK (((potential_duplicate = ANY (ARRAY[0, 1])) OR (potential_duplicate IS NULL))),
    CONSTRAINT activities_standard_flag_check CHECK (((standard_flag = ANY (ARRAY[0, 1])) OR (standard_flag IS NULL))),
    CONSTRAINT activities_standard_relation_check CHECK (((standard_relation)::text = ANY ((ARRAY['>'::character varying, '<'::character varying, '='::character varying, '~'::character varying, '<='::character varying, '>='::character varying, '<<'::character varying, '>>'::character varying])::text[])))
);


ALTER TABLE public.activities OWNER TO chembl;

--
-- Name: activity_stds_lookup; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE activity_stds_lookup (
    std_act_id integer NOT NULL,
    standard_type character varying(250) NOT NULL,
    definition character varying(500),
    standard_units character varying(100) NOT NULL,
    normal_range_min numeric(24,12),
    normal_range_max numeric(24,12)
);


ALTER TABLE public.activity_stds_lookup OWNER TO chembl;

--
-- Name: assay_parameters; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE assay_parameters (
    assay_param_id integer NOT NULL,
    parameter_value character varying(2000) NOT NULL,
    assay_id integer NOT NULL,
    parameter_type character varying(20) NOT NULL,
    CONSTRAINT assay_parameters_assay_param_id_check CHECK ((assay_param_id >= 0)),
    CONSTRAINT assay_parameters_assay_param_id_check1 CHECK ((assay_param_id >= 0))
);


ALTER TABLE public.assay_parameters OWNER TO chembl;

--
-- Name: assay_type; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE assay_type (
    assay_type character varying(1) NOT NULL,
    assay_desc character varying(250)
);


ALTER TABLE public.assay_type OWNER TO chembl;

--
-- Name: assays; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE assays (
    assay_id integer NOT NULL,
    description character varying(4000),
    assay_test_type character varying(20),
    assay_category character varying(20),
    assay_organism character varying(250),
    assay_tax_id integer,
    assay_strain character varying(200),
    assay_tissue character varying(100),
    assay_cell_type character varying(100),
    assay_subcellular_fraction character varying(100),
    activity_count integer,
    assay_source character varying(50),
    src_assay_id character varying(50),
    updated_on date,
    updated_by character varying(250),
    orig_description character varying(4000),
    a2t_complex smallint,
    a2t_multi smallint,
    mc_tax_id integer,
    mc_organism character varying(100),
    mc_target_type character varying(25),
    mc_target_name character varying(4000),
    mc_target_accession character varying(255),
    a2t_assay_tax_id integer,
    a2t_assay_organism character varying(250),
    a2t_updated_on date,
    a2t_updated_by character varying(100),
    bao_format character varying(11),
    assay_type character varying(1),
    cell_id integer,
    chembl_id character varying(20) NOT NULL,
    confidence_score integer,
    curated_by character varying(32),
    doc_id integer NOT NULL,
    relationship_type character varying(1),
    src_id integer NOT NULL,
    tid integer,
    CONSTRAINT assays_a2t_assay_tax_id_check CHECK ((a2t_assay_tax_id >= 0)),
    CONSTRAINT assays_a2t_assay_tax_id_check1 CHECK ((a2t_assay_tax_id >= 0)),
    CONSTRAINT assays_a2t_complex_check CHECK (((a2t_complex = ANY (ARRAY[0, 1])) OR (a2t_complex IS NULL))),
    CONSTRAINT assays_a2t_multi_check CHECK (((a2t_multi = ANY (ARRAY[0, 1])) OR (a2t_multi IS NULL))),
    CONSTRAINT assays_activity_count_check CHECK ((activity_count >= 0)),
    CONSTRAINT assays_activity_count_check1 CHECK ((activity_count >= 0)),
    CONSTRAINT assays_assay_category_check CHECK (((assay_category)::text = ANY ((ARRAY['screening'::character varying, 'panel'::character varying, 'confirmatory'::character varying, 'summary'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT assays_assay_tax_id_check CHECK ((assay_tax_id >= 0)),
    CONSTRAINT assays_assay_tax_id_check1 CHECK ((assay_tax_id >= 0)),
    CONSTRAINT assays_assay_test_type_check CHECK (((assay_test_type)::text = ANY ((ARRAY['In vivo'::character varying, 'In vitro'::character varying, 'Ex vivo'::character varying])::text[]))),
    CONSTRAINT assays_confidence_score_check CHECK ((confidence_score >= 0)),
    CONSTRAINT assays_mc_tax_id_check CHECK ((mc_tax_id >= 0)),
    CONSTRAINT assays_mc_tax_id_check1 CHECK ((mc_tax_id >= 0))
);


ALTER TABLE public.assays OWNER TO chembl;

--
-- Name: atc_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE atc_classification (
    who_name character varying(150),
    level1 character varying(10),
    level2 character varying(10),
    level3 character varying(10),
    level4 character varying(10),
    level5 character varying(10) NOT NULL,
    who_id character varying(15),
    level1_description character varying(150),
    level2_description character varying(150),
    level3_description character varying(150),
    level4_description character varying(150)
);


ALTER TABLE public.atc_classification OWNER TO chembl;

--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE auth_group (
    id integer NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO chembl;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_group_id_seq OWNER TO chembl;

--
-- Name: auth_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE auth_group_id_seq OWNED BY auth_group.id;


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE auth_group_permissions (
    id integer NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO chembl;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_group_permissions_id_seq OWNER TO chembl;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE auth_group_permissions_id_seq OWNED BY auth_group_permissions.id;


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE auth_permission (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO chembl;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_permission_id_seq OWNER TO chembl;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE auth_permission_id_seq OWNED BY auth_permission.id;


--
-- Name: auth_user; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE auth_user (
    id integer NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone NOT NULL,
    is_superuser boolean NOT NULL,
    username character varying(30) NOT NULL,
    first_name character varying(30) NOT NULL,
    last_name character varying(30) NOT NULL,
    email character varying(75) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL
);


ALTER TABLE public.auth_user OWNER TO chembl;

--
-- Name: auth_user_groups; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE auth_user_groups (
    id integer NOT NULL,
    user_id integer NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.auth_user_groups OWNER TO chembl;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE auth_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_groups_id_seq OWNER TO chembl;

--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE auth_user_groups_id_seq OWNED BY auth_user_groups.id;


--
-- Name: auth_user_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE auth_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_id_seq OWNER TO chembl;

--
-- Name: auth_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE auth_user_id_seq OWNED BY auth_user.id;


--
-- Name: auth_user_user_permissions; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE auth_user_user_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_user_user_permissions OWNER TO chembl;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE auth_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_user_user_permissions_id_seq OWNER TO chembl;

--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE auth_user_user_permissions_id_seq OWNED BY auth_user_user_permissions.id;


--
-- Name: binding_sites; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE binding_sites (
    site_id integer NOT NULL,
    site_name character varying(200),
    tid integer
);


ALTER TABLE public.binding_sites OWNER TO chembl;

--
-- Name: bio_component_sequences; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE bio_component_sequences (
    component_id integer NOT NULL,
    component_type character varying(50) NOT NULL,
    description character varying(200),
    sequence text,
    sequence_md5sum character varying(32),
    tax_id integer,
    organism character varying(150),
    updated_on date,
    updated_by character varying(100),
    insert_date date,
    accession character varying(25),
    db_source character varying(25),
    db_version character varying(10),
    CONSTRAINT bio_component_sequences_tax_id_check CHECK ((tax_id >= 0)),
    CONSTRAINT bio_component_sequences_tax_id_check1 CHECK ((tax_id >= 0))
);


ALTER TABLE public.bio_component_sequences OWNER TO chembl;

--
-- Name: biotherapeutic_components; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE biotherapeutic_components (
    biocomp_id integer NOT NULL,
    molregno integer NOT NULL,
    component_id integer NOT NULL
);


ALTER TABLE public.biotherapeutic_components OWNER TO chembl;

--
-- Name: biotherapeutics; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE biotherapeutics (
    molregno integer NOT NULL,
    description character varying(2000),
    helm_notation character varying(4000)
);


ALTER TABLE public.biotherapeutics OWNER TO chembl;

--
-- Name: cbh_chembl_id_generator_cbhcompoundid_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_id_generator_cbhcompoundid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_id_generator_cbhcompoundid_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_id_generator_cbhcompoundid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_id_generator_cbhcompoundid_id_seq OWNED BY cbh_chembl_id_generator_cbhcompoundid.id;


--
-- Name: cbh_chembl_id_generator_cbhplugin; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_chembl_id_generator_cbhplugin (
    id integer NOT NULL,
    full_function_name character varying(100) NOT NULL,
    plugin_type character varying(20) NOT NULL,
    input_json_path character varying(200) NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.cbh_chembl_id_generator_cbhplugin OWNER TO chembl;

--
-- Name: cbh_chembl_id_generator_cbhplugin_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_id_generator_cbhplugin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_id_generator_cbhplugin_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_id_generator_cbhplugin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_id_generator_cbhplugin_id_seq OWNED BY cbh_chembl_id_generator_cbhplugin.id;


--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_chembl_model_extension_cbhcompoundbatch (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    ctab text,
    std_ctab text,
    canonical_smiles text,
    original_smiles text,
    editable_by hstore NOT NULL,
    uncurated_fields hstore NOT NULL,
    created_by character varying(50),
    standard_inchi text,
    standard_inchi_key character varying(50),
    warnings hstore NOT NULL,
    properties hstore NOT NULL,
    custom_fields hstore NOT NULL,
    errors hstore NOT NULL,
    multiple_batch_id integer NOT NULL,
    project_id integer,
    related_molregno_id integer,
    batch_number integer,
    blinded_batch_id character varying(12)
);


ALTER TABLE public.cbh_chembl_model_extension_cbhcompoundbatch OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_cbhcompoundbatch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_cbhcompoundbatch_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_cbhcompoundbatch_id_seq OWNED BY cbh_chembl_model_extension_cbhcompoundbatch.id;


--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_chembl_model_extension_cbhcompoundmultiplebatch (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    created_by character varying(50),
    uploaded_data text NOT NULL,
    uploaded_file_id integer,
    project_id integer,
    saved boolean NOT NULL
);


ALTER TABLE public.cbh_chembl_model_extension_cbhcompoundmultiplebatch OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq OWNED BY cbh_chembl_model_extension_cbhcompoundmultiplebatch.id;


--
-- Name: cbh_core_model_customfieldconfig; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_customfieldconfig (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    name character varying(500) NOT NULL,
    created_by_id integer NOT NULL,
    schemaform text,
    data_type_id integer
);


ALTER TABLE public.cbh_core_model_customfieldconfig OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_customfieldconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_customfieldconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_customfieldconfig_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_customfieldconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_customfieldconfig_id_seq OWNED BY cbh_core_model_customfieldconfig.id;


--
-- Name: cbh_core_model_pinnedcustomfield; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_pinnedcustomfield (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    name character varying(500) NOT NULL,
    required boolean NOT NULL,
    part_of_blinded_key boolean NOT NULL,
    field_type character varying(15) NOT NULL,
    allowed_values character varying(1024),
    custom_field_config_id integer,
    "position" smallint NOT NULL,
    description character varying(1024),
    field_key character varying(500) NOT NULL,
    "default" character varying(500) NOT NULL,
    pinned_for_datatype_id integer,
    standardised_alias_id integer,
    attachment_field_mapped_to_id integer,
    CONSTRAINT cbh_chembl_model_extension_pinnedcustomfield_position_check CHECK (("position" >= 0))
);


ALTER TABLE public.cbh_core_model_pinnedcustomfield OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_pinnedcustomfield_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_pinnedcustomfield_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_pinnedcustomfield_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_pinnedcustomfield_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_pinnedcustomfield_id_seq OWNED BY cbh_core_model_pinnedcustomfield.id;


--
-- Name: cbh_core_model_project; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_project (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    name character varying(100),
    project_key character varying(50),
    created_by_id integer NOT NULL,
    custom_field_config_id integer,
    is_default boolean NOT NULL,
    project_type_id integer
);


ALTER TABLE public.cbh_core_model_project OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_project_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_project_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_project_id_seq OWNED BY cbh_core_model_project.id;


--
-- Name: cbh_core_model_projecttype; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_projecttype (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    name character varying(100),
    show_compounds boolean NOT NULL
);


ALTER TABLE public.cbh_core_model_projecttype OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_projecttype_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_projecttype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_projecttype_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_projecttype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_projecttype_id_seq OWNED BY cbh_core_model_projecttype.id;


--
-- Name: cbh_core_model_skinningconfig; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_skinningconfig (
    id integer NOT NULL,
    instance_alias character varying(50),
    project_alias character varying(50),
    result_alias character varying(50)
);


ALTER TABLE public.cbh_core_model_skinningconfig OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_skinningconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_chembl_model_extension_skinningconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_chembl_model_extension_skinningconfig_id_seq OWNER TO chembl;

--
-- Name: cbh_chembl_model_extension_skinningconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_chembl_model_extension_skinningconfig_id_seq OWNED BY cbh_core_model_skinningconfig.id;


--
-- Name: cbh_core_model_dataformconfig; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_dataformconfig (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    created_by_id integer NOT NULL,
    l0_id integer NOT NULL,
    l1_id integer,
    l2_id integer,
    l3_id integer,
    l4_id integer,
    human_added boolean,
    parent_id integer
);


ALTER TABLE public.cbh_core_model_dataformconfig OWNER TO chembl;

--
-- Name: cbh_core_model_dataformconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_core_model_dataformconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_core_model_dataformconfig_id_seq OWNER TO chembl;

--
-- Name: cbh_core_model_dataformconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_core_model_dataformconfig_id_seq OWNED BY cbh_core_model_dataformconfig.id;


--
-- Name: cbh_core_model_datatype; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_datatype (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    name character varying(500) NOT NULL,
    uri character varying(1000) NOT NULL,
    version character varying(10) NOT NULL
);


ALTER TABLE public.cbh_core_model_datatype OWNER TO chembl;

--
-- Name: cbh_core_model_datatype_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_core_model_datatype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_core_model_datatype_id_seq OWNER TO chembl;

--
-- Name: cbh_core_model_datatype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_core_model_datatype_id_seq OWNED BY cbh_core_model_datatype.id;


--
-- Name: cbh_core_model_project_enabled_forms; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_core_model_project_enabled_forms (
    id integer NOT NULL,
    project_id integer NOT NULL,
    dataformconfig_id integer NOT NULL
);


ALTER TABLE public.cbh_core_model_project_enabled_forms OWNER TO chembl;

--
-- Name: cbh_core_model_project_enabled_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_core_model_project_enabled_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_core_model_project_enabled_forms_id_seq OWNER TO chembl;

--
-- Name: cbh_core_model_project_enabled_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_core_model_project_enabled_forms_id_seq OWNED BY cbh_core_model_project_enabled_forms.id;


--
-- Name: cbh_datastore_model_attachment; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_datastore_model_attachment (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    sheet_name character varying(100) NOT NULL,
    attachment_custom_field_config_id integer NOT NULL,
    chosen_data_form_config_id integer NOT NULL,
    created_by_id integer NOT NULL,
    data_point_classification_id integer NOT NULL,
    flowfile_id integer,
    number_of_rows integer NOT NULL
);


ALTER TABLE public.cbh_datastore_model_attachment OWNER TO chembl;

--
-- Name: cbh_datastore_model_attachment_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_datastore_model_attachment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_datastore_model_attachment_id_seq OWNER TO chembl;

--
-- Name: cbh_datastore_model_attachment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_datastore_model_attachment_id_seq OWNED BY cbh_datastore_model_attachment.id;


--
-- Name: cbh_datastore_model_datapoint; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_datastore_model_datapoint (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    project_data hstore NOT NULL,
    supplementary_data hstore NOT NULL,
    created_by_id integer NOT NULL,
    custom_field_config_id integer NOT NULL
);


ALTER TABLE public.cbh_datastore_model_datapoint OWNER TO chembl;

--
-- Name: cbh_datastore_model_datapoint_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_datastore_model_datapoint_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_datastore_model_datapoint_id_seq OWNER TO chembl;

--
-- Name: cbh_datastore_model_datapoint_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_datastore_model_datapoint_id_seq OWNED BY cbh_datastore_model_datapoint.id;


--
-- Name: cbh_datastore_model_datapointclassification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_datastore_model_datapointclassification (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    description character varying(1000),
    created_by_id integer NOT NULL,
    l0_id integer NOT NULL,
    l1_id integer NOT NULL,
    l2_id integer NOT NULL,
    l3_id integer NOT NULL,
    l4_id integer NOT NULL,
    data_form_config_id integer NOT NULL,
    parent_id integer
);


ALTER TABLE public.cbh_datastore_model_datapointclassification OWNER TO chembl;

--
-- Name: cbh_datastore_model_datapointclassification_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_datastore_model_datapointclassification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_datastore_model_datapointclassification_id_seq OWNER TO chembl;

--
-- Name: cbh_datastore_model_datapointclassification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_datastore_model_datapointclassification_id_seq OWNED BY cbh_datastore_model_datapointclassification.id;


--
-- Name: cbh_datastore_model_datapointclassificationpermission; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_datastore_model_datapointclassificationpermission (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    data_point_classification_id integer NOT NULL,
    project_id integer NOT NULL
);


ALTER TABLE public.cbh_datastore_model_datapointclassificationpermission OWNER TO chembl;

--
-- Name: cbh_datastore_model_datapointclassificationpermission_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_datastore_model_datapointclassificationpermission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_datastore_model_datapointclassificationpermission_id_seq OWNER TO chembl;

--
-- Name: cbh_datastore_model_datapointclassificationpermission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_datastore_model_datapointclassificationpermission_id_seq OWNED BY cbh_datastore_model_datapointclassificationpermission.id;


--
-- Name: cbh_datastore_model_query; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cbh_datastore_model_query (
    id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    query hstore NOT NULL,
    aggs hstore NOT NULL,
    created_by_id integer NOT NULL,
    filter hstore NOT NULL
);


ALTER TABLE public.cbh_datastore_model_query OWNER TO chembl;

--
-- Name: cbh_datastore_model_query_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE cbh_datastore_model_query_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cbh_datastore_model_query_id_seq OWNER TO chembl;

--
-- Name: cbh_datastore_model_query_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE cbh_datastore_model_query_id_seq OWNED BY cbh_datastore_model_query.id;


--
-- Name: cell_dictionary; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE cell_dictionary (
    cell_id integer NOT NULL,
    cell_name character varying(50) NOT NULL,
    cell_description character varying(200),
    cell_source_tissue character varying(50),
    cell_source_organism character varying(150),
    cell_source_tax_id integer,
    clo_id character varying(11),
    efo_id character varying(12),
    cellosaurus_id character varying(15),
    downgraded integer DEFAULT 0,
    chembl_id character varying(20),
    cl_lincs_id character varying(8),
    CONSTRAINT cell_dictionary_cell_source_tax_id_check CHECK ((cell_source_tax_id >= 0)),
    CONSTRAINT cell_dictionary_cell_source_tax_id_check1 CHECK ((cell_source_tax_id >= 0)),
    CONSTRAINT cell_dictionary_downgraded_check CHECK ((downgraded >= 0)),
    CONSTRAINT cell_dictionary_downgraded_check1 CHECK ((downgraded >= 0))
);


ALTER TABLE public.cell_dictionary OWNER TO chembl;

--
-- Name: chembl_business_model_djangocheatsheet; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE chembl_business_model_djangocheatsheet (
    id integer NOT NULL,
    "bigIntegerField" bigint NOT NULL,
    "booleanField" boolean NOT NULL,
    "charField" character varying(10) NOT NULL,
    "commaSeparatedIntegerField" character varying(20) NOT NULL,
    "dateField" date NOT NULL,
    "dateTimeField" timestamp with time zone NOT NULL,
    "decimalField" numeric(9,3) NOT NULL,
    "emailField" character varying(75) NOT NULL,
    "filePathField" character varying(100) NOT NULL,
    "floatField" double precision NOT NULL,
    "integerField" integer NOT NULL,
    "ipAddressField" inet NOT NULL,
    "genericIPAddressField" inet NOT NULL,
    "nullBooleanField" boolean,
    "positiveIntegerField" integer NOT NULL,
    "positiveSmallIntegerField" smallint NOT NULL,
    "slugField" character varying(50) NOT NULL,
    "smallIntegerField" smallint NOT NULL,
    "textField" text NOT NULL,
    "timeField" time without time zone NOT NULL,
    "urlField" character varying(200) NOT NULL,
    CONSTRAINT "chembl_business_model_djangoche_positiveSmallIntegerField_check" CHECK (("positiveSmallIntegerField" >= 0)),
    CONSTRAINT "chembl_business_model_djangocheatshe_positiveIntegerField_check" CHECK (("positiveIntegerField" >= 0))
);


ALTER TABLE public.chembl_business_model_djangocheatsheet OWNER TO chembl;

--
-- Name: chembl_business_model_djangocheatsheet_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE chembl_business_model_djangocheatsheet_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chembl_business_model_djangocheatsheet_id_seq OWNER TO chembl;

--
-- Name: chembl_business_model_djangocheatsheet_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE chembl_business_model_djangocheatsheet_id_seq OWNED BY chembl_business_model_djangocheatsheet.id;


--
-- Name: chembl_business_model_imageerrors; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE chembl_business_model_imageerrors (
    id integer NOT NULL,
    error_type character varying(10) NOT NULL,
    image_id integer NOT NULL
);


ALTER TABLE public.chembl_business_model_imageerrors OWNER TO chembl;

--
-- Name: chembl_business_model_imageerrors_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE chembl_business_model_imageerrors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chembl_business_model_imageerrors_id_seq OWNER TO chembl;

--
-- Name: chembl_business_model_imageerrors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE chembl_business_model_imageerrors_id_seq OWNED BY chembl_business_model_imageerrors.id;


--
-- Name: chembl_business_model_inchierrors; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE chembl_business_model_inchierrors (
    id integer NOT NULL,
    error_type character varying(30) NOT NULL,
    structure_id integer NOT NULL
);


ALTER TABLE public.chembl_business_model_inchierrors OWNER TO chembl;

--
-- Name: chembl_business_model_inchierrors_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE chembl_business_model_inchierrors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chembl_business_model_inchierrors_id_seq OWNER TO chembl;

--
-- Name: chembl_business_model_inchierrors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE chembl_business_model_inchierrors_id_seq OWNED BY chembl_business_model_inchierrors.id;


--
-- Name: chembl_business_model_sdf; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE chembl_business_model_sdf (
    "originalSDF" character varying(100) NOT NULL,
    "originalHash" character varying(32) NOT NULL,
    "cleanSDF" character varying(100) NOT NULL,
    "cleanHash" character varying(32) NOT NULL
);


ALTER TABLE public.chembl_business_model_sdf OWNER TO chembl;

--
-- Name: chembl_id_lookup; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE chembl_id_lookup (
    chembl_id character varying(20) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id integer NOT NULL,
    status character varying(10) DEFAULT 'ACTIVE'::character varying NOT NULL,
    CONSTRAINT chembl_id_lookup_entity_type_check CHECK (((entity_type)::text = ANY (ARRAY[('ASSAY'::character varying)::text, ('COMPOUND'::character varying)::text, ('DOCUMENT'::character varying)::text, ('TARGET'::character varying)::text]))),
    CONSTRAINT chembl_id_lookup_status_check CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying, 'OBS'::character varying])::text[])))
);


ALTER TABLE public.chembl_id_lookup OWNER TO chembl;

--
-- Name: component_class; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE component_class (
    comp_class_id integer NOT NULL,
    component_id integer NOT NULL,
    protein_class_id integer NOT NULL
);


ALTER TABLE public.component_class OWNER TO chembl;

--
-- Name: component_domains; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE component_domains (
    compd_id integer NOT NULL,
    start_position integer,
    end_position integer,
    component_id integer NOT NULL,
    domain_id integer,
    CONSTRAINT component_domains_end_position_check CHECK ((end_position >= 0)),
    CONSTRAINT component_domains_end_position_check1 CHECK ((end_position >= 0)),
    CONSTRAINT component_domains_start_position_check CHECK ((start_position >= 0)),
    CONSTRAINT component_domains_start_position_check1 CHECK ((start_position >= 0))
);


ALTER TABLE public.component_domains OWNER TO chembl;

--
-- Name: component_sequences; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE component_sequences (
    component_id integer NOT NULL,
    component_type character varying(50),
    accession character varying(25),
    sequence text,
    sequence_md5sum character varying(32),
    description character varying(200),
    tax_id integer,
    organism character varying(150),
    db_source character varying(25),
    db_version character varying(10),
    insert_date date DEFAULT ('now'::text)::date,
    updated_on date,
    updated_by character varying(100),
    CONSTRAINT component_sequences_component_type_check CHECK (((component_type)::text = ANY ((ARRAY['PROTEIN'::character varying, 'DNA'::character varying, 'RNA'::character varying])::text[]))),
    CONSTRAINT component_sequences_db_source_check CHECK (((db_source)::text = ANY ((ARRAY['Manual'::character varying, 'SWISS-PROT'::character varying, 'TREMBL'::character varying])::text[]))),
    CONSTRAINT component_sequences_tax_id_check CHECK ((tax_id >= 0)),
    CONSTRAINT component_sequences_tax_id_check1 CHECK ((tax_id >= 0))
);


ALTER TABLE public.component_sequences OWNER TO chembl;

--
-- Name: component_synonyms; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE component_synonyms (
    compsyn_id integer NOT NULL,
    component_synonym character varying(500),
    syn_type character varying(20),
    component_id integer NOT NULL,
    CONSTRAINT component_synonyms_syn_type_check CHECK (((syn_type)::text = ANY ((ARRAY['HGNC_SYMBOL'::character varying, 'GENE_SYMBOL'::character varying, 'UNIPROT'::character varying, 'MANUAL'::character varying, 'OTHER'::character varying, 'EC_NUMBER'::character varying])::text[])))
);


ALTER TABLE public.component_synonyms OWNER TO chembl;

--
-- Name: compound_images; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE compound_images (
    molregno integer NOT NULL,
    png bytea,
    png_500 bytea
);


ALTER TABLE public.compound_images OWNER TO chembl;

--
-- Name: compound_mols; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE compound_mols (
    molregno integer NOT NULL,
    ctab mol
);


ALTER TABLE public.compound_mols OWNER TO chembl;

--
-- Name: compound_properties; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE compound_properties (
    molregno integer NOT NULL,
    mw_freebase numeric(9,2),
    alogp numeric(9,2),
    hba integer,
    hbd integer,
    psa numeric(9,2),
    rtb integer,
    ro3_pass character varying(3),
    num_ro5_violations integer,
    med_chem_friendly character varying(3),
    acd_most_apka numeric(9,2),
    acd_most_bpka numeric(9,2),
    acd_logp numeric(9,2),
    acd_logd numeric(9,2),
    molecular_species character varying(50),
    full_mwt numeric(9,2),
    aromatic_rings integer,
    heavy_atoms integer,
    num_alerts integer,
    qed_weighted numeric(3,2),
    updated_on date,
    mw_monoisotopic numeric(11,4),
    full_molformula character varying(100),
    hba_lipinski integer,
    hbd_lipinski integer,
    num_lipinski_ro5_violations integer,
    CONSTRAINT compound_properties_aromatic_rings_check CHECK ((aromatic_rings >= 0)),
    CONSTRAINT compound_properties_aromatic_rings_check1 CHECK ((aromatic_rings >= 0)),
    CONSTRAINT compound_properties_full_mwt_check CHECK ((full_mwt >= (0)::numeric)),
    CONSTRAINT compound_properties_hba_check CHECK ((hba >= 0)),
    CONSTRAINT compound_properties_hba_check1 CHECK ((hba >= 0)),
    CONSTRAINT compound_properties_hba_lipinski_check CHECK ((hba_lipinski >= 0)),
    CONSTRAINT compound_properties_hba_lipinski_check1 CHECK ((hba_lipinski >= 0)),
    CONSTRAINT compound_properties_hbd_check CHECK ((hbd >= 0)),
    CONSTRAINT compound_properties_hbd_check1 CHECK ((hbd >= 0)),
    CONSTRAINT compound_properties_hbd_lipinski_check CHECK ((hbd_lipinski >= 0)),
    CONSTRAINT compound_properties_hbd_lipinski_check1 CHECK ((hbd_lipinski >= 0)),
    CONSTRAINT compound_properties_heavy_atoms_check CHECK ((heavy_atoms >= 0)),
    CONSTRAINT compound_properties_heavy_atoms_check1 CHECK ((heavy_atoms >= 0)),
    CONSTRAINT compound_properties_med_chem_friendly_check CHECK (((med_chem_friendly)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT compound_properties_molecular_species_check CHECK (((molecular_species)::text = ANY ((ARRAY['ACID'::character varying, 'BASE'::character varying, 'ZWITTERION'::character varying, 'NEUTRAL'::character varying])::text[]))),
    CONSTRAINT compound_properties_mw_freebase_check CHECK ((mw_freebase >= (0)::numeric)),
    CONSTRAINT compound_properties_mw_monoisotopic_check CHECK ((mw_monoisotopic >= (0)::numeric)),
    CONSTRAINT compound_properties_num_alerts_check CHECK ((num_alerts >= 0)),
    CONSTRAINT compound_properties_num_alerts_check1 CHECK ((num_alerts >= 0)),
    CONSTRAINT compound_properties_num_lipinski_ro5_violations_check CHECK (((num_lipinski_ro5_violations >= 0) AND (num_lipinski_ro5_violations = ANY (ARRAY[0, 1, 2, 3, 4])))),
    CONSTRAINT compound_properties_num_lipinski_ro5_violations_check1 CHECK ((num_lipinski_ro5_violations >= 0)),
    CONSTRAINT compound_properties_num_ro5_violations_check CHECK (((num_ro5_violations >= 0) AND (num_ro5_violations = ANY (ARRAY[0, 1, 2, 3, 4])))),
    CONSTRAINT compound_properties_num_ro5_violations_check1 CHECK ((num_ro5_violations >= 0)),
    CONSTRAINT compound_properties_psa_check CHECK ((psa >= (0)::numeric)),
    CONSTRAINT compound_properties_qed_weighted_check CHECK ((qed_weighted >= (0)::numeric)),
    CONSTRAINT compound_properties_ro3_pass_check CHECK (((ro3_pass)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT compound_properties_rtb_check CHECK ((rtb >= 0)),
    CONSTRAINT compound_properties_rtb_check1 CHECK ((rtb >= 0))
);


ALTER TABLE public.compound_properties OWNER TO chembl;

--
-- Name: compound_records; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE compound_records (
    record_id integer NOT NULL,
    compound_key character varying(250),
    compound_name character varying(4000),
    filename character varying(250),
    updated_by character varying(100),
    updated_on date,
    src_compound_id character varying(150),
    removed smallint DEFAULT 0 NOT NULL,
    src_compound_id_version integer,
    curated smallint DEFAULT 0 NOT NULL,
    doc_id integer NOT NULL,
    molregno integer,
    src_id integer NOT NULL,
    CONSTRAINT compound_records_curated_check CHECK ((curated = ANY (ARRAY[0, 1]))),
    CONSTRAINT compound_records_removed_check CHECK ((removed = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT compound_records_src_compound_id_version_check CHECK (((src_compound_id_version >= 0) AND (src_compound_id_version = ANY (ARRAY[1, 2, 3, 4, 5, 6, 7, 8])))),
    CONSTRAINT compound_records_src_compound_id_version_check1 CHECK ((src_compound_id_version >= 0))
);


ALTER TABLE public.compound_records OWNER TO chembl;

--
-- Name: compound_structural_alerts; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE compound_structural_alerts (
    cpd_str_alert_id integer NOT NULL,
    alert_id integer NOT NULL,
    molregno integer NOT NULL,
    CONSTRAINT compound_structural_alerts_alert_id_check CHECK ((alert_id >= 0)),
    CONSTRAINT compound_structural_alerts_cpd_str_alert_id_check CHECK ((cpd_str_alert_id >= 0)),
    CONSTRAINT compound_structural_alerts_cpd_str_alert_id_check1 CHECK ((cpd_str_alert_id >= 0))
);


ALTER TABLE public.compound_structural_alerts OWNER TO chembl;

--
-- Name: compound_structures; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE compound_structures (
    molregno integer NOT NULL,
    molfile text,
    standard_inchi character varying(4000),
    standard_inchi_key character varying(27) NOT NULL,
    canonical_smiles character varying(4000),
    structure_exclude_flag smallint DEFAULT 0 NOT NULL,
    CONSTRAINT compound_structures_structure_exclude_flag_check CHECK ((structure_exclude_flag = ANY (ARRAY[0, 1])))
);


ALTER TABLE public.compound_structures OWNER TO chembl;

--
-- Name: confidence_score_lookup; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE confidence_score_lookup (
    confidence_score integer NOT NULL,
    description character varying(100) NOT NULL,
    target_mapping character varying(30) NOT NULL,
    CONSTRAINT confidence_score_lookup_confidence_score_check CHECK ((confidence_score >= 0)),
    CONSTRAINT confidence_score_lookup_confidence_score_check1 CHECK ((confidence_score >= 0))
);


ALTER TABLE public.confidence_score_lookup OWNER TO chembl;

--
-- Name: curation_lookup; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE curation_lookup (
    curated_by character varying(32) NOT NULL,
    description character varying(100) NOT NULL
);


ALTER TABLE public.curation_lookup OWNER TO chembl;

--
-- Name: data_validity_lookup; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE data_validity_lookup (
    data_validity_comment character varying(30) NOT NULL,
    description character varying(200)
);


ALTER TABLE public.data_validity_lookup OWNER TO chembl;

--
-- Name: defined_daily_dose; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE defined_daily_dose (
    ddd_value numeric(9,2),
    ddd_units character varying(20),
    ddd_admr character varying(30),
    ddd_comment character varying(400),
    ddd_id integer NOT NULL,
    atc_code character varying(10) NOT NULL,
    CONSTRAINT defined_daily_dose_ddd_units_check CHECK (((ddd_units)::text = ANY ((ARRAY['LSU'::character varying, 'MU'::character varying, 'TU'::character varying, 'U'::character varying, 'g'::character varying, 'mcg'::character varying, 'mg'::character varying, 'ml'::character varying, 'mmol'::character varying, 'tablet'::character varying])::text[])))
);


ALTER TABLE public.defined_daily_dose OWNER TO chembl;

--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id integer NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO chembl;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_admin_log_id_seq OWNER TO chembl;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE django_admin_log_id_seq OWNED BY django_admin_log.id;


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE django_content_type (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO chembl;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_content_type_id_seq OWNER TO chembl;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE django_content_type_id_seq OWNED BY django_content_type.id;


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE django_migrations (
    id integer NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE public.django_migrations OWNER TO chembl;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_migrations_id_seq OWNER TO chembl;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE django_migrations_id_seq OWNED BY django_migrations.id;


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO chembl;

--
-- Name: django_site; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE django_site (
    id integer NOT NULL,
    domain character varying(100) NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.django_site OWNER TO chembl;

--
-- Name: django_site_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE django_site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.django_site_id_seq OWNER TO chembl;

--
-- Name: django_site_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE django_site_id_seq OWNED BY django_site.id;


--
-- Name: docs; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE docs (
    doc_id integer NOT NULL,
    journal character varying(50),
    year integer,
    volume character varying(50),
    issue character varying(50),
    first_page character varying(50),
    last_page character varying(50),
    pubmed_id integer,
    updated_on date,
    updated_by character varying(100),
    doi character varying(50),
    title character varying(500),
    doc_type character varying(50) NOT NULL,
    authors character varying(4000),
    abstract text,
    chembl_id character varying(20) NOT NULL,
    journal_id integer,
    CONSTRAINT docs_doc_type_check CHECK (((doc_type)::text = ANY ((ARRAY['PUBLICATION'::character varying, 'BOOK'::character varying, 'DATASET'::character varying])::text[]))),
    CONSTRAINT docs_pubmed_id_check CHECK ((pubmed_id >= 0)),
    CONSTRAINT docs_pubmed_id_check1 CHECK ((pubmed_id >= 0)),
    CONSTRAINT docs_year_check CHECK ((year >= 0)),
    CONSTRAINT docs_year_check1 CHECK ((year >= 0))
);


ALTER TABLE public.docs OWNER TO chembl;

--
-- Name: domains; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE domains (
    domain_id integer NOT NULL,
    domain_type character varying(20) NOT NULL,
    source_domain_id character varying(20) NOT NULL,
    domain_name character varying(20),
    domain_description character varying(500),
    CONSTRAINT domains_domain_type_check CHECK (((domain_type)::text = ANY ((ARRAY['Pfam-A'::character varying, 'Pfam-B'::character varying])::text[])))
);


ALTER TABLE public.domains OWNER TO chembl;

--
-- Name: drug_mechanism; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE drug_mechanism (
    mec_id integer NOT NULL,
    mechanism_of_action character varying(250),
    direct_interaction smallint,
    molecular_mechanism smallint,
    disease_efficacy smallint,
    mechanism_comment character varying(500),
    selectivity_comment character varying(100),
    binding_site_comment character varying(100),
    curated_by character varying(20),
    date_added date DEFAULT ('now'::text)::date NOT NULL,
    date_removed date,
    downgraded smallint,
    downgrade_reason character varying(200),
    curator_comment character varying(500),
    curation_status character varying(10) DEFAULT 'PARTIAL'::character varying NOT NULL,
    action_type character varying(50),
    molregno integer,
    record_id integer NOT NULL,
    site_id integer,
    tid integer,
    CONSTRAINT drug_mechanism_curation_status_check CHECK (((curation_status)::text = ANY ((ARRAY['COMPLETE'::character varying, 'PARTIAL'::character varying])::text[]))),
    CONSTRAINT drug_mechanism_direct_interaction_check CHECK (((direct_interaction = ANY (ARRAY[0, 1])) OR (direct_interaction IS NULL))),
    CONSTRAINT drug_mechanism_disease_efficacy_check CHECK (((disease_efficacy = ANY (ARRAY[0, 1])) OR (disease_efficacy IS NULL))),
    CONSTRAINT drug_mechanism_downgraded_check CHECK (((downgraded = ANY (ARRAY[0, 1])) OR (downgraded IS NULL))),
    CONSTRAINT drug_mechanism_molecular_mechanism_check CHECK (((molecular_mechanism = ANY (ARRAY[0, 1])) OR (molecular_mechanism IS NULL))),
    CONSTRAINT drug_mechanism_selectivity_comment_check CHECK (((selectivity_comment)::text = ANY (ARRAY[('Broad spectrum'::character varying)::text, ('EDG5 less relevant'::character varying)::text, ('M3 selective'::character varying)::text, ('Non-selective but type 5 receptor is overexpressed in Cushing''s disease'::character varying)::text, ('Selective'::character varying)::text, ('Selective for the brain omega-1 receptor (i.e. BZ1-type, i.e. alpha1/beta1/gamma2-GABA receptor)'::character varying)::text, ('Selectivity for types 2, 3 and 5'::character varying)::text, ('selectivity for beta-3 containing complexes'::character varying)::text])))
);


ALTER TABLE public.drug_mechanism OWNER TO chembl;

--
-- Name: flowjs_flowfile; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE flowjs_flowfile (
    id integer NOT NULL,
    identifier character varying(255) NOT NULL,
    original_filename character varying(200) NOT NULL,
    total_size integer NOT NULL,
    total_chunks integer NOT NULL,
    total_chunks_uploaded integer NOT NULL,
    state integer NOT NULL,
    created timestamp with time zone NOT NULL,
    updated date NOT NULL
);


ALTER TABLE public.flowjs_flowfile OWNER TO chembl;

--
-- Name: flowjs_flowfile_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE flowjs_flowfile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flowjs_flowfile_id_seq OWNER TO chembl;

--
-- Name: flowjs_flowfile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE flowjs_flowfile_id_seq OWNED BY flowjs_flowfile.id;


--
-- Name: flowjs_flowfilechunk; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE flowjs_flowfilechunk (
    id integer NOT NULL,
    file character varying(255) NOT NULL,
    number integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    parent_id integer NOT NULL
);


ALTER TABLE public.flowjs_flowfilechunk OWNER TO chembl;

--
-- Name: flowjs_flowfilechunk_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE flowjs_flowfilechunk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flowjs_flowfilechunk_id_seq OWNER TO chembl;

--
-- Name: flowjs_flowfilechunk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE flowjs_flowfilechunk_id_seq OWNED BY flowjs_flowfilechunk.id;


--
-- Name: formulations; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE formulations (
    ingredient character varying(200),
    strength character varying(200),
    formulation_id integer NOT NULL,
    molregno integer,
    product_id character varying(30) NOT NULL,
    record_id integer NOT NULL
);


ALTER TABLE public.formulations OWNER TO chembl;

--
-- Name: frac_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE frac_classification (
    frac_class_id integer NOT NULL,
    active_ingredient character varying(500) NOT NULL,
    level1 character varying(2) NOT NULL,
    level1_description character varying(2000) NOT NULL,
    level2 character varying(2) NOT NULL,
    level2_description character varying(2000),
    level3 character varying(6) NOT NULL,
    level3_description character varying(2000),
    level4 character varying(7) NOT NULL,
    level4_description character varying(2000),
    level5 character varying(8) NOT NULL,
    frac_code character varying(4) NOT NULL
);


ALTER TABLE public.frac_classification OWNER TO chembl;

--
-- Name: hrac_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE hrac_classification (
    hrac_class_id integer NOT NULL,
    active_ingredient character varying(500) NOT NULL,
    level1 character varying(2) NOT NULL,
    level1_description character varying(2000) NOT NULL,
    level2 character varying(3) NOT NULL,
    level2_description character varying(2000),
    level3 character varying(5) NOT NULL,
    hrac_code character varying(2) NOT NULL
);


ALTER TABLE public.hrac_classification OWNER TO chembl;

--
-- Name: irac_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE irac_classification (
    irac_class_id integer NOT NULL,
    active_ingredient character varying(500) NOT NULL,
    level1 character varying(1) NOT NULL,
    level1_description character varying(2000) NOT NULL,
    level2 character varying(3) NOT NULL,
    level2_description character varying(2000) NOT NULL,
    level3 character varying(6) NOT NULL,
    level3_description character varying(2000) NOT NULL,
    level4 character varying(8) NOT NULL,
    irac_code character varying(3) NOT NULL,
    CONSTRAINT irac_classification_level1_check CHECK (((level1)::text = ANY ((ARRAY['A'::character varying, 'B'::character varying, 'C'::character varying, 'D'::character varying, 'E'::character varying, 'M'::character varying, 'U'::character varying])::text[]))),
    CONSTRAINT irac_classification_level1_description_check CHECK (((level1_description)::text = ANY ((ARRAY['ENERGY METABOLISM'::character varying, 'GROWTH REGULATION'::character varying, 'LIPID SYNTHESIS, GROWTH REGULATION'::character varying, 'MISCELLANEOUS'::character varying, 'NERVE ACTION'::character varying, 'NERVE AND MUSCLE ACTION'::character varying, 'UNKNOWN'::character varying])::text[])))
);


ALTER TABLE public.irac_classification OWNER TO chembl;

--
-- Name: journal_articles; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE journal_articles (
    int_pk integer NOT NULL,
    volume integer,
    issue integer,
    year integer,
    month integer,
    day integer,
    pagination character varying(50),
    first_page character varying(50),
    last_page character varying(50),
    pubmed_id integer,
    doi character varying(50),
    title text,
    abstract text,
    authors text,
    year_raw character varying(50),
    month_raw character varying(50),
    day_raw character varying(50),
    volume_raw character varying(50),
    issue_raw character varying(50),
    date_loaded date,
    journal_id integer NOT NULL,
    CONSTRAINT journal_articles_day_check CHECK ((day >= 0)),
    CONSTRAINT journal_articles_day_check1 CHECK ((day >= 0)),
    CONSTRAINT journal_articles_issue_check CHECK ((issue >= 0)),
    CONSTRAINT journal_articles_issue_check1 CHECK ((issue >= 0)),
    CONSTRAINT journal_articles_month_check CHECK ((month >= 0)),
    CONSTRAINT journal_articles_month_check1 CHECK ((month >= 0)),
    CONSTRAINT journal_articles_pubmed_id_check CHECK ((pubmed_id >= 0)),
    CONSTRAINT journal_articles_pubmed_id_check1 CHECK ((pubmed_id >= 0)),
    CONSTRAINT journal_articles_volume_check CHECK ((volume >= 0)),
    CONSTRAINT journal_articles_volume_check1 CHECK ((volume >= 0)),
    CONSTRAINT journal_articles_year_check CHECK ((year >= 0)),
    CONSTRAINT journal_articles_year_check1 CHECK ((year >= 0))
);


ALTER TABLE public.journal_articles OWNER TO chembl;

--
-- Name: journals; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE journals (
    journal_id integer NOT NULL,
    title character varying(100),
    iso_abbreviation character varying(50),
    issn_print character varying(20),
    issn_electronic character varying(20),
    publication_start_year integer,
    nlm_id character varying(15),
    doc_journal character varying(50),
    core_journal_flag smallint,
    CONSTRAINT journals_core_journal_flag_check CHECK (((core_journal_flag = ANY (ARRAY[0, 1])) OR (core_journal_flag IS NULL))),
    CONSTRAINT journals_publication_start_year_check CHECK ((publication_start_year >= 0)),
    CONSTRAINT journals_publication_start_year_check1 CHECK ((publication_start_year >= 0))
);


ALTER TABLE public.journals OWNER TO chembl;

--
-- Name: ligand_eff; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE ligand_eff (
    activity_id integer NOT NULL,
    bei numeric(9,2),
    sei numeric(9,2),
    le numeric(9,2),
    lle numeric(9,2),
    CONSTRAINT ligand_eff_bei_check CHECK ((bei >= (0)::numeric)),
    CONSTRAINT ligand_eff_le_check CHECK ((le >= (0)::numeric)),
    CONSTRAINT ligand_eff_sei_check CHECK ((sei >= (0)::numeric))
);


ALTER TABLE public.ligand_eff OWNER TO chembl;

--
-- Name: mechanism_refs; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE mechanism_refs (
    mecref_id integer NOT NULL,
    ref_type character varying(50) NOT NULL,
    ref_id character varying(100),
    ref_url character varying(200),
    mec_id integer NOT NULL,
    CONSTRAINT mechanism_refs_mecref_id_check CHECK ((mecref_id >= 0)),
    CONSTRAINT mechanism_refs_mecref_id_check1 CHECK ((mecref_id >= 0)),
    CONSTRAINT mechanism_refs_ref_type_check CHECK (((ref_type)::text = ANY ((ARRAY['ISBN'::character varying, 'IUPHAR'::character varying, 'DOI'::character varying, 'EMA'::character varying, 'PubMed'::character varying, 'USPO'::character varying, 'DailyMed'::character varying, 'FDA'::character varying, 'Expert'::character varying, 'Other'::character varying, 'InterPro'::character varying, 'Wikipedia'::character varying, 'UniProt'::character varying, 'KEGG'::character varying])::text[])))
);


ALTER TABLE public.mechanism_refs OWNER TO chembl;

--
-- Name: molecule_atc_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_atc_classification (
    mol_atc_id integer NOT NULL,
    level5 character varying(10) NOT NULL,
    molregno integer NOT NULL
);


ALTER TABLE public.molecule_atc_classification OWNER TO chembl;

--
-- Name: molecule_dictionary_molregno_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE molecule_dictionary_molregno_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.molecule_dictionary_molregno_seq OWNER TO chembl;

--
-- Name: molecule_dictionary; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_dictionary (
    molregno integer DEFAULT nextval('molecule_dictionary_molregno_seq'::regclass) NOT NULL,
    pref_name character varying(255),
    max_phase integer DEFAULT 0 NOT NULL,
    therapeutic_flag smallint DEFAULT 0 NOT NULL,
    dosed_ingredient smallint DEFAULT 0 NOT NULL,
    structure_key character varying(27),
    structure_type character varying(10) DEFAULT 'MOL'::character varying NOT NULL,
    chebi_id integer,
    chebi_par_id integer,
    insert_date date DEFAULT ('now'::text)::date,
    molfile_update date,
    downgraded smallint DEFAULT 0 NOT NULL,
    downgrade_reason character varying(2000),
    replacement_mrn integer,
    checked_by character varying(2000),
    nomerge smallint DEFAULT 0 NOT NULL,
    nomerge_reason character varying(200),
    molecule_type character varying(30),
    first_approval integer,
    oral smallint DEFAULT 0 NOT NULL,
    parenteral smallint DEFAULT 0 NOT NULL,
    topical smallint DEFAULT 0 NOT NULL,
    black_box_warning smallint DEFAULT 0 NOT NULL,
    natural_product smallint DEFAULT (-1) NOT NULL,
    first_in_class smallint DEFAULT (-1) NOT NULL,
    chirality integer DEFAULT (-1) NOT NULL,
    prodrug smallint DEFAULT (-1) NOT NULL,
    exclude smallint DEFAULT 0 NOT NULL,
    inorganic_flag smallint DEFAULT 0 NOT NULL,
    usan_year integer,
    availability_type integer,
    usan_stem character varying(50),
    polymer_flag smallint,
    usan_substem character varying(50),
    usan_stem_definition character varying(1000),
    indication_class character varying(1000),
    chembl_id character varying(20),
    created_by_id integer,
    forced_reg_index integer NOT NULL,
    forced_reg_reason character varying(200),
    project_id integer,
    public smallint NOT NULL,
    CONSTRAINT molecule_dictionary_availability_type_check CHECK ((availability_type = ANY (ARRAY[(-1), 0, 1, 2]))),
    CONSTRAINT molecule_dictionary_black_box_warning_check CHECK ((black_box_warning = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT molecule_dictionary_chebi_id_check CHECK ((chebi_id >= 0)),
    CONSTRAINT molecule_dictionary_chebi_id_check1 CHECK ((chebi_id >= 0)),
    CONSTRAINT molecule_dictionary_chebi_par_id_check CHECK ((chebi_par_id >= 0)),
    CONSTRAINT molecule_dictionary_chebi_par_id_check1 CHECK ((chebi_par_id >= 0)),
    CONSTRAINT molecule_dictionary_chirality_check CHECK ((chirality = ANY (ARRAY[(-1), 0, 1, 2]))),
    CONSTRAINT molecule_dictionary_dosed_ingredient_check CHECK ((dosed_ingredient = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_downgraded_check CHECK ((downgraded = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_exclude_check CHECK ((exclude = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_first_approval_check CHECK ((first_approval >= 0)),
    CONSTRAINT molecule_dictionary_first_approval_check1 CHECK ((first_approval >= 0)),
    CONSTRAINT molecule_dictionary_first_in_class_check CHECK ((first_in_class = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT molecule_dictionary_forced_reg_index_check CHECK ((forced_reg_index >= 0)),
    CONSTRAINT molecule_dictionary_inorganic_flag_check CHECK ((inorganic_flag = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT molecule_dictionary_max_phase_check CHECK (((max_phase >= 0) AND (max_phase = ANY (ARRAY[0, 1, 2, 3, 4])))),
    CONSTRAINT molecule_dictionary_max_phase_check1 CHECK ((max_phase >= 0)),
    CONSTRAINT molecule_dictionary_molecule_type_check CHECK (((molecule_type)::text = ANY ((ARRAY['Antibody'::character varying, 'Cell'::character varying, 'Enzyme'::character varying, 'Oligonucleotide'::character varying, 'Oligosaccharide'::character varying, 'Protein'::character varying, 'Small molecule'::character varying, 'Unclassified'::character varying, 'Unknown'::character varying])::text[]))),
    CONSTRAINT molecule_dictionary_natural_product_check CHECK ((natural_product = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT molecule_dictionary_nomerge_check CHECK ((nomerge = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_nomerge_reason_check CHECK (((nomerge_reason)::text = ANY ((ARRAY['GSK'::character varying, 'PARENT'::character varying, 'PDBE'::character varying, 'SALT'::character varying])::text[]))),
    CONSTRAINT molecule_dictionary_oral_check CHECK ((oral = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_parenteral_check CHECK ((parenteral = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_polymer_flag_check CHECK (((polymer_flag = ANY (ARRAY[0, 1])) OR (polymer_flag IS NULL))),
    CONSTRAINT molecule_dictionary_prodrug_check CHECK ((prodrug = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT molecule_dictionary_public_check CHECK ((public = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_replacement_mrn_check CHECK ((replacement_mrn >= 0)),
    CONSTRAINT molecule_dictionary_replacement_mrn_check1 CHECK ((replacement_mrn >= 0)),
    CONSTRAINT molecule_dictionary_structure_type_check CHECK (((structure_type)::text = ANY ((ARRAY['NONE'::character varying, 'MOL'::character varying, 'SEQ'::character varying, 'BOTH'::character varying])::text[]))),
    CONSTRAINT molecule_dictionary_therapeutic_flag_check CHECK ((therapeutic_flag = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_topical_check CHECK ((topical = ANY (ARRAY[0, 1]))),
    CONSTRAINT molecule_dictionary_usan_year_check CHECK ((usan_year >= 0)),
    CONSTRAINT molecule_dictionary_usan_year_check1 CHECK ((usan_year >= 0))
);


ALTER TABLE public.molecule_dictionary OWNER TO chembl;

--
-- Name: molecule_frac_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_frac_classification (
    mol_frac_id integer NOT NULL,
    frac_class_id integer NOT NULL,
    molregno integer NOT NULL
);


ALTER TABLE public.molecule_frac_classification OWNER TO chembl;

--
-- Name: molecule_hierarchy; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_hierarchy (
    molregno integer NOT NULL,
    active_molregno integer,
    parent_molregno integer
);


ALTER TABLE public.molecule_hierarchy OWNER TO chembl;

--
-- Name: molecule_hrac_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_hrac_classification (
    mol_hrac_id integer NOT NULL,
    hrac_class_id integer NOT NULL,
    molregno integer NOT NULL
);


ALTER TABLE public.molecule_hrac_classification OWNER TO chembl;

--
-- Name: molecule_irac_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_irac_classification (
    mol_irac_id integer NOT NULL,
    irac_class_id integer NOT NULL,
    molregno integer NOT NULL
);


ALTER TABLE public.molecule_irac_classification OWNER TO chembl;

--
-- Name: molecule_synonyms; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE molecule_synonyms (
    syn_type character varying(50) NOT NULL,
    molsyn_id integer NOT NULL,
    synonyms character varying(200),
    molregno integer NOT NULL,
    res_stem_id integer
);


ALTER TABLE public.molecule_synonyms OWNER TO chembl;

--
-- Name: organism_class; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE organism_class (
    oc_id integer NOT NULL,
    tax_id integer,
    l1 character varying(200),
    l2 character varying(200),
    l3 character varying(200),
    CONSTRAINT organism_class_tax_id_check CHECK ((tax_id >= 0)),
    CONSTRAINT organism_class_tax_id_check1 CHECK ((tax_id >= 0))
);


ALTER TABLE public.organism_class OWNER TO chembl;

--
-- Name: parameter_type; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE parameter_type (
    parameter_type character varying(20) NOT NULL,
    description character varying(2000)
);


ALTER TABLE public.parameter_type OWNER TO chembl;

--
-- Name: patent_use_codes; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE patent_use_codes (
    patent_use_code character varying(8) NOT NULL,
    definition character varying(500) NOT NULL
);


ALTER TABLE public.patent_use_codes OWNER TO chembl;

--
-- Name: predicted_binding_domains; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE predicted_binding_domains (
    predbind_id integer NOT NULL,
    prediction_method character varying(50),
    confidence character varying(10),
    activity_id integer,
    site_id integer,
    CONSTRAINT predicted_binding_domains_confidence_check CHECK (((confidence)::text = ANY ((ARRAY['high'::character varying, 'medium'::character varying, 'low'::character varying])::text[]))),
    CONSTRAINT predicted_binding_domains_prediction_method_check CHECK (((prediction_method)::text = ANY ((ARRAY['Manual'::character varying, 'Multi domain'::character varying, 'Single domain'::character varying])::text[])))
);


ALTER TABLE public.predicted_binding_domains OWNER TO chembl;

--
-- Name: product_patents; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE product_patents (
    prod_pat_id integer NOT NULL,
    patent_no character varying(11) NOT NULL,
    patent_expire_date date NOT NULL,
    drug_substance_flag smallint DEFAULT 0 NOT NULL,
    drug_product_flag smallint DEFAULT 0 NOT NULL,
    delist_flag smallint DEFAULT 0 NOT NULL,
    in_products integer DEFAULT 0 NOT NULL,
    patent_use_code character varying(8),
    product_id character varying(30) NOT NULL,
    CONSTRAINT product_patents_delist_flag_check CHECK ((delist_flag = ANY (ARRAY[0, 1]))),
    CONSTRAINT product_patents_drug_product_flag_check CHECK ((drug_product_flag = ANY (ARRAY[0, 1]))),
    CONSTRAINT product_patents_drug_substance_flag_check CHECK ((drug_substance_flag = ANY (ARRAY[0, 1]))),
    CONSTRAINT product_patents_in_products_check CHECK ((in_products >= 0)),
    CONSTRAINT product_patents_in_products_check1 CHECK ((in_products >= 0))
);


ALTER TABLE public.product_patents OWNER TO chembl;

--
-- Name: products; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE products (
    dosage_form character varying(200),
    route character varying(200),
    trade_name character varying(200),
    approval_date date,
    ad_type character varying(5),
    oral smallint,
    topical smallint,
    parenteral smallint,
    information_source character varying(100),
    black_box_warning smallint,
    product_class character varying(30),
    applicant_full_name character varying(200),
    innovator_company smallint,
    product_id character varying(30) NOT NULL,
    load_date date,
    removed_date date,
    nda_type character varying(10),
    tmp_ingred_count integer,
    exclude integer,
    CONSTRAINT products_ad_type_check CHECK (((ad_type)::text = ANY ((ARRAY['OTC'::character varying, 'RX'::character varying, 'DISCN'::character varying])::text[]))),
    CONSTRAINT products_black_box_warning_check CHECK (((black_box_warning = ANY (ARRAY[0, 1])) OR (black_box_warning IS NULL))),
    CONSTRAINT products_information_source_check CHECK (((information_source)::text = ANY (ARRAY[('CBER'::character varying)::text, ('CDER'::character varying)::text, ('MANUAL'::character varying)::text, ('ORANGE BOOK'::character varying)::text]))),
    CONSTRAINT products_innovator_company_check CHECK (((innovator_company = ANY (ARRAY[0, 1])) OR (innovator_company IS NULL))),
    CONSTRAINT products_nda_type_check CHECK (((nda_type)::text = ANY ((ARRAY['A'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT products_oral_check CHECK (((oral = ANY (ARRAY[0, 1])) OR (oral IS NULL))),
    CONSTRAINT products_parenteral_check CHECK (((parenteral = ANY (ARRAY[0, 1])) OR (parenteral IS NULL))),
    CONSTRAINT products_product_class_check CHECK (((product_class)::text = ANY (ARRAY[('VACCINE'::character varying)::text, ('ANTI-RHESIS ANTIBODY'::character varying)::text]))),
    CONSTRAINT products_tmp_ingred_count_check CHECK ((tmp_ingred_count >= 0)),
    CONSTRAINT products_tmp_ingred_count_check1 CHECK ((tmp_ingred_count >= 0)),
    CONSTRAINT products_topical_check CHECK (((topical = ANY (ARRAY[0, 1])) OR (topical IS NULL)))
);


ALTER TABLE public.products OWNER TO chembl;

--
-- Name: protein_class_synonyms; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE protein_class_synonyms (
    protclasssyn_id integer NOT NULL,
    protein_class_synonym character varying(1000),
    syn_type character varying(20),
    protein_class_id integer NOT NULL,
    CONSTRAINT protein_class_synonyms_syn_type_check CHECK (((syn_type)::text = ANY ((ARRAY['CHEMBL'::character varying, 'CONCEPT_WIKI'::character varying, 'UMLS'::character varying, 'CW_XREF'::character varying, 'MESH_XREF'::character varying])::text[])))
);


ALTER TABLE public.protein_class_synonyms OWNER TO chembl;

--
-- Name: protein_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE protein_classification (
    protein_class_id integer NOT NULL,
    parent_id integer,
    pref_name character varying(500),
    short_name character varying(50),
    protein_class_desc character varying(410) NOT NULL,
    definition character varying(4000),
    downgraded smallint,
    replaced_by integer,
    class_level integer NOT NULL,
    sort_order integer,
    CONSTRAINT protein_classification_class_level_check CHECK (((class_level >= 0) AND (class_level = ANY (ARRAY[0, 1, 2, 3, 4, 5, 6, 7, 8])))),
    CONSTRAINT protein_classification_class_level_check1 CHECK ((class_level >= 0)),
    CONSTRAINT protein_classification_downgraded_check CHECK (((downgraded = ANY (ARRAY[0, 1])) OR (downgraded IS NULL))),
    CONSTRAINT protein_classification_parent_id_check CHECK ((parent_id >= 0)),
    CONSTRAINT protein_classification_parent_id_check1 CHECK ((parent_id >= 0)),
    CONSTRAINT protein_classification_replaced_by_check CHECK ((replaced_by >= 0)),
    CONSTRAINT protein_classification_replaced_by_check1 CHECK ((replaced_by >= 0)),
    CONSTRAINT protein_classification_sort_order_check CHECK ((sort_order >= 0)),
    CONSTRAINT protein_classification_sort_order_check1 CHECK ((sort_order >= 0))
);


ALTER TABLE public.protein_classification OWNER TO chembl;

--
-- Name: protein_family_classification; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE protein_family_classification (
    protein_class_id integer NOT NULL,
    protein_class_desc character varying(810) NOT NULL,
    l1 character varying(100) NOT NULL,
    l2 character varying(100),
    l3 character varying(100),
    l4 character varying(100),
    l5 character varying(100),
    l6 character varying(100),
    l7 character varying(100),
    l8 character varying(100)
);


ALTER TABLE public.protein_family_classification OWNER TO chembl;

--
-- Name: record_drug_properties; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE record_drug_properties (
    record_id integer NOT NULL,
    max_phase integer DEFAULT 0 NOT NULL,
    withdrawn_status character varying(10),
    molecule_type character varying(30),
    first_approval integer,
    oral smallint DEFAULT 0 NOT NULL,
    parenteral smallint DEFAULT 0 NOT NULL,
    topical smallint DEFAULT 0 NOT NULL,
    black_box_warning smallint DEFAULT 0 NOT NULL,
    first_in_class smallint DEFAULT (-1) NOT NULL,
    chirality integer DEFAULT (-1) NOT NULL,
    prodrug smallint DEFAULT 0 NOT NULL,
    therapeutic_flag smallint DEFAULT 0 NOT NULL,
    natural_product smallint DEFAULT (-1) NOT NULL,
    inorganic_flag smallint DEFAULT 0 NOT NULL,
    applicants character varying(1000),
    usan_stem character varying(50),
    usan_year integer,
    availability_type integer,
    usan_substem character varying(50),
    indication_class character varying(1000),
    usan_stem_definition character varying(1000),
    polymer_flag smallint,
    CONSTRAINT record_drug_properties_availability_type_check CHECK ((availability_type = ANY (ARRAY[(-1), 0, 1, 2]))),
    CONSTRAINT record_drug_properties_black_box_warning_check CHECK ((black_box_warning = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT record_drug_properties_chirality_check CHECK ((chirality = ANY (ARRAY[(-1), 0, 1, 2]))),
    CONSTRAINT record_drug_properties_first_approval_check CHECK ((first_approval >= 0)),
    CONSTRAINT record_drug_properties_first_approval_check1 CHECK ((first_approval >= 0)),
    CONSTRAINT record_drug_properties_first_in_class_check CHECK ((first_in_class = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT record_drug_properties_inorganic_flag_check CHECK ((inorganic_flag = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT record_drug_properties_max_phase_check CHECK (((max_phase >= 0) AND (max_phase = ANY (ARRAY[0, 1, 2, 3, 4])))),
    CONSTRAINT record_drug_properties_max_phase_check1 CHECK ((max_phase >= 0)),
    CONSTRAINT record_drug_properties_molecule_type_check CHECK (((molecule_type)::text = ANY ((ARRAY['Antibody'::character varying, 'Cell'::character varying, 'Enzyme'::character varying, 'Oligonucleotide'::character varying, 'Oligosaccharide'::character varying, 'Protein'::character varying, 'Small molecule'::character varying, 'Unclassified'::character varying, 'Unknown'::character varying])::text[]))),
    CONSTRAINT record_drug_properties_natural_product_check CHECK ((natural_product = ANY (ARRAY[0, 1, (-1)]))),
    CONSTRAINT record_drug_properties_oral_check CHECK ((oral = ANY (ARRAY[0, 1]))),
    CONSTRAINT record_drug_properties_parenteral_check CHECK ((parenteral = ANY (ARRAY[0, 1]))),
    CONSTRAINT record_drug_properties_polymer_flag_check CHECK (((polymer_flag = ANY (ARRAY[0, 1])) OR (polymer_flag IS NULL))),
    CONSTRAINT record_drug_properties_prodrug_check CHECK ((prodrug = ANY (ARRAY[0, 1]))),
    CONSTRAINT record_drug_properties_therapeutic_flag_check CHECK ((therapeutic_flag = ANY (ARRAY[0, 1]))),
    CONSTRAINT record_drug_properties_topical_check CHECK ((topical = ANY (ARRAY[0, 1]))),
    CONSTRAINT record_drug_properties_usan_year_check CHECK ((usan_year >= 0)),
    CONSTRAINT record_drug_properties_usan_year_check1 CHECK ((usan_year >= 0))
);


ALTER TABLE public.record_drug_properties OWNER TO chembl;

--
-- Name: relationship_type; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE relationship_type (
    relationship_type character varying(1) NOT NULL,
    relationship_desc character varying(250)
);


ALTER TABLE public.relationship_type OWNER TO chembl;

--
-- Name: research_companies; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE research_companies (
    co_stem_id integer NOT NULL,
    company character varying(100),
    country character varying(50),
    previous_company character varying(100),
    res_stem_id integer
);


ALTER TABLE public.research_companies OWNER TO chembl;

--
-- Name: research_stem; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE research_stem (
    res_stem_id integer NOT NULL,
    research_stem character varying(20)
);


ALTER TABLE public.research_stem OWNER TO chembl;

--
-- Name: site_components; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE site_components (
    sitecomp_id integer NOT NULL,
    site_residues character varying(2000),
    component_id integer,
    domain_id integer,
    site_id integer NOT NULL
);


ALTER TABLE public.site_components OWNER TO chembl;

--
-- Name: source; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE source (
    src_id integer NOT NULL,
    src_description character varying(500),
    src_short_name character varying(20)
);


ALTER TABLE public.source OWNER TO chembl;

--
-- Name: structural_alert_sets; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE structural_alert_sets (
    alert_set_id integer NOT NULL,
    set_name character varying(100) NOT NULL,
    priority integer NOT NULL,
    CONSTRAINT structural_alert_sets_alert_set_id_check CHECK (((alert_set_id >= 0) AND (alert_set_id = ANY (ARRAY[1, 2, 3, 4, 5, 6, 7, 8])))),
    CONSTRAINT structural_alert_sets_alert_set_id_check1 CHECK ((alert_set_id >= 0)),
    CONSTRAINT structural_alert_sets_priority_check CHECK (((priority >= 0) AND (priority = ANY (ARRAY[1, 2, 3, 4, 5, 6, 7, 8])))),
    CONSTRAINT structural_alert_sets_priority_check1 CHECK ((priority >= 0)),
    CONSTRAINT structural_alert_sets_set_name_check CHECK (((set_name)::text = ANY ((ARRAY['BMS'::character varying, 'Dundee'::character varying, 'Glaxo'::character varying, 'Inpharmatica'::character varying, 'LINT'::character varying, 'MLSMR'::character varying, 'PAINS'::character varying, 'SureChEMBL'::character varying])::text[])))
);


ALTER TABLE public.structural_alert_sets OWNER TO chembl;

--
-- Name: structural_alerts; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE structural_alerts (
    alert_id integer NOT NULL,
    alert_name character varying(100) NOT NULL,
    smarts character varying(4000) NOT NULL,
    alert_set_id integer NOT NULL,
    CONSTRAINT structural_alerts_alert_id_check CHECK ((alert_id >= 0)),
    CONSTRAINT structural_alerts_alert_id_check1 CHECK ((alert_id >= 0)),
    CONSTRAINT structural_alerts_alert_set_id_check CHECK (((alert_set_id >= 0) AND (alert_set_id = ANY (ARRAY[1, 2, 3, 4, 5, 6, 7, 8]))))
);


ALTER TABLE public.structural_alerts OWNER TO chembl;

--
-- Name: target_components; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE target_components (
    relationship character varying(20) DEFAULT 'SUBUNIT'::character varying NOT NULL,
    stoichiometry integer,
    targcomp_id integer NOT NULL,
    homologue integer DEFAULT 0 NOT NULL,
    component_id integer NOT NULL,
    tid integer NOT NULL,
    CONSTRAINT target_components_homologue_check CHECK (((homologue >= 0) AND (homologue = ANY (ARRAY[0, 1, 2])))),
    CONSTRAINT target_components_homologue_check1 CHECK ((homologue >= 0)),
    CONSTRAINT target_components_relationship_check CHECK (((relationship)::text = ANY (ARRAY[('COMPARATIVE PROTEIN'::character varying)::text, ('EQUIVALENT PROTEIN'::character varying)::text, ('FUSION PROTEIN'::character varying)::text, ('GROUP MEMBER'::character varying)::text, ('INTERACTING PROTEIN'::character varying)::text, ('PROTEIN SUBUNIT'::character varying)::text, ('RNA'::character varying)::text, ('RNA SUBUNIT'::character varying)::text, ('SINGLE PROTEIN'::character varying)::text, ('UNCURATED'::character varying)::text, ('SUBUNIT'::character varying)::text]))),
    CONSTRAINT target_components_stoichiometry_check CHECK (((stoichiometry >= 0) AND (stoichiometry = ANY (ARRAY[0, 1, 2, 3, 12])))),
    CONSTRAINT target_components_stoichiometry_check1 CHECK ((stoichiometry >= 0))
);


ALTER TABLE public.target_components OWNER TO chembl;

--
-- Name: target_dictionary; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE target_dictionary (
    tid integer NOT NULL,
    pref_name character varying(200) NOT NULL,
    tax_id integer,
    organism character varying(150),
    updated_on date,
    updated_by character varying(100),
    insert_date date DEFAULT ('now'::text)::date,
    target_parent_type character varying(100),
    species_group_flag smallint,
    downgraded smallint DEFAULT 0,
    chembl_id character varying(20) NOT NULL,
    target_type character varying(30),
    CONSTRAINT target_dictionary_downgraded_check CHECK (((downgraded = ANY (ARRAY[0, 1])) OR (downgraded IS NULL))),
    CONSTRAINT target_dictionary_species_group_flag_check CHECK (((species_group_flag = ANY (ARRAY[0, 1])) OR (species_group_flag IS NULL))),
    CONSTRAINT target_dictionary_target_parent_type_check CHECK (((target_parent_type)::text = ANY ((ARRAY['MOLECULAR'::character varying, 'NON-MOLECULAR'::character varying, 'PROTEIN'::character varying, 'UNDEFINED'::character varying])::text[]))),
    CONSTRAINT target_dictionary_tax_id_check CHECK ((tax_id >= 0)),
    CONSTRAINT target_dictionary_tax_id_check1 CHECK ((tax_id >= 0))
);


ALTER TABLE public.target_dictionary OWNER TO chembl;

--
-- Name: target_relations; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE target_relations (
    relationship character varying(20) NOT NULL,
    targrel_id integer NOT NULL,
    related_tid integer NOT NULL,
    tid integer NOT NULL,
    CONSTRAINT target_relations_relationship_check CHECK (((relationship)::text = ANY ((ARRAY['EQUIVALENT TO'::character varying, 'OVERLAPS WITH'::character varying, 'SUBSET OF'::character varying, 'SUPERSET OF'::character varying])::text[]))),
    CONSTRAINT target_relations_targrel_id_check CHECK ((targrel_id >= 0)),
    CONSTRAINT target_relations_targrel_id_check1 CHECK ((targrel_id >= 0))
);


ALTER TABLE public.target_relations OWNER TO chembl;

--
-- Name: target_type; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE target_type (
    target_type character varying(30) NOT NULL,
    target_desc character varying(250),
    parent_type character varying(25)
);


ALTER TABLE public.target_type OWNER TO chembl;

--
-- Name: tastypie_apiaccess; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE tastypie_apiaccess (
    id integer NOT NULL,
    identifier character varying(255) NOT NULL,
    url character varying(255) NOT NULL,
    request_method character varying(10) NOT NULL,
    accessed integer NOT NULL,
    CONSTRAINT tastypie_apiaccess_accessed_check CHECK ((accessed >= 0))
);


ALTER TABLE public.tastypie_apiaccess OWNER TO chembl;

--
-- Name: tastypie_apiaccess_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE tastypie_apiaccess_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tastypie_apiaccess_id_seq OWNER TO chembl;

--
-- Name: tastypie_apiaccess_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE tastypie_apiaccess_id_seq OWNED BY tastypie_apiaccess.id;


--
-- Name: tastypie_apikey; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE tastypie_apikey (
    id integer NOT NULL,
    key character varying(128) NOT NULL,
    created timestamp with time zone NOT NULL,
    user_id integer NOT NULL
);


ALTER TABLE public.tastypie_apikey OWNER TO chembl;

--
-- Name: tastypie_apikey_id_seq; Type: SEQUENCE; Schema: public; Owner: chembl
--

CREATE SEQUENCE tastypie_apikey_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tastypie_apikey_id_seq OWNER TO chembl;

--
-- Name: tastypie_apikey_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: chembl
--

ALTER SEQUENCE tastypie_apikey_id_seq OWNED BY tastypie_apikey.id;


--
-- Name: usan_stems; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE usan_stems (
    usan_stem_id integer NOT NULL,
    stem character varying(100) NOT NULL,
    subgroup character varying(100) NOT NULL,
    annotation character varying(2000),
    stem_class character varying(100),
    major_class character varying(100),
    who_extra smallint DEFAULT 0,
    downgraded smallint DEFAULT 0,
    CONSTRAINT usan_stems_downgraded_check CHECK (((downgraded = ANY (ARRAY[0, 1])) OR (downgraded IS NULL))),
    CONSTRAINT usan_stems_major_class_check CHECK (((major_class)::text = ANY ((ARRAY['GPCR'::character varying, 'NR'::character varying, 'PDE'::character varying, 'ion channel'::character varying, 'kinase'::character varying, 'protease'::character varying])::text[]))),
    CONSTRAINT usan_stems_stem_class_check CHECK (((stem_class)::text = ANY ((ARRAY['Suffix'::character varying, 'Prefix'::character varying, 'Infix'::character varying])::text[]))),
    CONSTRAINT usan_stems_usan_stem_id_check CHECK ((usan_stem_id >= 0)),
    CONSTRAINT usan_stems_usan_stem_id_check1 CHECK ((usan_stem_id >= 0)),
    CONSTRAINT usan_stems_who_extra_check CHECK (((who_extra = ANY (ARRAY[0, 1])) OR (who_extra IS NULL)))
);


ALTER TABLE public.usan_stems OWNER TO chembl;

--
-- Name: version; Type: TABLE; Schema: public; Owner: chembl; Tablespace: 
--

CREATE TABLE version (
    name character varying(20) NOT NULL,
    creation_date date,
    comments character varying(2000)
);


ALTER TABLE public.version OWNER TO chembl;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_group ALTER COLUMN id SET DEFAULT nextval('auth_group_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('auth_group_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_permission ALTER COLUMN id SET DEFAULT nextval('auth_permission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user ALTER COLUMN id SET DEFAULT nextval('auth_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user_groups ALTER COLUMN id SET DEFAULT nextval('auth_user_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user_user_permissions ALTER COLUMN id SET DEFAULT nextval('auth_user_user_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_id_generator_cbhcompoundid ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_id_generator_cbhcompoundid_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_id_generator_cbhplugin ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_id_generator_cbhplugin_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundbatch ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_cbhcompoundbatch_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundmultiplebatch ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_customfieldconfig ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_customfieldconfig_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig ALTER COLUMN id SET DEFAULT nextval('cbh_core_model_dataformconfig_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_datatype ALTER COLUMN id SET DEFAULT nextval('cbh_core_model_datatype_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_pinnedcustomfield ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_pinnedcustomfield_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_project_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project_enabled_forms ALTER COLUMN id SET DEFAULT nextval('cbh_core_model_project_enabled_forms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_projecttype ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_projecttype_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_skinningconfig ALTER COLUMN id SET DEFAULT nextval('cbh_chembl_model_extension_skinningconfig_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_attachment ALTER COLUMN id SET DEFAULT nextval('cbh_datastore_model_attachment_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapoint ALTER COLUMN id SET DEFAULT nextval('cbh_datastore_model_datapoint_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification ALTER COLUMN id SET DEFAULT nextval('cbh_datastore_model_datapointclassification_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassificationpermission ALTER COLUMN id SET DEFAULT nextval('cbh_datastore_model_datapointclassificationpermission_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_query ALTER COLUMN id SET DEFAULT nextval('cbh_datastore_model_query_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY chembl_business_model_djangocheatsheet ALTER COLUMN id SET DEFAULT nextval('chembl_business_model_djangocheatsheet_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY chembl_business_model_imageerrors ALTER COLUMN id SET DEFAULT nextval('chembl_business_model_imageerrors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY chembl_business_model_inchierrors ALTER COLUMN id SET DEFAULT nextval('chembl_business_model_inchierrors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY django_admin_log ALTER COLUMN id SET DEFAULT nextval('django_admin_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY django_content_type ALTER COLUMN id SET DEFAULT nextval('django_content_type_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY django_migrations ALTER COLUMN id SET DEFAULT nextval('django_migrations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY django_site ALTER COLUMN id SET DEFAULT nextval('django_site_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY flowjs_flowfile ALTER COLUMN id SET DEFAULT nextval('flowjs_flowfile_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY flowjs_flowfilechunk ALTER COLUMN id SET DEFAULT nextval('flowjs_flowfilechunk_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY tastypie_apiaccess ALTER COLUMN id SET DEFAULT nextval('tastypie_apiaccess_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY tastypie_apikey ALTER COLUMN id SET DEFAULT nextval('tastypie_apikey_id_seq'::regclass);


--
-- Data for Name: action_type; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY action_type (action_type, description, parent_type) FROM stdin;
\.


--
-- Data for Name: activities; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY activities (activity_id, standard_relation, published_value, published_units, standard_value, standard_units, standard_flag, standard_type, updated_by, updated_on, activity_comment, published_type, manual_curation_flag, potential_duplicate, published_relation, original_activity_id, pchembl_value, bao_endpoint, uo_units, qudt_units, assay_id, data_validity_comment, doc_id, molregno, record_id) FROM stdin;
\.


--
-- Data for Name: activity_stds_lookup; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY activity_stds_lookup (std_act_id, standard_type, definition, standard_units, normal_range_min, normal_range_max) FROM stdin;
\.


--
-- Data for Name: assay_parameters; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY assay_parameters (assay_param_id, parameter_value, assay_id, parameter_type) FROM stdin;
\.


--
-- Data for Name: assay_type; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY assay_type (assay_type, assay_desc) FROM stdin;
\.


--
-- Data for Name: assays; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY assays (assay_id, description, assay_test_type, assay_category, assay_organism, assay_tax_id, assay_strain, assay_tissue, assay_cell_type, assay_subcellular_fraction, activity_count, assay_source, src_assay_id, updated_on, updated_by, orig_description, a2t_complex, a2t_multi, mc_tax_id, mc_organism, mc_target_type, mc_target_name, mc_target_accession, a2t_assay_tax_id, a2t_assay_organism, a2t_updated_on, a2t_updated_by, bao_format, assay_type, cell_id, chembl_id, confidence_score, curated_by, doc_id, relationship_type, src_id, tid) FROM stdin;
\.


--
-- Data for Name: atc_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY atc_classification (who_name, level1, level2, level3, level4, level5, who_id, level1_description, level2_description, level3_description, level4_description) FROM stdin;
\.


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY auth_group (id, name) FROM stdin;
\.


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('auth_group_id_seq', 1, false);


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('auth_group_permissions_id_seq', 1, false);


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add project type	1	add_projecttype
2	Can change project type	1	change_projecttype
3	Can delete project type	1	delete_projecttype
4	Can add data type	2	add_datatype
5	Can change data type	2	change_datatype
6	Can delete data type	2	delete_datatype
7	Can add custom field config	3	add_customfieldconfig
8	Can change custom field config	3	change_customfieldconfig
9	Can delete custom field config	3	delete_customfieldconfig
10	Can add data form config	4	add_dataformconfig
11	Can change data form config	4	change_dataformconfig
12	Can delete data form config	4	delete_dataformconfig
13	Can add project	5	add_project
14	Can change project	5	change_project
15	Can delete project	5	delete_project
16	Can add Skinning Configuration	6	add_skinningconfig
17	Can change Skinning Configuration	6	change_skinningconfig
18	Can delete Skinning Configuration	6	delete_skinningconfig
19	Can add pinned custom field	7	add_pinnedcustomfield
20	Can change pinned custom field	7	change_pinnedcustomfield
21	Can delete pinned custom field	7	delete_pinnedcustomfield
22	Can add attachment	8	add_attachment
23	Can change attachment	8	change_attachment
24	Can delete attachment	8	delete_attachment
25	Can add data point	9	add_datapoint
26	Can change data point	9	change_datapoint
27	Can delete data point	9	delete_datapoint
28	Can add data point classification	10	add_datapointclassification
29	Can change data point classification	10	change_datapointclassification
30	Can delete data point classification	10	delete_datapointclassification
31	Can add data point classification permission	11	add_datapointclassificationpermission
32	Can change data point classification permission	11	change_datapointclassificationpermission
33	Can delete data point classification permission	11	delete_datapointclassificationpermission
34	Can add query	12	add_query
35	Can change query	12	change_query
36	Can delete query	12	delete_query
37	Can add api access	13	add_apiaccess
38	Can change api access	13	change_apiaccess
39	Can delete api access	13	delete_apiaccess
40	Can add api key	14	add_apikey
41	Can change api key	14	change_apikey
42	Can delete api key	14	delete_apikey
43	Can add permission	15	add_permission
44	Can change permission	15	change_permission
45	Can delete permission	15	delete_permission
46	Can add group	16	add_group
47	Can change group	16	change_group
48	Can delete group	16	delete_group
49	Can add user	17	add_user
50	Can change user	17	change_user
51	Can delete user	17	delete_user
52	Can add content type	18	add_contenttype
53	Can change content type	18	change_contenttype
54	Can delete content type	18	delete_contenttype
55	Can add session	19	add_session
56	Can change session	19	change_session
57	Can delete session	19	delete_session
58	Can add site	20	add_site
59	Can change site	20	change_site
60	Can delete site	20	delete_site
61	Can add log entry	21	add_logentry
62	Can change log entry	21	change_logentry
63	Can delete log entry	21	delete_logentry
64	Can add version	22	add_version
65	Can change version	22	change_version
66	Can delete version	22	delete_version
67	Can add chembl id lookup	23	add_chemblidlookup
68	Can change chembl id lookup	23	change_chemblidlookup
69	Can delete chembl id lookup	23	delete_chemblidlookup
70	Can add source	24	add_source
71	Can change source	24	change_source
72	Can delete source	24	delete_source
73	Can add journals	25	add_journals
74	Can change journals	25	change_journals
75	Can delete journals	25	delete_journals
76	Can add docs	26	add_docs
77	Can change docs	26	change_docs
78	Can delete docs	26	delete_docs
79	Can add journal articles	27	add_journalarticles
80	Can change journal articles	27	change_journalarticles
81	Can delete journal articles	27	delete_journalarticles
82	Can add research stem	28	add_researchstem
83	Can change research stem	28	change_researchstem
84	Can delete research stem	28	delete_researchstem
85	Can add structural alert sets	29	add_structuralalertsets
86	Can change structural alert sets	29	change_structuralalertsets
87	Can delete structural alert sets	29	delete_structuralalertsets
88	Can add bio component sequences	30	add_biocomponentsequences
89	Can change bio component sequences	30	change_biocomponentsequences
90	Can delete bio component sequences	30	delete_biocomponentsequences
91	Can add molecule dictionary	31	add_moleculedictionary
92	Can change molecule dictionary	31	change_moleculedictionary
93	Can delete molecule dictionary	31	delete_moleculedictionary
94	Can add research companies	32	add_researchcompanies
95	Can change research companies	32	change_researchcompanies
96	Can delete research companies	32	delete_researchcompanies
97	Can add structural alerts	33	add_structuralalerts
98	Can change structural alerts	33	change_structuralalerts
99	Can delete structural alerts	33	delete_structuralalerts
100	Can add compound properties	34	add_compoundproperties
101	Can change compound properties	34	change_compoundproperties
102	Can delete compound properties	34	delete_compoundproperties
103	Can add compound records	35	add_compoundrecords
104	Can change compound records	35	change_compoundrecords
105	Can delete compound records	35	delete_compoundrecords
106	Can add record drug properties	36	add_recorddrugproperties
107	Can change record drug properties	36	change_recorddrugproperties
108	Can delete record drug properties	36	delete_recorddrugproperties
109	Can add molecule hierarchy	37	add_moleculehierarchy
110	Can change molecule hierarchy	37	change_moleculehierarchy
111	Can delete molecule hierarchy	37	delete_moleculehierarchy
112	Can add molecule synonyms	38	add_moleculesynonyms
113	Can change molecule synonyms	38	change_moleculesynonyms
114	Can delete molecule synonyms	38	delete_moleculesynonyms
115	Can add biotherapeutics	39	add_biotherapeutics
116	Can change biotherapeutics	39	change_biotherapeutics
117	Can delete biotherapeutics	39	delete_biotherapeutics
118	Can add compound structural alerts	40	add_compoundstructuralalerts
119	Can change compound structural alerts	40	change_compoundstructuralalerts
120	Can delete compound structural alerts	40	delete_compoundstructuralalerts
121	Can add compound images	41	add_compoundimages
122	Can change compound images	41	change_compoundimages
123	Can delete compound images	41	delete_compoundimages
124	Can add compound mols	42	add_compoundmols
125	Can change compound mols	42	change_compoundmols
126	Can delete compound mols	42	delete_compoundmols
127	Can add compound structures	43	add_compoundstructures
128	Can change compound structures	43	change_compoundstructures
129	Can delete compound structures	43	delete_compoundstructures
130	Can add biotherapeutic components	44	add_biotherapeuticcomponents
131	Can change biotherapeutic components	44	change_biotherapeuticcomponents
132	Can delete biotherapeutic components	44	delete_biotherapeuticcomponents
133	Can add target type	45	add_targettype
134	Can change target type	45	change_targettype
135	Can delete target type	45	delete_targettype
136	Can add organism class	46	add_organismclass
137	Can change organism class	46	change_organismclass
138	Can delete organism class	46	delete_organismclass
139	Can add protein family classification	47	add_proteinfamilyclassification
140	Can change protein family classification	47	change_proteinfamilyclassification
141	Can delete protein family classification	47	delete_proteinfamilyclassification
142	Can add protein classification	48	add_proteinclassification
143	Can change protein classification	48	change_proteinclassification
144	Can delete protein classification	48	delete_proteinclassification
145	Can add component sequences	49	add_componentsequences
146	Can change component sequences	49	change_componentsequences
147	Can delete component sequences	49	delete_componentsequences
148	Can add target dictionary	50	add_targetdictionary
149	Can change target dictionary	50	change_targetdictionary
150	Can delete target dictionary	50	delete_targetdictionary
151	Can add component class	51	add_componentclass
152	Can change component class	51	change_componentclass
153	Can delete component class	51	delete_componentclass
154	Can add component synonyms	52	add_componentsynonyms
155	Can change component synonyms	52	change_componentsynonyms
156	Can delete component synonyms	52	delete_componentsynonyms
157	Can add cell dictionary	53	add_celldictionary
158	Can change cell dictionary	53	change_celldictionary
159	Can delete cell dictionary	53	delete_celldictionary
160	Can add protein class synonyms	54	add_proteinclasssynonyms
161	Can change protein class synonyms	54	change_proteinclasssynonyms
162	Can delete protein class synonyms	54	delete_proteinclasssynonyms
163	Can add target components	55	add_targetcomponents
164	Can change target components	55	change_targetcomponents
165	Can delete target components	55	delete_targetcomponents
166	Can add target relations	56	add_targetrelations
167	Can change target relations	56	change_targetrelations
168	Can delete target relations	56	delete_targetrelations
169	Can add domains	57	add_domains
170	Can change domains	57	change_domains
171	Can delete domains	57	delete_domains
172	Can add component domains	58	add_componentdomains
173	Can change component domains	58	change_componentdomains
174	Can delete component domains	58	delete_componentdomains
175	Can add binding sites	59	add_bindingsites
176	Can change binding sites	59	change_bindingsites
177	Can delete binding sites	59	delete_bindingsites
178	Can add site components	60	add_sitecomponents
179	Can change site components	60	change_sitecomponents
180	Can delete site components	60	delete_sitecomponents
181	Can add assay type	61	add_assaytype
182	Can change assay type	61	change_assaytype
183	Can delete assay type	61	delete_assaytype
184	Can add relationship type	62	add_relationshiptype
185	Can change relationship type	62	change_relationshiptype
186	Can delete relationship type	62	delete_relationshiptype
187	Can add confidence score lookup	63	add_confidencescorelookup
188	Can change confidence score lookup	63	change_confidencescorelookup
189	Can delete confidence score lookup	63	delete_confidencescorelookup
190	Can add curation lookup	64	add_curationlookup
191	Can change curation lookup	64	change_curationlookup
192	Can delete curation lookup	64	delete_curationlookup
193	Can add activity stds lookup	65	add_activitystdslookup
194	Can change activity stds lookup	65	change_activitystdslookup
195	Can delete activity stds lookup	65	delete_activitystdslookup
196	Can add data validity lookup	66	add_datavaliditylookup
197	Can change data validity lookup	66	change_datavaliditylookup
198	Can delete data validity lookup	66	delete_datavaliditylookup
199	Can add parameter type	67	add_parametertype
200	Can change parameter type	67	change_parametertype
201	Can delete parameter type	67	delete_parametertype
202	Can add assays	68	add_assays
203	Can change assays	68	change_assays
204	Can delete assays	68	delete_assays
205	Can add activities	69	add_activities
206	Can change activities	69	change_activities
207	Can delete activities	69	delete_activities
208	Can add assay parameters	70	add_assayparameters
209	Can change assay parameters	70	change_assayparameters
210	Can delete assay parameters	70	delete_assayparameters
211	Can add products	71	add_products
212	Can change products	71	change_products
213	Can delete products	71	delete_products
214	Can add atc classification	72	add_atcclassification
215	Can change atc classification	72	change_atcclassification
216	Can delete atc classification	72	delete_atcclassification
217	Can add usan stems	73	add_usanstems
218	Can change usan stems	73	change_usanstems
219	Can delete usan stems	73	delete_usanstems
220	Can add hrac classification	74	add_hracclassification
221	Can change hrac classification	74	change_hracclassification
222	Can delete hrac classification	74	delete_hracclassification
223	Can add irac classification	75	add_iracclassification
224	Can change irac classification	75	change_iracclassification
225	Can delete irac classification	75	delete_iracclassification
226	Can add frac classification	76	add_fracclassification
227	Can change frac classification	76	change_fracclassification
228	Can delete frac classification	76	delete_fracclassification
229	Can add patent use codes	77	add_patentusecodes
230	Can change patent use codes	77	change_patentusecodes
231	Can delete patent use codes	77	delete_patentusecodes
232	Can add defined daily dose	78	add_defineddailydose
233	Can change defined daily dose	78	change_defineddailydose
234	Can delete defined daily dose	78	delete_defineddailydose
235	Can add product patents	79	add_productpatents
236	Can change product patents	79	change_productpatents
237	Can delete product patents	79	delete_productpatents
238	Can add molecule atc classification	80	add_moleculeatcclassification
239	Can change molecule atc classification	80	change_moleculeatcclassification
240	Can delete molecule atc classification	80	delete_moleculeatcclassification
241	Can add molecule irac classification	81	add_moleculeiracclassification
242	Can change molecule irac classification	81	change_moleculeiracclassification
243	Can delete molecule irac classification	81	delete_moleculeiracclassification
244	Can add molecule frac classification	82	add_moleculefracclassification
245	Can change molecule frac classification	82	change_moleculefracclassification
246	Can delete molecule frac classification	82	delete_moleculefracclassification
247	Can add molecule hrac classification	83	add_moleculehracclassification
248	Can change molecule hrac classification	83	change_moleculehracclassification
249	Can delete molecule hrac classification	83	delete_moleculehracclassification
250	Can add formulations	84	add_formulations
251	Can change formulations	84	change_formulations
252	Can delete formulations	84	delete_formulations
253	Can add action type	85	add_actiontype
254	Can change action type	85	change_actiontype
255	Can delete action type	85	delete_actiontype
256	Can add drug mechanism	86	add_drugmechanism
257	Can change drug mechanism	86	change_drugmechanism
258	Can delete drug mechanism	86	delete_drugmechanism
259	Can add ligand eff	87	add_ligandeff
260	Can change ligand eff	87	change_ligandeff
261	Can delete ligand eff	87	delete_ligandeff
262	Can add predicted binding domains	88	add_predictedbindingdomains
263	Can change predicted binding domains	88	change_predictedbindingdomains
264	Can delete predicted binding domains	88	delete_predictedbindingdomains
265	Can add mechanism refs	89	add_mechanismrefs
266	Can change mechanism refs	89	change_mechanismrefs
267	Can delete mechanism refs	89	delete_mechanismrefs
268	Can add inchi errors	90	add_inchierrors
269	Can change inchi errors	90	change_inchierrors
270	Can delete inchi errors	90	delete_inchierrors
271	Can add image errors	91	add_imageerrors
272	Can change image errors	91	change_imageerrors
273	Can delete image errors	91	delete_imageerrors
274	Can add django cheat sheet	92	add_djangocheatsheet
275	Can change django cheat sheet	92	change_djangocheatsheet
276	Can delete django cheat sheet	92	delete_djangocheatsheet
277	Can add sdf	93	add_sdf
278	Can change sdf	93	change_sdf
279	Can delete sdf	93	delete_sdf
280	Can add flow file	151	add_flowfile
281	Can change flow file	151	change_flowfile
282	Can delete flow file	151	delete_flowfile
283	Can add flow file chunk	152	add_flowfilechunk
284	Can change flow file chunk	152	change_flowfilechunk
285	Can delete flow file chunk	152	delete_flowfilechunk
286	Can add cbh compound multiple batch	153	add_cbhcompoundmultiplebatch
287	Can change cbh compound multiple batch	153	change_cbhcompoundmultiplebatch
288	Can delete cbh compound multiple batch	153	delete_cbhcompoundmultiplebatch
289	Can add cbh compound batch	154	add_cbhcompoundbatch
290	Can change cbh compound batch	154	change_cbhcompoundbatch
291	Can delete cbh compound batch	154	delete_cbhcompoundbatch
292	Can add chemreg project	5	add_chemregproject
293	Can change chemreg project	5	change_chemregproject
294	Can delete chemreg project	5	delete_chemregproject
295	Can add cbh plugin	156	add_cbhplugin
296	Can change cbh plugin	156	change_cbhplugin
297	Can delete cbh plugin	156	delete_cbhplugin
298	Can add cbh compound id	157	add_cbhcompoundid
299	Can change cbh compound id	157	change_cbhcompoundid
300	Can delete cbh compound id	157	delete_cbhcompoundid
\.


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('auth_permission_id_seq', 300, true);


--
-- Data for Name: auth_user; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY auth_user (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined) FROM stdin;
-1		2015-10-22 16:00:26.704063+01	f	-1				f	t	2015-10-22 16:00:26.704114+01
\.


--
-- Data for Name: auth_user_groups; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY auth_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Name: auth_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('auth_user_groups_id_seq', 1, false);


--
-- Name: auth_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('auth_user_id_seq', 1, false);


--
-- Data for Name: auth_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY auth_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Name: auth_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('auth_user_user_permissions_id_seq', 1, false);


--
-- Data for Name: binding_sites; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY binding_sites (site_id, site_name, tid) FROM stdin;
\.


--
-- Data for Name: bio_component_sequences; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY bio_component_sequences (component_id, component_type, description, sequence, sequence_md5sum, tax_id, organism, updated_on, updated_by, insert_date, accession, db_source, db_version) FROM stdin;
\.


--
-- Data for Name: biotherapeutic_components; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY biotherapeutic_components (biocomp_id, molregno, component_id) FROM stdin;
\.


--
-- Data for Name: biotherapeutics; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY biotherapeutics (molregno, description, helm_notation) FROM stdin;
\.


--
-- Data for Name: cbh_chembl_id_generator_cbhcompoundid; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_chembl_id_generator_cbhcompoundid (id, structure_key, assigned_id, original_installation_key, current_batch_id) FROM stdin;
\.


--
-- Name: cbh_chembl_id_generator_cbhcompoundid_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_id_generator_cbhcompoundid_id_seq', 1, false);


--
-- Data for Name: cbh_chembl_id_generator_cbhplugin; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_chembl_id_generator_cbhplugin (id, full_function_name, plugin_type, input_json_path, name) FROM stdin;
\.


--
-- Name: cbh_chembl_id_generator_cbhplugin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_id_generator_cbhplugin_id_seq', 1, false);


--
-- Data for Name: cbh_chembl_model_extension_cbhcompoundbatch; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_chembl_model_extension_cbhcompoundbatch (id, created, modified, ctab, std_ctab, canonical_smiles, original_smiles, editable_by, uncurated_fields, created_by, standard_inchi, standard_inchi_key, warnings, properties, custom_fields, errors, multiple_batch_id, project_id, related_molregno_id, batch_number, blinded_batch_id) FROM stdin;
\.


--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_cbhcompoundbatch_id_seq', 1, false);


--
-- Data for Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_chembl_model_extension_cbhcompoundmultiplebatch (id, created, modified, created_by, uploaded_data, uploaded_file_id, project_id, saved) FROM stdin;
\.


--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_cbhcompoundmultiplebatch_id_seq', 1, false);


--
-- Name: cbh_chembl_model_extension_customfieldconfig_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_customfieldconfig_id_seq', 1, false);


--
-- Name: cbh_chembl_model_extension_pinnedcustomfield_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_pinnedcustomfield_id_seq', 1, false);


--
-- Name: cbh_chembl_model_extension_project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_project_id_seq', 1, false);


--
-- Name: cbh_chembl_model_extension_projecttype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_projecttype_id_seq', 3, true);


--
-- Name: cbh_chembl_model_extension_skinningconfig_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_chembl_model_extension_skinningconfig_id_seq', 1, false);


--
-- Data for Name: cbh_core_model_customfieldconfig; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_customfieldconfig (id, created, modified, name, created_by_id, schemaform, data_type_id) FROM stdin;
-1	2015-10-22 16:00:26.706356+01	2015-10-22 16:00:26.706592+01	-1 default do not delete	-1		\N
\.


--
-- Data for Name: cbh_core_model_dataformconfig; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_dataformconfig (id, created, modified, created_by_id, l0_id, l1_id, l2_id, l3_id, l4_id, human_added, parent_id) FROM stdin;
\.


--
-- Name: cbh_core_model_dataformconfig_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_core_model_dataformconfig_id_seq', 1, false);


--
-- Data for Name: cbh_core_model_datatype; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_datatype (id, created, modified, name, uri, version) FROM stdin;
1	2015-10-22 16:00:16.741487+01	2015-10-22 16:00:16.741672+01	Assay		
2	2015-10-22 16:00:16.743424+01	2015-10-22 16:00:16.743582+01	Activity		
3	2015-10-22 16:00:16.744441+01	2015-10-22 16:00:16.744587+01	Study		
4	2015-10-22 16:00:20.299324+01	2015-10-22 16:00:20.300053+01	Project		
5	2015-10-22 16:00:20.302629+01	2015-10-22 16:00:20.303355+01	Sub-Project		
\.


--
-- Name: cbh_core_model_datatype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_core_model_datatype_id_seq', 5, true);


--
-- Data for Name: cbh_core_model_pinnedcustomfield; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_pinnedcustomfield (id, created, modified, name, required, part_of_blinded_key, field_type, allowed_values, custom_field_config_id, "position", description, field_key, "default", pinned_for_datatype_id, standardised_alias_id, attachment_field_mapped_to_id) FROM stdin;
\.


--
-- Data for Name: cbh_core_model_project; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_project (id, created, modified, name, project_key, created_by_id, custom_field_config_id, is_default, project_type_id) FROM stdin;
\.


--
-- Data for Name: cbh_core_model_project_enabled_forms; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_project_enabled_forms (id, project_id, dataformconfig_id) FROM stdin;
\.


--
-- Name: cbh_core_model_project_enabled_forms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_core_model_project_enabled_forms_id_seq', 1, false);


--
-- Data for Name: cbh_core_model_projecttype; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_projecttype (id, created, modified, name, show_compounds) FROM stdin;
1	2015-10-22 16:00:20.309699+01	2015-10-22 16:00:20.310403+01	chemical	t
2	2015-10-22 16:00:20.313852+01	2015-10-22 16:00:20.31453+01	assay	t
3	2015-10-22 16:00:20.316872+01	2015-10-22 16:00:20.317593+01	inventory	t
\.


--
-- Data for Name: cbh_core_model_skinningconfig; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_core_model_skinningconfig (id, instance_alias, project_alias, result_alias) FROM stdin;
\.


--
-- Data for Name: cbh_datastore_model_attachment; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_datastore_model_attachment (id, created, modified, sheet_name, attachment_custom_field_config_id, chosen_data_form_config_id, created_by_id, data_point_classification_id, flowfile_id, number_of_rows) FROM stdin;
\.


--
-- Name: cbh_datastore_model_attachment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_datastore_model_attachment_id_seq', 1, false);


--
-- Data for Name: cbh_datastore_model_datapoint; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_datastore_model_datapoint (id, created, modified, project_data, supplementary_data, created_by_id, custom_field_config_id) FROM stdin;
1	2015-10-22 16:00:26.709597+01	2015-10-22 16:00:26.709829+01			-1	-1
\.


--
-- Name: cbh_datastore_model_datapoint_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_datastore_model_datapoint_id_seq', 1, false);


--
-- Data for Name: cbh_datastore_model_datapointclassification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_datastore_model_datapointclassification (id, created, modified, description, created_by_id, l0_id, l1_id, l2_id, l3_id, l4_id, data_form_config_id, parent_id) FROM stdin;
\.


--
-- Name: cbh_datastore_model_datapointclassification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_datastore_model_datapointclassification_id_seq', 1, false);


--
-- Data for Name: cbh_datastore_model_datapointclassificationpermission; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_datastore_model_datapointclassificationpermission (id, created, modified, data_point_classification_id, project_id) FROM stdin;
\.


--
-- Name: cbh_datastore_model_datapointclassificationpermission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_datastore_model_datapointclassificationpermission_id_seq', 1, false);


--
-- Data for Name: cbh_datastore_model_query; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cbh_datastore_model_query (id, created, modified, query, aggs, created_by_id, filter) FROM stdin;
\.


--
-- Name: cbh_datastore_model_query_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('cbh_datastore_model_query_id_seq', 1, false);


--
-- Data for Name: cell_dictionary; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY cell_dictionary (cell_id, cell_name, cell_description, cell_source_tissue, cell_source_organism, cell_source_tax_id, clo_id, efo_id, cellosaurus_id, downgraded, chembl_id, cl_lincs_id) FROM stdin;
\.


--
-- Data for Name: chembl_business_model_djangocheatsheet; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY chembl_business_model_djangocheatsheet (id, "bigIntegerField", "booleanField", "charField", "commaSeparatedIntegerField", "dateField", "dateTimeField", "decimalField", "emailField", "filePathField", "floatField", "integerField", "ipAddressField", "genericIPAddressField", "nullBooleanField", "positiveIntegerField", "positiveSmallIntegerField", "slugField", "smallIntegerField", "textField", "timeField", "urlField") FROM stdin;
\.


--
-- Name: chembl_business_model_djangocheatsheet_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('chembl_business_model_djangocheatsheet_id_seq', 1, false);


--
-- Data for Name: chembl_business_model_imageerrors; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY chembl_business_model_imageerrors (id, error_type, image_id) FROM stdin;
\.


--
-- Name: chembl_business_model_imageerrors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('chembl_business_model_imageerrors_id_seq', 1, false);


--
-- Data for Name: chembl_business_model_inchierrors; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY chembl_business_model_inchierrors (id, error_type, structure_id) FROM stdin;
\.


--
-- Name: chembl_business_model_inchierrors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('chembl_business_model_inchierrors_id_seq', 1, false);


--
-- Data for Name: chembl_business_model_sdf; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY chembl_business_model_sdf ("originalSDF", "originalHash", "cleanSDF", "cleanHash") FROM stdin;
\.


--
-- Data for Name: chembl_id_lookup; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY chembl_id_lookup (chembl_id, entity_type, entity_id, status) FROM stdin;
\.


--
-- Data for Name: component_class; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY component_class (comp_class_id, component_id, protein_class_id) FROM stdin;
\.


--
-- Data for Name: component_domains; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY component_domains (compd_id, start_position, end_position, component_id, domain_id) FROM stdin;
\.


--
-- Data for Name: component_sequences; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY component_sequences (component_id, component_type, accession, sequence, sequence_md5sum, description, tax_id, organism, db_source, db_version, insert_date, updated_on, updated_by) FROM stdin;
\.


--
-- Data for Name: component_synonyms; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY component_synonyms (compsyn_id, component_synonym, syn_type, component_id) FROM stdin;
\.


--
-- Data for Name: compound_images; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY compound_images (molregno, png, png_500) FROM stdin;
\.


--
-- Data for Name: compound_mols; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY compound_mols (molregno, ctab) FROM stdin;
\.


--
-- Data for Name: compound_properties; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY compound_properties (molregno, mw_freebase, alogp, hba, hbd, psa, rtb, ro3_pass, num_ro5_violations, med_chem_friendly, acd_most_apka, acd_most_bpka, acd_logp, acd_logd, molecular_species, full_mwt, aromatic_rings, heavy_atoms, num_alerts, qed_weighted, updated_on, mw_monoisotopic, full_molformula, hba_lipinski, hbd_lipinski, num_lipinski_ro5_violations) FROM stdin;
\.


--
-- Data for Name: compound_records; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY compound_records (record_id, compound_key, compound_name, filename, updated_by, updated_on, src_compound_id, removed, src_compound_id_version, curated, doc_id, molregno, src_id) FROM stdin;
\.


--
-- Data for Name: compound_structural_alerts; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY compound_structural_alerts (cpd_str_alert_id, alert_id, molregno) FROM stdin;
\.


--
-- Data for Name: compound_structures; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY compound_structures (molregno, molfile, standard_inchi, standard_inchi_key, canonical_smiles, structure_exclude_flag) FROM stdin;
\.


--
-- Data for Name: confidence_score_lookup; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY confidence_score_lookup (confidence_score, description, target_mapping) FROM stdin;
\.


--
-- Data for Name: curation_lookup; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY curation_lookup (curated_by, description) FROM stdin;
\.


--
-- Data for Name: data_validity_lookup; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY data_validity_lookup (data_validity_comment, description) FROM stdin;
\.


--
-- Data for Name: defined_daily_dose; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY defined_daily_dose (ddd_value, ddd_units, ddd_admr, ddd_comment, ddd_id, atc_code) FROM stdin;
\.


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('django_admin_log_id_seq', 1, false);


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY django_content_type (id, name, app_label, model) FROM stdin;
1	project type	cbh_core_model	projecttype
2	data type	cbh_core_model	datatype
3	custom field config	cbh_core_model	customfieldconfig
4	data form config	cbh_core_model	dataformconfig
5	project	cbh_core_model	project
6	Skinning Configuration	cbh_core_model	skinningconfig
7	pinned custom field	cbh_core_model	pinnedcustomfield
8	attachment	cbh_datastore_model	attachment
9	data point	cbh_datastore_model	datapoint
10	data point classification	cbh_datastore_model	datapointclassification
11	data point classification permission	cbh_datastore_model	datapointclassificationpermission
12	query	cbh_datastore_model	query
13	api access	tastypie	apiaccess
14	api key	tastypie	apikey
15	permission	auth	permission
16	group	auth	group
17	user	auth	user
18	content type	contenttypes	contenttype
19	session	sessions	session
20	site	sites	site
21	log entry	admin	logentry
22	version	chembl_core_model	version
23	chembl id lookup	chembl_core_model	chemblidlookup
24	source	chembl_core_model	source
25	journals	chembl_core_model	journals
26	docs	chembl_core_model	docs
27	journal articles	chembl_core_model	journalarticles
28	research stem	chembl_core_model	researchstem
29	structural alert sets	chembl_core_model	structuralalertsets
30	bio component sequences	chembl_core_model	biocomponentsequences
31	molecule dictionary	chembl_core_model	moleculedictionary
32	research companies	chembl_core_model	researchcompanies
33	structural alerts	chembl_core_model	structuralalerts
34	compound properties	chembl_core_model	compoundproperties
35	compound records	chembl_core_model	compoundrecords
36	record drug properties	chembl_core_model	recorddrugproperties
37	molecule hierarchy	chembl_core_model	moleculehierarchy
38	molecule synonyms	chembl_core_model	moleculesynonyms
39	biotherapeutics	chembl_core_model	biotherapeutics
40	compound structural alerts	chembl_core_model	compoundstructuralalerts
41	compound images	chembl_core_model	compoundimages
42	compound mols	chembl_core_model	compoundmols
43	compound structures	chembl_core_model	compoundstructures
44	biotherapeutic components	chembl_core_model	biotherapeuticcomponents
45	target type	chembl_core_model	targettype
46	organism class	chembl_core_model	organismclass
47	protein family classification	chembl_core_model	proteinfamilyclassification
48	protein classification	chembl_core_model	proteinclassification
49	component sequences	chembl_core_model	componentsequences
50	target dictionary	chembl_core_model	targetdictionary
51	component class	chembl_core_model	componentclass
52	component synonyms	chembl_core_model	componentsynonyms
53	cell dictionary	chembl_core_model	celldictionary
54	protein class synonyms	chembl_core_model	proteinclasssynonyms
55	target components	chembl_core_model	targetcomponents
56	target relations	chembl_core_model	targetrelations
57	domains	chembl_core_model	domains
58	component domains	chembl_core_model	componentdomains
59	binding sites	chembl_core_model	bindingsites
60	site components	chembl_core_model	sitecomponents
61	assay type	chembl_core_model	assaytype
62	relationship type	chembl_core_model	relationshiptype
63	confidence score lookup	chembl_core_model	confidencescorelookup
64	curation lookup	chembl_core_model	curationlookup
65	activity stds lookup	chembl_core_model	activitystdslookup
66	data validity lookup	chembl_core_model	datavaliditylookup
67	parameter type	chembl_core_model	parametertype
68	assays	chembl_core_model	assays
69	activities	chembl_core_model	activities
70	assay parameters	chembl_core_model	assayparameters
71	products	chembl_core_model	products
72	atc classification	chembl_core_model	atcclassification
73	usan stems	chembl_core_model	usanstems
74	hrac classification	chembl_core_model	hracclassification
75	irac classification	chembl_core_model	iracclassification
76	frac classification	chembl_core_model	fracclassification
77	patent use codes	chembl_core_model	patentusecodes
78	defined daily dose	chembl_core_model	defineddailydose
79	product patents	chembl_core_model	productpatents
80	molecule atc classification	chembl_core_model	moleculeatcclassification
81	molecule irac classification	chembl_core_model	moleculeiracclassification
82	molecule frac classification	chembl_core_model	moleculefracclassification
83	molecule hrac classification	chembl_core_model	moleculehracclassification
84	formulations	chembl_core_model	formulations
85	action type	chembl_core_model	actiontype
86	drug mechanism	chembl_core_model	drugmechanism
87	ligand eff	chembl_core_model	ligandeff
88	predicted binding domains	chembl_core_model	predictedbindingdomains
89	mechanism refs	chembl_core_model	mechanismrefs
90	inchi errors	chembl_business_model	inchierrors
91	image errors	chembl_business_model	imageerrors
92	django cheat sheet	chembl_business_model	djangocheatsheet
93	sdf	chembl_business_model	sdf
94	component synonyms	chembl_business_model	componentsynonyms
95	target dictionary	chembl_business_model	targetdictionary
96	component sequences	chembl_business_model	componentsequences
97	compound records	chembl_business_model	compoundrecords
98	action type	chembl_business_model	actiontype
99	target components	chembl_business_model	targetcomponents
100	confidence score lookup	chembl_business_model	confidencescorelookup
101	molecule atc classification	chembl_business_model	moleculeatcclassification
102	component domains	chembl_business_model	componentdomains
103	component class	chembl_business_model	componentclass
104	assay parameters	chembl_business_model	assayparameters
105	research companies	chembl_business_model	researchcompanies
106	journal articles	chembl_business_model	journalarticles
107	biotherapeutics	chembl_business_model	biotherapeutics
108	site components	chembl_business_model	sitecomponents
109	biotherapeutic components	chembl_business_model	biotherapeuticcomponents
110	curation lookup	chembl_business_model	curationlookup
111	protein classification	chembl_business_model	proteinclassification
112	atc classification	chembl_business_model	atcclassification
113	formulations	chembl_business_model	formulations
114	activities	chembl_business_model	activities
115	source	chembl_business_model	source
116	version	chembl_business_model	version
117	activity stds lookup	chembl_business_model	activitystdslookup
118	products	chembl_business_model	products
119	compound structures	chembl_business_model	compoundstructures
120	predicted binding domains	chembl_business_model	predictedbindingdomains
121	molecule synonyms	chembl_business_model	moleculesynonyms
122	assay type	chembl_business_model	assaytype
123	target type	chembl_business_model	targettype
124	docs	chembl_business_model	docs
125	compound mols	chembl_business_model	compoundmols
126	bio component sequences	chembl_business_model	biocomponentsequences
127	molecule hierarchy	chembl_business_model	moleculehierarchy
128	protein family classification	chembl_business_model	proteinfamilyclassification
129	drug mechanism	chembl_business_model	drugmechanism
130	usan stems	chembl_business_model	usanstems
131	relationship type	chembl_business_model	relationshiptype
132	journals	chembl_business_model	journals
133	defined daily dose	chembl_business_model	defineddailydose
134	chembl id lookup	chembl_business_model	chemblidlookup
135	compound images	chembl_business_model	compoundimages
136	parameter type	chembl_business_model	parametertype
137	target relations	chembl_business_model	targetrelations
138	research stem	chembl_business_model	researchstem
139	record drug properties	chembl_business_model	recorddrugproperties
140	data validity lookup	chembl_business_model	datavaliditylookup
141	ligand eff	chembl_business_model	ligandeff
142	compound properties	chembl_business_model	compoundproperties
143	mechanism refs	chembl_business_model	mechanismrefs
144	organism class	chembl_business_model	organismclass
145	molecule dictionary	chembl_business_model	moleculedictionary
146	protein class synonyms	chembl_business_model	proteinclasssynonyms
147	cell dictionary	chembl_business_model	celldictionary
148	assays	chembl_business_model	assays
149	binding sites	chembl_business_model	bindingsites
150	domains	chembl_business_model	domains
151	flow file	flowjs	flowfile
152	flow file chunk	flowjs	flowfilechunk
153	cbh compound multiple batch	cbh_chembl_model_extension	cbhcompoundmultiplebatch
154	cbh compound batch	cbh_chembl_model_extension	cbhcompoundbatch
155	chemreg project	cbh_chembl_ws_extension	chemregproject
156	cbh plugin	cbh_chembl_id_generator	cbhplugin
157	cbh compound id	cbh_chembl_id_generator	cbhcompoundid
\.


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('django_content_type_id_seq', 157, true);


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2015-10-22 15:58:17.208469+01
2	auth	0001_initial	2015-10-22 15:58:17.299265+01
3	admin	0001_initial	2015-10-22 15:58:17.350547+01
4	cbh_chembl_id_generator	0001_initial	2015-10-22 15:58:17.371235+01
5	cbh_chembl_id_generator	0002_cbhcompoundid_current_batch_id	2015-10-22 15:58:17.403532+01
6	cbh_chembl_id_generator	0003_remove_cbhcompoundid_original_project_key	2015-10-22 15:58:17.416867+01
7	cbh_chembl_id_generator	0004_auto_20150515_0950	2015-10-22 15:58:17.432769+01
8	cbh_chembl_id_generator	0005_cbhplugin	2015-10-22 15:58:17.447958+01
9	cbh_chembl_id_generator	0006_cbhplugin_name	2015-10-22 15:58:17.470255+01
10	cbh_chembl_id_generator	0007_remove_cbhplugin_output_json_path	2015-10-22 15:58:17.490807+01
11	chembl_core_model	0001_initial	2015-10-22 15:58:29.761927+01
12	chembl_core_model	0002_auto_20150323_0929	2015-10-22 15:58:37.664383+01
13	chembl_core_model	0003_auto_20150323_1322	2015-10-22 15:58:37.92911+01
14	flowjs	0001_initial	2015-10-22 15:58:37.962839+01
15	chembl_business_model	0001_initial	2015-10-22 15:58:49.822765+01
16	cbh_chembl_model_extension	0001_initial	2015-10-22 15:58:52.183709+01
17	chembl_core_model	0004_auto_20150323_0942	2015-10-22 15:58:57.538516+01
18	chembl_core_model	0005_auto_20150323_1105	2015-10-22 15:58:59.260518+01
19	chembl_core_model	0006_auto_20150521_0906	2015-10-22 15:59:00.606043+01
20	cbh_core_model	0001_initial	2015-10-22 15:59:00.63668+01
21	cbh_chembl_model_extension	0002_pinnedcustomfield_position	2015-10-22 15:59:01.849011+01
22	cbh_chembl_model_extension	0003_auto_20150327_1145	2015-10-22 15:59:03.499249+01
23	cbh_chembl_model_extension	0004_auto_20150327_1205	2015-10-22 15:59:05.319278+01
24	cbh_chembl_model_extension	0005_auto_20150330_1047	2015-10-22 15:59:07.201674+01
25	cbh_chembl_model_extension	0006_auto_20150330_1048	2015-10-22 15:59:08.864691+01
26	cbh_chembl_model_extension	0007_auto_20150330_1052	2015-10-22 15:59:10.374419+01
27	cbh_chembl_model_extension	0008_auto_20150330_1127	2015-10-22 15:59:12.566213+01
28	cbh_chembl_model_extension	0009_auto_20150330_1250	2015-10-22 15:59:15.057675+01
29	cbh_chembl_model_extension	0010_auto_20150330_1309	2015-10-22 15:59:17.233431+01
30	cbh_chembl_model_extension	0011_project_custom_field_config	2015-10-22 15:59:19.685987+01
31	cbh_chembl_model_extension	0012_auto_20150408_0740	2015-10-22 15:59:22.625664+01
32	cbh_chembl_model_extension	0013_auto_20150409_1801	2015-10-22 15:59:25.449093+01
33	cbh_chembl_model_extension	0014_auto_20150417_1629	2015-10-22 15:59:28.612867+01
34	cbh_chembl_model_extension	0015_auto_20150417_1631	2015-10-22 15:59:31.81683+01
35	cbh_chembl_model_extension	0016_auto_20150420_0443	2015-10-22 15:59:34.770255+01
36	cbh_chembl_model_extension	0017_auto_20150512_0831	2015-10-22 15:59:38.483047+01
37	cbh_chembl_model_extension	0018_auto_20150521_0904	2015-10-22 15:59:42.167243+01
38	cbh_chembl_model_extension	0019_auto_20150721_0515	2015-10-22 15:59:45.828062+01
39	cbh_chembl_model_extension	0020_remove_skinningconfig_created_by	2015-10-22 15:59:49.313398+01
40	cbh_chembl_model_extension	0021_auto_20150721_0551	2015-10-22 15:59:53.270588+01
41	cbh_chembl_model_extension	0022_auto_20150721_1031	2015-10-22 15:59:57.31055+01
42	cbh_chembl_model_extension	0023_auto_20150806_0206	2015-10-22 16:00:01.345875+01
43	chembl_core_model	0007_auto_20150806_0115	2015-10-22 16:00:06.094686+01
44	cbh_chembl_model_extension	0024_auto_20150806_0115	2015-10-22 16:00:11.119895+01
45	cbh_chembl_model_extension	0025_auto_20150807_0933	2015-10-22 16:00:16.130972+01
46	cbh_core_model	0002_auto_20150806_0658	2015-10-22 16:00:16.255537+01
47	cbh_core_model	0003_pinnedcustomfield_default	2015-10-22 16:00:16.353372+01
48	cbh_core_model	0004_auto_20150807_0936	2015-10-22 16:00:16.455441+01
49	cbh_core_model	0005_auto_20150807_1425	2015-10-22 16:00:16.632697+01
50	cbh_core_model	0006_auto_20150807_1425	2015-10-22 16:00:16.747955+01
51	cbh_core_model	0007_auto_20150808_1120	2015-10-22 16:00:16.972382+01
52	cbh_core_model	0008_auto_20150808_1140	2015-10-22 16:00:17.15795+01
53	cbh_core_model	0009_project_enabled_forms	2015-10-22 16:00:17.339821+01
54	cbh_core_model	0010_auto_20150809_0021	2015-10-22 16:00:17.80252+01
55	cbh_core_model	0011_auto_20150831_0618	2015-10-22 16:00:18.03778+01
56	cbh_core_model	0012_auto_20150911_0825	2015-10-22 16:00:18.216672+01
57	cbh_core_model	0013_dataformconfig_human_added	2015-10-22 16:00:18.449249+01
58	cbh_core_model	0014_dataformconfig_parent	2015-10-22 16:00:18.70382+01
59	cbh_core_model	0015_auto_20150914_0954	2015-10-22 16:00:19.182116+01
60	cbh_core_model	0016_auto_20150914_2301	2015-10-22 16:00:19.549276+01
61	cbh_core_model	0017_auto_20150915_0022	2015-10-22 16:00:19.84896+01
62	cbh_chembl_ws_extension	0001_initial	2015-10-22 16:00:20.003259+01
63	cbh_core_model	0018_auto_20150915_1238	2015-10-22 16:00:20.321526+01
64	cbh_core_model	0019_auto_20150916_0629	2015-10-22 16:00:20.68708+01
65	cbh_core_model	0020_auto_20150917_0908	2015-10-22 16:00:21.041327+01
66	cbh_core_model	0021_pinnedcustomfield_attachment_field_mapped_to	2015-10-22 16:00:21.472527+01
67	cbh_core_model	0022_auto_20150925_0337	2015-10-22 16:00:21.936043+01
68	cbh_datastore_model	0001_initial	2015-10-22 16:00:22.102449+01
69	cbh_datastore_model	0002_auto_20150808_1120	2015-10-22 16:00:22.741222+01
70	cbh_datastore_model	0003_auto_20150808_1129	2015-10-22 16:00:22.973804+01
71	cbh_datastore_model	0004_auto_20150808_1139	2015-10-22 16:00:23.835118+01
72	cbh_datastore_model	0005_datapointclassification_data_form_config	2015-10-22 16:00:24.136552+01
73	cbh_datastore_model	0006_auto_20150808_1142	2015-10-22 16:00:24.455813+01
74	cbh_datastore_model	0007_remove_datapointclassification_l0_permission	2015-10-22 16:00:24.804312+01
75	cbh_datastore_model	0008_datapointclassificationpermission_data_point_classification	2015-10-22 16:00:25.19374+01
76	cbh_datastore_model	0009_auto_20150810_0915	2015-10-22 16:00:25.793824+01
77	cbh_datastore_model	0010_auto_20150810_0917	2015-10-22 16:00:26.263026+01
78	cbh_datastore_model	0011_auto_20150810_1258	2015-10-22 16:00:26.716111+01
79	cbh_datastore_model	0012_auto_20150810_1326	2015-10-22 16:00:27.54915+01
80	cbh_datastore_model	0013_query	2015-10-22 16:00:28.049353+01
81	cbh_datastore_model	0014_auto_20150819_1503	2015-10-22 16:00:28.74578+01
82	cbh_datastore_model	0015_datapointclassification_parent	2015-10-22 16:00:29.31973+01
83	cbh_datastore_model	0016_auto_20150915_0757	2015-10-22 16:00:29.871545+01
84	cbh_datastore_model	0017_attachment	2015-10-22 16:00:30.903612+01
85	cbh_datastore_model	0018_auto_20150922_0230	2015-10-22 16:00:32.009638+01
86	sessions	0001_initial	2015-10-22 16:00:32.022742+01
87	sites	0001_initial	2015-10-22 16:00:32.037691+01
88	tastypie	0001_initial	2015-10-22 16:00:32.127479+01
\.


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('django_migrations_id_seq', 88, true);


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: django_site; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY django_site (id, domain, name) FROM stdin;
1	example.com	example.com
\.


--
-- Name: django_site_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('django_site_id_seq', 1, true);


--
-- Data for Name: docs; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY docs (doc_id, journal, year, volume, issue, first_page, last_page, pubmed_id, updated_on, updated_by, doi, title, doc_type, authors, abstract, chembl_id, journal_id) FROM stdin;
\.


--
-- Data for Name: domains; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY domains (domain_id, domain_type, source_domain_id, domain_name, domain_description) FROM stdin;
\.


--
-- Data for Name: drug_mechanism; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY drug_mechanism (mec_id, mechanism_of_action, direct_interaction, molecular_mechanism, disease_efficacy, mechanism_comment, selectivity_comment, binding_site_comment, curated_by, date_added, date_removed, downgraded, downgrade_reason, curator_comment, curation_status, action_type, molregno, record_id, site_id, tid) FROM stdin;
\.


--
-- Data for Name: flowjs_flowfile; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY flowjs_flowfile (id, identifier, original_filename, total_size, total_chunks, total_chunks_uploaded, state, created, updated) FROM stdin;
\.


--
-- Name: flowjs_flowfile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('flowjs_flowfile_id_seq', 1, false);


--
-- Data for Name: flowjs_flowfilechunk; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY flowjs_flowfilechunk (id, file, number, created_at, parent_id) FROM stdin;
\.


--
-- Name: flowjs_flowfilechunk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('flowjs_flowfilechunk_id_seq', 1, false);


--
-- Data for Name: formulations; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY formulations (ingredient, strength, formulation_id, molregno, product_id, record_id) FROM stdin;
\.


--
-- Data for Name: frac_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY frac_classification (frac_class_id, active_ingredient, level1, level1_description, level2, level2_description, level3, level3_description, level4, level4_description, level5, frac_code) FROM stdin;
\.


--
-- Data for Name: hrac_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY hrac_classification (hrac_class_id, active_ingredient, level1, level1_description, level2, level2_description, level3, hrac_code) FROM stdin;
\.


--
-- Data for Name: irac_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY irac_classification (irac_class_id, active_ingredient, level1, level1_description, level2, level2_description, level3, level3_description, level4, irac_code) FROM stdin;
\.


--
-- Data for Name: journal_articles; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY journal_articles (int_pk, volume, issue, year, month, day, pagination, first_page, last_page, pubmed_id, doi, title, abstract, authors, year_raw, month_raw, day_raw, volume_raw, issue_raw, date_loaded, journal_id) FROM stdin;
\.


--
-- Data for Name: journals; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY journals (journal_id, title, iso_abbreviation, issn_print, issn_electronic, publication_start_year, nlm_id, doc_journal, core_journal_flag) FROM stdin;
\.


--
-- Data for Name: ligand_eff; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY ligand_eff (activity_id, bei, sei, le, lle) FROM stdin;
\.


--
-- Data for Name: mechanism_refs; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY mechanism_refs (mecref_id, ref_type, ref_id, ref_url, mec_id) FROM stdin;
\.


--
-- Data for Name: molecule_atc_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_atc_classification (mol_atc_id, level5, molregno) FROM stdin;
\.


--
-- Data for Name: molecule_dictionary; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_dictionary (molregno, pref_name, max_phase, therapeutic_flag, dosed_ingredient, structure_key, structure_type, chebi_id, chebi_par_id, insert_date, molfile_update, downgraded, downgrade_reason, replacement_mrn, checked_by, nomerge, nomerge_reason, molecule_type, first_approval, oral, parenteral, topical, black_box_warning, natural_product, first_in_class, chirality, prodrug, exclude, inorganic_flag, usan_year, availability_type, usan_stem, polymer_flag, usan_substem, usan_stem_definition, indication_class, chembl_id, created_by_id, forced_reg_index, forced_reg_reason, project_id, public) FROM stdin;
\.


--
-- Name: molecule_dictionary_molregno_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('molecule_dictionary_molregno_seq', 1, false);


--
-- Data for Name: molecule_frac_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_frac_classification (mol_frac_id, frac_class_id, molregno) FROM stdin;
\.


--
-- Data for Name: molecule_hierarchy; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_hierarchy (molregno, active_molregno, parent_molregno) FROM stdin;
\.


--
-- Data for Name: molecule_hrac_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_hrac_classification (mol_hrac_id, hrac_class_id, molregno) FROM stdin;
\.


--
-- Data for Name: molecule_irac_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_irac_classification (mol_irac_id, irac_class_id, molregno) FROM stdin;
\.


--
-- Data for Name: molecule_synonyms; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY molecule_synonyms (syn_type, molsyn_id, synonyms, molregno, res_stem_id) FROM stdin;
\.


--
-- Data for Name: organism_class; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY organism_class (oc_id, tax_id, l1, l2, l3) FROM stdin;
\.


--
-- Data for Name: parameter_type; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY parameter_type (parameter_type, description) FROM stdin;
\.


--
-- Data for Name: patent_use_codes; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY patent_use_codes (patent_use_code, definition) FROM stdin;
\.


--
-- Data for Name: predicted_binding_domains; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY predicted_binding_domains (predbind_id, prediction_method, confidence, activity_id, site_id) FROM stdin;
\.


--
-- Data for Name: product_patents; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY product_patents (prod_pat_id, patent_no, patent_expire_date, drug_substance_flag, drug_product_flag, delist_flag, in_products, patent_use_code, product_id) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY products (dosage_form, route, trade_name, approval_date, ad_type, oral, topical, parenteral, information_source, black_box_warning, product_class, applicant_full_name, innovator_company, product_id, load_date, removed_date, nda_type, tmp_ingred_count, exclude) FROM stdin;
\.


--
-- Data for Name: protein_class_synonyms; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY protein_class_synonyms (protclasssyn_id, protein_class_synonym, syn_type, protein_class_id) FROM stdin;
\.


--
-- Data for Name: protein_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY protein_classification (protein_class_id, parent_id, pref_name, short_name, protein_class_desc, definition, downgraded, replaced_by, class_level, sort_order) FROM stdin;
\.


--
-- Data for Name: protein_family_classification; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY protein_family_classification (protein_class_id, protein_class_desc, l1, l2, l3, l4, l5, l6, l7, l8) FROM stdin;
\.


--
-- Data for Name: record_drug_properties; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY record_drug_properties (record_id, max_phase, withdrawn_status, molecule_type, first_approval, oral, parenteral, topical, black_box_warning, first_in_class, chirality, prodrug, therapeutic_flag, natural_product, inorganic_flag, applicants, usan_stem, usan_year, availability_type, usan_substem, indication_class, usan_stem_definition, polymer_flag) FROM stdin;
\.


--
-- Data for Name: relationship_type; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY relationship_type (relationship_type, relationship_desc) FROM stdin;
\.


--
-- Data for Name: research_companies; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY research_companies (co_stem_id, company, country, previous_company, res_stem_id) FROM stdin;
\.


--
-- Data for Name: research_stem; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY research_stem (res_stem_id, research_stem) FROM stdin;
\.


--
-- Data for Name: site_components; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY site_components (sitecomp_id, site_residues, component_id, domain_id, site_id) FROM stdin;
\.


--
-- Data for Name: source; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY source (src_id, src_description, src_short_name) FROM stdin;
\.


--
-- Data for Name: structural_alert_sets; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY structural_alert_sets (alert_set_id, set_name, priority) FROM stdin;
\.


--
-- Data for Name: structural_alerts; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY structural_alerts (alert_id, alert_name, smarts, alert_set_id) FROM stdin;
\.


--
-- Data for Name: target_components; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY target_components (relationship, stoichiometry, targcomp_id, homologue, component_id, tid) FROM stdin;
\.


--
-- Data for Name: target_dictionary; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY target_dictionary (tid, pref_name, tax_id, organism, updated_on, updated_by, insert_date, target_parent_type, species_group_flag, downgraded, chembl_id, target_type) FROM stdin;
\.


--
-- Data for Name: target_relations; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY target_relations (relationship, targrel_id, related_tid, tid) FROM stdin;
\.


--
-- Data for Name: target_type; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY target_type (target_type, target_desc, parent_type) FROM stdin;
\.


--
-- Data for Name: tastypie_apiaccess; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY tastypie_apiaccess (id, identifier, url, request_method, accessed) FROM stdin;
\.


--
-- Name: tastypie_apiaccess_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('tastypie_apiaccess_id_seq', 1, false);


--
-- Data for Name: tastypie_apikey; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY tastypie_apikey (id, key, created, user_id) FROM stdin;
\.


--
-- Name: tastypie_apikey_id_seq; Type: SEQUENCE SET; Schema: public; Owner: chembl
--

SELECT pg_catalog.setval('tastypie_apikey_id_seq', 1, false);


--
-- Data for Name: usan_stems; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY usan_stems (usan_stem_id, stem, subgroup, annotation, stem_class, major_class, who_extra, downgraded) FROM stdin;
\.


--
-- Data for Name: version; Type: TABLE DATA; Schema: public; Owner: chembl
--

COPY version (name, creation_date, comments) FROM stdin;
\.


--
-- Name: action_type_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY action_type
    ADD CONSTRAINT action_type_pkey PRIMARY KEY (action_type);


--
-- Name: activities_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (activity_id);


--
-- Name: activity_stds_lookup_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY activity_stds_lookup
    ADD CONSTRAINT activity_stds_lookup_pkey PRIMARY KEY (std_act_id);


--
-- Name: activity_stds_lookup_standard_type_36c05a776b64c133_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY activity_stds_lookup
    ADD CONSTRAINT activity_stds_lookup_standard_type_36c05a776b64c133_uniq UNIQUE (standard_type, standard_units);


--
-- Name: assay_parameters_assay_id_270ac2fdcfbb96f_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY assay_parameters
    ADD CONSTRAINT assay_parameters_assay_id_270ac2fdcfbb96f_uniq UNIQUE (assay_id, parameter_type);


--
-- Name: assay_parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY assay_parameters
    ADD CONSTRAINT assay_parameters_pkey PRIMARY KEY (assay_param_id);


--
-- Name: assay_type_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY assay_type
    ADD CONSTRAINT assay_type_pkey PRIMARY KEY (assay_type);


--
-- Name: assays_chembl_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_chembl_id_key UNIQUE (chembl_id);


--
-- Name: assays_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_pkey PRIMARY KEY (assay_id);


--
-- Name: atc_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY atc_classification
    ADD CONSTRAINT atc_classification_pkey PRIMARY KEY (level5);


--
-- Name: auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions_group_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_key UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission_content_type_id_codename_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_key UNIQUE (content_type_id, codename);


--
-- Name: auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_pkey PRIMARY KEY (id);


--
-- Name: auth_user_groups_user_id_group_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_group_id_key UNIQUE (user_id, group_id);


--
-- Name: auth_user_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_user_user_permissions_user_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permissions_user_id_permission_id_key UNIQUE (user_id, permission_id);


--
-- Name: auth_user_username_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY auth_user
    ADD CONSTRAINT auth_user_username_key UNIQUE (username);


--
-- Name: binding_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY binding_sites
    ADD CONSTRAINT binding_sites_pkey PRIMARY KEY (site_id);


--
-- Name: bio_component_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY bio_component_sequences
    ADD CONSTRAINT bio_component_sequences_pkey PRIMARY KEY (component_id);


--
-- Name: biotherapeutic_components_molregno_b49ba5eab75bef6_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY biotherapeutic_components
    ADD CONSTRAINT biotherapeutic_components_molregno_b49ba5eab75bef6_uniq UNIQUE (molregno, component_id);


--
-- Name: biotherapeutic_components_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY biotherapeutic_components
    ADD CONSTRAINT biotherapeutic_components_pkey PRIMARY KEY (biocomp_id);


--
-- Name: biotherapeutics_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY biotherapeutics
    ADD CONSTRAINT biotherapeutics_pkey PRIMARY KEY (molregno);


--
-- Name: cbh_chembl_id_generator_cbhcompoundid_assigned_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_id_generator_cbhcompoundid
    ADD CONSTRAINT cbh_chembl_id_generator_cbhcompoundid_assigned_id_key UNIQUE (assigned_id);


--
-- Name: cbh_chembl_id_generator_cbhcompoundid_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_id_generator_cbhcompoundid
    ADD CONSTRAINT cbh_chembl_id_generator_cbhcompoundid_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_id_generator_cbhcompoundid_structure_key_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_id_generator_cbhcompoundid
    ADD CONSTRAINT cbh_chembl_id_generator_cbhcompoundid_structure_key_key UNIQUE (structure_key);


--
-- Name: cbh_chembl_id_generator_cbhplugin_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_id_generator_cbhplugin
    ADD CONSTRAINT cbh_chembl_id_generator_cbhplugin_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundbatch
    ADD CONSTRAINT cbh_chembl_model_extension_cbhcompoundbatch_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_cbhcompoundmult_uploaded_file_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundmultiplebatch
    ADD CONSTRAINT cbh_chembl_model_extension_cbhcompoundmult_uploaded_file_id_key UNIQUE (uploaded_file_id);


--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundmultiplebatch
    ADD CONSTRAINT cbh_chembl_model_extension_cbhcompoundmultiplebatch_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_customfieldconfig_name_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_customfieldconfig
    ADD CONSTRAINT cbh_chembl_model_extension_customfieldconfig_name_key UNIQUE (name);


--
-- Name: cbh_chembl_model_extension_customfieldconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_customfieldconfig
    ADD CONSTRAINT cbh_chembl_model_extension_customfieldconfig_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_pinnedcustomfield_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_pinnedcustomfield
    ADD CONSTRAINT cbh_chembl_model_extension_pinnedcustomfield_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_project_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_project
    ADD CONSTRAINT cbh_chembl_model_extension_project_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_project_project_key_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_project
    ADD CONSTRAINT cbh_chembl_model_extension_project_project_key_key UNIQUE (project_key);


--
-- Name: cbh_chembl_model_extension_projecttype_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_projecttype
    ADD CONSTRAINT cbh_chembl_model_extension_projecttype_pkey PRIMARY KEY (id);


--
-- Name: cbh_chembl_model_extension_skinningconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_skinningconfig
    ADD CONSTRAINT cbh_chembl_model_extension_skinningconfig_pkey PRIMARY KEY (id);


--
-- Name: cbh_core_model_dataformconfig_l0_id_651d962751e00713_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT cbh_core_model_dataformconfig_l0_id_651d962751e00713_uniq UNIQUE (l0_id, l1_id, l2_id, l3_id, l4_id);


--
-- Name: cbh_core_model_dataformconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT cbh_core_model_dataformconfig_pkey PRIMARY KEY (id);


--
-- Name: cbh_core_model_datatype_name_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_datatype
    ADD CONSTRAINT cbh_core_model_datatype_name_key UNIQUE (name);


--
-- Name: cbh_core_model_datatype_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_datatype
    ADD CONSTRAINT cbh_core_model_datatype_pkey PRIMARY KEY (id);


--
-- Name: cbh_core_model_project_enabled_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_project_enabled_forms
    ADD CONSTRAINT cbh_core_model_project_enabled_forms_pkey PRIMARY KEY (id);


--
-- Name: cbh_core_model_project_enabled_project_id_dataformconfig_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_core_model_project_enabled_forms
    ADD CONSTRAINT cbh_core_model_project_enabled_project_id_dataformconfig_id_key UNIQUE (project_id, dataformconfig_id);


--
-- Name: cbh_datastore_model_attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_datastore_model_attachment
    ADD CONSTRAINT cbh_datastore_model_attachment_pkey PRIMARY KEY (id);


--
-- Name: cbh_datastore_model_d_data_form_config_id_7e3e6b79c4a8c299_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh_datastore_model_d_data_form_config_id_7e3e6b79c4a8c299_uniq UNIQUE (data_form_config_id, l0_id, l1_id, l2_id, l3_id, l4_id);


--
-- Name: cbh_datastore_model_datapoint_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_datastore_model_datapoint
    ADD CONSTRAINT cbh_datastore_model_datapoint_pkey PRIMARY KEY (id);


--
-- Name: cbh_datastore_model_datapointclassification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh_datastore_model_datapointclassification_pkey PRIMARY KEY (id);


--
-- Name: cbh_datastore_model_datapointclassificationpermission_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassificationpermission
    ADD CONSTRAINT cbh_datastore_model_datapointclassificationpermission_pkey PRIMARY KEY (id);


--
-- Name: cbh_datastore_model_query_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cbh_datastore_model_query
    ADD CONSTRAINT cbh_datastore_model_query_pkey PRIMARY KEY (id);


--
-- Name: cell_dictionary_cell_name_2a8eabf42b9013bb_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cell_dictionary
    ADD CONSTRAINT cell_dictionary_cell_name_2a8eabf42b9013bb_uniq UNIQUE (cell_name, cell_source_tax_id);


--
-- Name: cell_dictionary_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY cell_dictionary
    ADD CONSTRAINT cell_dictionary_pkey PRIMARY KEY (cell_id);


--
-- Name: chembl_business_model_djangocheatsheet_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_business_model_djangocheatsheet
    ADD CONSTRAINT chembl_business_model_djangocheatsheet_pkey PRIMARY KEY (id);


--
-- Name: chembl_business_model_imageerrors_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_business_model_imageerrors
    ADD CONSTRAINT chembl_business_model_imageerrors_pkey PRIMARY KEY (id);


--
-- Name: chembl_business_model_inchierrors_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_business_model_inchierrors
    ADD CONSTRAINT chembl_business_model_inchierrors_pkey PRIMARY KEY (id);


--
-- Name: chembl_business_model_sdf_originalHash_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_business_model_sdf
    ADD CONSTRAINT "chembl_business_model_sdf_originalHash_key" UNIQUE ("originalHash");


--
-- Name: chembl_business_model_sdf_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_business_model_sdf
    ADD CONSTRAINT chembl_business_model_sdf_pkey PRIMARY KEY ("cleanHash");


--
-- Name: chembl_id_lookup_entity_id_a8280515028d87f_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_id_lookup
    ADD CONSTRAINT chembl_id_lookup_entity_id_a8280515028d87f_uniq UNIQUE (entity_id, entity_type);


--
-- Name: chembl_id_lookup_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY chembl_id_lookup
    ADD CONSTRAINT chembl_id_lookup_pkey PRIMARY KEY (chembl_id);


--
-- Name: component_class_component_id_16831ec6bb02c770_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_class
    ADD CONSTRAINT component_class_component_id_16831ec6bb02c770_uniq UNIQUE (component_id, protein_class_id);


--
-- Name: component_class_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_class
    ADD CONSTRAINT component_class_pkey PRIMARY KEY (comp_class_id);


--
-- Name: component_domains_domain_id_78701c23841d64fb_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_domains
    ADD CONSTRAINT component_domains_domain_id_78701c23841d64fb_uniq UNIQUE (domain_id, component_id, start_position);


--
-- Name: component_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_domains
    ADD CONSTRAINT component_domains_pkey PRIMARY KEY (compd_id);


--
-- Name: component_sequences_accession_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_sequences
    ADD CONSTRAINT component_sequences_accession_key UNIQUE (accession);


--
-- Name: component_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_sequences
    ADD CONSTRAINT component_sequences_pkey PRIMARY KEY (component_id);


--
-- Name: component_synonyms_component_id_74f14a6af9efc3f3_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_synonyms
    ADD CONSTRAINT component_synonyms_component_id_74f14a6af9efc3f3_uniq UNIQUE (component_id, component_synonym, syn_type);


--
-- Name: component_synonyms_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY component_synonyms
    ADD CONSTRAINT component_synonyms_pkey PRIMARY KEY (compsyn_id);


--
-- Name: compound_images_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_images
    ADD CONSTRAINT compound_images_pkey PRIMARY KEY (molregno);


--
-- Name: compound_mols_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_mols
    ADD CONSTRAINT compound_mols_pkey PRIMARY KEY (molregno);


--
-- Name: compound_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_properties
    ADD CONSTRAINT compound_properties_pkey PRIMARY KEY (molregno);


--
-- Name: compound_records_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_records
    ADD CONSTRAINT compound_records_pkey PRIMARY KEY (record_id);


--
-- Name: compound_structural_alerts_molregno_ad555374b94bdf0_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_structural_alerts
    ADD CONSTRAINT compound_structural_alerts_molregno_ad555374b94bdf0_uniq UNIQUE (molregno, alert_id);


--
-- Name: compound_structural_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_structural_alerts
    ADD CONSTRAINT compound_structural_alerts_pkey PRIMARY KEY (cpd_str_alert_id);


--
-- Name: compound_structures_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY compound_structures
    ADD CONSTRAINT compound_structures_pkey PRIMARY KEY (molregno);


--
-- Name: confidence_score_lookup_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY confidence_score_lookup
    ADD CONSTRAINT confidence_score_lookup_pkey PRIMARY KEY (confidence_score);


--
-- Name: curation_lookup_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY curation_lookup
    ADD CONSTRAINT curation_lookup_pkey PRIMARY KEY (curated_by);


--
-- Name: data_validity_lookup_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY data_validity_lookup
    ADD CONSTRAINT data_validity_lookup_pkey PRIMARY KEY (data_validity_comment);


--
-- Name: defined_daily_dose_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY defined_daily_dose
    ADD CONSTRAINT defined_daily_dose_pkey PRIMARY KEY (ddd_id);


--
-- Name: django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type_app_label_45f3b1d93ec8c61c_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_app_label_45f3b1d93ec8c61c_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: django_site_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY django_site
    ADD CONSTRAINT django_site_pkey PRIMARY KEY (id);


--
-- Name: docs_chembl_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY docs
    ADD CONSTRAINT docs_chembl_id_key UNIQUE (chembl_id);


--
-- Name: docs_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY docs
    ADD CONSTRAINT docs_pkey PRIMARY KEY (doc_id);


--
-- Name: docs_pubmed_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY docs
    ADD CONSTRAINT docs_pubmed_id_key UNIQUE (pubmed_id);


--
-- Name: domains_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY domains
    ADD CONSTRAINT domains_pkey PRIMARY KEY (domain_id);


--
-- Name: drug_mechanism_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY drug_mechanism
    ADD CONSTRAINT drug_mechanism_pkey PRIMARY KEY (mec_id);


--
-- Name: flowjs_flowfile_identifier_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY flowjs_flowfile
    ADD CONSTRAINT flowjs_flowfile_identifier_key UNIQUE (identifier);


--
-- Name: flowjs_flowfile_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY flowjs_flowfile
    ADD CONSTRAINT flowjs_flowfile_pkey PRIMARY KEY (id);


--
-- Name: flowjs_flowfilechunk_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY flowjs_flowfilechunk
    ADD CONSTRAINT flowjs_flowfilechunk_pkey PRIMARY KEY (id);


--
-- Name: formulations_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY formulations
    ADD CONSTRAINT formulations_pkey PRIMARY KEY (formulation_id);


--
-- Name: formulations_record_id_7b3fb17ece316828_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY formulations
    ADD CONSTRAINT formulations_record_id_7b3fb17ece316828_uniq UNIQUE (record_id, product_id);


--
-- Name: frac_classification_level5_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY frac_classification
    ADD CONSTRAINT frac_classification_level5_key UNIQUE (level5);


--
-- Name: frac_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY frac_classification
    ADD CONSTRAINT frac_classification_pkey PRIMARY KEY (frac_class_id);


--
-- Name: hrac_classification_level3_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY hrac_classification
    ADD CONSTRAINT hrac_classification_level3_key UNIQUE (level3);


--
-- Name: hrac_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY hrac_classification
    ADD CONSTRAINT hrac_classification_pkey PRIMARY KEY (hrac_class_id);


--
-- Name: irac_classification_level4_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY irac_classification
    ADD CONSTRAINT irac_classification_level4_key UNIQUE (level4);


--
-- Name: irac_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY irac_classification
    ADD CONSTRAINT irac_classification_pkey PRIMARY KEY (irac_class_id);


--
-- Name: journal_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY journal_articles
    ADD CONSTRAINT journal_articles_pkey PRIMARY KEY (int_pk);


--
-- Name: journals_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_pkey PRIMARY KEY (journal_id);


--
-- Name: ligand_eff_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY ligand_eff
    ADD CONSTRAINT ligand_eff_pkey PRIMARY KEY (activity_id);


--
-- Name: mechanism_refs_mec_id_5391c8d3cdf951fd_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY mechanism_refs
    ADD CONSTRAINT mechanism_refs_mec_id_5391c8d3cdf951fd_uniq UNIQUE (mec_id, ref_type, ref_id);


--
-- Name: mechanism_refs_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY mechanism_refs
    ADD CONSTRAINT mechanism_refs_pkey PRIMARY KEY (mecref_id);


--
-- Name: molecule_atc_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_atc_classification
    ADD CONSTRAINT molecule_atc_classification_pkey PRIMARY KEY (mol_atc_id);


--
-- Name: molecule_dictionary_chebi_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT molecule_dictionary_chebi_id_key UNIQUE (chebi_id);


--
-- Name: molecule_dictionary_chembl_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT molecule_dictionary_chembl_id_key UNIQUE (chembl_id);


--
-- Name: molecule_dictionary_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT molecule_dictionary_pkey PRIMARY KEY (molregno);


--
-- Name: molecule_dictionary_structure_key_3016bc50edab149a_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT molecule_dictionary_structure_key_3016bc50edab149a_uniq UNIQUE (structure_key, project_id, structure_type, forced_reg_index);


--
-- Name: molecule_frac_classificatio_frac_class_id_219bac5d180a464d_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_frac_classification
    ADD CONSTRAINT molecule_frac_classificatio_frac_class_id_219bac5d180a464d_uniq UNIQUE (frac_class_id, molregno);


--
-- Name: molecule_frac_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_frac_classification
    ADD CONSTRAINT molecule_frac_classification_pkey PRIMARY KEY (mol_frac_id);


--
-- Name: molecule_hierarchy_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_hierarchy
    ADD CONSTRAINT molecule_hierarchy_pkey PRIMARY KEY (molregno);


--
-- Name: molecule_hrac_classificatio_hrac_class_id_3a11664b3e71541b_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_hrac_classification
    ADD CONSTRAINT molecule_hrac_classificatio_hrac_class_id_3a11664b3e71541b_uniq UNIQUE (hrac_class_id, molregno);


--
-- Name: molecule_hrac_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_hrac_classification
    ADD CONSTRAINT molecule_hrac_classification_pkey PRIMARY KEY (mol_hrac_id);


--
-- Name: molecule_irac_classification_irac_class_id_7cc36d0899bc457_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_irac_classification
    ADD CONSTRAINT molecule_irac_classification_irac_class_id_7cc36d0899bc457_uniq UNIQUE (irac_class_id, molregno);


--
-- Name: molecule_irac_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_irac_classification
    ADD CONSTRAINT molecule_irac_classification_pkey PRIMARY KEY (mol_irac_id);


--
-- Name: molecule_synonyms_molregno_1d5a3c9f518dbfa7_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_synonyms
    ADD CONSTRAINT molecule_synonyms_molregno_1d5a3c9f518dbfa7_uniq UNIQUE (molregno, synonyms, syn_type);


--
-- Name: molecule_synonyms_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY molecule_synonyms
    ADD CONSTRAINT molecule_synonyms_pkey PRIMARY KEY (molsyn_id);


--
-- Name: organism_class_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY organism_class
    ADD CONSTRAINT organism_class_pkey PRIMARY KEY (oc_id);


--
-- Name: organism_class_tax_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY organism_class
    ADD CONSTRAINT organism_class_tax_id_key UNIQUE (tax_id);


--
-- Name: parameter_type_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY parameter_type
    ADD CONSTRAINT parameter_type_pkey PRIMARY KEY (parameter_type);


--
-- Name: patent_use_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY patent_use_codes
    ADD CONSTRAINT patent_use_codes_pkey PRIMARY KEY (patent_use_code);


--
-- Name: predicted_binding_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY predicted_binding_domains
    ADD CONSTRAINT predicted_binding_domains_pkey PRIMARY KEY (predbind_id);


--
-- Name: product_patents_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY product_patents
    ADD CONSTRAINT product_patents_pkey PRIMARY KEY (prod_pat_id);


--
-- Name: product_patents_product_id_157fc78542006c0_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY product_patents
    ADD CONSTRAINT product_patents_product_id_157fc78542006c0_uniq UNIQUE (product_id, patent_no, patent_expire_date, patent_use_code);


--
-- Name: products_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: protein_class_synonyms_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY protein_class_synonyms
    ADD CONSTRAINT protein_class_synonyms_pkey PRIMARY KEY (protclasssyn_id);


--
-- Name: protein_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY protein_classification
    ADD CONSTRAINT protein_classification_pkey PRIMARY KEY (protein_class_id);


--
-- Name: protein_family_classification_l1_6cdf03f539c81fe8_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY protein_family_classification
    ADD CONSTRAINT protein_family_classification_l1_6cdf03f539c81fe8_uniq UNIQUE (l1, l2, l3, l4, l5, l6, l7, l8);


--
-- Name: protein_family_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY protein_family_classification
    ADD CONSTRAINT protein_family_classification_pkey PRIMARY KEY (protein_class_id);


--
-- Name: protein_family_classification_protein_class_desc_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY protein_family_classification
    ADD CONSTRAINT protein_family_classification_protein_class_desc_key UNIQUE (protein_class_desc);


--
-- Name: record_drug_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY record_drug_properties
    ADD CONSTRAINT record_drug_properties_pkey PRIMARY KEY (record_id);


--
-- Name: relationship_type_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY relationship_type
    ADD CONSTRAINT relationship_type_pkey PRIMARY KEY (relationship_type);


--
-- Name: research_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY research_companies
    ADD CONSTRAINT research_companies_pkey PRIMARY KEY (co_stem_id);


--
-- Name: research_companies_res_stem_id_d1a5d7390882d6a_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY research_companies
    ADD CONSTRAINT research_companies_res_stem_id_d1a5d7390882d6a_uniq UNIQUE (res_stem_id, company);


--
-- Name: research_stem_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY research_stem
    ADD CONSTRAINT research_stem_pkey PRIMARY KEY (res_stem_id);


--
-- Name: research_stem_research_stem_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY research_stem
    ADD CONSTRAINT research_stem_research_stem_key UNIQUE (research_stem);


--
-- Name: site_components_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY site_components
    ADD CONSTRAINT site_components_pkey PRIMARY KEY (sitecomp_id);


--
-- Name: site_components_site_id_311c40dbe48147b8_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY site_components
    ADD CONSTRAINT site_components_site_id_311c40dbe48147b8_uniq UNIQUE (site_id, component_id, domain_id);


--
-- Name: source_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY source
    ADD CONSTRAINT source_pkey PRIMARY KEY (src_id);


--
-- Name: structural_alert_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY structural_alert_sets
    ADD CONSTRAINT structural_alert_sets_pkey PRIMARY KEY (alert_set_id);


--
-- Name: structural_alert_sets_set_name_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY structural_alert_sets
    ADD CONSTRAINT structural_alert_sets_set_name_key UNIQUE (set_name);


--
-- Name: structural_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY structural_alerts
    ADD CONSTRAINT structural_alerts_pkey PRIMARY KEY (alert_id);


--
-- Name: target_components_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY target_components
    ADD CONSTRAINT target_components_pkey PRIMARY KEY (targcomp_id);


--
-- Name: target_dictionary_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY target_dictionary
    ADD CONSTRAINT target_dictionary_pkey PRIMARY KEY (tid);


--
-- Name: target_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY target_relations
    ADD CONSTRAINT target_relations_pkey PRIMARY KEY (targrel_id);


--
-- Name: target_type_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY target_type
    ADD CONSTRAINT target_type_pkey PRIMARY KEY (target_type);


--
-- Name: tastypie_apiaccess_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY tastypie_apiaccess
    ADD CONSTRAINT tastypie_apiaccess_pkey PRIMARY KEY (id);


--
-- Name: tastypie_apikey_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY tastypie_apikey
    ADD CONSTRAINT tastypie_apikey_pkey PRIMARY KEY (id);


--
-- Name: tastypie_apikey_user_id_key; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY tastypie_apikey
    ADD CONSTRAINT tastypie_apikey_user_id_key UNIQUE (user_id);


--
-- Name: usan_stems_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY usan_stems
    ADD CONSTRAINT usan_stems_pkey PRIMARY KEY (usan_stem_id);


--
-- Name: usan_stems_stem_6a3b79c1be38601e_uniq; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY usan_stems
    ADD CONSTRAINT usan_stems_stem_6a3b79c1be38601e_uniq UNIQUE (stem, subgroup);


--
-- Name: version_pkey; Type: CONSTRAINT; Schema: public; Owner: chembl; Tablespace: 
--

ALTER TABLE ONLY version
    ADD CONSTRAINT version_pkey PRIMARY KEY (name);


--
-- Name: action_type_action_type_68f159543a81b8e7_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX action_type_action_type_68f159543a81b8e7_like ON action_type USING btree (action_type varchar_pattern_ops);


--
-- Name: activities_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_00d9daf3 ON activities USING btree (molregno);


--
-- Name: activities_0d36e2dc; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_0d36e2dc ON activities USING btree (published_relation);


--
-- Name: activities_182976b1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_182976b1 ON activities USING btree (standard_relation);


--
-- Name: activities_22874088; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_22874088 ON activities USING btree (pchembl_value);


--
-- Name: activities_282362a2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_282362a2 ON activities USING btree (standard_type);


--
-- Name: activities_52b51182; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_52b51182 ON activities USING btree (published_type);


--
-- Name: activities_5ca316a7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_5ca316a7 ON activities USING btree (record_id);


--
-- Name: activities_6fdc9822; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_6fdc9822 ON activities USING btree (published_value);


--
-- Name: activities_7879de9a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_7879de9a ON activities USING btree (assay_id);


--
-- Name: activities_860d1885; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_860d1885 ON activities USING btree (doc_id);


--
-- Name: activities_d42c47e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_d42c47e7 ON activities USING btree (published_units);


--
-- Name: activities_ddf37629; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_ddf37629 ON activities USING btree (standard_value);


--
-- Name: activities_dfdab8cc; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_dfdab8cc ON activities USING btree (standard_units);


--
-- Name: activities_fedfa23e; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_fedfa23e ON activities USING btree (data_validity_comment);


--
-- Name: activities_published_relation_40cd6bc7cd07a557_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_published_relation_40cd6bc7cd07a557_like ON activities USING btree (published_relation varchar_pattern_ops);


--
-- Name: activities_published_type_73c1f0c6e98e4e33_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_published_type_73c1f0c6e98e4e33_like ON activities USING btree (published_type varchar_pattern_ops);


--
-- Name: activities_published_units_40e1f4283a25ab93_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_published_units_40e1f4283a25ab93_like ON activities USING btree (published_units varchar_pattern_ops);


--
-- Name: activities_standard_relation_2d0d7471e95e2bd3_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_standard_relation_2d0d7471e95e2bd3_like ON activities USING btree (standard_relation varchar_pattern_ops);


--
-- Name: activities_standard_type_5fe77bb7aead06f7_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_standard_type_5fe77bb7aead06f7_like ON activities USING btree (standard_type varchar_pattern_ops);


--
-- Name: activities_standard_units_c7dc7a96e9effdf_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX activities_standard_units_c7dc7a96e9effdf_like ON activities USING btree (standard_units varchar_pattern_ops);


--
-- Name: assay_parameters_29fcc24a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assay_parameters_29fcc24a ON assay_parameters USING btree (parameter_type);


--
-- Name: assay_parameters_7879de9a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assay_parameters_7879de9a ON assay_parameters USING btree (assay_id);


--
-- Name: assay_type_assay_type_661a09471cbb189_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assay_type_assay_type_661a09471cbb189_like ON assay_type USING btree (assay_type varchar_pattern_ops);


--
-- Name: assays_3166800b; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_3166800b ON assays USING btree (src_id);


--
-- Name: assays_358e54bd; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_358e54bd ON assays USING btree (relationship_type);


--
-- Name: assays_4ecb7391; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_4ecb7391 ON assays USING btree (cell_id);


--
-- Name: assays_700ab74a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_700ab74a ON assays USING btree (bao_format);


--
-- Name: assays_860d1885; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_860d1885 ON assays USING btree (doc_id);


--
-- Name: assays_87bebea3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_87bebea3 ON assays USING btree (curated_by);


--
-- Name: assays_97beaa21; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_97beaa21 ON assays USING btree (tid);


--
-- Name: assays_assay_source_33cdfba7c7b9ece4_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_assay_source_33cdfba7c7b9ece4_like ON assays USING btree (assay_source varchar_pattern_ops);


--
-- Name: assays_bao_format_34dd198f43a7c13f_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_bao_format_34dd198f43a7c13f_like ON assays USING btree (bao_format varchar_pattern_ops);


--
-- Name: assays_c0d00038; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_c0d00038 ON assays USING btree (assay_source);


--
-- Name: assays_c15b3fcb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_c15b3fcb ON assays USING btree (assay_type);


--
-- Name: assays_d29b1517; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX assays_d29b1517 ON assays USING btree (confidence_score);


--
-- Name: atc_classification_level5_625a9044c6c1a3fb_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX atc_classification_level5_625a9044c6c1a3fb_like ON atc_classification USING btree (level5 varchar_pattern_ops);


--
-- Name: auth_group_name_253ae2a6331666e8_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_group_name_253ae2a6331666e8_like ON auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_0e939a4f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_group_permissions_0e939a4f ON auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_8373b171; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_group_permissions_8373b171 ON auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_417f1b1c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_permission_417f1b1c ON auth_permission USING btree (content_type_id);


--
-- Name: auth_user_groups_0e939a4f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_user_groups_0e939a4f ON auth_user_groups USING btree (group_id);


--
-- Name: auth_user_groups_e8701ad4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_user_groups_e8701ad4 ON auth_user_groups USING btree (user_id);


--
-- Name: auth_user_user_permissions_8373b171; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_user_user_permissions_8373b171 ON auth_user_user_permissions USING btree (permission_id);


--
-- Name: auth_user_user_permissions_e8701ad4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_user_user_permissions_e8701ad4 ON auth_user_user_permissions USING btree (user_id);


--
-- Name: auth_user_username_51b3b110094b8aae_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX auth_user_username_51b3b110094b8aae_like ON auth_user USING btree (username varchar_pattern_ops);


--
-- Name: binding_sites_97beaa21; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX binding_sites_97beaa21 ON binding_sites USING btree (tid);


--
-- Name: biotherapeutic_components_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX biotherapeutic_components_00d9daf3 ON biotherapeutic_components USING btree (molregno);


--
-- Name: biotherapeutic_components_ef5a1f55; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX biotherapeutic_components_ef5a1f55 ON biotherapeutic_components USING btree (component_id);


--
-- Name: cbh_chembl_id_generator_cbh_structure_key_21074c3267049c69_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_id_generator_cbh_structure_key_21074c3267049c69_like ON cbh_chembl_id_generator_cbhcompoundid USING btree (structure_key varchar_pattern_ops);


--
-- Name: cbh_chembl_id_generator_cbhco_assigned_id_38767193abd521fa_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_id_generator_cbhco_assigned_id_38767193abd521fa_like ON cbh_chembl_id_generator_cbhcompoundid USING btree (assigned_id varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_cbh_created_by_1341a485379f3368_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbh_created_by_1341a485379f3368_like ON cbh_chembl_model_extension_cbhcompoundmultiplebatch USING btree (created_by varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_cbh_created_by_553bd7e25d3ce5b4_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbh_created_by_553bd7e25d3ce5b4_like ON cbh_chembl_model_extension_cbhcompoundbatch USING btree (created_by varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_45deeed4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbhcompoundbatch_45deeed4 ON cbh_chembl_model_extension_cbhcompoundbatch USING btree (related_molregno_id);


--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_b098ad43; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbhcompoundbatch_b098ad43 ON cbh_chembl_model_extension_cbhcompoundbatch USING btree (project_id);


--
-- Name: cbh_chembl_model_extension_cbhcompoundbatch_dad46b20; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbhcompoundbatch_dad46b20 ON cbh_chembl_model_extension_cbhcompoundbatch USING btree (created_by);


--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch_b098ad43; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbhcompoundmultiplebatch_b098ad43 ON cbh_chembl_model_extension_cbhcompoundmultiplebatch USING btree (project_id);


--
-- Name: cbh_chembl_model_extension_cbhcompoundmultiplebatch_dad46b20; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_cbhcompoundmultiplebatch_dad46b20 ON cbh_chembl_model_extension_cbhcompoundmultiplebatch USING btree (created_by);


--
-- Name: cbh_chembl_model_extension_customfie_name_72aca9ac6a7d3859_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_customfie_name_72aca9ac6a7d3859_like ON cbh_core_model_customfieldconfig USING btree (name varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_customfieldconfig_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_customfieldconfig_e93cb7eb ON cbh_core_model_customfieldconfig USING btree (created_by_id);


--
-- Name: cbh_chembl_model_extension_pinnedcustomfield_f1803abb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_pinnedcustomfield_f1803abb ON cbh_core_model_pinnedcustomfield USING btree (custom_field_config_id);


--
-- Name: cbh_chembl_model_extension_pr_project_key_28bf940e8b6e2f8e_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_pr_project_key_28bf940e8b6e2f8e_like ON cbh_core_model_project USING btree (project_key varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_project_9894c25e; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_project_9894c25e ON cbh_core_model_project USING btree (project_type_id);


--
-- Name: cbh_chembl_model_extension_project_b068931c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_project_b068931c ON cbh_core_model_project USING btree (name);


--
-- Name: cbh_chembl_model_extension_project_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_project_e93cb7eb ON cbh_core_model_project USING btree (created_by_id);


--
-- Name: cbh_chembl_model_extension_project_f1803abb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_project_f1803abb ON cbh_core_model_project USING btree (custom_field_config_id);


--
-- Name: cbh_chembl_model_extension_project_name_77b17607beb9e0a3_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_project_name_77b17607beb9e0a3_like ON cbh_core_model_project USING btree (name varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_projecttyp_name_2d2c59eaa8bbe91_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_projecttyp_name_2d2c59eaa8bbe91_like ON cbh_core_model_projecttype USING btree (name varchar_pattern_ops);


--
-- Name: cbh_chembl_model_extension_projecttype_b068931c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_chembl_model_extension_projecttype_b068931c ON cbh_core_model_projecttype USING btree (name);


--
-- Name: cbh_core_model_customfieldconfig_7470d5e5; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_customfieldconfig_7470d5e5 ON cbh_core_model_customfieldconfig USING btree (data_type_id);


--
-- Name: cbh_core_model_dataformconfig_092d6e83; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_092d6e83 ON cbh_core_model_dataformconfig USING btree (l0_id);


--
-- Name: cbh_core_model_dataformconfig_6be37982; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_6be37982 ON cbh_core_model_dataformconfig USING btree (parent_id);


--
-- Name: cbh_core_model_dataformconfig_aa4011c1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_aa4011c1 ON cbh_core_model_dataformconfig USING btree (l1_id);


--
-- Name: cbh_core_model_dataformconfig_dae35287; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_dae35287 ON cbh_core_model_dataformconfig USING btree (l4_id);


--
-- Name: cbh_core_model_dataformconfig_e8a86cd2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_e8a86cd2 ON cbh_core_model_dataformconfig USING btree (l3_id);


--
-- Name: cbh_core_model_dataformconfig_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_e93cb7eb ON cbh_core_model_dataformconfig USING btree (created_by_id);


--
-- Name: cbh_core_model_dataformconfig_eb84092f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_dataformconfig_eb84092f ON cbh_core_model_dataformconfig USING btree (l2_id);


--
-- Name: cbh_core_model_datatype_name_42cdcb1fec531e1f_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_datatype_name_42cdcb1fec531e1f_like ON cbh_core_model_datatype USING btree (name varchar_pattern_ops);


--
-- Name: cbh_core_model_pinnedcustomfield_5ccf79e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_pinnedcustomfield_5ccf79e7 ON cbh_core_model_pinnedcustomfield USING btree (standardised_alias_id);


--
-- Name: cbh_core_model_pinnedcustomfield_9e8e2d3a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_pinnedcustomfield_9e8e2d3a ON cbh_core_model_pinnedcustomfield USING btree (pinned_for_datatype_id);


--
-- Name: cbh_core_model_pinnedcustomfield_a1cb7997; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_pinnedcustomfield_a1cb7997 ON cbh_core_model_pinnedcustomfield USING btree (attachment_field_mapped_to_id);


--
-- Name: cbh_core_model_project_enabled_forms_b098ad43; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_project_enabled_forms_b098ad43 ON cbh_core_model_project_enabled_forms USING btree (project_id);


--
-- Name: cbh_core_model_project_enabled_forms_e48bb7be; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_core_model_project_enabled_forms_e48bb7be ON cbh_core_model_project_enabled_forms USING btree (dataformconfig_id);


--
-- Name: cbh_datastore_model_attachment_5a7f35b1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_attachment_5a7f35b1 ON cbh_datastore_model_attachment USING btree (data_point_classification_id);


--
-- Name: cbh_datastore_model_attachment_7bfa90b6; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_attachment_7bfa90b6 ON cbh_datastore_model_attachment USING btree (chosen_data_form_config_id);


--
-- Name: cbh_datastore_model_attachment_d036e682; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_attachment_d036e682 ON cbh_datastore_model_attachment USING btree (flowfile_id);


--
-- Name: cbh_datastore_model_attachment_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_attachment_e93cb7eb ON cbh_datastore_model_attachment USING btree (created_by_id);


--
-- Name: cbh_datastore_model_attachment_ef6a9774; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_attachment_ef6a9774 ON cbh_datastore_model_attachment USING btree (attachment_custom_field_config_id);


--
-- Name: cbh_datastore_model_datapoint_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapoint_e93cb7eb ON cbh_datastore_model_datapoint USING btree (created_by_id);


--
-- Name: cbh_datastore_model_datapoint_f1803abb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapoint_f1803abb ON cbh_datastore_model_datapoint USING btree (custom_field_config_id);


--
-- Name: cbh_datastore_model_datapointclassification_092d6e83; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_092d6e83 ON cbh_datastore_model_datapointclassification USING btree (l0_id);


--
-- Name: cbh_datastore_model_datapointclassification_69c6136a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_69c6136a ON cbh_datastore_model_datapointclassification USING btree (data_form_config_id);


--
-- Name: cbh_datastore_model_datapointclassification_6be37982; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_6be37982 ON cbh_datastore_model_datapointclassification USING btree (parent_id);


--
-- Name: cbh_datastore_model_datapointclassification_aa4011c1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_aa4011c1 ON cbh_datastore_model_datapointclassification USING btree (l1_id);


--
-- Name: cbh_datastore_model_datapointclassification_dae35287; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_dae35287 ON cbh_datastore_model_datapointclassification USING btree (l4_id);


--
-- Name: cbh_datastore_model_datapointclassification_e8a86cd2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_e8a86cd2 ON cbh_datastore_model_datapointclassification USING btree (l3_id);


--
-- Name: cbh_datastore_model_datapointclassification_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_e93cb7eb ON cbh_datastore_model_datapointclassification USING btree (created_by_id);


--
-- Name: cbh_datastore_model_datapointclassification_eb84092f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassification_eb84092f ON cbh_datastore_model_datapointclassification USING btree (l2_id);


--
-- Name: cbh_datastore_model_datapointclassificationpermission_5a7f35b1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassificationpermission_5a7f35b1 ON cbh_datastore_model_datapointclassificationpermission USING btree (data_point_classification_id);


--
-- Name: cbh_datastore_model_datapointclassificationpermission_b098ad43; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_datapointclassificationpermission_b098ad43 ON cbh_datastore_model_datapointclassificationpermission USING btree (project_id);


--
-- Name: cbh_datastore_model_query_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cbh_datastore_model_query_e93cb7eb ON cbh_datastore_model_query USING btree (created_by_id);


--
-- Name: cell_dictionary_2a7a6dd2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX cell_dictionary_2a7a6dd2 ON cell_dictionary USING btree (chembl_id);


--
-- Name: chembl_business_model_djangoche_slugField_6facc4d6cfa5b951_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX "chembl_business_model_djangoche_slugField_6facc4d6cfa5b951_like" ON chembl_business_model_djangocheatsheet USING btree ("slugField" varchar_pattern_ops);


--
-- Name: chembl_business_model_djangocheatsheet_75e9bf68; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX chembl_business_model_djangocheatsheet_75e9bf68 ON chembl_business_model_djangocheatsheet USING btree ("slugField");


--
-- Name: chembl_business_model_imageerrors_f33175e6; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX chembl_business_model_imageerrors_f33175e6 ON chembl_business_model_imageerrors USING btree (image_id);


--
-- Name: chembl_business_model_inchierrors_e57b64e6; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX chembl_business_model_inchierrors_e57b64e6 ON chembl_business_model_inchierrors USING btree (structure_id);


--
-- Name: chembl_business_model_sdf_cleanHash_69ee15bd0fee52e8_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX "chembl_business_model_sdf_cleanHash_69ee15bd0fee52e8_like" ON chembl_business_model_sdf USING btree ("cleanHash" varchar_pattern_ops);


--
-- Name: chembl_business_model_sdf_originalHash_40b3a42d54aee97_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX "chembl_business_model_sdf_originalHash_40b3a42d54aee97_like" ON chembl_business_model_sdf USING btree ("originalHash" varchar_pattern_ops);


--
-- Name: chembl_id_lookup_chembl_id_238c8cf828fbc657_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX chembl_id_lookup_chembl_id_238c8cf828fbc657_like ON chembl_id_lookup USING btree (chembl_id varchar_pattern_ops);


--
-- Name: component_class_46877088; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX component_class_46877088 ON component_class USING btree (protein_class_id);


--
-- Name: component_class_ef5a1f55; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX component_class_ef5a1f55 ON component_class USING btree (component_id);


--
-- Name: component_domains_662cbf12; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX component_domains_662cbf12 ON component_domains USING btree (domain_id);


--
-- Name: component_domains_ef5a1f55; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX component_domains_ef5a1f55 ON component_domains USING btree (component_id);


--
-- Name: component_sequences_accession_6acd1919df071b15_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX component_sequences_accession_6acd1919df071b15_like ON component_sequences USING btree (accession varchar_pattern_ops);


--
-- Name: component_synonyms_ef5a1f55; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX component_synonyms_ef5a1f55 ON component_synonyms USING btree (component_id);


--
-- Name: compound_properties_3601890e; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_3601890e ON compound_properties USING btree (hbd);


--
-- Name: compound_properties_59a0aff2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_59a0aff2 ON compound_properties USING btree (mw_freebase);


--
-- Name: compound_properties_773ff10e; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_773ff10e ON compound_properties USING btree (num_ro5_violations);


--
-- Name: compound_properties_b11260d9; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_b11260d9 ON compound_properties USING btree (rtb);


--
-- Name: compound_properties_b9325cb1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_b9325cb1 ON compound_properties USING btree (alogp);


--
-- Name: compound_properties_d894729d; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_d894729d ON compound_properties USING btree (psa);


--
-- Name: compound_properties_fa5fc799; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_properties_fa5fc799 ON compound_properties USING btree (hba);


--
-- Name: compound_records_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_00d9daf3 ON compound_records USING btree (molregno);


--
-- Name: compound_records_3166800b; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_3166800b ON compound_records USING btree (src_id);


--
-- Name: compound_records_860d1885; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_860d1885 ON compound_records USING btree (doc_id);


--
-- Name: compound_records_compound_key_35c3f06ccebe9c6a_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_compound_key_35c3f06ccebe9c6a_like ON compound_records USING btree (compound_key varchar_pattern_ops);


--
-- Name: compound_records_e9a892b0; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_e9a892b0 ON compound_records USING btree (src_compound_id);


--
-- Name: compound_records_edc602b8; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_edc602b8 ON compound_records USING btree (compound_key);


--
-- Name: compound_records_src_compound_id_48d0fab5520ad978_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_records_src_compound_id_48d0fab5520ad978_like ON compound_records USING btree (src_compound_id varchar_pattern_ops);


--
-- Name: compound_structural_alerts_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_structural_alerts_00d9daf3 ON compound_structural_alerts USING btree (molregno);


--
-- Name: compound_structural_alerts_d58cc5c6; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_structural_alerts_d58cc5c6 ON compound_structural_alerts USING btree (alert_id);


--
-- Name: compound_structures_7f3343b2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_structures_7f3343b2 ON compound_structures USING btree (standard_inchi_key);


--
-- Name: compound_structures_standard_inchi_key_74c06fe27852e14f_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX compound_structures_standard_inchi_key_74c06fe27852e14f_like ON compound_structures USING btree (standard_inchi_key varchar_pattern_ops);


--
-- Name: curation_lookup_curated_by_3ddf62956472613e_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX curation_lookup_curated_by_3ddf62956472613e_like ON curation_lookup USING btree (curated_by varchar_pattern_ops);


--
-- Name: data_validity_looku_data_validity_comment_293c365f887f68fd_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX data_validity_looku_data_validity_comment_293c365f887f68fd_like ON data_validity_lookup USING btree (data_validity_comment varchar_pattern_ops);


--
-- Name: defined_daily_dose_a2b69451; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX defined_daily_dose_a2b69451 ON defined_daily_dose USING btree (atc_code);


--
-- Name: defined_daily_dose_atc_code_35cc27385707962c_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX defined_daily_dose_atc_code_35cc27385707962c_like ON defined_daily_dose USING btree (atc_code varchar_pattern_ops);


--
-- Name: django_admin_log_417f1b1c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX django_admin_log_417f1b1c ON django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_e8701ad4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX django_admin_log_e8701ad4 ON django_admin_log USING btree (user_id);


--
-- Name: django_session_de54fa62; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX django_session_de54fa62 ON django_session USING btree (expire_date);


--
-- Name: django_session_session_key_461cfeaa630ca218_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX django_session_session_key_461cfeaa630ca218_like ON django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: docs_0aae4c8f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_0aae4c8f ON docs USING btree (issue);


--
-- Name: docs_210ab9e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_210ab9e7 ON docs USING btree (volume);


--
-- Name: docs_84cdc76c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_84cdc76c ON docs USING btree (year);


--
-- Name: docs_ba73fb5f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_ba73fb5f ON docs USING btree (journal_id);


--
-- Name: docs_chembl_id_522eec303eeefb50_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_chembl_id_522eec303eeefb50_like ON docs USING btree (chembl_id varchar_pattern_ops);


--
-- Name: docs_fb9141b4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_fb9141b4 ON docs USING btree (journal);


--
-- Name: docs_issue_48ac3a183661e2f2_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_issue_48ac3a183661e2f2_like ON docs USING btree (issue varchar_pattern_ops);


--
-- Name: docs_journal_6e0c971bdaa0ec50_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_journal_6e0c971bdaa0ec50_like ON docs USING btree (journal varchar_pattern_ops);


--
-- Name: docs_volume_565dff6994eeb252_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX docs_volume_565dff6994eeb252_like ON docs USING btree (volume varchar_pattern_ops);


--
-- Name: drug_mechanism_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX drug_mechanism_00d9daf3 ON drug_mechanism USING btree (molregno);


--
-- Name: drug_mechanism_5ca316a7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX drug_mechanism_5ca316a7 ON drug_mechanism USING btree (record_id);


--
-- Name: drug_mechanism_9365d6e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX drug_mechanism_9365d6e7 ON drug_mechanism USING btree (site_id);


--
-- Name: drug_mechanism_97beaa21; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX drug_mechanism_97beaa21 ON drug_mechanism USING btree (tid);


--
-- Name: drug_mechanism_action_type_d03cb79f89de2bd_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX drug_mechanism_action_type_d03cb79f89de2bd_like ON drug_mechanism USING btree (action_type varchar_pattern_ops);


--
-- Name: drug_mechanism_ca47336a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX drug_mechanism_ca47336a ON drug_mechanism USING btree (action_type);


--
-- Name: flowjs_flowfile_identifier_4d8d60a1fae67937_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX flowjs_flowfile_identifier_4d8d60a1fae67937_like ON flowjs_flowfile USING btree (identifier varchar_pattern_ops);


--
-- Name: flowjs_flowfilechunk_6be37982; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX flowjs_flowfilechunk_6be37982 ON flowjs_flowfilechunk USING btree (parent_id);


--
-- Name: formulations_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX formulations_00d9daf3 ON formulations USING btree (molregno);


--
-- Name: formulations_5ca316a7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX formulations_5ca316a7 ON formulations USING btree (record_id);


--
-- Name: formulations_9bea82de; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX formulations_9bea82de ON formulations USING btree (product_id);


--
-- Name: frac_classification_level5_27b24744c9a2ac6c_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX frac_classification_level5_27b24744c9a2ac6c_like ON frac_classification USING btree (level5 varchar_pattern_ops);


--
-- Name: hrac_classification_level3_78a90b98e8c894b0_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX hrac_classification_level3_78a90b98e8c894b0_like ON hrac_classification USING btree (level3 varchar_pattern_ops);


--
-- Name: irac_classification_level4_1ca143c060060f24_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX irac_classification_level4_1ca143c060060f24_like ON irac_classification USING btree (level4 varchar_pattern_ops);


--
-- Name: journal_articles_0aae4c8f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_0aae4c8f ON journal_articles USING btree (issue);


--
-- Name: journal_articles_134c2848; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_134c2848 ON journal_articles USING btree (pubmed_id);


--
-- Name: journal_articles_210ab9e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_210ab9e7 ON journal_articles USING btree (volume);


--
-- Name: journal_articles_2f5a1ca4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_2f5a1ca4 ON journal_articles USING btree (last_page);


--
-- Name: journal_articles_59360cdc; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_59360cdc ON journal_articles USING btree (first_page);


--
-- Name: journal_articles_628b7db0; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_628b7db0 ON journal_articles USING btree (day);


--
-- Name: journal_articles_7436f942; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_7436f942 ON journal_articles USING btree (month);


--
-- Name: journal_articles_84cdc76c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_84cdc76c ON journal_articles USING btree (year);


--
-- Name: journal_articles_ba73fb5f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_ba73fb5f ON journal_articles USING btree (journal_id);


--
-- Name: journal_articles_fe7cd4d1; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_fe7cd4d1 ON journal_articles USING btree (pagination);


--
-- Name: journal_articles_first_page_6e8fc3082ea30600_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_first_page_6e8fc3082ea30600_like ON journal_articles USING btree (first_page varchar_pattern_ops);


--
-- Name: journal_articles_last_page_51483be561bb103_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_last_page_51483be561bb103_like ON journal_articles USING btree (last_page varchar_pattern_ops);


--
-- Name: journal_articles_pagination_3eceff3c558fe8b0_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX journal_articles_pagination_3eceff3c558fe8b0_like ON journal_articles USING btree (pagination varchar_pattern_ops);


--
-- Name: mechanism_refs_d288a21c; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX mechanism_refs_d288a21c ON mechanism_refs USING btree (mec_id);


--
-- Name: molecule_atc_classification_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_atc_classification_00d9daf3 ON molecule_atc_classification USING btree (molregno);


--
-- Name: molecule_atc_classification_a782ab6d; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_atc_classification_a782ab6d ON molecule_atc_classification USING btree (level5);


--
-- Name: molecule_atc_classification_level5_6edaf6cccd6efe83_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_atc_classification_level5_6edaf6cccd6efe83_like ON molecule_atc_classification USING btree (level5 varchar_pattern_ops);


--
-- Name: molecule_dictionary_5f1cb6bf; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_5f1cb6bf ON molecule_dictionary USING btree (forced_reg_index);


--
-- Name: molecule_dictionary_847cb17f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_847cb17f ON molecule_dictionary USING btree (max_phase);


--
-- Name: molecule_dictionary_86e7f1e3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_86e7f1e3 ON molecule_dictionary USING btree (pref_name);


--
-- Name: molecule_dictionary_b098ad43; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_b098ad43 ON molecule_dictionary USING btree (project_id);


--
-- Name: molecule_dictionary_c3d35a24; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_c3d35a24 ON molecule_dictionary USING btree (therapeutic_flag);


--
-- Name: molecule_dictionary_e93cb7eb; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_e93cb7eb ON molecule_dictionary USING btree (created_by_id);


--
-- Name: molecule_dictionary_pref_name_57678f71652d6899_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_pref_name_57678f71652d6899_like ON molecule_dictionary USING btree (pref_name varchar_pattern_ops);


--
-- Name: molecule_dictionary_structure_key_3622795080b1f525_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_dictionary_structure_key_3622795080b1f525_like ON molecule_dictionary USING btree (structure_key varchar_pattern_ops);


--
-- Name: molecule_frac_classification_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_frac_classification_00d9daf3 ON molecule_frac_classification USING btree (molregno);


--
-- Name: molecule_frac_classification_e27e5fca; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_frac_classification_e27e5fca ON molecule_frac_classification USING btree (frac_class_id);


--
-- Name: molecule_hierarchy_69ac9490; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_hierarchy_69ac9490 ON molecule_hierarchy USING btree (parent_molregno);


--
-- Name: molecule_hierarchy_e79613f8; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_hierarchy_e79613f8 ON molecule_hierarchy USING btree (active_molregno);


--
-- Name: molecule_hrac_classification_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_hrac_classification_00d9daf3 ON molecule_hrac_classification USING btree (molregno);


--
-- Name: molecule_hrac_classification_2c2181d0; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_hrac_classification_2c2181d0 ON molecule_hrac_classification USING btree (hrac_class_id);


--
-- Name: molecule_irac_classification_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_irac_classification_00d9daf3 ON molecule_irac_classification USING btree (molregno);


--
-- Name: molecule_irac_classification_395e6479; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_irac_classification_395e6479 ON molecule_irac_classification USING btree (irac_class_id);


--
-- Name: molecule_synonyms_00d9daf3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_synonyms_00d9daf3 ON molecule_synonyms USING btree (molregno);


--
-- Name: molecule_synonyms_afe7a8c2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX molecule_synonyms_afe7a8c2 ON molecule_synonyms USING btree (res_stem_id);


--
-- Name: parameter_type_parameter_type_2257888bf2494167_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX parameter_type_parameter_type_2257888bf2494167_like ON parameter_type USING btree (parameter_type varchar_pattern_ops);


--
-- Name: patent_use_codes_patent_use_code_49673be8f8575d45_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX patent_use_codes_patent_use_code_49673be8f8575d45_like ON patent_use_codes USING btree (patent_use_code varchar_pattern_ops);


--
-- Name: predicted_binding_domains_9365d6e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX predicted_binding_domains_9365d6e7 ON predicted_binding_domains USING btree (site_id);


--
-- Name: predicted_binding_domains_f8a3193a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX predicted_binding_domains_f8a3193a ON predicted_binding_domains USING btree (activity_id);


--
-- Name: product_patents_1d9aed70; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX product_patents_1d9aed70 ON product_patents USING btree (patent_use_code);


--
-- Name: product_patents_9bea82de; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX product_patents_9bea82de ON product_patents USING btree (product_id);


--
-- Name: product_patents_patent_use_code_6c64608df73e677e_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX product_patents_patent_use_code_6c64608df73e677e_like ON product_patents USING btree (patent_use_code varchar_pattern_ops);


--
-- Name: products_product_id_e96e3e5236e4cd8_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX products_product_id_e96e3e5236e4cd8_like ON products USING btree (product_id varchar_pattern_ops);


--
-- Name: protein_class_synonyms_46877088; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX protein_class_synonyms_46877088 ON protein_class_synonyms USING btree (protein_class_id);


--
-- Name: protein_family_classif_protein_class_desc_582de781356cdcf5_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX protein_family_classif_protein_class_desc_582de781356cdcf5_like ON protein_family_classification USING btree (protein_class_desc varchar_pattern_ops);


--
-- Name: record_drug_properties_847cb17f; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX record_drug_properties_847cb17f ON record_drug_properties USING btree (max_phase);


--
-- Name: record_drug_properties_c3d35a24; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX record_drug_properties_c3d35a24 ON record_drug_properties USING btree (therapeutic_flag);


--
-- Name: relationship_type_relationship_type_7f3528b1ff614e53_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX relationship_type_relationship_type_7f3528b1ff614e53_like ON relationship_type USING btree (relationship_type varchar_pattern_ops);


--
-- Name: research_companies_afe7a8c2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX research_companies_afe7a8c2 ON research_companies USING btree (res_stem_id);


--
-- Name: research_stem_research_stem_2c8ec6e88be7600b_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX research_stem_research_stem_2c8ec6e88be7600b_like ON research_stem USING btree (research_stem varchar_pattern_ops);


--
-- Name: site_components_662cbf12; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX site_components_662cbf12 ON site_components USING btree (domain_id);


--
-- Name: site_components_9365d6e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX site_components_9365d6e7 ON site_components USING btree (site_id);


--
-- Name: site_components_ef5a1f55; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX site_components_ef5a1f55 ON site_components USING btree (component_id);


--
-- Name: structural_alert_sets_set_name_57160719021904be_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX structural_alert_sets_set_name_57160719021904be_like ON structural_alert_sets USING btree (set_name varchar_pattern_ops);


--
-- Name: structural_alerts_c9d598a4; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX structural_alerts_c9d598a4 ON structural_alerts USING btree (alert_set_id);


--
-- Name: target_components_97beaa21; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_components_97beaa21 ON target_components USING btree (tid);


--
-- Name: target_components_ef5a1f55; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_components_ef5a1f55 ON target_components USING btree (component_id);


--
-- Name: target_dictionary_2a7a6dd2; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_2a7a6dd2 ON target_dictionary USING btree (chembl_id);


--
-- Name: target_dictionary_2e463512; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_2e463512 ON target_dictionary USING btree (target_type);


--
-- Name: target_dictionary_59fc14e7; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_59fc14e7 ON target_dictionary USING btree (tax_id);


--
-- Name: target_dictionary_82a6e458; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_82a6e458 ON target_dictionary USING btree (organism);


--
-- Name: target_dictionary_86e7f1e3; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_86e7f1e3 ON target_dictionary USING btree (pref_name);


--
-- Name: target_dictionary_chembl_id_9ce1c9e29d9cd16_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_chembl_id_9ce1c9e29d9cd16_like ON target_dictionary USING btree (chembl_id varchar_pattern_ops);


--
-- Name: target_dictionary_organism_3dca64114730d56c_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_organism_3dca64114730d56c_like ON target_dictionary USING btree (organism varchar_pattern_ops);


--
-- Name: target_dictionary_pref_name_55e429a39486105e_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_dictionary_pref_name_55e429a39486105e_like ON target_dictionary USING btree (pref_name varchar_pattern_ops);


--
-- Name: target_relations_6fca3e33; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_relations_6fca3e33 ON target_relations USING btree (related_tid);


--
-- Name: target_relations_97beaa21; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_relations_97beaa21 ON target_relations USING btree (tid);


--
-- Name: target_type_target_type_582fc96b04db2afb_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX target_type_target_type_582fc96b04db2afb_like ON target_type USING btree (target_type varchar_pattern_ops);


--
-- Name: tastypie_apikey_3c6e0b8a; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX tastypie_apikey_3c6e0b8a ON tastypie_apikey USING btree (key);


--
-- Name: tastypie_apikey_key_b86d63920e5bbcb_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX tastypie_apikey_key_b86d63920e5bbcb_like ON tastypie_apikey USING btree (key varchar_pattern_ops);


--
-- Name: version_name_310591769a492e51_like; Type: INDEX; Schema: public; Owner: chembl; Tablespace: 
--

CREATE INDEX version_name_310591769a492e51_like ON version USING btree (name varchar_pattern_ops);


--
-- Name: D0bf4d1eef52a0d3981ab1f032d3369e; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_hrac_classification
    ADD CONSTRAINT "D0bf4d1eef52a0d3981ab1f032d3369e" FOREIGN KEY (hrac_class_id) REFERENCES hrac_classification(hrac_class_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D0fbda1e4437adea39750f4107d82cf9; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundmultiplebatch
    ADD CONSTRAINT "D0fbda1e4437adea39750f4107d82cf9" FOREIGN KEY (project_id) REFERENCES cbh_core_model_project(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D1623fdd07f839117ce642a236e66c1c; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT "D1623fdd07f839117ce642a236e66c1c" FOREIGN KEY (relationship_type) REFERENCES relationship_type(relationship_type) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D1a57e90c33b2140b097dcad37cf46cc; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project
    ADD CONSTRAINT "D1a57e90c33b2140b097dcad37cf46cc" FOREIGN KEY (project_type_id) REFERENCES cbh_core_model_projecttype(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D1f16847ae2ece2927bf903ed4228f7a; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_pinnedcustomfield
    ADD CONSTRAINT "D1f16847ae2ece2927bf903ed4228f7a" FOREIGN KEY (standardised_alias_id) REFERENCES cbh_core_model_pinnedcustomfield(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D27317652aa14511dd115d27f97532db; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY component_synonyms
    ADD CONSTRAINT "D27317652aa14511dd115d27f97532db" FOREIGN KEY (component_id) REFERENCES component_sequences(component_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D27e0906fcf12ecc0122a0fedb63af55; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassificationpermission
    ADD CONSTRAINT "D27e0906fcf12ecc0122a0fedb63af55" FOREIGN KEY (data_point_classification_id) REFERENCES cbh_datastore_model_datapointclassification(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D3041e1b0d97d5bfe2538cca9a738a6b; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project
    ADD CONSTRAINT "D3041e1b0d97d5bfe2538cca9a738a6b" FOREIGN KEY (custom_field_config_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D305f25212d15c1bd0f642368f3690d8; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundbatch
    ADD CONSTRAINT "D305f25212d15c1bd0f642368f3690d8" FOREIGN KEY (project_id) REFERENCES cbh_core_model_project(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D30921c6fca224e0ab2dbfc0a697bd44; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project_enabled_forms
    ADD CONSTRAINT "D30921c6fca224e0ab2dbfc0a697bd44" FOREIGN KEY (dataformconfig_id) REFERENCES cbh_core_model_dataformconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D491f55cf65ce3d147deaa9e986e22d9; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY target_components
    ADD CONSTRAINT "D491f55cf65ce3d147deaa9e986e22d9" FOREIGN KEY (component_id) REFERENCES component_sequences(component_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D5eb31cc76290956d4c3538f700ea287; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT "D5eb31cc76290956d4c3538f700ea287" FOREIGN KEY (data_validity_comment) REFERENCES data_validity_lookup(data_validity_comment) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D605186f64ee05ef8d6261becf4ec5d7; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT "D605186f64ee05ef8d6261becf4ec5d7" FOREIGN KEY (parent_id) REFERENCES cbh_datastore_model_datapointclassification(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D63d1b80358d54bd6d57f0748c0fb6e1; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY component_class
    ADD CONSTRAINT "D63d1b80358d54bd6d57f0748c0fb6e1" FOREIGN KEY (protein_class_id) REFERENCES protein_classification(protein_class_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D70afb8aca5c0c487d50eab75b2fa388; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_pinnedcustomfield
    ADD CONSTRAINT "D70afb8aca5c0c487d50eab75b2fa388" FOREIGN KEY (custom_field_config_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D732cd922b9f52447f3a6f6e16ae118c; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY biotherapeutic_components
    ADD CONSTRAINT "D732cd922b9f52447f3a6f6e16ae118c" FOREIGN KEY (component_id) REFERENCES bio_component_sequences(component_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D77fb5ccfb46364f7a82e2420c7a6d11; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY structural_alerts
    ADD CONSTRAINT "D77fb5ccfb46364f7a82e2420c7a6d11" FOREIGN KEY (alert_set_id) REFERENCES structural_alert_sets(alert_set_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D799e0fec7a9e0c434793a1752093cd7; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_pinnedcustomfield
    ADD CONSTRAINT "D799e0fec7a9e0c434793a1752093cd7" FOREIGN KEY (attachment_field_mapped_to_id) REFERENCES cbh_core_model_pinnedcustomfield(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D7e2d19bbdd809cff3f3c90671ace3cd; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_attachment
    ADD CONSTRAINT "D7e2d19bbdd809cff3f3c90671ace3cd" FOREIGN KEY (data_point_classification_id) REFERENCES cbh_datastore_model_datapointclassification(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D8670aca8c6aad8a63b8d44c1bb37e8e; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY component_domains
    ADD CONSTRAINT "D8670aca8c6aad8a63b8d44c1bb37e8e" FOREIGN KEY (component_id) REFERENCES component_sequences(component_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D8fccbb1f79cad9dd90291da828a7afd; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_irac_classification
    ADD CONSTRAINT "D8fccbb1f79cad9dd90291da828a7afd" FOREIGN KEY (irac_class_id) REFERENCES irac_classification(irac_class_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D9801047c35794d8da33b7cdbddb986d; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT "D9801047c35794d8da33b7cdbddb986d" FOREIGN KEY (confidence_score) REFERENCES confidence_score_lookup(confidence_score) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: D9c5e7281bf68c242c725c56e3384498; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundbatch
    ADD CONSTRAINT "D9c5e7281bf68c242c725c56e3384498" FOREIGN KEY (related_molregno_id) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: a51a8833f63096604a96a0aedce670cd; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_attachment
    ADD CONSTRAINT a51a8833f63096604a96a0aedce670cd FOREIGN KEY (attachment_custom_field_config_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: aa8e2e8ebce3ff8d79ba9da1220fe501; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_frac_classification
    ADD CONSTRAINT aa8e2e8ebce3ff8d79ba9da1220fe501 FOREIGN KEY (frac_class_id) REFERENCES frac_classification(frac_class_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: abba467a38e5ba1ff49c5650a3e0dc70; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY protein_class_synonyms
    ADD CONSTRAINT abba467a38e5ba1ff49c5650a3e0dc70 FOREIGN KEY (protein_class_id) REFERENCES protein_classification(protein_class_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: activi_record_id_68c4a3f1e04b579e_fk_compound_records_record_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activi_record_id_68c4a3f1e04b579e_fk_compound_records_record_id FOREIGN KEY (record_id) REFERENCES compound_records(record_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: activities_assay_id_19ce72ed9be2b295_fk_assays_assay_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_assay_id_19ce72ed9be2b295_fk_assays_assay_id FOREIGN KEY (assay_id) REFERENCES assays(assay_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: activities_doc_id_1424c6b06c1521ea_fk_docs_doc_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_doc_id_1424c6b06c1521ea_fk_docs_doc_id FOREIGN KEY (doc_id) REFERENCES docs(doc_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: activities_molregno_409fc28a1fe46b59_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_molregno_409fc28a1fe46b59_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_curated_by_485dce9205d0908b_fk_curation_lookup_curated_by; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assay_curated_by_485dce9205d0908b_fk_curation_lookup_curated_by FOREIGN KEY (curated_by) REFERENCES curation_lookup(curated_by) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_parameters_assay_id_41488b2f9efa805a_fk_assays_assay_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assay_parameters
    ADD CONSTRAINT assay_parameters_assay_id_41488b2f9efa805a_fk_assays_assay_id FOREIGN KEY (assay_id) REFERENCES assays(assay_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assays_assay_type_3b977e85ee08d5f_fk_assay_type_assay_type; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_assay_type_3b977e85ee08d5f_fk_assay_type_assay_type FOREIGN KEY (assay_type) REFERENCES assay_type(assay_type) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assays_cell_id_68536d16e63deea0_fk_cell_dictionary_cell_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_cell_id_68536d16e63deea0_fk_cell_dictionary_cell_id FOREIGN KEY (cell_id) REFERENCES cell_dictionary(cell_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assays_chembl_id_2ab2cb7f6704cd85_fk_chembl_id_lookup_chembl_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_chembl_id_2ab2cb7f6704cd85_fk_chembl_id_lookup_chembl_id FOREIGN KEY (chembl_id) REFERENCES chembl_id_lookup(chembl_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assays_doc_id_68edd48dfeffa4b9_fk_docs_doc_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_doc_id_68edd48dfeffa4b9_fk_docs_doc_id FOREIGN KEY (doc_id) REFERENCES docs(doc_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assays_src_id_4a9a0296fc470991_fk_source_src_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_src_id_4a9a0296fc470991_fk_source_src_id FOREIGN KEY (src_id) REFERENCES source(src_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assays_tid_565a2e1ef364cd05_fk_target_dictionary_tid; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assays
    ADD CONSTRAINT assays_tid_565a2e1ef364cd05_fk_target_dictionary_tid FOREIGN KEY (tid) REFERENCES target_dictionary(tid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_content_type_id_508cf46651277a81_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_permission
    ADD CONSTRAINT auth_content_type_id_508cf46651277a81_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissio_group_id_689710a9a73b7457_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_group_id_689710a9a73b7457_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permission_id_1f49ccbbdc69d2fc_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_group_permissions
    ADD CONSTRAINT auth_group_permission_id_1f49ccbbdc69d2fc_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user__permission_id_384b62483d7071f0_fk_auth_permission_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user__permission_id_384b62483d7071f0_fk_auth_permission_id FOREIGN KEY (permission_id) REFERENCES auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups_group_id_33ac548dcf5f8e37_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_group_id_33ac548dcf5f8e37_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_groups_user_id_4b5ed4ffdb8fd9b0_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user_groups
    ADD CONSTRAINT auth_user_groups_user_id_4b5ed4ffdb8fd9b0_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_user_user_permiss_user_id_7f0938558328534a_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY auth_user_user_permissions
    ADD CONSTRAINT auth_user_user_permiss_user_id_7f0938558328534a_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: b52e93cdb10c494b17e3059f326fceb1; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapoint
    ADD CONSTRAINT b52e93cdb10c494b17e3059f326fceb1 FOREIGN KEY (custom_field_config_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: bb2fad37ce10c373d4eb6b474db3f05f; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY component_class
    ADD CONSTRAINT bb2fad37ce10c373d4eb6b474db3f05f FOREIGN KEY (component_id) REFERENCES component_sequences(component_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: be5e00d73e0e74b7a526116d12724aea; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY assay_parameters
    ADD CONSTRAINT be5e00d73e0e74b7a526116d12724aea FOREIGN KEY (parameter_type) REFERENCES parameter_type(parameter_type) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: binding_sites_tid_3ad9827e71453a4_fk_target_dictionary_tid; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY binding_sites
    ADD CONSTRAINT binding_sites_tid_3ad9827e71453a4_fk_target_dictionary_tid FOREIGN KEY (tid) REFERENCES target_dictionary(tid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biotherap_molregno_60135d39648e9c72_fk_biotherapeutics_molregno; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY biotherapeutic_components
    ADD CONSTRAINT biotherap_molregno_60135d39648e9c72_fk_biotherapeutics_molregno FOREIGN KEY (molregno) REFERENCES biotherapeutics(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biotherapeutics_molregno_61fe2eb147f735d0_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY biotherapeutics
    ADD CONSTRAINT biotherapeutics_molregno_61fe2eb147f735d0_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: c_l0_id_10b49cfa05bfd1c3_fk_cbh_core_model_customfieldconfig_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT c_l0_id_10b49cfa05bfd1c3_fk_cbh_core_model_customfieldconfig_id FOREIGN KEY (l0_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: c_l1_id_56240325e751a1be_fk_cbh_core_model_customfieldconfig_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT c_l1_id_56240325e751a1be_fk_cbh_core_model_customfieldconfig_id FOREIGN KEY (l1_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: c_l2_id_7c592455a79a26bb_fk_cbh_core_model_customfieldconfig_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT c_l2_id_7c592455a79a26bb_fk_cbh_core_model_customfieldconfig_id FOREIGN KEY (l2_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: c_l4_id_511ac037e8fc5d6f_fk_cbh_core_model_customfieldconfig_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT c_l4_id_511ac037e8fc5d6f_fk_cbh_core_model_customfieldconfig_id FOREIGN KEY (l4_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: c_structure_id_4b4eb0aeac2fd64c_fk_compound_structures_molregno; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY chembl_business_model_inchierrors
    ADD CONSTRAINT c_structure_id_4b4eb0aeac2fd64c_fk_compound_structures_molregno FOREIGN KEY (structure_id) REFERENCES compound_structures(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cb_l3_id_3474b704f917784_fk_cbh_core_model_customfieldconfig_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT cb_l3_id_3474b704f917784_fk_cbh_core_model_customfieldconfig_id FOREIGN KEY (l3_id) REFERENCES cbh_core_model_customfieldconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh__l0_id_1fe25be67698586b_fk_cbh_datastore_model_datapoint_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh__l0_id_1fe25be67698586b_fk_cbh_datastore_model_datapoint_id FOREIGN KEY (l0_id) REFERENCES cbh_datastore_model_datapoint(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh__l1_id_53cbe578b9a8da90_fk_cbh_datastore_model_datapoint_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh__l1_id_53cbe578b9a8da90_fk_cbh_datastore_model_datapoint_id FOREIGN KEY (l1_id) REFERENCES cbh_datastore_model_datapoint(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh__l2_id_7eb89ae23bcea073_fk_cbh_datastore_model_datapoint_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh__l2_id_7eb89ae23bcea073_fk_cbh_datastore_model_datapoint_id FOREIGN KEY (l2_id) REFERENCES cbh_datastore_model_datapoint(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh__l3_id_7aae6aebf19a3056_fk_cbh_datastore_model_datapoint_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh__l3_id_7aae6aebf19a3056_fk_cbh_datastore_model_datapoint_id FOREIGN KEY (l3_id) REFERENCES cbh_datastore_model_datapoint(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh__l4_id_7ea27dce6e8a48ef_fk_cbh_datastore_model_datapoint_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh__l4_id_7ea27dce6e8a48ef_fk_cbh_datastore_model_datapoint_id FOREIGN KEY (l4_id) REFERENCES cbh_datastore_model_datapoint(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_che_uploaded_file_id_2eaa889fb0be1019_fk_flowjs_flowfile_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_chembl_model_extension_cbhcompoundmultiplebatch
    ADD CONSTRAINT cbh_che_uploaded_file_id_2eaa889fb0be1019_fk_flowjs_flowfile_id FOREIGN KEY (uploaded_file_id) REFERENCES flowjs_flowfile(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_chembl_model__created_by_id_49d85ba97a2c139_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project
    ADD CONSTRAINT cbh_chembl_model__created_by_id_49d85ba97a2c139_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_chembl_model_created_by_id_283f4faeb14f037d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_customfieldconfig
    ADD CONSTRAINT cbh_chembl_model_created_by_id_283f4faeb14f037d_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_co_project_id_7b174848d24f3d5f_fk_cbh_core_model_project_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_project_enabled_forms
    ADD CONSTRAINT cbh_co_project_id_7b174848d24f3d5f_fk_cbh_core_model_project_id FOREIGN KEY (project_id) REFERENCES cbh_core_model_project(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_core_model_d_created_by_id_7a5a6bbf405f76cb_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT cbh_core_model_d_created_by_id_7a5a6bbf405f76cb_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_da_project_id_2373f087eebe98e8_fk_cbh_core_model_project_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassificationpermission
    ADD CONSTRAINT cbh_da_project_id_2373f087eebe98e8_fk_cbh_core_model_project_id FOREIGN KEY (project_id) REFERENCES cbh_core_model_project(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_data_type_id_2d208b487011d067_fk_cbh_core_model_datatype_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_customfieldconfig
    ADD CONSTRAINT cbh_data_type_id_2d208b487011d067_fk_cbh_core_model_datatype_id FOREIGN KEY (data_type_id) REFERENCES cbh_core_model_datatype(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_datastor_flowfile_id_5bf8988b9c88812f_fk_flowjs_flowfile_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_attachment
    ADD CONSTRAINT cbh_datastor_flowfile_id_5bf8988b9c88812f_fk_flowjs_flowfile_id FOREIGN KEY (flowfile_id) REFERENCES flowjs_flowfile(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_datastore_mo_created_by_id_1f57622084aada95_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_query
    ADD CONSTRAINT cbh_datastore_mo_created_by_id_1f57622084aada95_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_datastore_mo_created_by_id_30811767f457819d_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapoint
    ADD CONSTRAINT cbh_datastore_mo_created_by_id_30811767f457819d_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_datastore_mo_created_by_id_6a640f856e9dd8a7_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_attachment
    ADD CONSTRAINT cbh_datastore_mo_created_by_id_6a640f856e9dd8a7_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cbh_datastore_mod_created_by_id_171ae5a1241af93_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT cbh_datastore_mod_created_by_id_171ae5a1241af93_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cef9777fd7d2bebfb76f9b903002f156; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY site_components
    ADD CONSTRAINT cef9777fd7d2bebfb76f9b903002f156 FOREIGN KEY (component_id) REFERENCES component_sequences(component_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_d_chembl_id_411ff762808eea37_fk_chembl_id_lookup_chembl_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cell_dictionary
    ADD CONSTRAINT cell_d_chembl_id_411ff762808eea37_fk_chembl_id_lookup_chembl_id FOREIGN KEY (chembl_id) REFERENCES chembl_id_lookup(chembl_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: chembl_bu_image_id_377ad91b41c09aee_fk_compound_images_molregno; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY chembl_business_model_imageerrors
    ADD CONSTRAINT chembl_bu_image_id_377ad91b41c09aee_fk_compound_images_molregno FOREIGN KEY (image_id) REFERENCES compound_images(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: component_domai_domain_id_75f026b9fde96d0e_fk_domains_domain_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY component_domains
    ADD CONSTRAINT component_domai_domain_id_75f026b9fde96d0e_fk_domains_domain_id FOREIGN KEY (domain_id) REFERENCES domains(domain_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compoun_alert_id_305d2d0244dee404_fk_structural_alerts_alert_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_structural_alerts
    ADD CONSTRAINT compoun_alert_id_305d2d0244dee404_fk_structural_alerts_alert_id FOREIGN KEY (alert_id) REFERENCES structural_alerts(alert_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_images_molregno_6a45963990855dfd_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_images
    ADD CONSTRAINT compound_images_molregno_6a45963990855dfd_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_mols_molregno_5ce3e4279b5aa25a_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_mols
    ADD CONSTRAINT compound_mols_molregno_5ce3e4279b5aa25a_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_properties_molregno_160c5a72940b90_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_properties
    ADD CONSTRAINT compound_properties_molregno_160c5a72940b90_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_records_doc_id_351cc8be774a8ff_fk_docs_doc_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_records
    ADD CONSTRAINT compound_records_doc_id_351cc8be774a8ff_fk_docs_doc_id FOREIGN KEY (doc_id) REFERENCES docs(doc_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_records_molregno_7990cfe5f0b3e7c2_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_records
    ADD CONSTRAINT compound_records_molregno_7990cfe5f0b3e7c2_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_records_src_id_76640cd34545f829_fk_source_src_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_records
    ADD CONSTRAINT compound_records_src_id_76640cd34545f829_fk_source_src_id FOREIGN KEY (src_id) REFERENCES source(src_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_structural_alerts_molregno_5c93b53e6e6810ad_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_structural_alerts
    ADD CONSTRAINT compound_structural_alerts_molregno_5c93b53e6e6810ad_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: compound_structures_molregno_576c9f458c5a528b_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY compound_structures
    ADD CONSTRAINT compound_structures_molregno_576c9f458c5a528b_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: d6ff9b61d28876335144afd43a7be12e; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_pinnedcustomfield
    ADD CONSTRAINT d6ff9b61d28876335144afd43a7be12e FOREIGN KEY (pinned_for_datatype_id) REFERENCES cbh_core_model_datatype(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: db0999b05985dd643b50c34bb93dc227; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_attachment
    ADD CONSTRAINT db0999b05985dd643b50c34bb93dc227 FOREIGN KEY (chosen_data_form_config_id) REFERENCES cbh_core_model_dataformconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: db51acc1e8fae3eefb74a2ff631e3c51; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY product_patents
    ADD CONSTRAINT db51acc1e8fae3eefb74a2ff631e3c51 FOREIGN KEY (patent_use_code) REFERENCES patent_use_codes(patent_use_code) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dd7cb7e16b2ec28577c870c3d59f1c0d; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_datastore_model_datapointclassification
    ADD CONSTRAINT dd7cb7e16b2ec28577c870c3d59f1c0d FOREIGN KEY (data_form_config_id) REFERENCES cbh_core_model_dataformconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: defined__atc_code_35cc27385707962c_fk_atc_classification_level5; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY defined_daily_dose
    ADD CONSTRAINT defined__atc_code_35cc27385707962c_fk_atc_classification_level5 FOREIGN KEY (atc_code) REFERENCES atc_classification(level5) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: djan_content_type_id_697914295151027a_fk_django_content_type_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT djan_content_type_id_697914295151027a_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log_user_id_52fdd58701c5f563_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_52fdd58701c5f563_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: docs_chembl_id_522eec303eeefb50_fk_chembl_id_lookup_chembl_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY docs
    ADD CONSTRAINT docs_chembl_id_522eec303eeefb50_fk_chembl_id_lookup_chembl_id FOREIGN KEY (chembl_id) REFERENCES chembl_id_lookup(chembl_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: docs_journal_id_1189a3625a253fbf_fk_journals_journal_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY docs
    ADD CONSTRAINT docs_journal_id_1189a3625a253fbf_fk_journals_journal_id FOREIGN KEY (journal_id) REFERENCES journals(journal_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: drug_m_record_id_2fa2c4d19bac9d37_fk_compound_records_record_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY drug_mechanism
    ADD CONSTRAINT drug_m_record_id_2fa2c4d19bac9d37_fk_compound_records_record_id FOREIGN KEY (record_id) REFERENCES compound_records(record_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: drug_mec_action_type_d03cb79f89de2bd_fk_action_type_action_type; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY drug_mechanism
    ADD CONSTRAINT drug_mec_action_type_d03cb79f89de2bd_fk_action_type_action_type FOREIGN KEY (action_type) REFERENCES action_type(action_type) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: drug_mechanis_site_id_393dc7835a080705_fk_binding_sites_site_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY drug_mechanism
    ADD CONSTRAINT drug_mechanis_site_id_393dc7835a080705_fk_binding_sites_site_id FOREIGN KEY (site_id) REFERENCES binding_sites(site_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: drug_mechanism_molregno_77cf843ccae55220_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY drug_mechanism
    ADD CONSTRAINT drug_mechanism_molregno_77cf843ccae55220_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: drug_mechanism_tid_2f89e7096becf4b7_fk_target_dictionary_tid; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY drug_mechanism
    ADD CONSTRAINT drug_mechanism_tid_2f89e7096becf4b7_fk_target_dictionary_tid FOREIGN KEY (tid) REFERENCES target_dictionary(tid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: fa868899de62e5fcc2552916d24467ae; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT fa868899de62e5fcc2552916d24467ae FOREIGN KEY (project_id) REFERENCES cbh_core_model_project(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flowjs_flowfil_parent_id_7c52373f62ea75df_fk_flowjs_flowfile_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY flowjs_flowfilechunk
    ADD CONSTRAINT flowjs_flowfil_parent_id_7c52373f62ea75df_fk_flowjs_flowfile_id FOREIGN KEY (parent_id) REFERENCES flowjs_flowfile(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: formul_record_id_4e75dad439de8398_fk_compound_records_record_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY formulations
    ADD CONSTRAINT formul_record_id_4e75dad439de8398_fk_compound_records_record_id FOREIGN KEY (record_id) REFERENCES compound_records(record_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: formulations_molregno_41625752fab888d1_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY formulations
    ADD CONSTRAINT formulations_molregno_41625752fab888d1_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: formulations_product_id_543d84a3b2a3dfe7_fk_products_product_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY formulations
    ADD CONSTRAINT formulations_product_id_543d84a3b2a3dfe7_fk_products_product_id FOREIGN KEY (product_id) REFERENCES products(product_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: journal_arti_journal_id_62792bc1625b4419_fk_journals_journal_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY journal_articles
    ADD CONSTRAINT journal_arti_journal_id_62792bc1625b4419_fk_journals_journal_id FOREIGN KEY (journal_id) REFERENCES journals(journal_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: ligand_e_activity_id_62deda1608e681ec_fk_activities_activity_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY ligand_eff
    ADD CONSTRAINT ligand_e_activity_id_62deda1608e681ec_fk_activities_activity_id FOREIGN KEY (activity_id) REFERENCES activities(activity_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: mechanism_refs_mec_id_5fbae17dfa2e0416_fk_drug_mechanism_mec_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY mechanism_refs
    ADD CONSTRAINT mechanism_refs_mec_id_5fbae17dfa2e0416_fk_drug_mechanism_mec_id FOREIGN KEY (mec_id) REFERENCES drug_mechanism(mec_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molec_res_stem_id_70f6bdfc7e58c948_fk_research_stem_res_stem_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_synonyms
    ADD CONSTRAINT molec_res_stem_id_70f6bdfc7e58c948_fk_research_stem_res_stem_id FOREIGN KEY (res_stem_id) REFERENCES research_stem(res_stem_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecu_chembl_id_1bcfc9c893233925_fk_chembl_id_lookup_chembl_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT molecu_chembl_id_1bcfc9c893233925_fk_chembl_id_lookup_chembl_id FOREIGN KEY (chembl_id) REFERENCES chembl_id_lookup(chembl_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_a_level5_6edaf6cccd6efe83_fk_atc_classification_level5; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_atc_classification
    ADD CONSTRAINT molecule_a_level5_6edaf6cccd6efe83_fk_atc_classification_level5 FOREIGN KEY (level5) REFERENCES atc_classification(level5) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_atc_classification_molregno_322418af48ffd81d_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_atc_classification
    ADD CONSTRAINT molecule_atc_classification_molregno_322418af48ffd81d_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_diction_created_by_id_28c6e8e7de34c388_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_dictionary
    ADD CONSTRAINT molecule_diction_created_by_id_28c6e8e7de34c388_fk_auth_user_id FOREIGN KEY (created_by_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_frac_classification_molregno_5844b36804f90988_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_frac_classification
    ADD CONSTRAINT molecule_frac_classification_molregno_5844b36804f90988_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_hierarchy_active_molregno_25fe7b0f3bae467a_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_hierarchy
    ADD CONSTRAINT molecule_hierarchy_active_molregno_25fe7b0f3bae467a_fk FOREIGN KEY (active_molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_hierarchy_molregno_203a50eedde1b394_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_hierarchy
    ADD CONSTRAINT molecule_hierarchy_molregno_203a50eedde1b394_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_hierarchy_parent_molregno_23e4c0f304333240_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_hierarchy
    ADD CONSTRAINT molecule_hierarchy_parent_molregno_23e4c0f304333240_fk FOREIGN KEY (parent_molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_hrac_classification_molregno_d388f3d5aa1418e_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_hrac_classification
    ADD CONSTRAINT molecule_hrac_classification_molregno_d388f3d5aa1418e_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_irac_classification_molregno_51d8ac6eb3668887_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_irac_classification
    ADD CONSTRAINT molecule_irac_classification_molregno_51d8ac6eb3668887_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: molecule_synonyms_molregno_59baecdd91cae712_fk; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY molecule_synonyms
    ADD CONSTRAINT molecule_synonyms_molregno_59baecdd91cae712_fk FOREIGN KEY (molregno) REFERENCES molecule_dictionary(molregno) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: parent_id_4d157f5503cdb68d_fk_cbh_core_model_dataformconfig_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY cbh_core_model_dataformconfig
    ADD CONSTRAINT parent_id_4d157f5503cdb68d_fk_cbh_core_model_dataformconfig_id FOREIGN KEY (parent_id) REFERENCES cbh_core_model_dataformconfig(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: predicted_activity_id_4695eb7404eab9c_fk_activities_activity_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY predicted_binding_domains
    ADD CONSTRAINT predicted_activity_id_4695eb7404eab9c_fk_activities_activity_id FOREIGN KEY (activity_id) REFERENCES activities(activity_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: predicted_bin_site_id_383ce0293944a176_fk_binding_sites_site_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY predicted_binding_domains
    ADD CONSTRAINT predicted_bin_site_id_383ce0293944a176_fk_binding_sites_site_id FOREIGN KEY (site_id) REFERENCES binding_sites(site_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: product_pate_product_id_3186059d632f525e_fk_products_product_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY product_patents
    ADD CONSTRAINT product_pate_product_id_3186059d632f525e_fk_products_product_id FOREIGN KEY (product_id) REFERENCES products(product_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: record_record_id_47d724f2cd1202f5_fk_compound_records_record_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY record_drug_properties
    ADD CONSTRAINT record_record_id_47d724f2cd1202f5_fk_compound_records_record_id FOREIGN KEY (record_id) REFERENCES compound_records(record_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: resea_res_stem_id_4ed094f887aeb951_fk_research_stem_res_stem_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY research_companies
    ADD CONSTRAINT resea_res_stem_id_4ed094f887aeb951_fk_research_stem_res_stem_id FOREIGN KEY (res_stem_id) REFERENCES research_stem(res_stem_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: site_componen_site_id_53e357b2125d61f8_fk_binding_sites_site_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY site_components
    ADD CONSTRAINT site_componen_site_id_53e357b2125d61f8_fk_binding_sites_site_id FOREIGN KEY (site_id) REFERENCES binding_sites(site_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: site_components_domain_id_8fea5bd01b22cd5_fk_domains_domain_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY site_components
    ADD CONSTRAINT site_components_domain_id_8fea5bd01b22cd5_fk_domains_domain_id FOREIGN KEY (domain_id) REFERENCES domains(domain_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: target__chembl_id_9ce1c9e29d9cd16_fk_chembl_id_lookup_chembl_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY target_dictionary
    ADD CONSTRAINT target__chembl_id_9ce1c9e29d9cd16_fk_chembl_id_lookup_chembl_id FOREIGN KEY (chembl_id) REFERENCES chembl_id_lookup(chembl_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: target__target_type_303f9b9d6a726347_fk_target_type_target_type; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY target_dictionary
    ADD CONSTRAINT target__target_type_303f9b9d6a726347_fk_target_type_target_type FOREIGN KEY (target_type) REFERENCES target_type(target_type) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: target_components_tid_3080831634b6c00_fk_target_dictionary_tid; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY target_components
    ADD CONSTRAINT target_components_tid_3080831634b6c00_fk_target_dictionary_tid FOREIGN KEY (tid) REFERENCES target_dictionary(tid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: target_re_related_tid_65f867593280324a_fk_target_dictionary_tid; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY target_relations
    ADD CONSTRAINT target_re_related_tid_65f867593280324a_fk_target_dictionary_tid FOREIGN KEY (related_tid) REFERENCES target_dictionary(tid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: target_relations_tid_53fda8274f78238e_fk_target_dictionary_tid; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY target_relations
    ADD CONSTRAINT target_relations_tid_53fda8274f78238e_fk_target_dictionary_tid FOREIGN KEY (tid) REFERENCES target_dictionary(tid) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tastypie_apikey_user_id_ffeb4840e0b406b_fk_auth_user_id; Type: FK CONSTRAINT; Schema: public; Owner: chembl
--

ALTER TABLE ONLY tastypie_apikey
    ADD CONSTRAINT tastypie_apikey_user_id_ffeb4840e0b406b_fk_auth_user_id FOREIGN KEY (user_id) REFERENCES auth_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

