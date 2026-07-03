-- =============================================================================
-- SCHEMA: public
-- PROJETO: Fiscal Fácil
-- DATA: 2026-05-06
-- DESCRIÇÃO: Objetos globais compartilhados por todos os schemas do projeto.
--            Extensões, configurações de Full Text Search e funções utilitárias
--            reutilizadas por account, partner, xml, socket e demais schemas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. CONFIGURAÇÃO DE SESSÃO
-- -----------------------------------------------------------------------------

-- Define locale de tempo padrão do banco para português do Brasil.
-- Configuração persistente aplicada a novas conexões deste banco.
-- Impacta formatações com nomes de mês/dia (ex: to_char com Month/Day).
ALTER DATABASE nome_do_banco SET lc_time = 'pt_BR.utf8';

-- -----------------------------------------------------------------------------
-- 1. EXTENSÕES
-- -----------------------------------------------------------------------------

-- Remove acentos de tokens durante a busca FTS.
CREATE EXTENSION IF NOT EXISTS unaccent;

COMMENT ON EXTENSION unaccent IS
    'Remove acentos de tokens durante a busca FTS (ex: "joão" e "joao" retornam o mesmo resultado). '
    'Utilizada pela configuração public.simple_portuguese e pela função public.fn_format_tsquery.';

-- -----------------------------------------------------------------------------
-- 2. CONFIGURAÇÕES DE BUSCA
-- -----------------------------------------------------------------------------

-- Configuração baseada em pg_catalog.simple (sem stopwords) com unaccent como dicionário,
-- permitindo que "joão" e "joao" retornem os mesmos resultados.
CREATE TEXT SEARCH CONFIGURATION public.simple_portuguese (COPY = pg_catalog.simple);

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ALTER MAPPING FOR hword, hword_part, word
    WITH unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese OWNER TO dorcilio;

COMMENT ON TEXT SEARCH CONFIGURATION public.simple_portuguese IS
    'Configuração FTS para português sem stopwords, com remoção de acentos via unaccent. '
    'Garante que "joão" e "joao" produzam o mesmo token de busca.';

-- -----------------------------------------------------------------------------
-- 3. FUNÇÕES
-- -----------------------------------------------------------------------------

-- Converte texto livre do usuário em sintaxe de operadores tsquery (&, |, !).
CREATE OR REPLACE FUNCTION public.fn_format_tsquery(
    p_search_text  text,
    p_keep_accent  boolean DEFAULT false)
RETURNS text
LANGUAGE plpgsql
COST 100
IMMUTABLE PARALLEL SAFE
AS $$
DECLARE
    v_query text;
BEGIN
    -- 1. Limpeza inicial e tratamento de acentos
    v_query := trim(p_search_text);
    
    IF NOT p_keep_accent THEN
        v_query := public.unaccent(v_query);
    END IF;

    -- 2. Remover caracteres especiais que podem quebrar a sintaxe do tsquery
    v_query := regexp_replace(v_query, E'[\\(\\)\\*\\:\\\\]', ' ', 'g');

    -- 3. Normalizar espaços (transforma múltiplos espaços em um só)
    v_query := regexp_replace(v_query, E'\\s+', ' ', 'g');

    -- 4. Tratar negação (NOT): Transforma "termo -excluir" ou "termo !excluir" em "termo & !excluir"
    v_query := regexp_replace(v_query, E'\\s[-!]', ' & !', 'g');

    -- 5. Tratar OU (OR): Substitui vírgulas, ponto-e-virgula e a palavra "OU" por PIPE (|)
    -- Remove espaços ao redor dos separadores antes da troca
    v_query := regexp_replace(v_query, E'\\s*[,;]|\\s+OU\\s+', '|', 'gi');

    -- 6. Tratar E (AND): Substitui espaços restantes, "&" ou a palavra "E" por ampersand (&)
    -- Evita duplicar & onde já existe negação ou pipe
    v_query := regexp_replace(v_query, E'\\s*&\\s*|\\s+E\\s+|\\s+', '&', 'gi');

    -- 7. Limpeza final de operadores órfãos (ex: "termo & |")
    v_query := regexp_replace(v_query, E'&+', '&', 'g');
    v_query := regexp_replace(v_query, E'\\|+', '|', 'g');
    v_query := trim(both '&|' from v_query);

    RETURN v_query;
END;
$$;

ALTER FUNCTION public.fn_format_tsquery(text, boolean) OWNER TO dorcilio;

COMMENT ON FUNCTION public.fn_format_tsquery(text, boolean) IS
    'Prepara input do usuário para Full Text Search. Converte espaços/E em &, vírgulas/OU em | e hífens em !';

-- Atualiza updated_at automaticamente antes de qualquer UPDATE em qualquer schema.
CREATE OR REPLACE FUNCTION public.fn_update_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.fn_update_timestamp() OWNER TO dorcilio;

COMMENT ON FUNCTION public.fn_update_timestamp() IS
    'Trigger function centralizada para atualizar updated_at antes de todo UPDATE. '
    'Utilizada por todos os schemas do projeto (account, partner, xml, socket). '
    'Substitui: account.fn_update_timestamp, partner.fn_refresh_timestamp, '
    'xml.fn_update_timestamp e public.update_updated_at_column.';