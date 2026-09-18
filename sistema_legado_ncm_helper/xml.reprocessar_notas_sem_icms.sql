-- FUNCTION: xml.reprocessar_notas_sem_icms()

-- DROP FUNCTION IF EXISTS xml.reprocessar_notas_sem_icms();

CREATE OR REPLACE FUNCTION xml.reprocessar_notas_sem_icms()
	RETURNS TABLE(ch_nf character varying, xml_id bigint, resultado jsonb)
	LANGUAGE 'plpgsql'
	VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
	_nota RECORD;
	_total INTEGER;
	_atual INTEGER := 0;
	_ok INTEGER := 0;
	_falhas INTEGER := 0;
	_sucesso BOOLEAN;
BEGIN
/*
 * Reprocessa NF-e que possuem nfe.raiz_nfe mas nenhum registro em
 * nfe.icms_filhos (notas da Reforma desestruturadas antes da correção do
 * ICMS fantasma).
 *
 * Estratégia:
 *   1. Coleta TODAS as notas afetadas (raiz_nfe com IBS/CBS e sem icms_filhos).
 *   2. Deleta em batch de nfe.raiz_nfe (cascade remove todos os filhos).
 *   3. Reprocessa cada nota com xml.desestruturar_xml_nfe_nfce(xml_id, false),
 *      já que a nota foi removida na etapa anterior.
 *
 * O XML de origem (xml.nfe_nfce) nunca é apagado, então qualquer falha de
 * reprocessamento é recuperável.
 */
	DROP TABLE IF EXISTS _notas_sem_icms;
	CREATE TEMP TABLE _notas_sem_icms ON COMMIT DROP AS
	SELECT DISTINCT r.id_nfe, r.inf_nfe AS ch_nf, r.xml_id
	FROM nfe.raiz_nfe r
	JOIN nfe.ub12_ibs_cbs ibs ON ibs.id_nfe = r.id_nfe
	WHERE r.xml_id IS NOT NULL
		AND NOT EXISTS (
			SELECT 1 FROM nfe.icms_filhos icf WHERE icf.id_nfe = r.id_nfe
		);

	SELECT COUNT(*) INTO _total FROM _notas_sem_icms;
	RAISE INFO '[reprocessar_notas_sem_icms] % nota(s) afetada(s) para reprocessar', _total;

	DELETE FROM nfe.raiz_nfe r
	WHERE r.id_nfe IN (SELECT n.id_nfe FROM _notas_sem_icms n);
	RAISE INFO '[reprocessar_notas_sem_icms] % raiz_nfe deletada(s) em batch', _total;

	FOR _nota IN
		SELECT n.ch_nf, n.xml_id FROM _notas_sem_icms n
	LOOP
		_atual := _atual + 1;
		ch_nf := _nota.ch_nf;
		xml_id := _nota.xml_id;
		resultado := xml.desestruturar_xml_nfe_nfce(_nota.xml_id, false);

		_sucesso := COALESCE((resultado->>'success')::BOOLEAN, FALSE);
		IF _sucesso THEN
			_ok := _ok + 1;
			RAISE INFO '[reprocessar_notas_sem_icms] (%/%) OK ch_nf=% xml_id=%', _atual, _total, ch_nf, xml_id;
		ELSE
			_falhas := _falhas + 1;
			RAISE WARNING '[reprocessar_notas_sem_icms] (%/%) FALHA ch_nf=% xml_id=% -> %', _atual, _total, ch_nf, xml_id, resultado->>'message';
		END IF;

		RETURN NEXT;
	END LOOP;

	RAISE INFO '[reprocessar_notas_sem_icms] Concluído: % sucesso(s), % falha(s) de % nota(s)', _ok, _falhas, _total;
END;
$BODY$;

ALTER FUNCTION xml.reprocessar_notas_sem_icms()
	OWNER TO dorcilio;

COMMENT ON FUNCTION xml.reprocessar_notas_sem_icms() IS
'Deleta em batch NF-e com raiz_nfe sem icms_filhos e reprocessa via xml.desestruturar_xml_nfe_nfce(xml_id, false).';

/*
-- Reprocessar TODAS as notas afetadas do banco:
SELECT * FROM xml.reprocessar_notas_sem_icms();
*/
