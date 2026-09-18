--
-- PostgreSQL database dump
--

-- Dumped from database version 13.16 (Ubuntu 13.16-1.pgdg24.04+1)
-- Dumped by pg_dump version 17.5

-- Started on 2026-09-09 18:36:37

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 286 (class 2615 OID 16431)
-- Name: nfe; Type: SCHEMA; Schema: -; Owner: planosassessoria
--

CREATE SCHEMA nfe;


ALTER SCHEMA nfe OWNER TO planosassessoria;

--
-- TOC entry 3000 (class 1255 OID 16749)
-- Name: corrigir_situacao_nfe(integer, date, date); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.corrigir_situacao_nfe(id_empresa integer, dt_inicial date, dt_final date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
begin
create temp table situacao on commit drop as
(		
	select
		a.id_empresa,
		a.inf_nfe,
		case b.c_stat
		when 101 then 'Cancelada'::text
		when 151 then 'Cancelada Fora Do Prazo'::text
		when 301 then 'Denegada'::text
		else a.situacao end as situacao,
		a.tipo_nf
	from
	(
		with dados as
		(
			select
				a.id_empresa,
				a.cpf_cnpj,
				a.razao_social as nome,
				$2::date as dt_ini2,
				$3::date as dt_fin2
			from
				ncm_helper.cad_empresas as a
			where
				a.id_empresa = $1
		)
		select
			a.id_empresa,
			b.inf_nfe,
			b.situacao,
			'Proprias'::text as tipo_nf
		from
			dados as a
		join
			livros.consulta_nfe_sefaz_saida as b using(id_empresa)
		where
			b.d_emi between a.dt_ini2 and a.dt_fin2 and
			b.pesquisa_fts @@ to_tsquery('autorizada')
		union

		select
			a.id_empresa,
			b.inf_nfe,
			b.situacao,
			'Terceiros'::text as tipo_nf
		from
			dados as a
		join
			livros.consulta_nfe_sefaz as b using(id_empresa)
		where
			b.d_emi between  a.dt_ini2 and a.dt_fin2 and
			b.pesquisa_fts @@ to_tsquery('autorizada')
	)as a
	join
		dfe.const_sit_nfe_inf_prot as b on a.inf_nfe = b.chv_nfe 
	where
		not b.c_stat = some(array[100, 150])

	union

	select
		a.id_empresa,
		a.inf_nfe,
		case b.c_stat
		when 101 then 'Cancelada'::text
		when 151 then 'Cancelada Fora Do Prazo'::text
		when 301 then 'Denegada'::text
		else a.situacao end as situacao,
		a.tipo_nf
	from
	(
		with dados as
		(
			select
				a.id_empresa,
				a.cpf_cnpj,
				a.razao_social as nome,
				$2::date as dt_ini2,
				$3::date as dt_fin2
			from
				ncm_helper.cad_empresas as a
			where
				a.id_empresa = $1
		)
		select
			a.id_empresa,
			b.inf_nfe,
			b.situacao,
			'Proprias'::text as tipo_nf
		from
			dados as a
		join
			livros.consulta_nfe_sefaz_saida as b using(id_empresa)
		where
			b.d_emi between a.dt_ini2 and a.dt_fin2 and
			b.pesquisa_fts @@ to_tsquery('autorizada')
		union

		select
			a.id_empresa,
			b.inf_nfe,
			b.situacao,
			'Terceiros'::text as tipo_nf
		from
			dados as a
		join
			livros.consulta_nfe_sefaz as b using(id_empresa)
		where
			b.d_emi between  a.dt_ini2 and a.dt_fin2 and
			b.pesquisa_fts @@ to_tsquery('autorizada')
	)as a
	join
		dfe.cons_sit_nfe as b on a.inf_nfe = b.chv_nfe 
	where
		not b.c_stat = some(array[100, 150])
);
update
	livros.consulta_nfe_sefaz_saida as a
set
	situacao = b.situacao 
from
(
	select
		a.id_empresa,
		a.inf_nfe,
		a.situacao,
		a.tipo_nf
	from
		situacao as a
	where
		a.tipo_nf = 'Proprias'
)as b
where
	(a.id_empresa, a.inf_nfe) = (b.id_empresa, b.inf_nfe);

update
	livros.consulta_nfe_sefaz as a
set
	situacao = b.situacao 
from
(
	select
		a.id_empresa,
		a.inf_nfe,
		a.situacao,
		a.tipo_nf
	from
		situacao as a
	where
		a.tipo_nf = 'Terceiros'
)as b
where
	(a.id_empresa, a.inf_nfe) = (b.id_empresa, b.inf_nfe);
end;
$_$;


ALTER FUNCTION nfe.corrigir_situacao_nfe(id_empresa integer, dt_inicial date, dt_final date) OWNER TO celismar;

--
-- TOC entry 3482 (class 1255 OID 513700597)
-- Name: deleta_contingencia(); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.deleta_contingencia() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    delete from nfe.contingencia where (cpf_cnpj, n_nf, serie, "mod") = (new.cpf_cnpj, new.n_nf, new.serie, new."mod");

    return new;
end; 
$$;


ALTER FUNCTION nfe.deleta_contingencia() OWNER TO celismar;

--
-- TOC entry 3483 (class 1255 OID 513700599)
-- Name: delete_old_nfe(); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.delete_old_nfe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    DELETE FROM nfe.raiz_nfe WHERE (cpf_cnpj, n_nf, serie, mod) = (new.cpf_cnpj, new.n_nf, new.serie, new.mod);
    return new;
end;
$$;


ALTER FUNCTION nfe.delete_old_nfe() OWNER TO celismar;

--
-- TOC entry 3001 (class 1255 OID 16752)
-- Name: falta_xml_proprios_terceiros(integer, date, date, character varying, text); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.falta_xml_proprios_terceiros(id_empresa integer, dt_inicial date, dt_final date, modelo character varying, tipo text) RETURNS TABLE(tipo_emissao text, cod_mod character varying, num_doc integer, ser character varying, chv_nfe character varying, situacao text, tipo_nota text)
    LANGUAGE plpgsql
    AS $_$
declare
	dados	record;
begin
/*

    select * from nfe.falta_xml_proprios_terceiros(1124, '2020-02-01', '2020-02-29', '55', '' )

    select * from nfe.falta_xml_proprios_terceiros(1124, '2020-02-01', '2020-02-29', '55', null )


*/

    if not pg_try_advisory_lock(5) then
        raise exception 'Já existe uma consulta em andamento!' using errcode='55006';
    end if;

select a.id_empresa, a.cpf_cnpj, to_char($2::date,'yymm')::varchar(4) as ano_mes from ncm_helper.cad_empresas as a where a.id_empresa = $1 into dados;


create temp table sped_terc on commit drop as
(
    select
        a.id_empresa,
        a.cpf_cnpj as cnpj,
        b.cpf_cnpj,
        substring(c.chv_nfe, 7,14)::varchar(14) as cnpj_chave,
        c.num_doc,
        case
        when c.ser = '' then '1'::varchar(3)
        when c.ser = '0' then c.ser
        when c.ser = '00' then '0'::varchar(3)
        when c.ser = '000' then '0'::varchar(3)
        else ltrim(c.ser, '0') end ser,
        c.cod_mod,
        c.chv_nfe
    from
        sf.reg_0000 as a
    join
        sf.reg_0150 as b using(id_reg_0000)
    join
        sf.reg_c100 as c using(id_reg_0000, cod_part)
    where
        a.id_empresa = $1 and
        a.dt_ini2 between $2 and $3 and
        c.ind_emit = '1' and c.chv_nfe <> '' and
        c.cod_sit = any(array['00','01','06','07','08']) and
	not exists(select 1 from nfe.raiz_nfe as d where (a.cpf_cnpj, c.chv_nfe) = (d.dest_cpf_cnpj, d.inf_nfe)) and  
	c.cod_mod = '55'

);


create temp table sefaz on commit drop as
(
    select
        a.id_empresa,
        case when (select distinct a.cnpj from sped_terc as a) <> '' then (select distinct a.cnpj from sped_terc as a) else c.cpf_cnpj end as cnpj,
        case when a.emit_cnpj <> '' then  a.emit_cnpj else a.emit_cpf end as cpf_cnpj,
        substring(a.inf_nfe, 7,14)::varchar(14) as cnpj_chave,
        a.n_nf,
        a.inf_nfe,
        a.serie,
        a.cod_mod,
        a.d_emi,
        'Terceiros'::text as tipo_nf,
        a.situacao
    from
        livros.consulta_nfe_sefaz as a
    join
        ncm_helper.cad_empresas as c using(id_empresa)
    left join
        sped_terc as b on(a.id_empresa, a.n_nf, a.serie, a.cod_mod, a.inf_nfe) = (b.id_empresa, b.num_doc, b.ser, b.cod_mod, b.chv_nfe)
    where
        a.id_empresa = $1 and
        a.d_emi between $2 and $3 and
        a.pesquisa_fts @@ to_tsquery('autorizada') and
        b.id_empresa is null and
	not exists(select 1 from nfe.raiz_nfe as d where (c.cpf_cnpj, a.inf_nfe) = (d.dest_cpf_cnpj, d.inf_nfe))
);



create temp table terceiros on commit drop as
(
    select
        a.id_empresa,
        a.cnpj,
        a.cpf_cnpj,
        a.cnpj_chave,
        a.num_doc,
        a.ser,
        a.cod_mod,
        a.chv_nfe
    from
    (
        select
            a.id_empresa,
            a.cnpj,
            a.cpf_cnpj,
            a.cnpj_chave,
            a.num_doc,
            a.ser,
            a.cod_mod,
            a.chv_nfe
        from
            sped_terc as a
        join
            livros.consulta_nfe_sefaz as b on(a.id_empresa, a.num_doc, a.ser, a.cod_mod, a.chv_nfe) = (b.id_empresa, b.n_nf, b.serie, b.cod_mod, b.inf_nfe)
        where
            b.pesquisa_fts @@ to_tsquery('autorizada') and
	    not exists(select 1 from nfe.raiz_nfe as c where (a.cnpj, b.inf_nfe) = (c.dest_cpf_cnpj, c.inf_nfe))

        union

        select
            a.id_empresa,
            a.cnpj,
            a.cpf_cnpj,
            a.cnpj_chave,
            a.num_doc,
            a.ser,
            a.cod_mod,
            a.chv_nfe
        from
            sped_terc as a
        where
            a.chv_nfe <> ''and
	    not exists(select 1 from nfe.raiz_nfe as c where (a.cnpj, a.chv_nfe) = (c.dest_cpf_cnpj, c.inf_nfe))
    )as a

);


create temp table sped_prop on commit drop as
(
select
    distinct 'Proprias'::text as tipo_emissao,
    a.cod_mod,
    a.num_doc,
    a.ser,
    a.chv_nfe,
    substring(a.chv_nfe, 7,14)::varchar(14) as cnpj,
    a.id_empresa
from
    livros.falta_xml_empresa_simples($1,$2,$3) as a
where
    (a.cod_mod = modelo or modelo is null)
);

create temp table apuracao on commit drop as
(
    select
        a.cpf_cnpj,
        a.tipo_emissao,
        a.cod_mod,
        a.num_doc,
        a.ser,
        a.chv_nfe,
        a.situacao,
        a.tipo_nota
    from
    (
        select
            a.cpf_cnpj,
            a.tipo_emissao,
            a.cod_mod,
            a.num_doc,
            a.ser,
            a.chv_nfe,
            a.situacao,
            case when b.id_nfe is null then a.tipo_nota else 'Nota importada c/ divergencia de cpf_cnpj do Emitente'::text end as tipo_nota
        from
        (
            select
                a.cpf_cnpj,
                a.tipo_emissao,
                a.cod_mod,
                a.num_doc,
                a.ser,
                a.chv_nfe,
                a.situacao,
                case when b.id_nfe is null then 'Nota Nao importada'::text else 'Nota importada mas não é do cliente'::text end as tipo_nota
            from
            (
                select
                    a.tipo_emissao,
                    a.cod_mod,
                    a.num_doc,
                    a.ser,
                    a.chv_nfe,
                    a.situacao,
                    a.cpf_cnpj
                from
                (
                    select
                        distinct 'Terceiros'::text as tipo_emissao,
                        a.cpf_cnpj,
                        a.num_doc,
                        a.ser,
                        a.cod_mod,
                        a.chv_nfe,
                        'Autoriada'::text as situacao
                    from
                        terceiros as a
                    left join
                        nfe.raiz_nfe as b on(a.cnpj, a.num_doc, a.ser, a.cod_mod, a.chv_nfe) = (b.dest_cpf_cnpj, b.n_nf, b.ser, b.mod, b.inf_nfe)
                    where
                        b.id_nfe is null

                    union

                    select
                        distinct 'Terceiros'::text as tipo_emissao,
                        a.cpf_cnpj,
                        a.n_nf,
                        a.serie,
                        a.cod_mod,
                        a.inf_nfe,
                        a.situacao
                    from
                        sefaz as a
                    left join
                        nfe.raiz_nfe as b on(a.cnpj, a.n_nf, a.serie, a.cod_mod, a.inf_nfe) = (b.dest_cpf_cnpj, b.n_nf, b.ser, b.mod, b.inf_nfe)
                    where
                        b.id_nfe is null

                )as a

                union

                select
                    a.tipo_emissao,
                    a.cod_mod,
                    a.num_doc,
                    a.ser,
                    case when b.inf_nfe <> '' then b.inf_nfe else a.chv_nfe end as chv_nfe,
                    case when b.inf_nfe <> '' then 'Autoriada'::text else 'Contigencia'::text end as situacao,
                    a.cnpj
                from
                    sped_prop as a
                left join
                    livros.consulta_nfe_sefaz_saida as b on(a.id_empresa, a.num_doc, a.ser, a.cod_mod, a.chv_nfe) = (b.id_empresa, b.n_nf, b.serie, b.cod_mod, b.inf_nfe) and b.pesquisa_fts @@ to_tsquery('autorizada')
            )as a
            left join
                nfe.raiz_nfe as b on(a.num_doc, a.chv_nfe) = (b.n_nf, b.inf_nfe) and not b.dest_cpf_cnpj = any(select distinct a.cnpj from sped_terc as a)

        ) as a
        left join
            nfe.raiz_nfe as b on(a.num_doc, a.chv_nfe) = (b.n_nf, b.inf_nfe) and a.cpf_cnpj <> b.cpf_cnpj
    )as a
    where
        CASE WHEN tipo IS NULL OR tipo = '' THEN
        TRUE
        ELSE
        LOWER(a.tipo_emissao) = LOWER(tipo)
        END
);

return query
select
    a.tipo_emissao::text,
    a.cod_mod::varchar(2),
    a.num_doc::integer,
    a.ser::varchar(3),
    a.chv_nfe::varchar(44),
    a.situacao::text,
    a.tipo_nota::text
from
(
	select
	    a.tipo_emissao::text,
	    a.cod_mod::varchar(2),
	    a.num_doc::integer,
	    a.ser::varchar(3),
	    a.chv_nfe::varchar(44),
	    a.situacao::text,
	    a.tipo_nota::text
	from
	(
	    select
		distinct on(a.num_doc, a.ser, a.cod_mod, a.chv_nfe)
		a.cpf_cnpj,
		a.tipo_emissao,
		a.cod_mod,
		a.num_doc,
		a.ser,
		a.chv_nfe,
		a.situacao,
		a.tipo_nota
	    from
		apuracao as a
	)as a

	union


	select 
		a.tipo_nf as tipo_emissao,
		a.cod_mod,
		a.num_doc,
		(a.ser::integer)::varchar(3) as ser,
		a.chv_cte,
		'Autorizado'::text as situacao,
		'Nota Nao importado'::text as tipo_nota	
	from
	(

		select 
			a.tipo_nf,
			a.cod_mod,
			a.num_doc, 
			a.chv_cte,
			substring(a.chv_cte,23,3)::varchar(3) as ser
		from
		(
			select 
				distinct 'Proprias'::text as tipo_nf,
				substring(a.chv_cte,21,2)::varchar(2) as cod_mod,
				substring(a.chv_cte,26,9)::integer as num_doc,
				a.chv_cte
			from 
				relatorios.cte_sefaz_dados a
			join
				relatorios.cte_sefaz_dados_emi b using(id_rel_cte)
			where
				b.cnpj = dados.cpf_cnpj and
				a.d_emi between $2 and $3 and
				not exists
				(	select 	1 from 
					(	
						select 
							b.cnpj,
							a.inf_cte
						from 
							cte.raiz_cte a
						join
							cte.emit b using(id_cte)		
						where
							b.cnpj = dados.cpf_cnpj and
							substring(a.inf_cte,3,4) >= dados.ano_mes
					)as d where (b.cnpj, a.chv_cte) = (d.cnpj, d.inf_cte))

				
						
		)as a

		union

		select 
			a.tipo_nf,
			a.cod_mod,
			a.num_doc,
			a.chv_cte,
			substring(a.chv_cte,23,3)::varchar(3) as ser
		from
		(
			select 
				distinct 'Terceiros'::text as tipo_nf,
				substring(a.chv_cte,21,2)::varchar(2) as cod_mod,
				substring(a.chv_cte,26,9)::integer as num_doc,
				a.chv_cte
			from 
				relatorios.cte_sefaz_dados a
			join
				relatorios.cte_sefaz_dados_tom b using(id_rel_cte)
			where
				b.cnpj = dados.cpf_cnpj and
				a.d_emi between $2 and $3 and
				not exists
				(	select 1 from 
					(	
						select 
							b.cnpj,
							a.inf_cte
						from 
							cte.raiz_cte a
						join
							cte.emit b using(id_cte)		
						where	
							b.cnpj <> dados.cpf_cnpj and
							substring(a.inf_cte,3,4) >= '2011'
					)as d where (b.cnpj, a.chv_cte) = (d.cnpj, d.inf_cte))

		)as a

		union

		select 
			case when a.ind_emit = '1' then 'Terceiros'::text else 'Proprias'::text  end as tipo_nf,	
			a.cod_mod,
			a.num_doc,
			a.chv_cte,
			substring(a.chv_cte,23,3)::varchar(3) as ser
		from
		(	
			select	
				b.ind_emit,
				substring(b.chv_cte,21,2)::varchar(2) as cod_mod,
				substring(b.chv_cte,26,9)::integer as num_doc,
				b.chv_cte
			from
				sf.reg_0000 as a
			join
				sf.reg_d100 as b using(id_reg_0000)
			where
				a.cpf_cnpj = dados.cpf_cnpj and
				a.dt_ini2 between $2 and $3

		)as a
		where
			not exists(select 1 from cte.raiz_cte as b where (a.num_doc, a.chv_cte) = ( b.n_ct, b.inf_cte))

	)as a
)as a
order by
    a.tipo_emissao, a.cod_mod, a.num_doc;

    if not pg_advisory_unlock(5) then
        raise exception 'Algo errado aconteceu ao desbloquear o lock da falta_xml_proprios_terceiros' using errcode='55006';
    end if;
END;
$_$;


ALTER FUNCTION nfe.falta_xml_proprios_terceiros(id_empresa integer, dt_inicial date, dt_final date, modelo character varying, tipo text) OWNER TO celismar;

--
-- TOC entry 3479 (class 1255 OID 513700594)
-- Name: faz_magia(); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.faz_magia() RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
tabela record;
begin
    for tabela in (
        SELECT
            tc.constraint_name,
            tc.table_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM
            information_schema.table_constraints AS tc
        JOIN
            information_schema.key_column_usage AS kcu using (constraint_name)
        JOIN
            information_schema.constraint_column_usage AS ccu using (constraint_name)
        WHERE
            constraint_type = 'FOREIGN KEY' AND tc.table_schema='nfe' --and kcu.column_name = 'id_nfe'
    ) loop
        execute format('alter table nfe.%s drop constraint %s;', tabela.table_name, tabela.constraint_name);
        --execute format('alter table nfe.%s add constraint %s FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe (id_nfe) ON UPDATE NO ACTION ON DELETE cascade;', tabela.table_name, tabela.constraint_name);
        --execute format('alter table nfe.%s add constraint %s FOREIGN KEY (%s) REFERENCES nfe.%s (%s) ON UPDATE NO ACTION ON DELETE NO ACTION;', tabela.table_name, tabela.constraint_name, tabela.column_name, tabela.foreign_table_name, tabela.foreign_column_name);
        --execute format('alter table nfe.%s add constraint %s FOREIGN KEY (%s) REFERENCES nfe.%s (%s) ON UPDATE NO ACTION ON DELETE cascade;', tabela.table_name, tabela.constraint_name, tabela.column_name, tabela.foreign_table_name, tabela.foreign_column_name);
    end loop;

    /*
        begin;
        select nfe.faz_magia();
        commit
    */
end;
$$;


ALTER FUNCTION nfe.faz_magia() OWNER TO planosassessoria;

--
-- TOC entry 3002 (class 1255 OID 16756)
-- Name: insere_cnpj_chave(); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.insere_cnpj_chave() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    new.cnpj_chave = case when (trim(new.inf_nfe) = '' or new.inf_nfe is null) then null else SUBSTR(new.inf_nfe, 7, 14)::VARCHAR(14) end;
    return new;
end;
$$;


ALTER FUNCTION nfe.insere_cnpj_chave() OWNER TO celismar;

--
-- TOC entry 3003 (class 1255 OID 16757)
-- Name: insere_cpf_cnpj(); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.insere_cpf_cnpj() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    new.cpf_cnpj = case when (trim(new.cnpj) = '' or new.cnpj is null) then new.cpf else new.cnpj end;
    return new;
end;
$$;


ALTER FUNCTION nfe.insere_cpf_cnpj() OWNER TO planosassessoria;

--
-- TOC entry 3004 (class 1255 OID 16764)
-- Name: insere_pesquisa_fts(); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.insere_pesquisa_fts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.pesquisa_fts = to_tsvector('pg_catalog.portuguese', concat(new.cpf_cnpj, ' ', new.inf_nfe, ' ', new.n_nf::text));
  return new;
end
$$;


ALTER FUNCTION nfe.insere_pesquisa_fts() OWNER TO celismar;

--
-- TOC entry 3005 (class 1255 OID 16765)
-- Name: insere_ser_on_raiz_nfe(); Type: FUNCTION; Schema: nfe; Owner: operador
--

CREATE FUNCTION nfe.insere_ser_on_raiz_nfe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if (not new.serie is null) then
		new.ser = new.serie::varchar(3);
	end if;

	return new;
end;
$$;


ALTER FUNCTION nfe.insere_ser_on_raiz_nfe() OWNER TO operador;

--
-- TOC entry 3006 (class 1255 OID 16766)
-- Name: inserir_produtos_nfe(integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.inserir_produtos_nfe(id_nfe integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
declare
    sped record;
begin
/*

select * from nfe.inserir_produtos_nfe(153498265)

select * from nfe.raiz_nfe where inf_nfe = '51210808664123000139550020000742841117691338'

*/
    select a.cpf_cnpj, b.id_empresa from nfe.raiz_nfe as a join ncm_helper.cad_empresas as b using(cpf_cnpj) where a.id_nfe = $1 into sped;
		
	drop table if exists prod_xml;
	create temp table prod_xml as
	(
		select
			distinct on (a.id_empresa, a.dt_ocorrencia, a.c_prod)
			a.id_empresa,
			a.tipo,
			a.c_prod,
			a.c_ean,
			a.ncm,
			a.cest,
			a.dt_ocorrencia,
			(select * from ncm_helper.sem_acentos(upper(a.descricao)))as descricao,
			a.unid
		from
		(
			select
				a.id_empresa,
				a.tipo,
				c.c_prod,
				case when c.c_ean = 'SEM GTIN' then ''::text 
				when (c.c_ean is null or c.c_ean = '') then ''::text 
				else c.c_ean end as c_ean,
				case when length(c.ncm) = '8' then
				trim(c.ncm) else ''::text end as ncm,
				case when c.cest = 0 then ''::varchar(7)
				when c.cest is null then ''::varchar(7)
				else lpad(c.cest::text, 7,'0')::varchar(7) end as cest,
				to_char(b.d_emi,'yyyy-mm-01')::date as dt_ocorrencia,
				upper(trim(c.x_prod))::varchar(255) as descricao,
				upper(trim(c.u_com)) as unid
			from ncm_helper.cad_empresas as a
			join nfe.raiz_nfe as b using(cpf_cnpj)
			join nfe.i01_prod as c using(cpf_cnpj, n_nf, serie, mod)
			where b.id_nfe = $1 and c.c_ean = c.c_ean_trib

			union

			select
				a.id_empresa,
				a.tipo,
				c.c_prod,
				case when c.c_ean = 'SEM GTIN' then ''::text 
				when (c.c_ean is null or c.c_ean = '') then ''::text 
				else c.c_ean end as c_ean,
				case when length(c.ncm) = '8' then
				c.ncm else ''::text	end as ncm,
				case when c.cest = 0 then ''::varchar(7)
				when c.cest is null then ''::varchar(7)
				else lpad(c.cest::text, 7,'0')::varchar(7) end as cest,
				to_char(b.d_emi,'yyyy-mm-01')::date as dt_ocorrencia,
				upper(trim(c.x_prod))::varchar(255) as descricao,
				upper(trim(c.u_com)) as unid
			from ncm_helper.cad_empresas as a
			join nfe.raiz_nfe as b using(cpf_cnpj)
			join nfe.i01_prod as c using(cpf_cnpj, n_nf, serie, mod)
			where b.id_nfe = $1 and c.c_ean <> c.c_ean_trib
			
			union

			select
				a.id_empresa,
				a.tipo,
				c.c_prod,
				case when c.c_ean = 'SEM GTIN' then ''::text 
				when (c.c_ean is null or c.c_ean = '') then ''::text 
				else c.c_ean end as c_ean,
				case when length(c.ncm) = '8' then
				c.ncm else ''::text	end as ncm,
				case when c.cest = 0 then ''::varchar(7)
				when c.cest is null then ''::varchar(7)
				else lpad(c.cest::text, 7,'0')::varchar(7) end as cest,
				to_char(b.d_emi,'yyyy-mm-01')::date as dt_ocorrencia,
				upper(trim(c.x_prod))::varchar(255) as descricao,
				upper(trim(c.u_com)) as unid
			from ncm_helper.cad_empresas as a
			join nfe.raiz_nfe as b using(cpf_cnpj)
			join nfe.c01_emit as d using(id_nfe, ie)
			join nfe.i01_prod as c on(a.cpf_cnpj, b.n_nf, b.serie, b.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			where b.id_nfe = $1
		)as a
		left join ncm_helper.cad_produtos_ocorrencia as b on (a.id_empresa, a.c_prod, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.dt_ocorrencia)
		where b.id_empresa is null
	);

	insert into ncm_helper.cad_produtos (codg_produto, codg_barra, descricao, ncm, id_empresa, cest)
	(
		select
			a.c_prod,
			a.c_ean,
			a.descricao,
			a.ncm,
			a.id_empresa,
			a.cest
		from prod_xml as a 
		left join ncm_helper.cad_produtos as b on(a.id_empresa,  a.c_prod) = (b.id_empresa, b.codg_produto)
		where b.id_produto is null			

	)on conflict do nothing;

	  INSERT INTO ncm_helper.cad_produtos_ocorrencia 
	  (id_empresa, codg_produto, dt_ocorrencia, cst_icms, descricao, ncm, unid, codg_barra) 
      (
		select
			a.id_empresa,
			a.c_prod,
			a.dt_ocorrencia,
		  	'060'::varchar(3) as cst_icms,
		  	a.descricao, 
		  	a.ncm,
		  	coalesce(a.unid,'UN') as unid,
		  	a.c_ean
		from prod_xml as a 
        left join ncm_helper.cad_produtos_ocorrencia as b on (a.id_empresa, a.c_prod, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.dt_ocorrencia)
		where b.id_empresa is null
    )on conflict do nothing;
	
	update ncm_helper.cad_produtos as a
	set codg_barra = b.c_ean
	from
	(
		select
			a.id_empresa,
			a.codg_produto,
			a.c_prod,
			a.c_ean,
			a.codg_barra
		from
		(
			select
				a.id_empresa,
				b.codg_produto,
				a.c_prod,
				a.c_ean,
				CASE WHEN (b.codg_barra IS NULL OR b.codg_barra = '') THEN ''::varchar(14) ELSE b.codg_barra END AS codg_barra
			from prod_xml as a 
			join ncm_helper.cad_produtos as b on(a.id_empresa,  a.c_prod) = (b.id_empresa, b.codg_produto)
		)AS a 
		where a.c_ean <> a.codg_barra
	)as b
	where (a.id_empresa, a.codg_produto) = (b.id_empresa, b.codg_produto);

	update ncm_helper.cad_produtos as a
	set descricao = b.descricao,
		auditado = 0
	from
	(
		select
			a.id_empresa,
			b.codg_produto,
			a.c_prod,
			a.descricao			
		from prod_xml as a 
		join ncm_helper.cad_produtos as b on(a.id_empresa,  a.c_prod) = (b.id_empresa, b.codg_produto)
		where a.descricao not like '%CUPOM%' and a.descricao <> b.descricao
	)as b
	where (a.id_empresa, a.codg_produto) = (b.id_empresa, b.codg_produto);
	
	
	update ncm_helper.cad_produtos_ocorrencia as a
	set auditado = b.auditado
	from
	(
		select
			a.id_empresa,
			a.codg_produto,
			a.descricao,
			a.dt_ocorrencia,
			b.auditado
		from
		(	select
				b.id_empresa,
				b.codg_produto,
				b.descricao,
		 		b.dt_ocorrencia,
				(b.dt_ocorrencia - interval '1 month')::date as dt
			from prod_xml as a 
			join ncm_helper.cad_produtos_ocorrencia as b on (a.id_empresa, a.c_prod, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.dt_ocorrencia)
		)as a
		join ncm_helper.cad_produtos_ocorrencia as b on (a.id_empresa, a.codg_produto, a.descricao, a.dt) = (b.id_empresa, b.codg_produto, b.descricao, b.dt_ocorrencia)
	)as b
	where (a.id_empresa, a.codg_produto, a.descricao, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.descricao, b.dt_ocorrencia);	
	
	/*update ncm_helper.cad_produtos_ocorrencia as a
	set unid = b.unid
	from
	(
		select
			a.id_empresa,
			a.codg_produto,
			a.descricao,
			a.dt_ocorrencia,
			b.unid
		from
		(	select
				b.id_empresa,
				b.codg_produto,
				b.descricao,
		 		b.dt_ocorrencia
			from prod_xml as a 
			join ncm_helper.cad_produtos_ocorrencia as b on (a.id_empresa, a.c_prod, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.dt_ocorrencia)
		 	where (a.unid = '' or a.unid is null)
		)as a
		join ncm_helper.cad_produtos_ocorrencia as b on (a.id_empresa, a.codg_produto, a.descricao) = (b.id_empresa, b.codg_produto, b.descricao)
		where b.unid <> ''
	)as b
	where (a.id_empresa, a.codg_produto, a.descricao, a.dt_ocorrencia) = (b.id_empresa, b.codg_produto, b.descricao, b.dt_ocorrencia);	

*/
-------------------========= acrescentei essa parte qui pra ajudar o pesosal na referenciação ================----------------------------

	update ncm_helper.cad_produtos as a
	set auditado = 0,
		ncm = b.ncm,
		ex_ipi = ''
	from
	(
		select
			a.id_empresa,
			a.codg_produto,
			a.descricao,
			b.ncm
		from ncm_helper.cad_produtos as a
		join prod_xml as b on(a.id_empresa, a.codg_produto) = (b.id_empresa, b.c_prod)
		where a.ncm <> b.ncm
	)as b
	where (a.id_empresa, a.codg_produto) = (b.id_empresa, b.codg_produto);

return;
end;
$_$;


ALTER FUNCTION nfe.inserir_produtos_nfe(id_nfe integer) OWNER TO planosassessoria;

--
-- TOC entry 3401 (class 1255 OID 279086827)
-- Name: itens_nfe_tela_cfop(bigint, character varying[]); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.itens_nfe_tela_cfop(_id_nfe bigint, _operacao character varying[]) RETURNS TABLE(n_item integer, c_prod character varying, x_prod text, unid character varying, cfop integer, ncm character varying, cst_icms character varying, vl_liquido numeric, vl_item numeric, vl_desc numeric, qtd numeric, vl_bc_icms numeric, aliq_icms numeric, vl_icms numeric, operacao character varying, cod_cta character varying, operacao_contabil character varying, codigo_dominio smallint, nome_cta character varying, codigo_zero boolean, referenciar_contabil boolean)
    LANGUAGE plpgsql
    AS $_$
/*
	select * from nfe.itens_nfe_tela_cfop(145847129, null)
	
	select * from nfe.itens_nfe_tela_cfop(145847129, array['Entrada - Consumo','Bens de Pequeno Valor', 'Material de Escritorio','Compra'])

*/
begin


update sf.reg_0200 as a
set cod_ncm = b.ncm,
	ex_ipi = b.ex_ipi
from
(
	select
		a.id_reg_0000,
		a.id_reg_0200,
		b.ncm,
		b.ex_ipi
	from
	(
		select
			a.id_empresa, 
			e.id_reg_0000,
			e.id_reg_0200,
			e.cod_item,
			e.cod_ncm,
			case when e.ex_ipi <> '' then e.ex_ipi else ''::varchar(3) end as ex_ipi
		from sf.reg_0000 as a
		join sf.reg_0150 as b using(id_reg_0000)
		join sf.reg_c100 as c using(id_reg_0000, cod_part)
		join sf.reg_c170 as d using(id_reg_0000, id_reg_c100)
		join sf.reg_0200 as e using(id_reg_0000, cod_item)
		join nfe.raiz_nfe as f on(a.cpf_cnpj, b.cpf_cnpj, c.num_doc, c.ser, c.cod_mod) = (f.dest_cpf_cnpj, f.cpf_cnpj, f.n_nf, f.ser, f.mod)
		where f.id_nfe = $1
	)as a
	join ncm_helper.cad_produtos as b on (a.id_empresa, a.cod_item) = (b.id_empresa, b.codg_produto)
	where (a.cod_ncm <> b.ncm or a.ex_ipi <> b.ex_ipi)
)as b
where (a.id_reg_0000, a.id_reg_0200) = (b.id_reg_0000, b.id_reg_0200);			
		
		
return query
select
	a.n_item,
	a.c_prod,
	a.x_prod,
	a.unid,
	a.cfop,
	a.ncm,
	a.cst_icms,
	a.vl_liquido,
	a.vl_item,
	a.vl_desc,
	a.qtd,
	a.vl_bc_icms,
	a.aliq_icms,
	a.vl_icms,
	a.operacao,
	a.cod_cta,
	a.operacao_contabil,
	a.codigo_dominio,
	a.nome_cta,
	a.codigo_zero,
	a.referenciar_contabil
from
(
	with itens_notas as
	(
		select
			a.n_item,
			a.c_prod,
			a.x_prod,
			a.u_trib as unid,
			a.cfop,
			a.ncm,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 then '060'::varchar(3)
			  when b.cst = any(array['060','070','010']) then '060'::varchar(3)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then '060'::varchar(3)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then '060'::varchar(3)
			  when substring(a.cfop::text,2,1) = '4' then '060'::varchar(3)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then '090'::varchar(3)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then '040'::varchar(3)
			else b.cst end as cst_icms,
			((a.v_prod + coalesce(b.v_icms_st,0.00) + coalesce(b.v_fcp_st,0.00) + coalesce(a.v_frete,0.00) + coalesce(a.v_seg,0.00) + coalesce(c.v_ipi,0.00) + coalesce(a.v_outro,0.00) ) - (coalesce(a.v_desc, 0.00) + coalesce(b.v_icms_deson, 0.00)))::numeric(18,2) as vl_liquido,
			a.v_prod as vl_item,
			coalesce(a.v_desc, 0.00) as vl_desc,
			a.q_com::numeric(18,3) as qtd,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 THEN 0.00::numeric(18,2)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then 0.00::numeric(18,2)
			ELSE coalesce(b.v_bc,0.00)
			END as vl_bc_icms,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 then NULL::numeric(18,2)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then null::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then null::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then null::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then null::numeric(18,2)
			  when coalesce(b.p_icms,b.p_cred_sn,0.00)::numeric(18,2) = 0.00 then null::numeric(18,2)
			else coalesce(b.p_icms,NULL)::numeric(18,2)
			end as aliq_icms,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 then 0.00::numeric(18,2)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then 0.00::numeric(18,2)
			else coalesce(b.v_icms, 0.00)
			end as vl_icms,
			d.operacao,
			f.cod_cta,
			f.operacao_contabil,
			f.codigo_dominio,
			f.nome_cta,
			case when a.c_prod similar to '[0-0]+' then true else false end as codigo_zero,
			case when d.id_operacao = any(array[1001, 1029, 1014, 1005, 1007]) and not a.ncm = any(array['27101921','22071010','27101932','27101259','27101931']) then true else false end as referenciar_contabil
		from nfe.i01_prod as a
		join ncm_helper.cad_cfop as d using(cfop)
		join 
		(
			select 
				b.id_nfe, b.c_prod, b.x_prod, b.id
			from nfe.w02_icms_tot as a
			join nfe.i01_prod as b using(id_nfe)
			where a.id_nfe = $1 and a.v_icms_deson > 0.00
		)as g on (a.id_nfe, a.c_prod, a.x_prod, a.id) = (g.id_nfe, g.c_prod, g.x_prod, g.id)
		left join nfe.icms_filhos b on (a.id_nfe, a.id) = (b.id_nfe, b.id_prod)
		left join nfe.ipi_filhos c on (a.id_nfe, a.id) = (c.id_nfe, c.id_prod)
		left join (
			select
			  a.id_nfe,
			  c.c_prod,
			  c.x_prod,
			  d.cod_cta,
			  c.id,
			  d.operacao as operacao_contabil,
			  e.cod_cta_ext as codigo_dominio,
			  e.nome_cta
			from nfe.raiz_nfe as a
			join ncm_helper.cad_empresas as b on a.dest_cpf_cnpj = b.cpf_cnpj
			join nfe.i01_prod as c on (a.cpf_cnpj, a.n_nf, a.serie, a.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			join contabil.resumo_contabil as d on (b.id_empresa, c.cpf_cnpj, c.c_prod, c.x_prod) = (d.id_empresa, d.cpf_cnpj, d.cod_item, d.descr_item)
			join contabil.plano_conta_padrao as e on d.cod_cta = e.cod_cta
			join ncm_helper.cad_cfop as f on c.cfop = f.cfop
			where a.id_nfe = $1 and c.c_prod similar to '[0-0]+' and d.operacao = some($2) -- (array[string_to_array($2, ',')]) 
			and f.id_operacao = any(array[1001, 1029, 1014, 1005, 1007])

			union

			select
			  a.id_nfe,
			  c.c_prod,
			  c.x_prod,
			  d.cod_cta,
			  c.id,
			  d.operacao as operacao_contabil,
			  e.cod_cta_ext as codigo_dominio,
			  e.nome_cta
			from nfe.raiz_nfe as a
			join ncm_helper.cad_empresas as b on a.dest_cpf_cnpj = b.cpf_cnpj
			join nfe.i01_prod as c on (a.cpf_cnpj, a.n_nf, a.serie, a.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			join contabil.resumo_contabil as d on (b.id_empresa, c.cpf_cnpj, c.c_prod) = (d.id_empresa, d.cpf_cnpj, d.cod_item)
			join contabil.plano_conta_padrao as e on d.cod_cta = e.cod_cta
			join ncm_helper.cad_cfop as f on c.cfop = f.cfop
			where a.id_nfe = $1 and not c.c_prod similar to '[0-0]+' and d.operacao = some($2) -- (array[string_to_array($2, ',')]) 
			and f.id_operacao = any(array[1001, 1029, 1014, 1005, 1007])
		) as f on (a.id_nfe, a.c_prod, a.x_prod, a.id) = (f.id_nfe, f.c_prod, f.x_prod, f.id)
		where b.id_nfe = $1

		union

		select
			a.n_item,
			a.c_prod,
			a.x_prod,
			a.u_trib as unid,
			a.cfop,
			a.ncm,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 then '060'::varchar(3)
			  when b.cst = any(array['060','070','010']) then '060'::varchar(3)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then '060'::varchar(3)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then '060'::varchar(3)
			  when substring(a.cfop::text,2,1) = '4' then '060'::varchar(3)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then '090'::varchar(3)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then '040'::varchar(3)
			else b.cst end as cst_icms,
			((a.v_prod + coalesce(b.v_icms_st,0.00) + coalesce(b.v_fcp_st,0.00) + coalesce(a.v_frete,0.00) + coalesce(a.v_seg,0.00) + coalesce(c.v_ipi,0.00) + coalesce(a.v_outro,0.00) ) - coalesce(a.v_desc, 0.00))::numeric(18,2) as vl_liquido,
			a.v_prod as vl_item,
			coalesce(a.v_desc, 0.00) as vl_desc,
			a.q_com::numeric(18,3) as qtd,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 THEN 0.00::numeric(18,2)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then 0.00::numeric(18,2)
			ELSE coalesce(b.v_bc,0.00)
			END as vl_bc_icms,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 then NULL::numeric(18,2)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then null::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then null::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then null::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then null::numeric(18,2)
			  when coalesce(b.p_icms,b.p_cred_sn,0.00)::numeric(18,2) = 0.00 then null::numeric(18,2)
			else coalesce(b.p_icms,NULL)::numeric(18,2)
			end as aliq_icms,
			case
			  when coalesce(b.v_icms_st,0.00) > 0.00 then 0.00::numeric(18,2)
			  when substring(b.cst,2,2) = any(array['10','60','70']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['500','201','202']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['101','102','900']) then 0.00::numeric(18,2)
			  when lpad(b.cso_sn, 3, '0') = any(array['103','203','400']) then 0.00::numeric(18,2)
			else coalesce(b.v_icms, 0.00)
			end as vl_icms,
			d.operacao,
			f.cod_cta,
			f.operacao_contabil,
			f.codigo_dominio,
			f.nome_cta,
			case when a.c_prod similar to '[0-0]+' then true else false end as codigo_zero,
			case when d.id_operacao = any(array[1001, 1029, 1014, 1005, 1007]) and not a.ncm = any(array['27101921','22071010','27101932','27101259','27101931']) then true else false end as referenciar_contabil
		from nfe.i01_prod as a
		join ncm_helper.cad_cfop as d using(cfop)
		join 
		(
			select 
				b.id_nfe, b.c_prod, b.x_prod, b.id
			from nfe.w02_icms_tot as a
			join nfe.i01_prod as b using(id_nfe)
			where a.id_nfe = $1 and coalesce(a.v_icms_deson,0.00) = 0.00
		)as g on (a.id_nfe, a.c_prod, a.x_prod, a.id) = (g.id_nfe, g.c_prod, g.x_prod, g.id)
		left join nfe.icms_filhos b on (a.id_nfe, a.id) = (b.id_nfe, b.id_prod)
		left join nfe.ipi_filhos c on (a.id_nfe, a.id) = (c.id_nfe, c.id_prod)
		left join (
			select
			  a.id_nfe,
			  c.c_prod,
			  c.x_prod,
			  d.cod_cta,
			  c.id,
			  d.operacao as operacao_contabil,
			  e.cod_cta_ext as codigo_dominio,
			  e.nome_cta
			from nfe.raiz_nfe as a
			join ncm_helper.cad_empresas as b on a.dest_cpf_cnpj = b.cpf_cnpj
			join nfe.i01_prod as c on (a.cpf_cnpj, a.n_nf, a.serie, a.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			join contabil.resumo_contabil as d on (b.id_empresa, c.cpf_cnpj, c.c_prod, c.x_prod) = (d.id_empresa, d.cpf_cnpj, d.cod_item, d.descr_item)
			join contabil.plano_conta_padrao as e on d.cod_cta = e.cod_cta
			join ncm_helper.cad_cfop as f on c.cfop = f.cfop
			where a.id_nfe = $1 and c.c_prod similar to '[0-0]+' and d.operacao = some($2) -- (array[string_to_array($2, ',')]) 
			and f.id_operacao = any(array[1001, 1029, 1014, 1005, 1007])

			union

			select
			  a.id_nfe,
			  c.c_prod,
			  c.x_prod,
			  d.cod_cta,
			  c.id,
			  d.operacao as operacao_contabil,
			  e.cod_cta_ext as codigo_dominio,
			  e.nome_cta
			from nfe.raiz_nfe as a
			join ncm_helper.cad_empresas as b on a.dest_cpf_cnpj = b.cpf_cnpj
			join nfe.i01_prod as c on (a.cpf_cnpj, a.n_nf, a.serie, a.mod) = (c.cpf_cnpj, c.n_nf, c.serie, c.mod)
			join contabil.resumo_contabil as d on (b.id_empresa, c.cpf_cnpj, c.c_prod) = (d.id_empresa, d.cpf_cnpj, d.cod_item)
			join contabil.plano_conta_padrao as e on d.cod_cta = e.cod_cta
			join ncm_helper.cad_cfop as f on c.cfop = f.cfop
			where a.id_nfe = $1 and not c.c_prod similar to '[0-0]+' and d.operacao = some($2) -- (array[string_to_array($2, ',')]) 
			and f.id_operacao = any(array[1001, 1029, 1014, 1005, 1007])
		) as f on (a.id_nfe, a.c_prod, a.x_prod, a.id) = (f.id_nfe, f.c_prod, f.x_prod, f.id)
		where b.id_nfe = $1
	)
	select
		a.n_item,
		a.c_prod,
		a.x_prod,
		a.unid,
		a.cfop,
		a.ncm,
		a.cst_icms,
		a.vl_liquido,
		a.vl_item,
		a.vl_desc,
		a.qtd,
		a.vl_bc_icms,
		a.aliq_icms,
		a.vl_icms,
		a.operacao,
		a.cod_cta,
		a.operacao_contabil,
		a.codigo_dominio,
		a.nome_cta,
		a.codigo_zero,
		a.referenciar_contabil
	from itens_notas as a
)as a
order by a.n_item;
end;
$_$;


ALTER FUNCTION nfe.itens_nfe_tela_cfop(_id_nfe bigint, _operacao character varying[]) OWNER TO celismar;

--
-- TOC entry 3007 (class 1255 OID 16767)
-- Name: limpar_canceladas(integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.limpar_canceladas(_id_empresa integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
r integer;
begin
/*
    delete from
        nfe.nfe_itens a
    where
    a.id_nfe in (
        select
            b.id_nfe
        from
            nfe.view_nfe b, sf.reg_c100 c, sf.reg_0000 d
        where
            b.n_nf = c.num_doc and
            b.id_empresa = d.id_empresa and
            c.id_reg_0000 = d.id_reg_0000 and
            c.cod_sit = any(array['02', '03', '04', '05']) and
            d.id_empresa = _id_empresa
    );

    update
        nfe.nfe a
    set
        v_frete=0,
        v_seg=0,
        v_desc=0,
        v_outro=0,
        nat_op=null,
        d_emi=null,
        d_sai_ent=null,
        dest_cpf=null,
        dest_cnpj=null,
        dest_ie=null,
        dest_xnome=null,
        dest_cmun=null,
        v_nf=0,
        v_icms_st=0,
        v_ipi=0,
        v_iss=0,
        v_irrf=0,
        dest_cep=null,
        dest_xbairro=null,
        dest_fone=null,
        dest_xlogr=null,
        dest_nro=null,
        dest_xcpl=null,
        dest_cpais=null,
        inf_nfe =
        case when a.cod_sit = '05' then
            null
        else
            a.inf_nfe
        end
    from
        nfe.view_nfe b, sf.reg_c100 c, sf.reg_0000 d
    where
        a.id_nfe = b.id_nfe and
        b.n_nf = c.num_doc and
        b.id_empresa = d.id_empresa and
        c.id_reg_0000 = d.id_reg_0000 and
        c.cod_sit = any(array['02', '03', '04', '05']) and
        d.id_empresa = _id_empresa;
*/
    get diagnostics r := row_count;
    return r;

    /*
        begin;
        select nfe.limpar_canceladas(65) as num_rows;
    */
end;
$$;


ALTER FUNCTION nfe.limpar_canceladas(_id_empresa integer) OWNER TO planosassessoria;

--
-- TOC entry 3008 (class 1255 OID 16768)
-- Name: nfe(); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.nfe() RETURNS TABLE(id_nfe integer, inf_nfe character varying, n_nf integer, v_frete numeric, v_seg numeric, v_desc numeric, v_outro numeric, nat_op character varying, d_emi bigint, d_sai_ent bigint, cpf_cnpj character varying, dest_cpf_cnpj character varying, dest_ie character varying, dest_xnome character varying, dest_cmun integer, d_sai_ent2 date, d_emi2 date, v_nf numeric, contabilizado_emissor integer, contabilizado_dest integer, v_icms_st numeric, v_ipi numeric, v_iss numeric, v_irrf numeric, dest_cep character varying, dest_xbairro character varying, dest_fone character varying, dest_xlogr character varying, dest_nro character varying, dest_xcpl character varying, dest_cpais integer, serie integer, cod_sit character varying, ie character varying, vl_bc_icms numeric, vl_icms numeric, vl_bc_icms_st numeric, id_empresa integer)
    LANGUAGE plpgsql
    AS $$
begin
/*
return query
	SELECT
		a.id_nfe,
		a.inf_nfe,
		a.n_nf,
		b.v_frete,
		b.v_seg,
		b.v_desc,
		b.v_outro,
		c.nat_op,
		date_part('epoch'::text, c.d_emi)::bigint AS d_emi,
		date_part('epoch'::text, c.d_sai_ent)::bigint AS d_sai_ent,
		d.cpf_cnpj,
		e.cpf_cnpj AS dest_cpf_cnpj,
		e.ie AS dest_ie,
		e.x_nome AS dest_xnome,
		f.c_mun AS dest_cmun,
		c.d_sai_ent AS d_sai_ent2,
		c.d_emi AS d_emi2,
		b.v_nf,
		a.contabilizado_emissor,
		a.contabilizado_dest,
		b.v_st AS v_icms_st,
		b.v_ipi,
		g.v_iss,
		h.v_irrf,
		f.cep AS dest_cep,
		f.x_bairro AS dest_xbairro,
		f.fone AS dest_fone,
		f.x_lgr AS dest_xlogr,
		f.nro AS dest_nro,
		f.x_cpl AS dest_xcpl,
		f.c_pais AS dest_cpais,
		c.serie,
		a.cod_sit,
		d.ie,
		b.v_bc AS vl_bc_icms,
		b.v_icms AS vl_icms,
		b.v_bc_st AS vl_bc_icms_st,
		i.id_empresa
		--i.cpf_cnpj
	FROM
		nfe.raiz_nfe a
	JOIN nfe.w02_icms_tot b ON a.id_nfe = b.id_nfe
	JOIN nfe.b01_ide c ON a.id_nfe = c.id_nfe
	JOIN nfe.c01_emit d ON a.id_nfe = d.id_nfe
	JOIN nfe.e01_dest e ON a.id_nfe = e.id_nfe
	JOIN nfe.e05_ender_dest f ON a.id_nfe = f.id_nfe
	LEFT JOIN nfe.w17_issqn_tot g ON a.id_nfe = g.id_nfe
	LEFT JOIN nfe.w23_ret_trib h ON a.id_nfe = h.id_nfe
	JOIN ncm_helper.cad_empresas i ON d.cpf_cnpj = i.cpf_cnpj;
	*/
end;
$$;


ALTER FUNCTION nfe.nfe() OWNER TO planosassessoria;

--
-- TOC entry 3009 (class 1255 OID 16769)
-- Name: nfe_sequencias(integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.nfe_sequencias(id_empresa integer) RETURNS TABLE(n_nf bigint, serie integer)
    LANGUAGE plpgsql
    AS $_$
declare
	menor	integer;
	maior	integer;
	linha	record;
begin
/*
	create temp table nfe as (
		select
			a.n_nf,
			a.serie
		from
			nfe.b01_ide a
		join
			nfe.c01_emit b using (id_nfe)
		join
			ncm_helper.cad_empresas c using (cpf_cnpj)
		where
			c.id_empresa = $1
		order by
			n_nf
	);

	create temp table retorno as select * from nfe where 1=2;
	
	for linha in select distinct a.serie from nfe a loop
		select min(a.n_nf), max(a.n_nf) from nfe a where a.serie = linha.serie into menor, maior;

		insert into retorno (n_nf, serie)
		(
			select
 				a.n_nf,
 				linha.serie
 			from
 			(
				select generate_series(menor, maior) as n_nf
 			) a
 			where
 				a.n_nf not in (select b.n_nf from nfe b where b.serie = linha.serie)
		);
	end loop;
	return query select a.n_nf, a.serie from retorno a order by a.n_nf;

	drop table retorno;
	drop table nfe;
*/
/*
	select * from nfe.nfe_sequencias(65);
*/
	
end;
$_$;


ALTER FUNCTION nfe.nfe_sequencias(id_empresa integer) OWNER TO planosassessoria;

--
-- TOC entry 3010 (class 1255 OID 16770)
-- Name: notas_faltantes_entre_sped_xml(integer, date, date); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.notas_faltantes_entre_sped_xml(empresa integer, dt_inicial date, dt_final date) RETURNS TABLE(cpf_cnpj character varying, x_nome character varying, ie character varying, n_nf integer, ser character varying, mod character varying, inf_nfe character varying, d_emi date, v_nf numeric, v_merc numeric, v_desc numeric, operacao character varying, situacao character varying, id_empresa bigint, id_nfe bigint, nota_recusada boolean)
    LANGUAGE plpgsql
    AS $_$

begin

/*

	select 
		a.cpf_cnpj,
		a.x_nome,
		a.ie,
		a.n_nf, 
		a.inf_nfe,
		a.d_emi,
		a.v_nf,
		a.v_merc, 
		a.v_desc,
		a.operacao
	from nfe.notas_faltantes_entre_sped_xml(2281,'2023-01-01','2023-12-31') as a

*/
drop table if exists sped;
create temp table sped as 
(
	select 
		a.id_empresa,
		a.cpf_cnpj as dest_cpf_cnpj, 
		c.num_doc,
		c.chv_nfe,
		b.cpf_cnpj,
		substring(c.chv_nfe, 7,14)::varchar(14) as cnpj_chave,
		c.id_reg_c100
	from sf.reg_0000 as a
	join sf.reg_0150 as b using(id_reg_0000)
	join sf.reg_c100 as c using(id_reg_0000, cod_part)
	where a.id_empresa = $1 and a.dt_ini2 >= $2 and c.ind_emit = '1' and c.chv_nfe <> ''
);

drop table if exists xml_nfe; 
create temp table xml_nfe as 
(
	select 
		a.id_empresa,
		a.id_reg_c100,
		b.id_nfe,
		b.inf_nfe
	from sped as a
	join nfe.raiz_nfe as b on(a.dest_cpf_cnpj, a.cpf_cnpj, a.num_doc, a.chv_nfe) = (b.dest_cpf_cnpj, b.cpf_cnpj, b.n_nf, b.inf_nfe)
	where a.id_empresa = $1
	
	union
	
	select 
		a.id_empresa,
		a.id_reg_c100,
		b.id_nfe,
		b.inf_nfe
	from sped as a
	join nfe.raiz_nfe as b on(a.dest_cpf_cnpj, a.cnpj_chave, a.num_doc, a.chv_nfe) = (b.dest_cpf_cnpj, b.cnpj_chave, b.n_nf, b.inf_nfe)
	where a.id_empresa = $1
	
	union
	
	select 
		a.id_empresa,
		a.id_reg_c100,
		b.id_nfe,
		b.inf_nfe
	from sped as a
	join nfe.raiz_nfe as b on(a.dest_cpf_cnpj, a.num_doc, a.chv_nfe) = (b.dest_cpf_cnpj, b.n_nf, b.inf_nfe)
	where a.id_empresa = $1
);

drop table if exists sefazt;
create temp table sefazt as 
(
	select 
		a.id_empresa,
		b.n_nf, 
		b.inf_nfe,
		b.d_emi,
		'Autorizada'::text as situacao,
		case when b.cod_sit <> '' then b.cod_sit else '00'::varchar(2) end as cod_sit,
		a.cpf_cnpj as dest_cpf_cnpj,
		substring(b.inf_nfe, 7,14)::varchar(14) as cpf_cnpj
	from ncm_helper.cad_empresas as a
	join livros.consulta_nfe_sefaz as b using(id_empresa)
	where a.id_empresa = $1 and b.d_emi between $2 and $3 and b.pesquisa_fts @@ to_tsquery('autorizada') and a.cpf_cnpj <> substring(b.inf_nfe, 7,14)::varchar(14)
);

drop table if exists xml_sefaz;
create temp table xml_sefaz as 
(
	select 
		a.id_empresa,
		b.id_nfe,
		b.dest_cpf_cnpj, 
		b.cpf_cnpj, 
		b.n_nf, 
		b.ser, 
		b.mod,
		b.inf_nfe,
		a.d_emi,
		a.situacao,
		a.cod_sit,
		b.nota_recusada
	from sefazt as a
	join nfe.raiz_nfe as b using(dest_cpf_cnpj, cpf_cnpj, n_nf, inf_nfe)
	where a.id_empresa = $1
	
	union
	
	select 
		a.id_empresa,
		b.id_nfe,
		b.dest_cpf_cnpj, 
		b.cpf_cnpj, 
		b.n_nf, 
		b.ser, 
		b.mod,
		b.inf_nfe,
		a.d_emi,
		a.situacao,
		a.cod_sit,
		b.nota_recusada
	from sefazt as a
	join nfe.raiz_nfe as b using(dest_cpf_cnpj, n_nf, inf_nfe)
	where a.id_empresa = $1
);

drop table if exists notas;
create temp table notas as 
(
	select
		a.id_empresa,
		a.id_nfe,
		a.dest_cpf_cnpj, 
		a.cpf_cnpj, 
		a.n_nf, 
		a.ser, 
		a.mod,
		a.inf_nfe,
		a.d_emi,
		a.situacao,
		a.cod_sit,
		a.nota_recusada
	from xml_sefaz as a
	left join
	(		
		select 
			a.id_empresa,
			a.id_reg_c100,
			a.id_nfe
		from xml_nfe as a				
		where a.id_empresa = $1
	)as b on(a.id_empresa, a.id_nfe) = (b.id_empresa, b.id_nfe)
	where a.id_empresa = $1 and b.id_reg_c100 is null
);

drop table if exists faltante;
create temp table faltante as
(

	select
		a.id_empresa,
		a.id_nfe,
		a.dest_cpf_cnpj, 
		a.cpf_cnpj, 
		a.n_nf, 
		a.ser, 
		a.mod,
		a.inf_nfe,
		a.d_emi,
		a.v_nf,
		a.v_prod,
		a.v_desc,
		a.v_outro,
		a.x_nome,
		a.ie,
		a.operacao,
		a.entrada,
		a.situacao,
		a.nota_recusada,
		a.cod_sit
	from
	(
		select
			distinct on(a.id_nfe,c.operacao, a.situacao)
			a.id_empresa,
			a.id_nfe,
			a.dest_cpf_cnpj, 
			a.cpf_cnpj, 
			a.n_nf, 
			a.ser, 
			a.mod,
			a.inf_nfe,
			a.d_emi,
			a.v_nf,
			a.v_prod,
			a.v_desc,
			a.v_outro,
			a.x_nome,
			a.ie,
			c.operacao,
			c.entrada,
			a.situacao,
			a.nota_recusada,
			a.cod_sit
		from
		(
			select
				a.id_empresa,
				a.id_nfe,
				a.dest_cpf_cnpj, 
				a.cpf_cnpj, 
				a.n_nf, 
				a.ser, 
				a.mod,
				a.inf_nfe,
				a.d_emi,
				b.v_nf,
				b.v_prod,
				coalesce(b.v_desc, 0.0) as v_desc,
				coalesce(b.v_outro, 0.0) as v_outro,
				replace(c.x_nome,';','') as x_nome,
				c.ie,
				a.situacao,
				a.nota_recusada,
				a.cod_sit
			from notas as a
			join nfe.w02_icms_tot as b using(id_nfe)
			join nfe.c01_emit as c using(id_nfe)
			where a.id_empresa = $1
				
		)as a
		join nfe.i01_prod as b using(id_nfe)
		join ncm_helper.cad_cfop as c using(cfop)
		where a.id_empresa = $1
	)as a

);

drop table if exists notas_faltantes;
create temp table notas_faltantes as
(

	select
		a.dest_cpf_cnpj,
		a.id_empresa,
		a.id_nfe,
		a.cpf_cnpj, 
		a.n_nf, 
		a.ser, 
		a.mod,
		a.inf_nfe,
		a.nota_recusada
	from
	(
		select
			a.dest_cpf_cnpj,
			a.id_empresa,
			a.id_nfe,
			a.cpf_cnpj, 
			a.n_nf, 
			a.ser, 
			a.mod,
			a.inf_nfe,
			a.nota_recusada
		from faltante as a
		join
		(
			select
				a.id_empresa,
				a.dest_cpf_cnpj,
				a.cpf_cnpj, 
				a.n_nf as num_doc,
				a.v_nf,
				a.entrada,
				b.ref_nfe as inf_nfe
			from faltante as a
			join nfe.b12a_nf_ref as b using(id_nfe)
			where a.entrada is true and a.id_empresa = $1
		)as b using(dest_cpf_cnpj, cpf_cnpj, v_nf, inf_nfe)
		where a.entrada <> b.entrada

		union

		select
			a.dest_cpf_cnpj,
			a.id_empresa,
			a.id_nfe,
			a.cpf_cnpj, 
			a.n_nf, 
			a.ser, 
			a.mod,
			a.inf_nfe,
			a.nota_recusada
		from faltante as a
		join
		(
			select
				a.dest_cpf_cnpj,
				a.cpf_cnpj, 
				a.n_nf as num_doc,
				a.v_nf,
				a.entrada
			from faltante as a
			left join nfe.b12a_nf_ref as b using(id_nfe)
			where a.id_empresa = $1 and a.entrada is true and b.id is null 
		)as b using(dest_cpf_cnpj, cpf_cnpj, v_nf)
		where a.id_empresa = $1 and a.entrada <> b.entrada and a.n_nf < b.num_doc

		union

		select
			a.dest_cpf_cnpj,
			a.id_empresa,
			a.id_nfe,
			a.cpf_cnpj, 
			a.n_nf, 
			a.ser, 
			a.mod,
			a.inf_nfe,
			a.nota_recusada
		from faltante as a
		join
		(
			select
				a.dest_cpf_cnpj,
				a.cpf_cnpj, 
				a.n_nf as num_doc,
				a.v_nf,
				a.entrada
			from faltante as a
			left join nfe.b12a_nf_ref as b using(id_nfe)
			where a.id_empresa = $1 and a.entrada is true and b.id is null
		)as b using(dest_cpf_cnpj, cpf_cnpj, v_nf)
		where a.entrada <> b.entrada
	)as a
	
);

return query 
select
	a.cpf_cnpj,
	a.x_nome,
	a.ie,
	a.n_nf, 
	a.ser,
	a.mod,
	a.inf_nfe,
	a.d_emi,
	a.v_nf,
	a.v_merc, 
	a.v_desc,
	a.operacao,
	a.situacao,
	a.id_empresa,
	a.id_nfe,
	a.nota_recusada
from
(
	select
		a.cpf_cnpj::varchar(14) as cpf_cnpj,
		a.x_nome::varchar(255) as x_nome,
		a.ie::varchar(14) as ie,
		a.n_nf::integer as n_nf, 
		a.ser::varchar(3) as ser, 
		a.mod::varchar(2) as mod,
		a.inf_nfe::varchar(44) as inf_nfe,
		a.d_emi::date as d_emi,
		a.v_nf::numeric(18,2) as v_nf,
		a.v_prod::numeric(18,2) as v_merc,
		a.v_desc::numeric(18,2) as v_desc,
		a.operacao::varchar(255) as operacao,
		a.situacao::varchar(255) as situacao,
		a.id_empresa::bigint as id_empresa,
		a.id_nfe::bigint as id_nfe,
		a.nota_recusada::boolean as nota_recusada
	from
	(
		select
			a.id_empresa,
			a.dest_cpf_cnpj,
			a.cpf_cnpj,
			a.x_nome,
			a.ie,
			a.n_nf, 
			a.ser, 
			a.mod,
			a.inf_nfe,
			a.d_emi,
			a.v_nf,
			a.v_prod,
			a.v_desc,
			a.v_outro,
			--a.operacao,
			array_agg(a.operacao) as operacao,
			a.situacao,
			a.id_nfe,
			a.nota_recusada
		from
		(
			select
				distinct on(a.id_nfe, a.operacao)
				a.id_empresa,
				a.dest_cpf_cnpj,
				a.cpf_cnpj,
				a.x_nome,
				a.ie,
				a.n_nf, 
				a.ser, 
				a.mod,
				a.inf_nfe,
				a.d_emi,
				a.v_nf,
				a.v_prod,
				a.v_desc,
				a.v_outro,
				a.operacao,
				a.situacao,
				a.id_nfe,
				a.nota_recusada
			from
			(
				select
					distinct on(a.id_nfe, a.operacao)
					a.id_empresa,
					a.dest_cpf_cnpj,
					a.cpf_cnpj,
					a.x_nome,
					a.ie,
					a.n_nf, 
					a.ser, 
					a.mod,
					a.inf_nfe,
					a.d_emi,
					a.v_nf,
					a.v_prod,
					a.v_desc,
					a.v_outro,
					a.operacao,
					a.situacao,
					a.id_nfe,
					a.nota_recusada
				from faltante as a
				left join
				(
					select
						a.id_nfe,
						a.cpf_cnpj, 
						a.n_nf, 
						a.ser, 
						a.mod,
						a.inf_nfe
					from notas_faltantes as a

				)as b using(id_nfe, cpf_cnpj, n_nf, ser, mod, inf_nfe)
				where a.id_empresa = $1 and a.entrada = false and b.id_nfe is null
			)as a
		)as a
		group by a.id_empresa, a.dest_cpf_cnpj, a.cpf_cnpj,	a.x_nome, a.ie, a.n_nf, a.ser, a.mod, a.inf_nfe, a.d_emi, a.v_nf, a.v_prod, a.v_desc, a.v_outro, a.situacao, a.id_nfe,	a.nota_recusada
	)as a

	/*union

	select
		a.cpf_cnpj,
		a.x_nome,
		a.ie,
		a.n_nf, 
		a.ser,
		a.mod,
		a.inf_nfe,
		a.d_emi,
		a.v_nf,
		a.v_merc, 
		a.v_desc,
		a.operacao,
		a.situacao,
		a.id_empresa,
		a.id_nfe,
		a.nota_recusada
	from
	(
		select
			c.cpf_cnpj::varchar(14) as cpf_cnpj,
			d.x_nome::varchar(255) as x_nome,
			coalesce(d.ie,'')::varchar(14) as ie,
			c.n_ct::integer as n_nf, 
			c.serie::varchar(3) as ser,
			c.mod::varchar(2) as mod,
			c.ch_cte::varchar(44) as inf_nfe,
			c.d_emi::date as d_emi,
			c.v_t_prest::numeric(18,2) as v_nf,
			c.v_t_prest::numeric(18,2) as v_merc, 
			0.00::numeric(18,2) as v_desc,
			c.nat_op::varchar(255) as operacao,
			f.sit::varchar(255) as situacao,
			a.id_empresa::bigint as id_empresa,
			0::bigint as id_nfe,
			false::boolean as nota_recusada
		from ncm_helper.cad_empresas as a
		join ctes.tomador_ender as b on a.cpf_cnpj = b.cpf_cnpj_toma
		join ctes.inf_cte_ide as c on(b.cpf_cnpj, b.n_ct, b.serie, b.mod) = (c.cpf_cnpj, c.n_ct, c.serie, c.mod)
		join ctes.emit_ender as d on(c.cpf_cnpj, c.n_ct, c.serie, c.mod) = (d.cpf_cnpj, d.n_ct, d.serie, d.mod)
		join relatorios.cte_sefaz_dados as e on c.ch_cte = e.chv_cte
		join relatorios.cte_sefaz_carac as f on e.id_rel_cte = f.id_rel_cte
		where a.id_empresa = $1 and c.d_emi between $2 and $3 and f.pesquisa_fts @@ to_tsquery('autorizado') and a.id_empresa = any(array[169,121,248])
	)as a
	left join
	(
		select 
			a.id_empresa,
			b.cpf_cnpj, 
			c.num_doc,
			c.chv_cte,
			c.id_reg_d100
		from sf.reg_0000 as a
		join sf.reg_0150 as b using(id_reg_0000)
		join sf.reg_d100 as c using(id_reg_0000, cod_part)
		where a.id_empresa = $1 and c.dt_doc2 between $2 and $3
	)as b on(a.id_empresa,a.cpf_cnpj, a.n_nf, a.inf_nfe) = (b.id_empresa, b.cpf_cnpj, b.num_doc, b.chv_cte)
	where b.id_reg_d100 is null*/
)as a
order by a.mod, a.cpf_cnpj, a.n_nf;

END;
$_$;


ALTER FUNCTION nfe.notas_faltantes_entre_sped_xml(empresa integer, dt_inicial date, dt_final date) OWNER TO celismar;

--
-- TOC entry 3480 (class 1255 OID 513700595)
-- Name: pega_data(integer, integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.pega_data(id_empresa integer, cod_mod integer) RETURNS TABLE(chv_nfe character varying, data_provavel date, n_nf bigint, serie integer, cod_sit character varying)
    LANGUAGE plpgsql
    AS $_$
declare
	linha record;
begin
	create temp table notas_faltantes(chv_nfe varchar(44), data_provavel date, n_nf bigint, serie integer, cod_sit varchar(2)); -- on commit drop;
	
	for linha in
	(
		select
			a.n_nf,
			a.serie
		from
			nfe.nfe_sequencias($1) as a
	)
	loop	
		insert into notas_faltantes (chv_nfe, data_provavel, n_nf, serie, cod_sit)
		(
			with nota_serie as
			(
				select linha.n_nf, linha.serie
			)
			select
				b.chv_nfe,
				c.d_emi,
				a.n_nf,
				a.serie,
				case when b.cod_sit in ('02', '03', '04', '05') then
					b.cod_sit::varchar(2)
				else
					''::varchar(2)
				end as cod_sit
			from
				nota_serie a
			left join
			(
				select
					a.chv_nfe,
					a.num_doc as n_nf,  
					a.ser::integer as serie,
					a.cod_sit,
					a.dt_doc2 as dt_doc
				from
					sf.reg_c100 a
				join
					sf.reg_0000 b using (id_reg_0000)
				where
					a.ser similar to '[0-9]+' and
					a.ind_emit = '0' and
					a.cod_mod = $2::varchar(2) and
					b.id_empresa = $1
			) b using(serie, n_nf)
			join
			(
				select
					linha.n_nf,
					a.d_emi
				from
					nfe.b01_ide a
				join
					nfe.c01_emit b using (id_nfe)
				join
				(
					select 
						max(a.n_nf) as n_nf,
						a.serie,
						c.id_empresa
					from
						nfe.b01_ide a
					join
						nfe.c01_emit b using (id_nfe)
					join
						ncm_helper.cad_empresas c using (cpf_cnpj)
					where 
						a.n_nf < linha.n_nf and
						a.serie = linha.serie and
						c.id_empresa = $1
					group by
						a.serie, c.id_empresa
				) c using (n_nf, serie)
				join
					ncm_helper.cad_empresas d using (cpf_cnpj, id_empresa)
			) c using(n_nf)
		);
	end loop;

	return query select a.chv_nfe, a.data_provavel, a.n_nf, a.serie, a.cod_sit from notas_faltantes a order by n_nf;
	truncate table notas_faltantes;
	drop table notas_faltantes;
return;
/*
select a.chv_nfe, a.data_provavel, a.n_nf, a.serie, a.cod_sit from nfe.pega_data (378) as a
*/
end;
$_$;


ALTER FUNCTION nfe.pega_data(id_empresa integer, cod_mod integer) OWNER TO planosassessoria;

--
-- TOC entry 3481 (class 1255 OID 513700596)
-- Name: pega_data_antigo(integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.pega_data_antigo(_id_empresa integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
declare
	linha 		record;
begin
	create temp table notas_faltantes(chv_nfe varchar(44), d_emi2 varchar(10), n_nf integer, serie varchar(3)) on commit drop;

	for linha in
	(
		select 
			a.n_nf, 
			a.serie
		from 
			nfe.nfe_sequencias(_id_empresa) as a (n_nf integer, serie integer)
	)
	loop	
		insert into notas_faltantes (chv_nfe, d_emi2, n_nf, serie)
		(
			select 
				b.chv_nfe,
				c.d_emi2,
				a.n_nf, 
				a.serie
			from 
				nfe.nfe_sequencias(_id_empresa) as a (n_nf integer, serie integer)
			left join
			(
				select
					a.chv_nfe,
					a.num_doc,   
					a.ser::integer as serie
				from
					sf.reg_c100 a
				join
					sf.reg_0000 b on a.id_reg_0000 = b.id_reg_0000
				where
					a.ind_emit = '0' and
					a.cod_mod = '55' and
					a.cod_sit <> '02' and
					b.id_empresa = _id_empresa
			) b on a.n_nf = b.num_doc and a.serie = b.serie
			join
			(
				select
					linha.n_nf as nota,
					a.d_emi2,
					a.n_nf,
					b.cnpj
				from
					nfe.nfe a
				join
				(
					select 
						max(a.n_nf) as nf_anterior,
						a.serie,
						a.cnpj
					from 
						nfe.nfe a
					join
						ncm_helper.cad_empresas b on a.cnpj = regexp_replace(b.cpf_cnpj, E'\\D', '', 'g')
					where 
						a.n_nf < linha.n_nf and
						a.serie = linha.serie and
						b.id_empresa = _id_empresa
					group by
						a.serie, a.cnpj
				) b on a.n_nf = b.nf_anterior and a.serie = b.serie
				where
					a.cnpj = b.cnpj
			) c on a.n_nf = c.nota
		);
	end loop;

	return query select a.chv_nfe, a.d_emi2, a.n_nf, a.serie from notas_faltantes a order by n_nf;
	truncate table notas_faltantes;
return;
/*
select a.chv_nfe, a.d_emi2, a.n_nf, a.serie from nfe.pega_data (91) as a (chv_nfe varchar, d_emi2 varchar, n_nf integer, serie varchar)
*/
end;
$$;


ALTER FUNCTION nfe.pega_data_antigo(_id_empresa integer) OWNER TO planosassessoria;

--
-- TOC entry 3478 (class 1255 OID 513700542)
-- Name: pega_nfces_faltantes_por_serie(integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.pega_nfces_faltantes_por_serie(id_empresa integer) RETURNS TABLE(serie integer, n_nf integer)
    LANGUAGE plpgsql
    AS $_$
declare
	i record;
begin

	create temp table nfce as (select a.n_nf, substring(a.inf_nfe, 23, 3)::integer as serie, a.inf_nfe, substring(a.inf_nfe, 7, 14) from livros.consulta_nfe_sefaz_saida a where substring(a.inf_nfe, 21, 2) = '65' and substring(a.inf_nfe, 7, 14) = (select b.cpf_cnpj from ncm_helper.cad_empresas b where b.id_empresa = $1));

	for i in (select min(a.n_nf), max(a.n_nf), a.serie from nfce a group by a.serie) loop
		return query
		select
			i.serie,
			a.n_nf
		from
		(
			select generate_series(i.min, i.max) as n_nf
		) a
		left join
			nfce b using(n_nf)
		where
			b.n_nf is null
		order by
			i.serie,
			a.n_nf;
	end loop;

	truncate table nfce;
	drop table nfce;
	

/*
	select * from nfe.pega_nfces_faltantes_por_serie(272);
*/

end;
$_$;


ALTER FUNCTION nfe.pega_nfces_faltantes_por_serie(id_empresa integer) OWNER TO planosassessoria;

--
-- TOC entry 3011 (class 1255 OID 16776)
-- Name: referenciar_itens_por_codigo_barras(integer); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.referenciar_itens_por_codigo_barras(empresa integer) RETURNS TABLE(id_empresa integer, fornecedor_cnpj text, cliente_c_prod character varying, cliente_codg_barra character varying, fornecedor_c_prod character varying, fornecedor_codg_barra text, fornecedor_descricao character varying, cliente_descricao character varying, fornecedor_nome text)
    LANGUAGE plpgsql
    AS $_$
begin
/*
return query
	select
		distinct on (a.cpf_cnpj, b.c_prod)
		a.id_empresa,
		a.cpf_cnpj::text as fornecedor_cnpj,
		c.codg_produto as cliente_c_prod,
		c.codg_barra as cliente_codg_barra,
		b.c_prod as fornecedor_c_prod,
		b.c_ean::text as fornecedor_codg_barra,
		b.x_prod as fornecedor_descricao,
		c.descricao as cliente_descricao,
		a.emit_x_nome::text as fornecedor_nome
	from
		nfe.nfe_terceiros a
	join
		nfe.nfe_itens b on a.id_nfe = b.id_nfe
	join
		ncm_helper.cad_produtos c on c.codg_barra = b.c_ean::text and a.id_empresa = c.id_empresa
	left join
		ncm_helper.cad_produtos_referenciados d on a.cpf_cnpj = d.fornecedor_cnpj and b.c_prod = d.fornecedor_codg_produto and a.id_empresa = d.id_empresa
	where
		d.fornecedor_codg_produto is null and
		b.vetorfts @@ to_tsquery(regexp_replace(regexp_replace(regexp_replace(regexp_replace(c.descricao, E'[^0-9a-zA-Z]', ' ', 'g'), E'\\s{2,}', ' ','g'), E'\\s', '|', 'g'), E'^\\||\\|$', '', 'g')) and
		c.codg_barra::bigint > 7000000 and
		c.codg_barra similar to '[0-9]+' and
		a.id_empresa = $1;*/

		
/*
select
	a.id_empresa,
	a.fornecedor_cnpj,
	a.cliente_c_prod,
	a.cliente_codg_barra,
	a.fornecedor_c_prod,
	a.fornecedor_codg_barra,
	a.fornecedor_descricao,
	a.cliente_descricao
from
	nfe.referenciar_itens_por_codigo_barras(122) as a where cliente_codg_barra = '7897168510570';
*/

end;
$_$;


ALTER FUNCTION nfe.referenciar_itens_por_codigo_barras(empresa integer) OWNER TO planosassessoria;

--
-- TOC entry 3484 (class 1255 OID 513700600)
-- Name: replica_data_nfe_3_10(); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.replica_data_nfe_3_10() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if (new.dh_emi is not null) then
        new.d_emi = new.dh_emi::date;
    end if;
    if (new.dh_sai_ent is not null) then
        new.d_sai_ent = new.dh_sai_ent::date;
        new.h_sai_ent = new.dh_sai_ent::TIME WITH TIME ZONE;
    end if;

    update nfe.raiz_nfe as a set d_emi = new.d_emi where a.id_nfe = new.id_nfe;

    return new;
end;
$$;


ALTER FUNCTION nfe.replica_data_nfe_3_10() OWNER TO planosassessoria;

--
-- TOC entry 3514 (class 1255 OID 534829846)
-- Name: sincronizar(integer); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.sincronizar(id_empresa integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
/*

select * from nfe.sincronizar(2001)

   select
      	a.xml_id, b.id_empresa
    from xml.nfe_nfce as a
	join ncm_helper.cad_empresas as b using(cpf_cnpj)
    left join nfe.raiz_nfe as c on (a.xml_id, a.ch_nf) = (c.xml_id, c.inf_nfe)
    where c.id_nfe is null  limit 2


SELECT * FROM xml.desestruturar_xml_nfe_nfce(45422, true);

*/
declare
  nfe record;
  nfe_entrada cursor for (
  	select
		a.xml_id
	from
	(    select
			a.xml_id
		from xml.nfe_nfce as a
		join ncm_helper.cad_empresas as b using(cpf_cnpj)
    	left join nfe.raiz_nfe as c on (a.xml_id, a.ch_nf) = (c.xml_id, c.inf_nfe)
   		where c.id_nfe is null and b.id_empresa = $1
	 	--and a.ch_nf = '51250205594828000139651020002216181274733448' 
		--and substring(a.ch_nf,21,2)::varchar(2) = '65'
	)as a
  );
  
begin
for nfe in nfe_entrada
loop
	PERFORM xml.desestruturar_xml_nfe_nfce(nfe.xml_id, true);  
end loop;
end;
$_$;


ALTER FUNCTION nfe.sincronizar(id_empresa integer) OWNER TO celismar;

--
-- TOC entry 3302 (class 1255 OID 149512058)
-- Name: valida_codg_barra_byte(text); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.valida_codg_barra_byte(arg text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
    ean TEXT := CASE WHEN length($1) = 12 THEN '0' || $1 ELSE $1 END;
BEGIN
    IF ean !~ '^\\d{13}$' THEN RETURN FALSE; END IF;

    RETURN  10 - (
        (
            -- Sum even numerals.
            substring(ean, 2, 1)::integer
            + substring(ean, 4, 1)::integer
            + substring(ean, 6, 1)::integer
            + substring(ean, 8, 1)::integer
            + substring(ean, 10, 1)::integer
            + substring(ean, 12, 1)::integer
        ) * 3 -- Multiply total by 3.
        -- Add odd numerals except for checksum (13).
        + substring(ean, 1, 1)::integer
        + substring(ean, 3, 1)::integer
        + substring(ean, 5, 1)::integer
        + substring(ean, 7, 1)::integer
        + substring(ean, 9, 1)::integer
        + substring(ean, 11, 1)::integer
    -- Compare to the checksum.
    ) % 10 = substring(ean, 13, 1)::integer;
END;
$_$;


ALTER FUNCTION nfe.valida_codg_barra_byte(arg text) OWNER TO planosassessoria;

--
-- TOC entry 3012 (class 1255 OID 16778)
-- Name: validar_doc(character); Type: FUNCTION; Schema: nfe; Owner: celismar
--

CREATE FUNCTION nfe.validar_doc(character) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
	doc ALIAS FOR $1;
	numero int;
	digito_verificacao int;
BEGIN
	IF char_length(doc) < 3 THEN
		RAISE EXCEPTION 'O DOC deve possuir 3 digitos';
	END IF;
	
	numero := to_number(substr(doc,1, 2), '99');
	digito_verificacao := to_number(substr(doc, 3, 1), '9');

	/*
	IF mod(numero, 2) = digito_verificacao THEN
		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
	*/
	
	return (mod(numero, 2) = digito_verificacao);
END;
$_$;


ALTER FUNCTION nfe.validar_doc(character) OWNER TO celismar;

--
-- TOC entry 3304 (class 1255 OID 149519231)
-- Name: verifica_codg_barra_byte(text); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.verifica_codg_barra_byte(arg text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
    ean BYTEA := CASE WHEN length($1) = 12 THEN '0' || $1 ELSE $1 END;
BEGIN
    IF ean !~ '^\\d{13}$' THEN RETURN FALSE; END IF;
	-- SELECT * FROM public.verifica_codg_barra_byte('0000000000116');
	-- SELECT * FROM public.verifica_codg_barra_byte('7899592833744');
    RETURN 10 - (
        (
            -- Sum odd numerals.
            get_byte(ean,  1) - 48
            + get_byte(ean,  3) - 48
            + get_byte(ean,  5) - 48
            + get_byte(ean,  7) - 48
            + get_byte(ean,  9) - 48
            + get_byte(ean, 11) - 48
        ) * 3 -- Multiply total by 3.
        -- Add even numerals except for checksum (12).
        + get_byte(ean,  0) - 48
        + get_byte(ean,  2) - 48
        + get_byte(ean,  4) - 48
        + get_byte(ean,  6) - 48
        + get_byte(ean,  8) - 48
        + get_byte(ean, 10) - 48
    -- Compare to the checksum.
    ) % 10 = get_byte(ean, 12) - 48;
END;
$_$;


ALTER FUNCTION nfe.verifica_codg_barra_byte(arg text) OWNER TO planosassessoria;

--
-- TOC entry 3303 (class 1255 OID 149518990)
-- Name: verifica_codg_barra_subs(text); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.verifica_codg_barra_subs(arg text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
    ean TEXT := CASE WHEN length($1) = 12 THEN '0' || $1 ELSE $1 END;
BEGIN
    IF ean !~ '^\\d{13}$' THEN RETURN FALSE; END IF;
	-- SELECT * FROM public.verifica_codg_barra_subs('0000000000116');
	-- SELECT * FROM public.verifica_codg_barra_subs('7899592833744');
    RETURN  10 - (
        (
            -- Sum even numerals.
            substring(ean, 2, 1)::integer
            + substring(ean, 4, 1)::integer
            + substring(ean, 6, 1)::integer
            + substring(ean, 8, 1)::integer
            + substring(ean, 10, 1)::integer
            + substring(ean, 12, 1)::integer
        ) * 3 -- Multiply total by 3.
        -- Add odd numerals except for checksum (13).
        + substring(ean, 1, 1)::integer
        + substring(ean, 3, 1)::integer
        + substring(ean, 5, 1)::integer
        + substring(ean, 7, 1)::integer
        + substring(ean, 9, 1)::integer
        + substring(ean, 11, 1)::integer
    -- Compare to the checksum.
    ) % 10 = substring(ean, 13, 1)::integer;
END;
$_$;


ALTER FUNCTION nfe.verifica_codg_barra_subs(arg text) OWNER TO planosassessoria;

--
-- TOC entry 3305 (class 1255 OID 149519280)
-- Name: verifica_codg_barra_substr(text); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.verifica_codg_barra_substr(text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
    ean TEXT := CASE WHEN length($1) = 12 THEN '0' || $1 ELSE $1 END;
BEGIN
    IF ean !~ '^\\d{13}$' THEN RETURN FALSE; END IF;

    RETURN 10 - (
        (
            -- Sum even
            substring(ean, 2, 1)::integer
            + substring(ean, 4, 1)::integer
            + substring(ean, 6, 1)::integer
            + substring(ean, 8, 1)::integer
            + substring(ean, 10, 1)::integer
            + substring(ean, 12, 1)::integer
        ) * 3 -- Multiply total by 3
        -- Add odd numerals except for checksum (13)
        + substring(ean, 1, 1)::integer
        + substring(ean, 3, 1)::integer
        + substring(ean, 5, 1)::integer
        + substring(ean, 7, 1)::integer
        + substring(ean, 9, 1)::integer
        + substring(ean, 11, 1)::integer
    -- Compare to the checksum.
    ) % 10 = substring(ean, 13, 1)::integer;
end;
$_$;


ALTER FUNCTION nfe.verifica_codg_barra_substr(text) OWNER TO planosassessoria;

--
-- TOC entry 3013 (class 1255 OID 16779)
-- Name: verifica_id_nfe(character varying[]); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.verifica_id_nfe(nfes character varying[]) RETURNS TABLE(inf_nfe character varying, mod character varying, cpf_cnpj character varying, n_nf integer, serie integer, id_nfe integer, importada boolean)
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nota TEXT[];
	empresas INTEGER[];
BEGIN
	/*
	select * from nfe.verifica_id_nfe(
	'{{35150943588045000131550050001274041000000003,43588045000131,26546176000137,25238,3},
	{51140704084183000121651050000000901418801354,04084183000121,'',25234,3},
	{51160801304252000177650010000903441001997547,01304252000177,'',90344,1},
	{51150900620051000116550010000063241000063247,00620051000116,'',6324,1}}')
	
	*/
	foreach nota slice 1 IN ARRAY $1
	LOOP
		RETURN query
			SELECT
				a.inf_nfe,
				a.mod,
				a.cpf_cnpj,
				a.n_nf,
				a.serie,					
				b.id_nfe,
				CASE WHEN b.id_nfe IS NULL THEN
                    		  FALSE
				ELSE
				  TRUE
				END AS importada
			FROM
			(
				SELECT nota[1]::VARCHAR(44) AS inf_nfe, SUBSTR(nota[1]::VARCHAR(44), 21, 2)::VARCHAR(2) AS mod, nota[2]::VARCHAR(14) AS cpf_cnpj, nota[4]::INTEGER AS n_nf, nota[5]::INTEGER AS serie
			) a
			LEFT JOIN
				nfe.raiz_nfe b USING (n_nf, cpf_cnpj, serie, mod);	
	END LOOP;
END;
$_$;


ALTER FUNCTION nfe.verifica_id_nfe(nfes character varying[]) OWNER TO planosassessoria;

--
-- TOC entry 3014 (class 1255 OID 16780)
-- Name: verifica_status_nfe(character varying[]); Type: FUNCTION; Schema: nfe; Owner: planosassessoria
--

CREATE FUNCTION nfe.verifica_status_nfe(nfes character varying[]) RETURNS TABLE(inf_nfe character varying, mod character varying, cpf_cnpj character varying, n_nf integer, serie integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
	nota TEXT[];
	empresas INTEGER[];
BEGIN
	/*
	SELECT * FROM nfe.verifica_status_nfe(
	'{{35150943588045000131550050001274041000000003,43588045000131,26546176000137,127404,5},
	{51140704084183000121651050000000901418801354,04084183000121,'',25234,3},
	{51160801304252000177650010000903441001997547,01304252000177,'',90344,1},
	{51150900620051000116550010000063241000063247,00620051000116,'',6324,1}}')
	*/

	/**
	* Cria tabela temporária e índices para inserção temporária das informações
	*/
	CREATE TEMPORARY TABLE list_data_nfe 
	(
	    inf_nfe VARCHAR(44),
	    n_nf INTEGER,
	    serie INTEGER,
	    MOD VARCHAR(2),
	    cpf_cnpj VARCHAR(14)    
	);

	CREATE INDEX idx_n_nf_on_temp_nfe ON list_data_nfe (n_nf);
	CREATE INDEX idx_serie_on_temp_nfe ON list_data_nfe (serie);
	CREATE INDEX idx_mod_on_temp_nfe ON list_data_nfe (mod);
	CREATE INDEX idx_cpf_cnpj_on_temp_nfe ON list_data_nfe (cpf_cnpj);
	
	foreach nota slice 1 IN ARRAY $1
	LOOP

		/**
		* Verifica se um dos cnpjs passados na nota existe na nossa base de clientes
		* se nao existir desconsidera a nf
		*/
		SELECT array_agg(a.id_empresa) FROM ncm_helper.cad_empresas a WHERE a.cpf_cnpj = SOME (ARRAY[nota[2], nota[3]]) INTO empresas;

		
		/**
		* Se existe um ou os dois cnpjs ele entra e verifica se a nota da volta existe no banco, se nao existe
		* ele coloca entao que e para inserir a nota
		*/
		IF empresas IS NOT NULL THEN
			INSERT INTO list_data_nfe(inf_nfe, n_nf, serie, mod, cpf_cnpj) 
			SELECT
				a.inf_nfe,
				a.n_nf,
				a.serie,
				a.mod,
				a.cpf_cnpj
			FROM
			(
				SELECT nota[1]::VARCHAR(44) AS inf_nfe, nota[4]::INTEGER AS n_nf, nota[5]::INTEGER AS serie, SUBSTR(nota[1]::VARCHAR(44), 21, 2)::VARCHAR(2) AS mod, nota[2]::VARCHAR(14) AS cpf_cnpj
			) a;		
		END IF;
	END LOOP;

	RETURN query 
		SELECT 
			DISTINCT ON(a.n_nf, a.serie, a.mod, a.cpf_cnpj)
			a.inf_nfe,
			a.mod,
			a.cpf_cnpj,
			a.n_nf, 
			a.serie
		FROM 
			list_data_nfe a
		LEFT JOIN
			nfe.raiz_nfe b USING(n_nf, serie, mod, cpf_cnpj)
		WHERE 
			b.n_nf IS NULL;
	TRUNCATE TABLE list_data_nfe;
	DROP TABLE list_data_nfe;
END;
$_$;


ALTER FUNCTION nfe.verifica_status_nfe(nfes character varying[]) OWNER TO planosassessoria;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 878 (class 1259 OID 11339499)
-- Name: notas_ocultas; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.notas_ocultas (
    id integer NOT NULL,
    id_empresa bigint NOT NULL,
    chv_nfe character varying(44) NOT NULL,
    obs text,
    num_doc bigint,
    data timestamp without time zone DEFAULT (now())::timestamp without time zone
);


ALTER TABLE nfe.notas_ocultas OWNER TO planosassessoria;

--
-- TOC entry 879 (class 1259 OID 11339506)
-- Name: raiz_nfe; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.raiz_nfe (
    id_nfe integer NOT NULL,
    inf_nfe character varying(44) NOT NULL,
    n_nf integer NOT NULL,
    cod_sit character varying(2),
    serie integer NOT NULL,
    cpf_cnpj character varying(14) NOT NULL,
    mod character varying(2) NOT NULL,
    ser character varying(3),
    dest_cpf_cnpj character varying(14),
    cnpj_chave character varying(14),
    pesquisa_fts tsvector,
    nota_recusada boolean DEFAULT false,
    d_emi date,
    ch_nfe character varying(44),
    xml_id bigint,
    guia boolean DEFAULT false
)
WITH (autovacuum_vacuum_cost_delay='0', autovacuum_analyze_scale_factor='0.004', autovacuum_vacuum_scale_factor='0.0009');


ALTER TABLE nfe.raiz_nfe OWNER TO planosassessoria;

--
-- TOC entry 1172 (class 1259 OID 11340703)
-- Name: b01_ide; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.b01_ide (
    id_nfe bigint NOT NULL,
    c_uf integer,
    nat_op text,
    ind_pag integer,
    mod character varying(2),
    serie integer,
    n_nf bigint,
    d_emi date,
    d_sai_ent date,
    h_sai_ent time with time zone,
    tp_nf integer,
    c_mun_fg integer,
    tp_imp integer,
    tp_emis integer,
    c_dv integer,
    tp_amb integer,
    fin_nfe integer,
    proc_emi integer,
    ver_proc character varying(20),
    dh_cont timestamp with time zone,
    x_just character varying(256),
    c_nf character varying(9),
    dh_emi timestamp with time zone,
    dh_sai_ent timestamp with time zone,
    id_dest integer,
    ind_final integer,
    ind_pres integer
)
WITH (autovacuum_analyze_scale_factor='0.004', autovacuum_vacuum_scale_factor='0.001');


ALTER TABLE nfe.b01_ide OWNER TO planosassessoria;

--
-- TOC entry 11844 (class 0 OID 0)
-- Dependencies: 1172
-- Name: COLUMN b01_ide.nat_op; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.b01_ide.nat_op IS 'TAMANHO DO MANUAL É: 60, PORÉM VEM COM VALOR MAIOR.';


--
-- TOC entry 2192 (class 1259 OID 26383289)
-- Name: b12a_nf_ref_id_seq; Type: SEQUENCE; Schema: nfe; Owner: operador
--

CREATE SEQUENCE nfe.b12a_nf_ref_id_seq
    START WITH 466175
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.b12a_nf_ref_id_seq OWNER TO operador;

--
-- TOC entry 2191 (class 1259 OID 26383082)
-- Name: b12a_nf_ref; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.b12a_nf_ref (
    id integer DEFAULT nextval('nfe.b12a_nf_ref_id_seq'::regclass) NOT NULL,
    id_nfe bigint,
    ref_nfe character varying(44),
    ref_cte character varying(44)
);


ALTER TABLE nfe.b12a_nf_ref OWNER TO planosassessoria;

--
-- TOC entry 1173 (class 1259 OID 11340728)
-- Name: c01_emit; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.c01_emit (
    id integer NOT NULL,
    id_nfe bigint NOT NULL,
    cnpj character varying(14),
    cpf character varying(11),
    x_nome character varying(60),
    x_fant character varying(60),
    ie character varying(14),
    iest character varying(14),
    im character varying(15),
    cnae character varying(7),
    crt integer,
    cpf_cnpj character varying(14),
    pesquisa_fts tsvector
)
WITH (autovacuum_analyze_scale_factor='0.005', autovacuum_vacuum_scale_factor='0.001');


ALTER TABLE nfe.c01_emit OWNER TO planosassessoria;

--
-- TOC entry 1174 (class 1259 OID 11340731)
-- Name: c01_emit_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.c01_emit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.c01_emit_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11849 (class 0 OID 0)
-- Dependencies: 1174
-- Name: c01_emit_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.c01_emit_id_seq OWNED BY nfe.c01_emit.id;


--
-- TOC entry 1175 (class 1259 OID 11340733)
-- Name: c05_ender_emit; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.c05_ender_emit (
    id integer NOT NULL,
    id_nfe bigint NOT NULL,
    id_emit bigint,
    x_lgr text,
    nro character varying(60),
    x_cpl character varying(60),
    x_bairro character varying(60),
    c_mun integer,
    x_mun character varying(60),
    uf character varying(2),
    cep character varying(8),
    c_pais integer,
    x_pais character varying(60),
    fone character varying(14)
)
WITH (autovacuum_analyze_scale_factor='0.005', autovacuum_vacuum_scale_factor='0.002');


ALTER TABLE nfe.c05_ender_emit OWNER TO planosassessoria;

--
-- TOC entry 11851 (class 0 OID 0)
-- Dependencies: 1175
-- Name: COLUMN c05_ender_emit.x_lgr; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.c05_ender_emit.x_lgr IS 'TAMANHO DO MANUAL É: 60, PORÉM VEM COM VALOR MAIOR.
ATT: CIDOR';


--
-- TOC entry 1176 (class 1259 OID 11340736)
-- Name: c05_ender_emit_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.c05_ender_emit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.c05_ender_emit_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11853 (class 0 OID 0)
-- Dependencies: 1176
-- Name: c05_ender_emit_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.c05_ender_emit_id_seq OWNED BY nfe.c05_ender_emit.id;


--
-- TOC entry 1177 (class 1259 OID 11340738)
-- Name: cofins_filhos; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.cofins_filhos (
    id_nfe bigint NOT NULL,
    cst character varying(2),
    v_bc numeric(15,2),
    p_cofins numeric(5,2),
    q_bc_prod numeric(16,4),
    v_aliq_prod numeric(15,4),
    v_cofins numeric(15,2),
    id_prod bigint NOT NULL
)
WITH (autovacuum_analyze_scale_factor='0.002', autovacuum_vacuum_scale_factor='0.002');


ALTER TABLE nfe.cofins_filhos OWNER TO planosassessoria;

--
-- TOC entry 2330 (class 1259 OID 118954386)
-- Name: contingencia; Type: TABLE; Schema: nfe; Owner: operador
--

CREATE TABLE nfe.contingencia (
    cpf_cnpj character varying(14) NOT NULL,
    n_nf integer NOT NULL,
    serie integer NOT NULL,
    mod character varying(2) NOT NULL,
    ch_nf character varying(44)
);


ALTER TABLE nfe.contingencia OWNER TO operador;

--
-- TOC entry 1178 (class 1259 OID 11340743)
-- Name: d01_avulsa; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.d01_avulsa (
    id_nfe bigint NOT NULL,
    cnpj character varying(14),
    x_orgao character varying(60),
    matr character varying(60),
    x_agente character varying(60),
    fone character varying(14),
    uf character varying(2),
    n_dar character varying(60),
    d_emi date,
    v_dar numeric(15,2),
    rep_emi character varying(60),
    d_pag date
);


ALTER TABLE nfe.d01_avulsa OWNER TO planosassessoria;

--
-- TOC entry 1179 (class 1259 OID 11340748)
-- Name: e01_dest; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.e01_dest (
    id integer NOT NULL,
    id_nfe bigint NOT NULL,
    cnpj character varying(14),
    cpf character varying(11),
    ie character varying(14),
    isuf character varying(9),
    email character varying(60),
    cpf_cnpj character varying(14),
    id_estrangeiro character varying(20),
    ind_ie_dest integer,
    im character varying(15),
    x_nome text,
    pesquisa_fts tsvector
)
WITH (autovacuum_analyze_scale_factor='0.03', autovacuum_vacuum_scale_factor='0.008');


ALTER TABLE nfe.e01_dest OWNER TO planosassessoria;

--
-- TOC entry 1180 (class 1259 OID 11340754)
-- Name: e01_dest_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.e01_dest_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.e01_dest_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11859 (class 0 OID 0)
-- Dependencies: 1180
-- Name: e01_dest_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.e01_dest_id_seq OWNED BY nfe.e01_dest.id;


--
-- TOC entry 1181 (class 1259 OID 11340756)
-- Name: e05_ender_dest; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.e05_ender_dest (
    id integer NOT NULL,
    id_nfe bigint NOT NULL,
    id_dest bigint,
    x_lgr character varying(60),
    nro character varying(60),
    x_cpl character varying(60),
    x_bairro character varying(60),
    c_mun integer,
    x_mun character varying(60),
    uf character varying(2),
    cep character varying(8),
    c_pais integer,
    x_pais character varying(60),
    fone character varying(14)
)
WITH (autovacuum_analyze_scale_factor='0.03', autovacuum_vacuum_scale_factor='0.01');


ALTER TABLE nfe.e05_ender_dest OWNER TO planosassessoria;

--
-- TOC entry 1182 (class 1259 OID 11340759)
-- Name: e05_ender_dest_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.e05_ender_dest_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.e05_ender_dest_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11862 (class 0 OID 0)
-- Dependencies: 1182
-- Name: e05_ender_dest_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.e05_ender_dest_id_seq OWNED BY nfe.e05_ender_dest.id;


--
-- TOC entry 2669 (class 1259 OID 549717740)
-- Name: guia_icms_st; Type: TABLE; Schema: nfe; Owner: celismar
--

CREATE TABLE nfe.guia_icms_st (
    dest_cpf_cnpj character varying(14) NOT NULL,
    cpf_cnpj character varying(14) NOT NULL,
    n_nf integer NOT NULL,
    serie integer NOT NULL,
    mod character varying(2) NOT NULL,
    inf_nfe character varying(44) NOT NULL,
    guia boolean DEFAULT false
);


ALTER TABLE nfe.guia_icms_st OWNER TO celismar;

--
-- TOC entry 1183 (class 1259 OID 11340784)
-- Name: i01_prod; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.i01_prod (
    id integer NOT NULL,
    id_nfe bigint,
    c_prod character varying(60),
    x_prod text,
    ncm character varying(10),
    ex_tipi character varying(3),
    cfop integer,
    u_com character varying(10),
    v_prod numeric(15,2),
    u_trib character varying(10),
    v_frete numeric(15,2),
    v_seg numeric(15,2),
    v_desc numeric(15,2),
    v_outro numeric(15,2),
    ind_tot integer,
    x_ped character varying(15),
    n_item_ped character varying(10),
    v_un_com character varying(32),
    v_un_trib character varying(32),
    vetorfts tsvector,
    q_com numeric(15,4),
    q_trib numeric(15,4),
    n_fci text,
    nve character varying(10),
    cest bigint,
    c_ean character varying(14),
    c_ean_trib character varying(14),
    n_item integer,
    inf_ad_prod text,
    ind_escala character varying(1),
    cnpj_fab character varying(14),
    c_benef character varying(10),
    cpf_cnpj character varying(14),
    n_nf integer,
    mod character varying(2),
    serie integer,
    d_emi date,
    vl_st_apurado numeric(18,2) DEFAULT 0.00,
    vl_pobreza_apurado numeric(18,2) DEFAULT 0.00,
    vl_difal numeric(18,2) DEFAULT 0.00,
    vl_bc_difal numeric(18,2) DEFAULT 0.00,
    aliq_difal numeric(18,2) DEFAULT 0.00,
    vl_bc_st numeric(18,2) DEFAULT 0.00,
    aliq_icms_st numeric(18,2),
    vl_fundes numeric(18,2) DEFAULT 0.00,
    cod_cta character varying(60) DEFAULT ''::character varying(60)
)
WITH (autovacuum_vacuum_cost_delay='0', autovacuum_enabled='true', autovacuum_analyze_scale_factor='0.0008', autovacuum_vacuum_scale_factor='0.0002');


ALTER TABLE nfe.i01_prod OWNER TO planosassessoria;

--
-- TOC entry 11865 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.x_prod; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.x_prod IS '-- Tamanho original 120, modificado para para resolver problema...';


--
-- TOC entry 11866 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.ncm; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.ncm IS 'Tamanho original 8, modificado para 10 para resolver problema...';


--
-- TOC entry 11867 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.n_item; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.n_item IS 'Campo do det(H01), movido para prod para melhor manipulação';


--
-- TOC entry 11868 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.inf_ad_prod; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.inf_ad_prod IS 'Campo do det(H01), movido para prod para melhor manipulação';


--
-- TOC entry 11869 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.ind_escala; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.ind_escala IS 'NOTA TÉCNICA 2016/002 v1.42 para 22/01/2018';


--
-- TOC entry 11870 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.cnpj_fab; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.cnpj_fab IS 'NOTA TÉCNICA 2016/002 v1.42 para 22/01/2018';


--
-- TOC entry 11871 (class 0 OID 0)
-- Dependencies: 1183
-- Name: COLUMN i01_prod.c_benef; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.i01_prod.c_benef IS 'NOTA TÉCNICA 2016/002 v1.42 para 22/01/2018';


--
-- TOC entry 1184 (class 1259 OID 11340790)
-- Name: i01_prod_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.i01_prod_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.i01_prod_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11873 (class 0 OID 0)
-- Dependencies: 1184
-- Name: i01_prod_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.i01_prod_id_seq OWNED BY nfe.i01_prod.id;


--
-- TOC entry 1185 (class 1259 OID 11340812)
-- Name: icms_filhos; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.icms_filhos (
    id_nfe bigint NOT NULL,
    orig integer,
    cst character varying(3),
    cso_sn character varying(3),
    p_cred_sn numeric(5,2),
    v_cred_icms_sn numeric(15,2),
    mod_bc integer,
    mod_bc_st integer,
    p_red_bc numeric(15,4),
    p_red_bc_st numeric(15,4),
    p_mva_st numeric(15,4),
    v_bc numeric(15,2),
    v_bc_st numeric(15,2),
    v_bc_st_ret numeric(15,2),
    p_icms numeric(15,4),
    v_icms numeric(15,2),
    p_icms_st numeric(15,4),
    v_icms_st numeric(15,2),
    v_icms_st_ret numeric(15,2),
    mot_des_icms integer,
    p_bc_op numeric(15,4),
    v_icms_deson numeric(15,2),
    v_icms_op numeric(15,2),
    p_dif numeric(15,4),
    v_icms_dif numeric(15,2),
    p_st numeric(15,4),
    uf_st character varying(2),
    v_bc_st_dest numeric(15,2),
    v_icms_st_dest numeric(15,2),
    v_bc_fcp numeric(15,2),
    p_fcp numeric(15,4),
    v_bc_fcp_st numeric(15,2),
    p_fcp_st numeric(15,4),
    v_fcp_st numeric(15,2),
    v_bc_fcp_st_ret numeric(15,2),
    p_fcp_st_ret numeric(15,4),
    v_fcp_st_ret numeric(15,2),
    v_fcp numeric(15,2),
    id_prod bigint NOT NULL,
    v_icms_substituto numeric(15,2),
    p_red_bc_efet numeric(15,4),
    v_bc_efet numeric(15,2),
    p_icms_efet numeric(15,4),
    v_icms_efet numeric(15,2)
)
WITH (autovacuum_analyze_scale_factor='0.001', autovacuum_vacuum_scale_factor='0.0008');


ALTER TABLE nfe.icms_filhos OWNER TO planosassessoria;

--
-- TOC entry 1186 (class 1259 OID 11340817)
-- Name: ipi_filhos; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.ipi_filhos (
    id_nfe bigint NOT NULL,
    cst character varying(2),
    v_bc numeric(15,2),
    p_ipi numeric(5,2),
    q_unid numeric(16,4),
    v_unid numeric(15,4),
    v_ipi numeric(15,2),
    id_prod bigint NOT NULL,
    cl_enq character varying(5),
    cnpj_prod character varying(14),
    c_selo character varying(60),
    q_selo character varying(12),
    c_enq character varying(3)
)
WITH (autovacuum_analyze_scale_factor='0.02', autovacuum_vacuum_scale_factor='0.02');


ALTER TABLE nfe.ipi_filhos OWNER TO planosassessoria;

--
-- TOC entry 1187 (class 1259 OID 11340852)
-- Name: m01_imposto; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.m01_imposto (
    id_nfe bigint NOT NULL,
    v_tot_trib numeric(15,2),
    id_prod bigint NOT NULL
)
WITH (autovacuum_analyze_scale_factor='0.001', autovacuum_vacuum_scale_factor='0.001');


ALTER TABLE nfe.m01_imposto OWNER TO planosassessoria;

--
-- TOC entry 1188 (class 1259 OID 11340902)
-- Name: na01_icms_uf_dest; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.na01_icms_uf_dest (
    id_nfe bigint NOT NULL,
    v_bc_uf_dest numeric(15,2),
    p_fcp_uf_dest numeric(5,2),
    p_icms_uf_dest numeric(5,2),
    p_icms_inter numeric(5,2),
    p_icms_inter_part numeric(5,2),
    v_fcp_uf_dest numeric(15,2),
    v_icms_uf_dest numeric(15,2),
    v_icms_uf_remet numeric(15,2),
    id_prod bigint NOT NULL
);


ALTER TABLE nfe.na01_icms_uf_dest OWNER TO planosassessoria;

--
-- TOC entry 1192 (class 1259 OID 11340921)
-- Name: nfe_devolucao_corrigida; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.nfe_devolucao_corrigida (
    id_nfe integer,
    inf_nfe character varying(44),
    id_item integer,
    c_prod character varying(60),
    cfop integer,
    vl_item numeric,
    n_nf integer,
    d_emi bigint,
    cst_piscofins_entrada character varying(4),
    id_tipo_regime integer,
    movimenta_piscofins smallint,
    id_empresa integer,
    vl_pis numeric(18,2),
    vl_cofins numeric(18,2),
    aliq_pis numeric(18,4),
    aliq_cofins numeric(18,4),
    vl_bc_pis numeric(18,2),
    vl_bc_cofins numeric(18,2),
    tipo_credito character varying(3)
);


ALTER TABLE nfe.nfe_devolucao_corrigida OWNER TO planosassessoria;

--
-- TOC entry 1194 (class 1259 OID 11340959)
-- Name: notas_ocultas_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.notas_ocultas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.notas_ocultas_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11880 (class 0 OID 0)
-- Dependencies: 1194
-- Name: notas_ocultas_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.notas_ocultas_id_seq OWNED BY nfe.notas_ocultas.id;


--
-- TOC entry 1195 (class 1259 OID 11340963)
-- Name: p01_ii; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.p01_ii (
    id integer NOT NULL,
    id_nfe bigint NOT NULL,
    id_imposto bigint,
    v_bc numeric(15,2),
    v_desp_adu numeric(15,2),
    v_ii numeric(15,2),
    v_iof numeric(15,2),
    id_prod bigint NOT NULL
);


ALTER TABLE nfe.p01_ii OWNER TO planosassessoria;

--
-- TOC entry 1196 (class 1259 OID 11340966)
-- Name: p01_ii_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.p01_ii_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.p01_ii_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11883 (class 0 OID 0)
-- Dependencies: 1196
-- Name: p01_ii_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.p01_ii_id_seq OWNED BY nfe.p01_ii.id;


--
-- TOC entry 1193 (class 1259 OID 11340930)
-- Name: pis_filhos; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.pis_filhos (
    id_nfe bigint NOT NULL,
    cst character varying(2),
    q_bc_prod numeric(16,4),
    v_aliq_prod numeric(15,4),
    v_bc numeric(15,2),
    p_pis numeric(5,2),
    v_pis numeric(15,2),
    id_prod bigint NOT NULL
)
WITH (autovacuum_analyze_scale_factor='0.002', autovacuum_vacuum_scale_factor='0.002');


ALTER TABLE nfe.pis_filhos OWNER TO planosassessoria;

--
-- TOC entry 1197 (class 1259 OID 11340975)
-- Name: pr03_inf_prot; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.pr03_inf_prot (
    id_nfe bigint NOT NULL,
    id text,
    ch_nfe character varying(44),
    dh_recbto timestamp without time zone,
    n_prot character varying(15),
    dig_val text,
    c_stat integer NOT NULL,
    x_motivo character varying(255)
)
WITH (autovacuum_analyze_scale_factor='0.006', autovacuum_vacuum_scale_factor='0.002');


ALTER TABLE nfe.pr03_inf_prot OWNER TO planosassessoria;

--
-- TOC entry 1198 (class 1259 OID 11341001)
-- Name: raiz_nfe_id_nfe_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.raiz_nfe_id_nfe_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.raiz_nfe_id_nfe_seq OWNER TO planosassessoria;

--
-- TOC entry 11887 (class 0 OID 0)
-- Dependencies: 1198
-- Name: raiz_nfe_id_nfe_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.raiz_nfe_id_nfe_seq OWNED BY nfe.raiz_nfe.id_nfe;


--
-- TOC entry 2495 (class 1259 OID 298636048)
-- Name: reg_federal; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.reg_federal (
    id_empresa bigint,
    simples boolean,
    tipo_empresa integer,
    ncm character varying(8),
    ex_ipi character varying(3),
    vigencia2 date
);


ALTER TABLE nfe.reg_federal OWNER TO planosassessoria;

--
-- TOC entry 2394 (class 1259 OID 169512277)
-- Name: role; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.role (
    id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE nfe.role OWNER TO planosassessoria;

--
-- TOC entry 2393 (class 1259 OID 169512275)
-- Name: role_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.role_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11891 (class 0 OID 0)
-- Dependencies: 2393
-- Name: role_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.role_id_seq OWNED BY nfe.role.id;


--
-- TOC entry 1199 (class 1259 OID 11341015)
-- Name: ua01_imposto_devol; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.ua01_imposto_devol (
    id integer NOT NULL,
    id_nfe bigint,
    p_devol numeric(5,2),
    id_prod bigint
);


ALTER TABLE nfe.ua01_imposto_devol OWNER TO planosassessoria;

--
-- TOC entry 1200 (class 1259 OID 11341018)
-- Name: ua01_imposto_devol_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.ua01_imposto_devol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.ua01_imposto_devol_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11894 (class 0 OID 0)
-- Dependencies: 1200
-- Name: ua01_imposto_devol_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.ua01_imposto_devol_id_seq OWNED BY nfe.ua01_imposto_devol.id;


--
-- TOC entry 1201 (class 1259 OID 11341020)
-- Name: ua04_ipi; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.ua04_ipi (
    id integer NOT NULL,
    id_nfe bigint,
    id_imposto_devol bigint,
    v_ipi_devol numeric(15,2)
);


ALTER TABLE nfe.ua04_ipi OWNER TO planosassessoria;

--
-- TOC entry 1202 (class 1259 OID 11341023)
-- Name: ua04_ipi_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.ua04_ipi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.ua04_ipi_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11897 (class 0 OID 0)
-- Dependencies: 1202
-- Name: ua04_ipi_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.ua04_ipi_id_seq OWNED BY nfe.ua04_ipi.id;


--
-- TOC entry 2714 (class 1259 OID 577427595)
-- Name: ub01_is; Type: TABLE; Schema: nfe; Owner: dorcilio
--

CREATE TABLE nfe.ub01_is (
    id_nfe bigint NOT NULL,
    id_i01_prod bigint NOT NULL,
    id_ub01_is integer NOT NULL,
    cst_is character varying(3) NOT NULL,
    c_class_trib_is character varying(6) NOT NULL,
    v_bc_is numeric(15,2) NOT NULL,
    p_is numeric(15,4) NOT NULL,
    p_is_espec numeric(15,4),
    u_trib character varying(6) NOT NULL,
    q_trib numeric(15,4) NOT NULL,
    v_is numeric(15,2) NOT NULL
);


ALTER TABLE nfe.ub01_is OWNER TO dorcilio;

--
-- TOC entry 2713 (class 1259 OID 577427593)
-- Name: ub01_is_id_ub01_is_seq; Type: SEQUENCE; Schema: nfe; Owner: dorcilio
--

ALTER TABLE nfe.ub01_is ALTER COLUMN id_ub01_is ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME nfe.ub01_is_id_ub01_is_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 2716 (class 1259 OID 578421855)
-- Name: ub12_ibs_cbs; Type: TABLE; Schema: nfe; Owner: dorcilio
--

CREATE TABLE nfe.ub12_ibs_cbs (
    id_nfe bigint NOT NULL,
    id_i01_prod bigint NOT NULL,
    id_ub12_ibs_cbs integer NOT NULL,
    cst character varying(3) NOT NULL,
    c_class_trib character varying(6) NOT NULL,
    ind_doacao character varying(1),
    v_bc numeric(15,2) NOT NULL,
    p_ibs_uf numeric(15,4) NOT NULL,
    p_dif_ibs numeric(15,4),
    v_dif_ibs numeric(15,2),
    v_dev_trib_ibs numeric(15,2),
    p_red_aliq_ibs numeric(15,4),
    p_aliq_efet_ibs numeric(15,4),
    v_ibs_uf numeric(15,2) NOT NULL,
    p_ibs_mun numeric(15,4) NOT NULL,
    p_dif_ibs_mun numeric(15,4),
    v_dif_ibs_mun numeric(15,2),
    v_dev_trib_ibs_mun numeric(15,2),
    p_red_aliq_ibs_mun numeric(15,4),
    p_aliq_efet_ibs_mun numeric(15,4),
    v_ibs_mun numeric(15,2) NOT NULL,
    v_ibs numeric(15,2) NOT NULL,
    p_cbs numeric(15,4) NOT NULL,
    p_dif_cbs numeric(15,4),
    v_dif_cbs numeric(15,2),
    v_dev_trib_cbs numeric(15,2),
    p_red_aliq_cbs numeric(15,2),
    p_aliq_efet_cbs numeric(15,4),
    v_cbs numeric(15,2) NOT NULL,
    cst_reg character varying(3),
    c_class_trib_reg character varying(6),
    p_aliq_efet_reg_ibs_uf numeric(15,4),
    v_trib_reg_ibs_uf numeric(15,2),
    p_aliq_efet_reg_ibs_mun numeric(15,4),
    v_trib_reg_ibs_mun numeric(15,2),
    p_aliq_efet_reg_cbs numeric(15,4),
    v_trib_reg_cbs numeric(15,2),
    p_aliq_ibs_uf numeric(15,4),
    v_trib_ibs_uf numeric(15,2),
    p_aliq_ibs_mun numeric(15,4),
    v_trib_ibs_mun numeric(15,2),
    p_aliq_cbs numeric(15,4),
    v_trib_cbs numeric(15,2),
    q_bc_mono numeric(15,4),
    ad_rem_ibs numeric(15,4),
    ad_rem_cbs numeric(15,4),
    v_ibs_mono numeric(15,2),
    v_cbs_mono numeric(15,2),
    q_bc_mono_reten numeric(15,4),
    ad_rem_ibs_reten numeric(15,4),
    v_ibs_mono_reten numeric(15,2),
    ad_rem_cbs_reten numeric(15,4),
    v_cbs_mono_reten numeric(15,2),
    q_bc_mono_ret numeric(15,4),
    ad_rem_ibs_ret numeric(15,4),
    v_ibs_mono_ret numeric(15,2),
    ad_rem_cbs_ret numeric(15,4),
    v_cbs_mono_ret numeric(15,2),
    p_dif_ibs_mono numeric(15,4),
    v_ibs_mono_dif numeric(15,2),
    p_dif_cbs_mono numeric(15,4),
    v_cbs_mono_dif numeric(15,2),
    v_tot_ibs_mono_item numeric(15,2),
    v_tot_cbs_mono_item numeric(15,2),
    v_ibs_trans_cred numeric(15,2),
    v_cbs_trans_cred numeric(15,2),
    compet_apur_ajuste_compet character varying(7),
    v_ibs_ajuste_compet numeric(15,2),
    v_cbs_ajuste_compet numeric(15,2),
    v_ibs_est_cred numeric(15,2),
    v_cbs_est_cred numeric(15,2),
    v_bc_cred_pres numeric(15,2),
    c_cred_pres character varying(2),
    p_cred_pres_ibs numeric(15,4),
    v_cred_pres_ibs numeric(15,2),
    v_cred_pres_cond_sus_ibs numeric(15,2),
    p_cred_pres_cbs numeric(15,4),
    v_cred_pres_cbs numeric(15,2),
    v_cred_pres_cond_sus_cbs numeric(15,2),
    compet_apur_ibs_zfm character varying(7),
    tp_cred_pres_ibs_zfm character varying(1),
    v_cred_pres_ibs_zfm numeric(15,2)
);


ALTER TABLE nfe.ub12_ibs_cbs OWNER TO dorcilio;

--
-- TOC entry 2715 (class 1259 OID 578421853)
-- Name: ub12_ibs_cbs_id_ub12_ibs_cbs_seq; Type: SEQUENCE; Schema: nfe; Owner: dorcilio
--

ALTER TABLE nfe.ub12_ibs_cbs ALTER COLUMN id_ub12_ibs_cbs ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME nfe.ub12_ibs_cbs_id_ub12_ibs_cbs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 2396 (class 1259 OID 169512292)
-- Name: users; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.users (
    id integer NOT NULL,
    name character varying NOT NULL,
    cnpj character varying NOT NULL,
    empresa character varying NOT NULL,
    role_id integer NOT NULL,
    password character varying NOT NULL,
    email character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    active boolean NOT NULL
);


ALTER TABLE nfe.users OWNER TO planosassessoria;

--
-- TOC entry 2395 (class 1259 OID 169512290)
-- Name: users_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.users_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11904 (class 0 OID 0)
-- Dependencies: 2395
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.users_id_seq OWNED BY nfe.users.id;


--
-- TOC entry 1189 (class 1259 OID 11340907)
-- Name: w02_icms_tot; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.w02_icms_tot (
    id_nfe bigint NOT NULL,
    v_bc numeric(15,2),
    v_icms numeric(15,2),
    v_bc_st numeric(15,2),
    v_st numeric(15,2),
    v_prod numeric(15,2),
    v_frete numeric(15,2),
    v_seg numeric(15,2),
    v_desc numeric(15,2),
    v_ii numeric(15,2),
    v_ipi numeric(15,2),
    v_pis numeric(15,2),
    v_cofins numeric(15,2),
    v_outro numeric(15,2),
    v_nf numeric(15,2),
    v_tot_trib numeric(15,2),
    v_icms_deson numeric(15,2),
    v_fcp_uf_dest numeric(15,2),
    v_icms_uf_dest numeric(15,2),
    v_icms_uf_remet numeric(15,2),
    v_fcp numeric(15,2),
    v_fcp_st numeric(15,2),
    v_fcp_st_ret numeric(15,2),
    v_ipi_devol numeric(15,2)
)
WITH (autovacuum_analyze_scale_factor='0.005', autovacuum_vacuum_scale_factor='0.002');


ALTER TABLE nfe.w02_icms_tot OWNER TO planosassessoria;

--
-- TOC entry 11906 (class 0 OID 0)
-- Dependencies: 1189
-- Name: COLUMN w02_icms_tot.v_fcp; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.w02_icms_tot.v_fcp IS 'NOTA TÉCNICA 2016/002 v1.20 para 15/08/2018';


--
-- TOC entry 11907 (class 0 OID 0)
-- Dependencies: 1189
-- Name: COLUMN w02_icms_tot.v_fcp_st; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.w02_icms_tot.v_fcp_st IS 'NOTA TÉCNICA 2016/002 v1.20 para 15/08/2018';


--
-- TOC entry 11908 (class 0 OID 0)
-- Dependencies: 1189
-- Name: COLUMN w02_icms_tot.v_fcp_st_ret; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.w02_icms_tot.v_fcp_st_ret IS 'NOTA TÉCNICA 2016/002 v1.20 para 15/08/2018';


--
-- TOC entry 11909 (class 0 OID 0)
-- Dependencies: 1189
-- Name: COLUMN w02_icms_tot.v_ipi_devol; Type: COMMENT; Schema: nfe; Owner: planosassessoria
--

COMMENT ON COLUMN nfe.w02_icms_tot.v_ipi_devol IS 'NOTA TÉCNICA 2016/002 v1.20 para 15/08/2018';


--
-- TOC entry 1190 (class 1259 OID 11340910)
-- Name: w17_issqn_tot; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.w17_issqn_tot (
    id_nfe bigint NOT NULL,
    v_serv numeric(15,2),
    v_bc numeric(15,2),
    v_iss numeric(15,2),
    v_pis numeric(15,2),
    v_cofins numeric(15,2),
    d_compet date,
    v_deducao numeric(15,2),
    v_outro numeric(15,2),
    v_desc_incond numeric(15,2),
    v_desc_cond numeric(15,2),
    v_iss_ret numeric(15,2),
    c_reg_trib integer
);


ALTER TABLE nfe.w17_issqn_tot OWNER TO planosassessoria;

--
-- TOC entry 1191 (class 1259 OID 11340913)
-- Name: w23_ret_trib; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.w23_ret_trib (
    id_nfe bigint NOT NULL,
    v_ret_pis numeric(15,2),
    v_ret_cofins numeric(15,2),
    v_ret_csll numeric(15,2),
    v_bc_irrf numeric(15,2),
    v_irrf numeric(15,2),
    v_bc_ret_prev numeric(15,2),
    v_ret_prev numeric(15,2)
);


ALTER TABLE nfe.w23_ret_trib OWNER TO planosassessoria;

--
-- TOC entry 2200 (class 1259 OID 26775976)
-- Name: web_services; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.web_services (
    servico text NOT NULL,
    versao numeric(5,2) NOT NULL,
    tp_amb integer NOT NULL,
    codg_estado integer NOT NULL,
    url text NOT NULL
);


ALTER TABLE nfe.web_services OWNER TO planosassessoria;

--
-- TOC entry 2485 (class 1259 OID 287363051)
-- Name: xml_faltante; Type: TABLE; Schema: nfe; Owner: celismar
--

CREATE TABLE nfe.xml_faltante (
    cpf_cnpj character varying(14) NOT NULL,
    chv_nfe character varying(44) NOT NULL
);


ALTER TABLE nfe.xml_faltante OWNER TO celismar;

--
-- TOC entry 2195 (class 1259 OID 26495144)
-- Name: y07_dup_id_dup_seq; Type: SEQUENCE; Schema: nfe; Owner: operador
--

CREATE SEQUENCE nfe.y07_dup_id_dup_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.y07_dup_id_dup_seq OWNER TO operador;

--
-- TOC entry 1203 (class 1259 OID 11341193)
-- Name: y07_dup; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.y07_dup (
    id_nfe bigint NOT NULL,
    n_dup character varying(60),
    d_venc date,
    v_dup numeric(15,2),
    id_dup integer DEFAULT nextval('nfe.y07_dup_id_dup_seq'::regclass) NOT NULL
)
WITH (autovacuum_analyze_scale_factor='0.07', autovacuum_vacuum_scale_factor='0.06');


ALTER TABLE nfe.y07_dup OWNER TO planosassessoria;

--
-- TOC entry 1204 (class 1259 OID 11341198)
-- Name: ya01_pag; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.ya01_pag (
    id_nfe bigint NOT NULL,
    t_pag character varying(2),
    v_pag numeric(15,2),
    v_troco numeric(15,2),
    id_pag bigint NOT NULL,
    ind_pag integer,
    x_pag character varying(60),
    d_pag date,
    cnpj_pag character varying(14),
    uf_pag character varying(2)
)
WITH (autovacuum_analyze_scale_factor='0.006', autovacuum_vacuum_scale_factor='0.006');


ALTER TABLE nfe.ya01_pag OWNER TO planosassessoria;

--
-- TOC entry 2729 (class 1259 OID 586681870)
-- Name: ya01_pag_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.ya01_pag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.ya01_pag_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11918 (class 0 OID 0)
-- Dependencies: 2729
-- Name: ya01_pag_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.ya01_pag_id_seq OWNED BY nfe.ya01_pag.id_pag;


--
-- TOC entry 1205 (class 1259 OID 11341203)
-- Name: ya04_card; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.ya04_card (
    id_nfe bigint NOT NULL,
    cnpj character varying(14),
    t_band character varying(2),
    c_aut character varying(128),
    tp_integra integer,
    id_pag bigint,
    cnpj_receb character varying(14),
    id_term_pag character varying(40),
    id_card bigint NOT NULL
)
WITH (autovacuum_analyze_scale_factor='0.05', autovacuum_vacuum_scale_factor='0.03');


ALTER TABLE nfe.ya04_card OWNER TO planosassessoria;

--
-- TOC entry 2731 (class 1259 OID 586766584)
-- Name: ya04_card_id_seq; Type: SEQUENCE; Schema: nfe; Owner: planosassessoria
--

CREATE SEQUENCE nfe.ya04_card_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.ya04_card_id_seq OWNER TO planosassessoria;

--
-- TOC entry 11921 (class 0 OID 0)
-- Dependencies: 2731
-- Name: ya04_card_id_seq; Type: SEQUENCE OWNED BY; Schema: nfe; Owner: planosassessoria
--

ALTER SEQUENCE nfe.ya04_card_id_seq OWNED BY nfe.ya04_card.id_card;


--
-- TOC entry 1206 (class 1259 OID 11341208)
-- Name: z01_inf_adic; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.z01_inf_adic (
    id_nfe bigint NOT NULL,
    inf_ad_fisco character varying(2000),
    inf_cpl character varying(5000),
    id bigint
)
WITH (autovacuum_analyze_scale_factor='0.01', autovacuum_vacuum_scale_factor='0.003');


ALTER TABLE nfe.z01_inf_adic OWNER TO planosassessoria;

--
-- TOC entry 2363 (class 1259 OID 119797805)
-- Name: z04_obs_cont_id_seq; Type: SEQUENCE; Schema: nfe; Owner: operador
--

CREATE SEQUENCE nfe.z04_obs_cont_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.z04_obs_cont_id_seq OWNER TO operador;

--
-- TOC entry 1207 (class 1259 OID 11341216)
-- Name: z04_obs_cont; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.z04_obs_cont (
    id_nfe bigint NOT NULL,
    x_campo character varying(20),
    x_texto character varying(60),
    id_inf_adic bigint,
    id bigint DEFAULT nextval('nfe.z04_obs_cont_id_seq'::regclass) NOT NULL
);


ALTER TABLE nfe.z04_obs_cont OWNER TO planosassessoria;

--
-- TOC entry 2362 (class 1259 OID 119797292)
-- Name: z04_obs_cont_id_inf_adic_seq; Type: SEQUENCE; Schema: nfe; Owner: operador
--

CREATE SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq OWNER TO operador;

--
-- TOC entry 1208 (class 1259 OID 11341221)
-- Name: z07_obs_fisco; Type: TABLE; Schema: nfe; Owner: planosassessoria
--

CREATE TABLE nfe.z07_obs_fisco (
    id_nfe bigint NOT NULL,
    x_campo character varying(20),
    x_texto character varying(60),
    id_inf_adic bigint
);


ALTER TABLE nfe.z07_obs_fisco OWNER TO planosassessoria;

--
-- TOC entry 11362 (class 2604 OID 18137)
-- Name: c01_emit id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.c01_emit ALTER COLUMN id SET DEFAULT nextval('nfe.c01_emit_id_seq'::regclass);


--
-- TOC entry 11363 (class 2604 OID 18138)
-- Name: c05_ender_emit id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.c05_ender_emit ALTER COLUMN id SET DEFAULT nextval('nfe.c05_ender_emit_id_seq'::regclass);


--
-- TOC entry 11364 (class 2604 OID 18139)
-- Name: e01_dest id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.e01_dest ALTER COLUMN id SET DEFAULT nextval('nfe.e01_dest_id_seq'::regclass);


--
-- TOC entry 11365 (class 2604 OID 18140)
-- Name: e05_ender_dest id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.e05_ender_dest ALTER COLUMN id SET DEFAULT nextval('nfe.e05_ender_dest_id_seq'::regclass);


--
-- TOC entry 11366 (class 2604 OID 18141)
-- Name: i01_prod id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.i01_prod ALTER COLUMN id SET DEFAULT nextval('nfe.i01_prod_id_seq'::regclass);


--
-- TOC entry 11357 (class 2604 OID 18142)
-- Name: notas_ocultas id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.notas_ocultas ALTER COLUMN id SET DEFAULT nextval('nfe.notas_ocultas_id_seq'::regclass);


--
-- TOC entry 11375 (class 2604 OID 18143)
-- Name: p01_ii id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.p01_ii ALTER COLUMN id SET DEFAULT nextval('nfe.p01_ii_id_seq'::regclass);


--
-- TOC entry 11359 (class 2604 OID 18144)
-- Name: raiz_nfe id_nfe; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.raiz_nfe ALTER COLUMN id_nfe SET DEFAULT nextval('nfe.raiz_nfe_id_nfe_seq'::regclass);


--
-- TOC entry 11383 (class 2604 OID 169512280)
-- Name: role id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.role ALTER COLUMN id SET DEFAULT nextval('nfe.role_id_seq'::regclass);


--
-- TOC entry 11376 (class 2604 OID 18145)
-- Name: ua01_imposto_devol id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua01_imposto_devol ALTER COLUMN id SET DEFAULT nextval('nfe.ua01_imposto_devol_id_seq'::regclass);


--
-- TOC entry 11377 (class 2604 OID 18146)
-- Name: ua04_ipi id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua04_ipi ALTER COLUMN id SET DEFAULT nextval('nfe.ua04_ipi_id_seq'::regclass);


--
-- TOC entry 11386 (class 2604 OID 169512295)
-- Name: users id; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.users ALTER COLUMN id SET DEFAULT nextval('nfe.users_id_seq'::regclass);


--
-- TOC entry 11379 (class 2604 OID 586682687)
-- Name: ya01_pag id_pag; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ya01_pag ALTER COLUMN id_pag SET DEFAULT nextval('nfe.ya01_pag_id_seq'::regclass);


--
-- TOC entry 11380 (class 2604 OID 586766586)
-- Name: ya04_card id_card; Type: DEFAULT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ya04_card ALTER COLUMN id_card SET DEFAULT nextval('nfe.ya04_card_id_seq'::regclass);


--
-- TOC entry 11507 (class 2606 OID 169512302)
-- Name: users PK_a3ffb1c0c8416b9fc6f907b7433; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.users
    ADD CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY (id);


--
-- TOC entry 11503 (class 2606 OID 169512287)
-- Name: role PK_b36bcfe02fc8de3c57a8b2391c2; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.role
    ADD CONSTRAINT "PK_b36bcfe02fc8de3c57a8b2391c2" PRIMARY KEY (id);


--
-- TOC entry 11509 (class 2606 OID 169512306)
-- Name: users REL_a2cecd1a3531c0b041e29ba46e; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.users
    ADD CONSTRAINT "REL_a2cecd1a3531c0b041e29ba46e" UNIQUE (role_id);


--
-- TOC entry 11511 (class 2606 OID 169512304)
-- Name: users UQ_97672ac88f789774dd47f7c8be3; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.users
    ADD CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE (email);


--
-- TOC entry 11505 (class 2606 OID 169512289)
-- Name: role UQ_ae4578dcaed5adff96595e61660; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.role
    ADD CONSTRAINT "UQ_ae4578dcaed5adff96595e61660" UNIQUE (name);


--
-- TOC entry 11417 (class 2606 OID 19039)
-- Name: b01_ide b01_ide_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.b01_ide
    ADD CONSTRAINT b01_ide_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11495 (class 2606 OID 19040)
-- Name: b12a_nf_ref b12a_nf_ref_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.b12a_nf_ref
    ADD CONSTRAINT b12a_nf_ref_pkey PRIMARY KEY (id);


--
-- TOC entry 11422 (class 2606 OID 19041)
-- Name: c01_emit c01_emit_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.c01_emit
    ADD CONSTRAINT c01_emit_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11425 (class 2606 OID 19042)
-- Name: c05_ender_emit c05_ender_emit_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.c05_ender_emit
    ADD CONSTRAINT c05_ender_emit_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11427 (class 2606 OID 19043)
-- Name: cofins_filhos cofins_filhos_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.cofins_filhos
    ADD CONSTRAINT cofins_filhos_pkey PRIMARY KEY (id_nfe, id_prod);


--
-- TOC entry 11501 (class 2606 OID 19044)
-- Name: contingencia contingencia_pkey; Type: CONSTRAINT; Schema: nfe; Owner: operador
--

ALTER TABLE ONLY nfe.contingencia
    ADD CONSTRAINT contingencia_pkey PRIMARY KEY (cpf_cnpj, n_nf, serie, mod);

ALTER TABLE nfe.contingencia CLUSTER ON contingencia_pkey;


--
-- TOC entry 11429 (class 2606 OID 19045)
-- Name: d01_avulsa d01_avulsa_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.d01_avulsa
    ADD CONSTRAINT d01_avulsa_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11432 (class 2606 OID 19046)
-- Name: e01_dest e01_dest_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.e01_dest
    ADD CONSTRAINT e01_dest_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11435 (class 2606 OID 19047)
-- Name: e05_ender_dest e05_ender_dest_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.e05_ender_dest
    ADD CONSTRAINT e05_ender_dest_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11515 (class 2606 OID 549717745)
-- Name: guia_icms_st guia_icms_st_pkey; Type: CONSTRAINT; Schema: nfe; Owner: celismar
--

ALTER TABLE ONLY nfe.guia_icms_st
    ADD CONSTRAINT guia_icms_st_pkey PRIMARY KEY (dest_cpf_cnpj, cpf_cnpj, n_nf, serie, mod, inf_nfe);


--
-- TOC entry 11445 (class 2606 OID 19048)
-- Name: i01_prod i01_prod_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.i01_prod
    ADD CONSTRAINT i01_prod_pkey PRIMARY KEY (id);


--
-- TOC entry 11450 (class 2606 OID 19049)
-- Name: ipi_filhos ipi_filhos_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ipi_filhos
    ADD CONSTRAINT ipi_filhos_pkey PRIMARY KEY (id_nfe, id_prod);


--
-- TOC entry 11453 (class 2606 OID 19050)
-- Name: m01_imposto m01_imposto_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.m01_imposto
    ADD CONSTRAINT m01_imposto_pkey PRIMARY KEY (id_nfe, id_prod);


--
-- TOC entry 11456 (class 2606 OID 19051)
-- Name: na01_icms_uf_dest na01_icms_uf_dest_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.na01_icms_uf_dest
    ADD CONSTRAINT na01_icms_uf_dest_pkey PRIMARY KEY (id_nfe, id_prod);


--
-- TOC entry 11466 (class 2606 OID 19052)
-- Name: p01_ii p01_ii_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.p01_ii
    ADD CONSTRAINT p01_ii_pkey PRIMARY KEY (id_nfe, id_prod);


--
-- TOC entry 11469 (class 2606 OID 19053)
-- Name: pr03_inf_prot pr03_inf_prot_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.pr03_inf_prot
    ADD CONSTRAINT pr03_inf_prot_pkey PRIMARY KEY (id_nfe, c_stat);


--
-- TOC entry 11407 (class 2606 OID 19054)
-- Name: raiz_nfe raiz_nfe_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.raiz_nfe
    ADD CONSTRAINT raiz_nfe_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11473 (class 2606 OID 19055)
-- Name: ua01_imposto_devol ua01_imposto_devol_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua01_imposto_devol
    ADD CONSTRAINT ua01_imposto_devol_pkey PRIMARY KEY (id);


--
-- TOC entry 11477 (class 2606 OID 19056)
-- Name: ua04_ipi ua04_ipi_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua04_ipi
    ADD CONSTRAINT ua04_ipi_pkey PRIMARY KEY (id);


--
-- TOC entry 11519 (class 2606 OID 577427599)
-- Name: ub01_is ub01_is_pkey; Type: CONSTRAINT; Schema: nfe; Owner: dorcilio
--

ALTER TABLE ONLY nfe.ub01_is
    ADD CONSTRAINT ub01_is_pkey PRIMARY KEY (id_ub01_is);


--
-- TOC entry 11524 (class 2606 OID 578421859)
-- Name: ub12_ibs_cbs ub12_ibs_cbs_pkey; Type: CONSTRAINT; Schema: nfe; Owner: dorcilio
--

ALTER TABLE ONLY nfe.ub12_ibs_cbs
    ADD CONSTRAINT ub12_ibs_cbs_pkey PRIMARY KEY (id_ub12_ibs_cbs);


--
-- TOC entry 11413 (class 2606 OID 19057)
-- Name: raiz_nfe unica_nota; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.raiz_nfe
    ADD CONSTRAINT unica_nota UNIQUE (cpf_cnpj, n_nf, serie, mod);


--
-- TOC entry 11458 (class 2606 OID 19058)
-- Name: w02_icms_tot w02_icms_tot_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.w02_icms_tot
    ADD CONSTRAINT w02_icms_tot_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11460 (class 2606 OID 19059)
-- Name: w17_issqn_tot w17_issqn_tot_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.w17_issqn_tot
    ADD CONSTRAINT w17_issqn_tot_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11462 (class 2606 OID 19060)
-- Name: w23_ret_trib w23_ret_trib_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.w23_ret_trib
    ADD CONSTRAINT w23_ret_trib_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11499 (class 2606 OID 19061)
-- Name: web_services web_services_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.web_services
    ADD CONSTRAINT web_services_pkey PRIMARY KEY (servico, versao, tp_amb, codg_estado);


--
-- TOC entry 11513 (class 2606 OID 287363055)
-- Name: xml_faltante xml_faltante_pkey; Type: CONSTRAINT; Schema: nfe; Owner: celismar
--

ALTER TABLE ONLY nfe.xml_faltante
    ADD CONSTRAINT xml_faltante_pkey PRIMARY KEY (cpf_cnpj, chv_nfe);


--
-- TOC entry 11479 (class 2606 OID 19062)
-- Name: y07_dup y07_dup_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.y07_dup
    ADD CONSTRAINT y07_dup_pkey PRIMARY KEY (id_nfe, id_dup);


--
-- TOC entry 11482 (class 2606 OID 586682689)
-- Name: ya01_pag ya01_pag_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ya01_pag
    ADD CONSTRAINT ya01_pag_pkey PRIMARY KEY (id_pag);


--
-- TOC entry 11486 (class 2606 OID 586767365)
-- Name: ya04_card ya04_card_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ya04_card
    ADD CONSTRAINT ya04_card_pkey PRIMARY KEY (id_card);


--
-- TOC entry 11488 (class 2606 OID 19065)
-- Name: z01_inf_adic z01_inf_adic_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.z01_inf_adic
    ADD CONSTRAINT z01_inf_adic_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11490 (class 2606 OID 119797821)
-- Name: z04_obs_cont z04_obs_cont_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.z04_obs_cont
    ADD CONSTRAINT z04_obs_cont_pkey PRIMARY KEY (id_nfe, id);


--
-- TOC entry 11492 (class 2606 OID 19067)
-- Name: z07_obs_fisco z07_obs_fisco_pkey; Type: CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.z07_obs_fisco
    ADD CONSTRAINT z07_obs_fisco_pkey PRIMARY KEY (id_nfe);


--
-- TOC entry 11414 (class 1259 OID 112651234)
-- Name: b01_ide_id_nfe_d_emi_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX b01_ide_id_nfe_d_emi_idx ON nfe.b01_ide USING btree (id_nfe, d_emi);


--
-- TOC entry 11415 (class 1259 OID 112651235)
-- Name: b01_ide_n_nf_serie_mod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX b01_ide_n_nf_serie_mod_idx ON nfe.b01_ide USING btree (n_nf, serie, mod);


--
-- TOC entry 11493 (class 1259 OID 112651245)
-- Name: b12a_nf_ref_id_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX b12a_nf_ref_id_nfe_idx ON nfe.b12a_nf_ref USING btree (id_nfe);


--
-- TOC entry 11496 (class 1259 OID 165549945)
-- Name: b12a_nf_ref_ref_cte_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX b12a_nf_ref_ref_cte_idx ON nfe.b12a_nf_ref USING btree (ref_cte);


--
-- TOC entry 11497 (class 1259 OID 165549944)
-- Name: b12a_nf_ref_ref_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX b12a_nf_ref_ref_nfe_idx ON nfe.b12a_nf_ref USING btree (ref_nfe);


--
-- TOC entry 11418 (class 1259 OID 112651254)
-- Name: c01_emit_cpf_cnpj_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX c01_emit_cpf_cnpj_idx ON nfe.c01_emit USING btree (cpf_cnpj);


--
-- TOC entry 11419 (class 1259 OID 112651253)
-- Name: c01_emit_cpf_cnpj_ie_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX c01_emit_cpf_cnpj_ie_idx ON nfe.c01_emit USING btree (cpf_cnpj, ie);


--
-- TOC entry 11420 (class 1259 OID 112651255)
-- Name: c01_emit_ie_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX c01_emit_ie_idx ON nfe.c01_emit USING btree (ie);


--
-- TOC entry 11423 (class 1259 OID 586272170)
-- Name: c05_ender_emit_id_nfe_id_emit_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX c05_ender_emit_id_nfe_id_emit_idx ON nfe.c05_ender_emit USING btree (id_nfe, id_emit);


--
-- TOC entry 11430 (class 1259 OID 112651289)
-- Name: e01_dest_id_nfe_cpf_cnpj_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX e01_dest_id_nfe_cpf_cnpj_idx ON nfe.e01_dest USING btree (id_nfe, cpf_cnpj);


--
-- TOC entry 11433 (class 1259 OID 586272171)
-- Name: e05_ender_dest_id_nfe_id_dest_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX e05_ender_dest_id_nfe_id_dest_idx ON nfe.e05_ender_dest USING btree (id_nfe, id_dest);


--
-- TOC entry 11436 (class 1259 OID 112651307)
-- Name: i01_prod_c_prod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_c_prod_idx ON nfe.i01_prod USING btree (c_prod);


--
-- TOC entry 11437 (class 1259 OID 112651308)
-- Name: i01_prod_cfop_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_cfop_idx ON nfe.i01_prod USING btree (cfop);


--
-- TOC entry 11438 (class 1259 OID 112651304)
-- Name: i01_prod_cpf_cnpj_d_emi_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_cpf_cnpj_d_emi_idx ON nfe.i01_prod USING btree (cpf_cnpj, d_emi);


--
-- TOC entry 11439 (class 1259 OID 112651305)
-- Name: i01_prod_cpf_cnpj_n_nf_serie_mod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_cpf_cnpj_n_nf_serie_mod_idx ON nfe.i01_prod USING btree (cpf_cnpj, n_nf, serie, mod);


--
-- TOC entry 11440 (class 1259 OID 112651309)
-- Name: i01_prod_id_nfe_c_prod_x_prod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_id_nfe_c_prod_x_prod_idx ON nfe.i01_prod USING btree (id_nfe, c_prod, x_prod);


--
-- TOC entry 11441 (class 1259 OID 112651306)
-- Name: i01_prod_id_nfe_d_emi_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_id_nfe_d_emi_idx ON nfe.i01_prod USING btree (id_nfe, d_emi);


--
-- TOC entry 11442 (class 1259 OID 112651310)
-- Name: i01_prod_id_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_id_nfe_idx ON nfe.i01_prod USING btree (id_nfe);


--
-- TOC entry 11443 (class 1259 OID 112651311)
-- Name: i01_prod_n_item_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_n_item_idx ON nfe.i01_prod USING btree (n_item);


--
-- TOC entry 11446 (class 1259 OID 112651312)
-- Name: i01_prod_vetorfts_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_vetorfts_idx ON nfe.i01_prod USING gin (vetorfts);


--
-- TOC entry 11447 (class 1259 OID 112651313)
-- Name: i01_prod_x_prod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX i01_prod_x_prod_idx ON nfe.i01_prod USING btree (x_prod);


--
-- TOC entry 11448 (class 1259 OID 112659639)
-- Name: icms_filhos_id_nfe_id_prod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX icms_filhos_id_nfe_id_prod_idx ON nfe.icms_filhos USING btree (id_nfe, id_prod);


--
-- TOC entry 11516 (class 1259 OID 577428518)
-- Name: idx_id_i01_prod_on_ub01_is; Type: INDEX; Schema: nfe; Owner: dorcilio
--

CREATE INDEX idx_id_i01_prod_on_ub01_is ON nfe.ub01_is USING btree (id_i01_prod);


--
-- TOC entry 11520 (class 1259 OID 578421871)
-- Name: idx_id_i01_prod_on_ub12_ibs_cbs; Type: INDEX; Schema: nfe; Owner: dorcilio
--

CREATE INDEX idx_id_i01_prod_on_ub12_ibs_cbs ON nfe.ub12_ibs_cbs USING btree (id_i01_prod);


--
-- TOC entry 11521 (class 1259 OID 596241485)
-- Name: idx_id_nfe_i01_prod_on_ub12_ibs_cbs; Type: INDEX; Schema: nfe; Owner: dorcilio
--

CREATE INDEX idx_id_nfe_i01_prod_on_ub12_ibs_cbs ON nfe.ub12_ibs_cbs USING btree (id_nfe, id_i01_prod);


--
-- TOC entry 11517 (class 1259 OID 577428516)
-- Name: idx_id_nfe_on_ub01_is; Type: INDEX; Schema: nfe; Owner: dorcilio
--

CREATE INDEX idx_id_nfe_on_ub01_is ON nfe.ub01_is USING btree (id_nfe);


--
-- TOC entry 11522 (class 1259 OID 578421870)
-- Name: idx_id_nfe_on_ub12_ibs_cbs; Type: INDEX; Schema: nfe; Owner: dorcilio
--

CREATE INDEX idx_id_nfe_on_ub12_ibs_cbs ON nfe.ub12_ibs_cbs USING btree (id_nfe);


--
-- TOC entry 11451 (class 1259 OID 590196243)
-- Name: idx_id_prod_on_m01_imposto; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_id_prod_on_m01_imposto ON nfe.m01_imposto USING btree (id_prod);


--
-- TOC entry 11454 (class 1259 OID 590201774)
-- Name: idx_id_prod_on_na01_icms_uf_dest; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_id_prod_on_na01_icms_uf_dest ON nfe.na01_icms_uf_dest USING btree (id_prod);


--
-- TOC entry 11464 (class 1259 OID 590206604)
-- Name: idx_id_prod_on_p01_ii; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_id_prod_on_p01_ii ON nfe.p01_ii USING btree (id_prod);


--
-- TOC entry 11390 (class 1259 OID 596318145)
-- Name: idx_inf_nfe_id_nfe_on_raiz_nfe; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_inf_nfe_id_nfe_on_raiz_nfe ON nfe.raiz_nfe USING btree (inf_nfe) INCLUDE (id_nfe);


--
-- TOC entry 11391 (class 1259 OID 165549943)
-- Name: idx_nfe_raiz_nfe_cnpj_chave_n_nf_ser_mod; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_nfe_raiz_nfe_cnpj_chave_n_nf_ser_mod ON nfe.raiz_nfe USING btree (cnpj_chave, n_nf, ser, mod);


--
-- TOC entry 11392 (class 1259 OID 526394966)
-- Name: idx_nfe_raiz_nfe_cpf_cnpj_n_nf_inf_nfe; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_nfe_raiz_nfe_cpf_cnpj_n_nf_inf_nfe ON nfe.raiz_nfe USING btree (cpf_cnpj, n_nf, "substring"((inf_nfe)::text, 1, 34));


--
-- TOC entry 11393 (class 1259 OID 118943971)
-- Name: idx_nfe_raiz_nfe_dest_cpf_cnpj_cpf_cnpj_n_nf_ser_mod; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_nfe_raiz_nfe_dest_cpf_cnpj_cpf_cnpj_n_nf_ser_mod ON nfe.raiz_nfe USING btree (dest_cpf_cnpj, cpf_cnpj, n_nf, ser, mod);


--
-- TOC entry 11394 (class 1259 OID 350736861)
-- Name: idx_nfe_raiz_nfe_n_nf_inf_nfe; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_nfe_raiz_nfe_n_nf_inf_nfe ON nfe.raiz_nfe USING btree (n_nf, inf_nfe);


--
-- TOC entry 11480 (class 1259 OID 586682711)
-- Name: idx_ya01_pag_id_nfe; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_ya01_pag_id_nfe ON nfe.ya01_pag USING btree (id_nfe);


--
-- TOC entry 11483 (class 1259 OID 586767449)
-- Name: idx_ya04_card_id_nfe; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_ya04_card_id_nfe ON nfe.ya04_card USING btree (id_nfe);


--
-- TOC entry 11484 (class 1259 OID 586767653)
-- Name: idx_ya04_card_id_pag; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX idx_ya04_card_id_pag ON nfe.ya04_card USING btree (id_pag);


--
-- TOC entry 11463 (class 1259 OID 112659638)
-- Name: pis_filhos_id_nfe_id_prod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX pis_filhos_id_nfe_id_prod_idx ON nfe.pis_filhos USING btree (id_nfe, id_prod);


--
-- TOC entry 11467 (class 1259 OID 290004408)
-- Name: pr03_inf_prot_id_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX pr03_inf_prot_id_nfe_idx ON nfe.pr03_inf_prot USING btree (id_nfe);


--
-- TOC entry 11395 (class 1259 OID 114376568)
-- Name: raiz_nfe_ch_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_ch_nfe_idx ON nfe.raiz_nfe USING btree (ch_nfe);


--
-- TOC entry 11396 (class 1259 OID 112644253)
-- Name: raiz_nfe_cnpj_chave_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_cnpj_chave_idx ON nfe.raiz_nfe USING btree (cnpj_chave);


--
-- TOC entry 11397 (class 1259 OID 112644565)
-- Name: raiz_nfe_cpf_cnpj_d_emi_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_cpf_cnpj_d_emi_idx ON nfe.raiz_nfe USING btree (cpf_cnpj, d_emi);


--
-- TOC entry 11398 (class 1259 OID 112644329)
-- Name: raiz_nfe_cpf_cnpj_n_nf_ser_mod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_cpf_cnpj_n_nf_ser_mod_idx ON nfe.raiz_nfe USING btree (cpf_cnpj, n_nf, ser, mod);


--
-- TOC entry 11399 (class 1259 OID 112644331)
-- Name: raiz_nfe_d_emi_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_d_emi_idx ON nfe.raiz_nfe USING btree (d_emi);


--
-- TOC entry 11400 (class 1259 OID 144370502)
-- Name: raiz_nfe_d_emi_idx1; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_d_emi_idx1 ON nfe.raiz_nfe USING btree (d_emi) WHERE (d_emi > '2019-12-31'::date);


--
-- TOC entry 11401 (class 1259 OID 112644566)
-- Name: raiz_nfe_dest_cpf_cnpj_cnpj_chave_n_nf_serie_mod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_dest_cpf_cnpj_cnpj_chave_n_nf_serie_mod_idx ON nfe.raiz_nfe USING btree (dest_cpf_cnpj, cnpj_chave, n_nf, serie, mod);


--
-- TOC entry 11402 (class 1259 OID 112659640)
-- Name: raiz_nfe_dest_cpf_cnpj_d_emi_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_dest_cpf_cnpj_d_emi_idx ON nfe.raiz_nfe USING btree (dest_cpf_cnpj, d_emi);


--
-- TOC entry 11403 (class 1259 OID 112644332)
-- Name: raiz_nfe_dest_cpf_cnpj_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_dest_cpf_cnpj_idx ON nfe.raiz_nfe USING btree (dest_cpf_cnpj);


--
-- TOC entry 11404 (class 1259 OID 112644333)
-- Name: raiz_nfe_inf_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_inf_nfe_idx ON nfe.raiz_nfe USING btree (inf_nfe);


--
-- TOC entry 11405 (class 1259 OID 112644497)
-- Name: raiz_nfe_pesquisa_fts_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_pesquisa_fts_idx ON nfe.raiz_nfe USING gin (pesquisa_fts);


--
-- TOC entry 11408 (class 1259 OID 112644564)
-- Name: raiz_nfe_serie_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_serie_idx ON nfe.raiz_nfe USING btree (((serie)::character varying(3)));


--
-- TOC entry 11409 (class 1259 OID 352468878)
-- Name: raiz_nfe_substring_chv_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_substring_chv_idx ON nfe.raiz_nfe USING btree ("substring"((inf_nfe)::text, 1, 34));


--
-- TOC entry 11410 (class 1259 OID 112644228)
-- Name: raiz_nfe_substring_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_substring_idx ON nfe.raiz_nfe USING btree ("substring"((inf_nfe)::text, 3, 4));


--
-- TOC entry 11411 (class 1259 OID 533342818)
-- Name: raiz_nfe_xml_id_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX raiz_nfe_xml_id_idx ON nfe.raiz_nfe USING btree (xml_id);


--
-- TOC entry 11470 (class 1259 OID 112659486)
-- Name: ua01_imposto_devol_id_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX ua01_imposto_devol_id_nfe_idx ON nfe.ua01_imposto_devol USING btree (id_nfe);


--
-- TOC entry 11471 (class 1259 OID 112659487)
-- Name: ua01_imposto_devol_id_prod_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX ua01_imposto_devol_id_prod_idx ON nfe.ua01_imposto_devol USING btree (id_prod);


--
-- TOC entry 11474 (class 1259 OID 112659489)
-- Name: ua04_ipi_id_imposto_devol_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX ua04_ipi_id_imposto_devol_idx ON nfe.ua04_ipi USING btree (id_imposto_devol);


--
-- TOC entry 11475 (class 1259 OID 112659488)
-- Name: ua04_ipi_id_nfe_idx; Type: INDEX; Schema: nfe; Owner: planosassessoria
--

CREATE INDEX ua04_ipi_id_nfe_idx ON nfe.ua04_ipi USING btree (id_nfe);


--
-- TOC entry 11564 (class 2620 OID 19613)
-- Name: raiz_nfe insere_cnpj_chave_on_raiz_nfe; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insere_cnpj_chave_on_raiz_nfe BEFORE INSERT OR UPDATE ON nfe.raiz_nfe FOR EACH ROW EXECUTE FUNCTION nfe.insere_cnpj_chave();


--
-- TOC entry 11568 (class 2620 OID 19614)
-- Name: c01_emit insere_cpf_cnpj; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insere_cpf_cnpj BEFORE INSERT ON nfe.c01_emit FOR EACH ROW EXECUTE FUNCTION nfe.insere_cpf_cnpj();


--
-- TOC entry 11570 (class 2620 OID 19615)
-- Name: e01_dest insere_cpf_cnpj; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insere_cpf_cnpj BEFORE INSERT ON nfe.e01_dest FOR EACH ROW EXECUTE FUNCTION nfe.insere_cpf_cnpj();


--
-- TOC entry 11565 (class 2620 OID 19616)
-- Name: raiz_nfe insere_pesquisa_fts; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insere_pesquisa_fts BEFORE INSERT OR UPDATE ON nfe.raiz_nfe FOR EACH ROW EXECUTE FUNCTION nfe.insere_pesquisa_fts();


--
-- TOC entry 11566 (class 2620 OID 19617)
-- Name: raiz_nfe insere_ser_on_raiz_nfe; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insere_ser_on_raiz_nfe BEFORE INSERT OR UPDATE ON nfe.raiz_nfe FOR EACH ROW EXECUTE FUNCTION nfe.insere_ser_on_raiz_nfe();


--
-- TOC entry 11572 (class 2620 OID 19618)
-- Name: i01_prod insere_vetorfts_on_i01_prod; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insere_vetorfts_on_i01_prod BEFORE INSERT OR UPDATE ON nfe.i01_prod FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('vetorfts', 'pg_catalog.portuguese', 'c_prod', 'x_prod');


--
-- TOC entry 11569 (class 2620 OID 19619)
-- Name: c01_emit insert_pesquisa_fts_on_c01_emit; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insert_pesquisa_fts_on_c01_emit BEFORE INSERT OR UPDATE ON nfe.c01_emit FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('pesquisa_fts', 'pg_catalog.portuguese', 'cpf_cnpj', 'x_nome', 'x_fant');


--
-- TOC entry 11571 (class 2620 OID 19620)
-- Name: e01_dest insert_pesquisa_fts_on_e01_dest; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER insert_pesquisa_fts_on_e01_dest BEFORE INSERT OR UPDATE ON nfe.e01_dest FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('pesquisa_fts', 'pg_catalog.portuguese', 'cpf_cnpj', 'x_nome');


--
-- TOC entry 11567 (class 2620 OID 513708597)
-- Name: b01_ide replica_data_em_b01_ide; Type: TRIGGER; Schema: nfe; Owner: planosassessoria
--

CREATE TRIGGER replica_data_em_b01_ide BEFORE INSERT ON nfe.b01_ide FOR EACH ROW EXECUTE FUNCTION nfe.replica_data_nfe_3_10();


--
-- TOC entry 11559 (class 2606 OID 169512307)
-- Name: users FK_a2cecd1a3531c0b041e29ba46e1; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.users
    ADD CONSTRAINT "FK_a2cecd1a3531c0b041e29ba46e1" FOREIGN KEY (role_id) REFERENCES nfe.role(id);


--
-- TOC entry 11525 (class 2606 OID 22197)
-- Name: b01_ide b01_ide_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.b01_ide
    ADD CONSTRAINT b01_ide_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11557 (class 2606 OID 22202)
-- Name: b12a_nf_ref b12a_nf_ref_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.b12a_nf_ref
    ADD CONSTRAINT b12a_nf_ref_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11526 (class 2606 OID 22207)
-- Name: c01_emit c01_emit_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.c01_emit
    ADD CONSTRAINT c01_emit_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11527 (class 2606 OID 22212)
-- Name: c05_ender_emit c05_ender_emit_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.c05_ender_emit
    ADD CONSTRAINT c05_ender_emit_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11528 (class 2606 OID 22217)
-- Name: cofins_filhos cofins_filhos_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.cofins_filhos
    ADD CONSTRAINT cofins_filhos_id_nfe_fkey FOREIGN KEY (id_nfe, id_prod) REFERENCES nfe.m01_imposto(id_nfe, id_prod) ON DELETE CASCADE;


--
-- TOC entry 11529 (class 2606 OID 22222)
-- Name: d01_avulsa d01_avulsa_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.d01_avulsa
    ADD CONSTRAINT d01_avulsa_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11530 (class 2606 OID 22227)
-- Name: e01_dest e01_dest_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.e01_dest
    ADD CONSTRAINT e01_dest_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11531 (class 2606 OID 22232)
-- Name: e05_ender_dest e05_ender_dest_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.e05_ender_dest
    ADD CONSTRAINT e05_ender_dest_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11532 (class 2606 OID 22237)
-- Name: i01_prod i01_prod_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.i01_prod
    ADD CONSTRAINT i01_prod_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11533 (class 2606 OID 22242)
-- Name: icms_filhos icms_filhos_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.icms_filhos
    ADD CONSTRAINT icms_filhos_id_nfe_fkey FOREIGN KEY (id_nfe, id_prod) REFERENCES nfe.m01_imposto(id_nfe, id_prod) ON DELETE CASCADE;


--
-- TOC entry 11534 (class 2606 OID 22247)
-- Name: ipi_filhos ipi_filhos_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ipi_filhos
    ADD CONSTRAINT ipi_filhos_id_nfe_fkey FOREIGN KEY (id_nfe, id_prod) REFERENCES nfe.m01_imposto(id_nfe, id_prod) ON DELETE CASCADE;


--
-- TOC entry 11535 (class 2606 OID 22252)
-- Name: m01_imposto m01_imposto_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.m01_imposto
    ADD CONSTRAINT m01_imposto_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11536 (class 2606 OID 22257)
-- Name: m01_imposto m01_imposto_id_prod_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.m01_imposto
    ADD CONSTRAINT m01_imposto_id_prod_fkey FOREIGN KEY (id_prod) REFERENCES nfe.i01_prod(id) ON DELETE CASCADE;


--
-- TOC entry 11537 (class 2606 OID 22262)
-- Name: na01_icms_uf_dest na01_icms_uf_dest_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.na01_icms_uf_dest
    ADD CONSTRAINT na01_icms_uf_dest_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11538 (class 2606 OID 22267)
-- Name: na01_icms_uf_dest na01_icms_uf_dest_id_nfe_fkey1; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.na01_icms_uf_dest
    ADD CONSTRAINT na01_icms_uf_dest_id_nfe_fkey1 FOREIGN KEY (id_nfe, id_prod) REFERENCES nfe.m01_imposto(id_nfe, id_prod) ON DELETE CASCADE;


--
-- TOC entry 11539 (class 2606 OID 22272)
-- Name: na01_icms_uf_dest na01_icms_uf_dest_id_prod_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.na01_icms_uf_dest
    ADD CONSTRAINT na01_icms_uf_dest_id_prod_fkey FOREIGN KEY (id_prod) REFERENCES nfe.i01_prod(id) ON DELETE CASCADE;


--
-- TOC entry 11544 (class 2606 OID 22277)
-- Name: p01_ii p01_ii_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.p01_ii
    ADD CONSTRAINT p01_ii_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11545 (class 2606 OID 22282)
-- Name: p01_ii p01_ii_id_prod_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.p01_ii
    ADD CONSTRAINT p01_ii_id_prod_fkey FOREIGN KEY (id_prod) REFERENCES nfe.i01_prod(id) ON DELETE CASCADE;


--
-- TOC entry 11543 (class 2606 OID 22287)
-- Name: pis_filhos pis_filhos_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.pis_filhos
    ADD CONSTRAINT pis_filhos_id_nfe_fkey FOREIGN KEY (id_nfe, id_prod) REFERENCES nfe.m01_imposto(id_nfe, id_prod) ON DELETE CASCADE;


--
-- TOC entry 11546 (class 2606 OID 22292)
-- Name: pr03_inf_prot pr03_inf_prot_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.pr03_inf_prot
    ADD CONSTRAINT pr03_inf_prot_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11547 (class 2606 OID 22297)
-- Name: ua01_imposto_devol ua01_imposto_devol_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua01_imposto_devol
    ADD CONSTRAINT ua01_imposto_devol_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11548 (class 2606 OID 22302)
-- Name: ua01_imposto_devol ua01_imposto_devol_id_prod_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua01_imposto_devol
    ADD CONSTRAINT ua01_imposto_devol_id_prod_fkey FOREIGN KEY (id_prod) REFERENCES nfe.i01_prod(id) ON DELETE CASCADE;


--
-- TOC entry 11549 (class 2606 OID 22307)
-- Name: ua04_ipi ua04_ipi_id_imposto_devol_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua04_ipi
    ADD CONSTRAINT ua04_ipi_id_imposto_devol_fkey FOREIGN KEY (id_imposto_devol) REFERENCES nfe.ua01_imposto_devol(id) ON DELETE CASCADE;


--
-- TOC entry 11550 (class 2606 OID 22312)
-- Name: ua04_ipi ua04_ipi_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ua04_ipi
    ADD CONSTRAINT ua04_ipi_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11560 (class 2606 OID 577427626)
-- Name: ub01_is ub01_is_id_i01_prod_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: dorcilio
--

ALTER TABLE ONLY nfe.ub01_is
    ADD CONSTRAINT ub01_is_id_i01_prod_fkey FOREIGN KEY (id_i01_prod) REFERENCES nfe.i01_prod(id) ON DELETE CASCADE;


--
-- TOC entry 11561 (class 2606 OID 577427621)
-- Name: ub01_is ub01_is_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: dorcilio
--

ALTER TABLE ONLY nfe.ub01_is
    ADD CONSTRAINT ub01_is_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11562 (class 2606 OID 578421865)
-- Name: ub12_ibs_cbs ub12_ibs_cbs_id_i01_prod_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: dorcilio
--

ALTER TABLE ONLY nfe.ub12_ibs_cbs
    ADD CONSTRAINT ub12_ibs_cbs_id_i01_prod_fkey FOREIGN KEY (id_i01_prod) REFERENCES nfe.i01_prod(id) ON DELETE CASCADE;


--
-- TOC entry 11563 (class 2606 OID 578421860)
-- Name: ub12_ibs_cbs ub12_ibs_cbs_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: dorcilio
--

ALTER TABLE ONLY nfe.ub12_ibs_cbs
    ADD CONSTRAINT ub12_ibs_cbs_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11540 (class 2606 OID 22317)
-- Name: w02_icms_tot w02_icms_tot_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.w02_icms_tot
    ADD CONSTRAINT w02_icms_tot_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11541 (class 2606 OID 22322)
-- Name: w17_issqn_tot w17_issqn_tot_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.w17_issqn_tot
    ADD CONSTRAINT w17_issqn_tot_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11542 (class 2606 OID 22327)
-- Name: w23_ret_trib w23_ret_trib_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.w23_ret_trib
    ADD CONSTRAINT w23_ret_trib_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11558 (class 2606 OID 22332)
-- Name: web_services web_services_codg_estado_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.web_services
    ADD CONSTRAINT web_services_codg_estado_fkey FOREIGN KEY (codg_estado) REFERENCES ncm_helper.cad_estados(codg_estado) ON DELETE CASCADE;


--
-- TOC entry 11551 (class 2606 OID 22337)
-- Name: y07_dup y07_dup_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.y07_dup
    ADD CONSTRAINT y07_dup_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11552 (class 2606 OID 22342)
-- Name: ya01_pag ya01_pag_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ya01_pag
    ADD CONSTRAINT ya01_pag_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11553 (class 2606 OID 22347)
-- Name: ya04_card ya04_card_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.ya04_card
    ADD CONSTRAINT ya04_card_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11554 (class 2606 OID 22352)
-- Name: z01_inf_adic z01_inf_adic_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.z01_inf_adic
    ADD CONSTRAINT z01_inf_adic_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11555 (class 2606 OID 22357)
-- Name: z04_obs_cont z04_obs_cont_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.z04_obs_cont
    ADD CONSTRAINT z04_obs_cont_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11556 (class 2606 OID 22362)
-- Name: z07_obs_fisco z07_obs_fisco_id_nfe_fkey; Type: FK CONSTRAINT; Schema: nfe; Owner: planosassessoria
--

ALTER TABLE ONLY nfe.z07_obs_fisco
    ADD CONSTRAINT z07_obs_fisco_id_nfe_fkey FOREIGN KEY (id_nfe) REFERENCES nfe.raiz_nfe(id_nfe) ON DELETE CASCADE;


--
-- TOC entry 11841 (class 0 OID 0)
-- Dependencies: 286
-- Name: SCHEMA nfe; Type: ACL; Schema: -; Owner: planosassessoria
--

GRANT USAGE ON SCHEMA nfe TO celismar;
GRANT USAGE ON SCHEMA nfe TO eder;
GRANT USAGE ON SCHEMA nfe TO cassio;
GRANT USAGE ON SCHEMA nfe TO ferretti;
GRANT USAGE ON SCHEMA nfe TO wesley;
GRANT USAGE ON SCHEMA nfe TO planosauditores;
GRANT USAGE ON SCHEMA nfe TO ermorais;
GRANT USAGE ON SCHEMA nfe TO ivanete;
GRANT USAGE ON SCHEMA nfe TO paula;
GRANT USAGE ON SCHEMA nfe TO irisneide;
GRANT USAGE ON SCHEMA nfe TO aliny;
GRANT USAGE ON SCHEMA nfe TO misael;
GRANT USAGE ON SCHEMA nfe TO ana;
GRANT USAGE ON SCHEMA nfe TO andrea;
GRANT USAGE ON SCHEMA nfe TO thais;
GRANT USAGE ON SCHEMA nfe TO adriano;
GRANT USAGE ON SCHEMA nfe TO kallita;
GRANT USAGE ON SCHEMA nfe TO igor;
GRANT USAGE ON SCHEMA nfe TO julia;
GRANT USAGE ON SCHEMA nfe TO consultor;
GRANT USAGE ON SCHEMA nfe TO vanessa;
GRANT USAGE ON SCHEMA nfe TO edinara;
GRANT USAGE ON SCHEMA nfe TO hellen;
GRANT USAGE ON SCHEMA nfe TO fiscalfacil;
GRANT USAGE ON SCHEMA nfe TO dorcilio;


--
-- TOC entry 11842 (class 0 OID 0)
-- Dependencies: 878
-- Name: TABLE notas_ocultas; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO celismar;
GRANT SELECT ON TABLE nfe.notas_ocultas TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO planosauditores;
GRANT SELECT ON TABLE nfe.notas_ocultas TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.notas_ocultas TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.notas_ocultas TO dorcilio;


--
-- TOC entry 11843 (class 0 OID 0)
-- Dependencies: 879
-- Name: TABLE raiz_nfe; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO celismar;
GRANT SELECT ON TABLE nfe.raiz_nfe TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO planosauditores;
GRANT SELECT ON TABLE nfe.raiz_nfe TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.raiz_nfe TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.raiz_nfe TO dorcilio;


--
-- TOC entry 11845 (class 0 OID 0)
-- Dependencies: 1172
-- Name: TABLE b01_ide; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO celismar;
GRANT SELECT ON TABLE nfe.b01_ide TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO planosauditores;
GRANT SELECT ON TABLE nfe.b01_ide TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.b01_ide TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b01_ide TO dorcilio;


--
-- TOC entry 11846 (class 0 OID 0)
-- Dependencies: 2192
-- Name: SEQUENCE b12a_nf_ref_id_seq; Type: ACL; Schema: nfe; Owner: operador
--

GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO planosauditores;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.b12a_nf_ref_id_seq TO dorcilio;


--
-- TOC entry 11847 (class 0 OID 0)
-- Dependencies: 2191
-- Name: TABLE b12a_nf_ref; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO ivanete;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO planosauditores;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.b12a_nf_ref TO dorcilio;


--
-- TOC entry 11848 (class 0 OID 0)
-- Dependencies: 1173
-- Name: TABLE c01_emit; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO celismar;
GRANT SELECT ON TABLE nfe.c01_emit TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO planosauditores;
GRANT SELECT ON TABLE nfe.c01_emit TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.c01_emit TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c01_emit TO dorcilio;


--
-- TOC entry 11850 (class 0 OID 0)
-- Dependencies: 1174
-- Name: SEQUENCE c01_emit_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.c01_emit_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.c01_emit_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.c01_emit_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.c01_emit_id_seq TO dorcilio;


--
-- TOC entry 11852 (class 0 OID 0)
-- Dependencies: 1175
-- Name: TABLE c05_ender_emit; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO celismar;
GRANT SELECT ON TABLE nfe.c05_ender_emit TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO planosauditores;
GRANT SELECT ON TABLE nfe.c05_ender_emit TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.c05_ender_emit TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.c05_ender_emit TO dorcilio;


--
-- TOC entry 11854 (class 0 OID 0)
-- Dependencies: 1176
-- Name: SEQUENCE c05_ender_emit_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.c05_ender_emit_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.c05_ender_emit_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.c05_ender_emit_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.c05_ender_emit_id_seq TO dorcilio;


--
-- TOC entry 11855 (class 0 OID 0)
-- Dependencies: 1177
-- Name: TABLE cofins_filhos; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO celismar;
GRANT SELECT ON TABLE nfe.cofins_filhos TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO planosauditores;
GRANT SELECT ON TABLE nfe.cofins_filhos TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.cofins_filhos TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.cofins_filhos TO dorcilio;


--
-- TOC entry 11856 (class 0 OID 0)
-- Dependencies: 2330
-- Name: TABLE contingencia; Type: ACL; Schema: nfe; Owner: operador
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO planosauditores;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.contingencia TO dorcilio;


--
-- TOC entry 11857 (class 0 OID 0)
-- Dependencies: 1178
-- Name: TABLE d01_avulsa; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO celismar;
GRANT SELECT ON TABLE nfe.d01_avulsa TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO planosauditores;
GRANT SELECT ON TABLE nfe.d01_avulsa TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.d01_avulsa TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.d01_avulsa TO dorcilio;


--
-- TOC entry 11858 (class 0 OID 0)
-- Dependencies: 1179
-- Name: TABLE e01_dest; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO celismar;
GRANT SELECT ON TABLE nfe.e01_dest TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO planosauditores;
GRANT SELECT ON TABLE nfe.e01_dest TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.e01_dest TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e01_dest TO dorcilio;


--
-- TOC entry 11860 (class 0 OID 0)
-- Dependencies: 1180
-- Name: SEQUENCE e01_dest_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.e01_dest_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.e01_dest_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.e01_dest_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.e01_dest_id_seq TO dorcilio;


--
-- TOC entry 11861 (class 0 OID 0)
-- Dependencies: 1181
-- Name: TABLE e05_ender_dest; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO celismar;
GRANT SELECT ON TABLE nfe.e05_ender_dest TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO planosauditores;
GRANT SELECT ON TABLE nfe.e05_ender_dest TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.e05_ender_dest TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.e05_ender_dest TO dorcilio;


--
-- TOC entry 11863 (class 0 OID 0)
-- Dependencies: 1182
-- Name: SEQUENCE e05_ender_dest_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.e05_ender_dest_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.e05_ender_dest_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.e05_ender_dest_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.e05_ender_dest_id_seq TO dorcilio;


--
-- TOC entry 11864 (class 0 OID 0)
-- Dependencies: 2669
-- Name: TABLE guia_icms_st; Type: ACL; Schema: nfe; Owner: celismar
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.guia_icms_st TO cassio;


--
-- TOC entry 11872 (class 0 OID 0)
-- Dependencies: 1183
-- Name: TABLE i01_prod; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO celismar;
GRANT SELECT ON TABLE nfe.i01_prod TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO planosauditores;
GRANT SELECT ON TABLE nfe.i01_prod TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.i01_prod TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.i01_prod TO dorcilio;


--
-- TOC entry 11874 (class 0 OID 0)
-- Dependencies: 1184
-- Name: SEQUENCE i01_prod_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.i01_prod_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.i01_prod_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.i01_prod_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.i01_prod_id_seq TO dorcilio;


--
-- TOC entry 11875 (class 0 OID 0)
-- Dependencies: 1185
-- Name: TABLE icms_filhos; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO celismar;
GRANT SELECT ON TABLE nfe.icms_filhos TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO planosauditores;
GRANT SELECT ON TABLE nfe.icms_filhos TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.icms_filhos TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.icms_filhos TO dorcilio;


--
-- TOC entry 11876 (class 0 OID 0)
-- Dependencies: 1186
-- Name: TABLE ipi_filhos; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO celismar;
GRANT SELECT ON TABLE nfe.ipi_filhos TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO planosauditores;
GRANT SELECT ON TABLE nfe.ipi_filhos TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.ipi_filhos TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ipi_filhos TO dorcilio;


--
-- TOC entry 11877 (class 0 OID 0)
-- Dependencies: 1187
-- Name: TABLE m01_imposto; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO celismar;
GRANT SELECT ON TABLE nfe.m01_imposto TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO planosauditores;
GRANT SELECT ON TABLE nfe.m01_imposto TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.m01_imposto TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.m01_imposto TO dorcilio;


--
-- TOC entry 11878 (class 0 OID 0)
-- Dependencies: 1188
-- Name: TABLE na01_icms_uf_dest; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO celismar;
GRANT SELECT ON TABLE nfe.na01_icms_uf_dest TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO planosauditores;
GRANT SELECT ON TABLE nfe.na01_icms_uf_dest TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.na01_icms_uf_dest TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.na01_icms_uf_dest TO dorcilio;


--
-- TOC entry 11879 (class 0 OID 0)
-- Dependencies: 1192
-- Name: TABLE nfe_devolucao_corrigida; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO celismar;
GRANT SELECT ON TABLE nfe.nfe_devolucao_corrigida TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO planosauditores;
GRANT SELECT ON TABLE nfe.nfe_devolucao_corrigida TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.nfe_devolucao_corrigida TO dorcilio;


--
-- TOC entry 11881 (class 0 OID 0)
-- Dependencies: 1194
-- Name: SEQUENCE notas_ocultas_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.notas_ocultas_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.notas_ocultas_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.notas_ocultas_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.notas_ocultas_id_seq TO dorcilio;


--
-- TOC entry 11882 (class 0 OID 0)
-- Dependencies: 1195
-- Name: TABLE p01_ii; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO celismar;
GRANT SELECT ON TABLE nfe.p01_ii TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO planosauditores;
GRANT SELECT ON TABLE nfe.p01_ii TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.p01_ii TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.p01_ii TO dorcilio;


--
-- TOC entry 11884 (class 0 OID 0)
-- Dependencies: 1196
-- Name: SEQUENCE p01_ii_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.p01_ii_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.p01_ii_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.p01_ii_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.p01_ii_id_seq TO dorcilio;


--
-- TOC entry 11885 (class 0 OID 0)
-- Dependencies: 1193
-- Name: TABLE pis_filhos; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO celismar;
GRANT SELECT ON TABLE nfe.pis_filhos TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO planosauditores;
GRANT SELECT ON TABLE nfe.pis_filhos TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.pis_filhos TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pis_filhos TO dorcilio;


--
-- TOC entry 11886 (class 0 OID 0)
-- Dependencies: 1197
-- Name: TABLE pr03_inf_prot; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO celismar;
GRANT SELECT ON TABLE nfe.pr03_inf_prot TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO planosauditores;
GRANT SELECT ON TABLE nfe.pr03_inf_prot TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.pr03_inf_prot TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.pr03_inf_prot TO dorcilio;


--
-- TOC entry 11888 (class 0 OID 0)
-- Dependencies: 1198
-- Name: SEQUENCE raiz_nfe_id_nfe_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO eder;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO paula;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO misael;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO ana;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO thais;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO igor;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO julia;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.raiz_nfe_id_nfe_seq TO dorcilio;


--
-- TOC entry 11889 (class 0 OID 0)
-- Dependencies: 2495
-- Name: TABLE reg_federal; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.reg_federal TO cassio;


--
-- TOC entry 11890 (class 0 OID 0)
-- Dependencies: 2394
-- Name: TABLE role; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.role TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.role TO dorcilio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.role TO cassio;


--
-- TOC entry 11892 (class 0 OID 0)
-- Dependencies: 2393
-- Name: SEQUENCE role_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT ALL ON SEQUENCE nfe.role_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.role_id_seq TO dorcilio;
GRANT SELECT,USAGE ON SEQUENCE nfe.role_id_seq TO cassio;


--
-- TOC entry 11893 (class 0 OID 0)
-- Dependencies: 1199
-- Name: TABLE ua01_imposto_devol; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO celismar;
GRANT SELECT ON TABLE nfe.ua01_imposto_devol TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO planosauditores;
GRANT SELECT ON TABLE nfe.ua01_imposto_devol TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.ua01_imposto_devol TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua01_imposto_devol TO dorcilio;


--
-- TOC entry 11895 (class 0 OID 0)
-- Dependencies: 1200
-- Name: SEQUENCE ua01_imposto_devol_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.ua01_imposto_devol_id_seq TO dorcilio;


--
-- TOC entry 11896 (class 0 OID 0)
-- Dependencies: 1201
-- Name: TABLE ua04_ipi; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO celismar;
GRANT SELECT ON TABLE nfe.ua04_ipi TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO planosauditores;
GRANT SELECT ON TABLE nfe.ua04_ipi TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.ua04_ipi TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ua04_ipi TO dorcilio;


--
-- TOC entry 11898 (class 0 OID 0)
-- Dependencies: 1202
-- Name: SEQUENCE ua04_ipi_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT USAGE ON SEQUENCE nfe.ua04_ipi_id_seq TO celismar;
GRANT USAGE ON SEQUENCE nfe.ua04_ipi_id_seq TO eder;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO ferretti;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO planosauditores;
GRANT USAGE ON SEQUENCE nfe.ua04_ipi_id_seq TO ermorais;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO paula;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO misael;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO aliny;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO ana;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO thais;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO igor;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO julia;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.ua04_ipi_id_seq TO dorcilio;


--
-- TOC entry 11899 (class 0 OID 0)
-- Dependencies: 2714
-- Name: TABLE ub01_is; Type: ACL; Schema: nfe; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ub01_is TO cassio;


--
-- TOC entry 11900 (class 0 OID 0)
-- Dependencies: 2713
-- Name: SEQUENCE ub01_is_id_ub01_is_seq; Type: ACL; Schema: nfe; Owner: dorcilio
--

GRANT SELECT,USAGE ON SEQUENCE nfe.ub01_is_id_ub01_is_seq TO cassio;


--
-- TOC entry 11901 (class 0 OID 0)
-- Dependencies: 2716
-- Name: TABLE ub12_ibs_cbs; Type: ACL; Schema: nfe; Owner: dorcilio
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ub12_ibs_cbs TO cassio;


--
-- TOC entry 11902 (class 0 OID 0)
-- Dependencies: 2715
-- Name: SEQUENCE ub12_ibs_cbs_id_ub12_ibs_cbs_seq; Type: ACL; Schema: nfe; Owner: dorcilio
--

GRANT SELECT,USAGE ON SEQUENCE nfe.ub12_ibs_cbs_id_ub12_ibs_cbs_seq TO cassio;


--
-- TOC entry 11903 (class 0 OID 0)
-- Dependencies: 2396
-- Name: TABLE users; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.users TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.users TO dorcilio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.users TO cassio;


--
-- TOC entry 11905 (class 0 OID 0)
-- Dependencies: 2395
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT ALL ON SEQUENCE nfe.users_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.users_id_seq TO dorcilio;
GRANT SELECT,USAGE ON SEQUENCE nfe.users_id_seq TO cassio;


--
-- TOC entry 11910 (class 0 OID 0)
-- Dependencies: 1189
-- Name: TABLE w02_icms_tot; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO celismar;
GRANT SELECT ON TABLE nfe.w02_icms_tot TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO planosauditores;
GRANT SELECT ON TABLE nfe.w02_icms_tot TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.w02_icms_tot TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w02_icms_tot TO dorcilio;


--
-- TOC entry 11911 (class 0 OID 0)
-- Dependencies: 1190
-- Name: TABLE w17_issqn_tot; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO celismar;
GRANT SELECT ON TABLE nfe.w17_issqn_tot TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO planosauditores;
GRANT SELECT ON TABLE nfe.w17_issqn_tot TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.w17_issqn_tot TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w17_issqn_tot TO dorcilio;


--
-- TOC entry 11912 (class 0 OID 0)
-- Dependencies: 1191
-- Name: TABLE w23_ret_trib; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO celismar;
GRANT SELECT ON TABLE nfe.w23_ret_trib TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO planosauditores;
GRANT SELECT ON TABLE nfe.w23_ret_trib TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.w23_ret_trib TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.w23_ret_trib TO dorcilio;


--
-- TOC entry 11913 (class 0 OID 0)
-- Dependencies: 2200
-- Name: TABLE web_services; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO ivanete;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO planosauditores;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.web_services TO dorcilio;


--
-- TOC entry 11914 (class 0 OID 0)
-- Dependencies: 2485
-- Name: TABLE xml_faltante; Type: ACL; Schema: nfe; Owner: celismar
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.xml_faltante TO cassio;


--
-- TOC entry 11915 (class 0 OID 0)
-- Dependencies: 2195
-- Name: SEQUENCE y07_dup_id_dup_seq; Type: ACL; Schema: nfe; Owner: operador
--

GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO adriano;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO ivanete;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO planosauditores;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO kallita;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO irisneide;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO igor;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO julia;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO andrea;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO paula;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO consultor;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO vanessa;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.y07_dup_id_dup_seq TO dorcilio;


--
-- TOC entry 11916 (class 0 OID 0)
-- Dependencies: 1203
-- Name: TABLE y07_dup; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO celismar;
GRANT SELECT ON TABLE nfe.y07_dup TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO planosauditores;
GRANT SELECT ON TABLE nfe.y07_dup TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.y07_dup TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.y07_dup TO dorcilio;


--
-- TOC entry 11917 (class 0 OID 0)
-- Dependencies: 1204
-- Name: TABLE ya01_pag; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO celismar;
GRANT SELECT ON TABLE nfe.ya01_pag TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO planosauditores;
GRANT SELECT ON TABLE nfe.ya01_pag TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.ya01_pag TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya01_pag TO dorcilio;


--
-- TOC entry 11919 (class 0 OID 0)
-- Dependencies: 2729
-- Name: SEQUENCE ya01_pag_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,USAGE ON SEQUENCE nfe.ya01_pag_id_seq TO cassio;


--
-- TOC entry 11920 (class 0 OID 0)
-- Dependencies: 1205
-- Name: TABLE ya04_card; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO celismar;
GRANT SELECT ON TABLE nfe.ya04_card TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO planosauditores;
GRANT SELECT ON TABLE nfe.ya04_card TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.ya04_card TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.ya04_card TO dorcilio;


--
-- TOC entry 11922 (class 0 OID 0)
-- Dependencies: 2731
-- Name: SEQUENCE ya04_card_id_seq; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,USAGE ON SEQUENCE nfe.ya04_card_id_seq TO cassio;


--
-- TOC entry 11923 (class 0 OID 0)
-- Dependencies: 1206
-- Name: TABLE z01_inf_adic; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO celismar;
GRANT SELECT ON TABLE nfe.z01_inf_adic TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO planosauditores;
GRANT SELECT ON TABLE nfe.z01_inf_adic TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.z01_inf_adic TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z01_inf_adic TO dorcilio;


--
-- TOC entry 11924 (class 0 OID 0)
-- Dependencies: 2363
-- Name: SEQUENCE z04_obs_cont_id_seq; Type: ACL; Schema: nfe; Owner: operador
--

GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO planosauditores;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_seq TO dorcilio;


--
-- TOC entry 11925 (class 0 OID 0)
-- Dependencies: 1207
-- Name: TABLE z04_obs_cont; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO celismar;
GRANT SELECT ON TABLE nfe.z04_obs_cont TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO planosauditores;
GRANT SELECT ON TABLE nfe.z04_obs_cont TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.z04_obs_cont TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z04_obs_cont TO dorcilio;


--
-- TOC entry 11926 (class 0 OID 0)
-- Dependencies: 2362
-- Name: SEQUENCE z04_obs_cont_id_inf_adic_seq; Type: ACL; Schema: nfe; Owner: operador
--

GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO planosauditores;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO wesley;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO edinara;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO cassio;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO hellen;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO fiscalfacil;
GRANT ALL ON SEQUENCE nfe.z04_obs_cont_id_inf_adic_seq TO dorcilio;


--
-- TOC entry 11927 (class 0 OID 0)
-- Dependencies: 1208
-- Name: TABLE z07_obs_fisco; Type: ACL; Schema: nfe; Owner: planosassessoria
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO celismar;
GRANT SELECT ON TABLE nfe.z07_obs_fisco TO eder;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO cassio;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO ferretti;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO wesley;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO planosauditores;
GRANT SELECT ON TABLE nfe.z07_obs_fisco TO ermorais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO ivanete;
GRANT SELECT,INSERT,DELETE,TRIGGER,UPDATE ON TABLE nfe.z07_obs_fisco TO paula;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO irisneide;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO aliny;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO misael;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO ana;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO andrea;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO thais;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO adriano;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO kallita;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO igor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO julia;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO consultor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO vanessa;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO edinara;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO hellen;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO fiscalfacil;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nfe.z07_obs_fisco TO dorcilio;


-- Completed on 2026-09-09 18:36:41

--
-- PostgreSQL database dump complete
--

