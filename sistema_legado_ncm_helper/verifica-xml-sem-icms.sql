/*
 * Diagnóstico: identifica XMLs de NF-e/NFC-e que NÃO possuem o grupo <ICMS>
 * (notas no layout da Reforma Tributária que trazem apenas <IBSCBS>),
 * situação que impede a inserção em nfe.icms_filhos.
 *
 * Uso: substitua a lista dentro de ARRAY[] por suas chaves,
 *      separadas por vírgula e entre aspas simples.
 */
WITH chaves AS (
    SELECT unnest(ARRAY[
        '51260824978538000133550010000075761017893574',
		'51260824978538000133550010000075331017822866',
		'51260824978538000133550010000075521017837583',
		'51260824978538000133550010000075311017819208',
		'51260824978538000133550010000075301017818166',
		'51260824978538000133550010000075371017834820',
		'51260824978538000133550010000075281017803411',
		'51260824978538000133550010000075491017837421',
		'51260824978538000133550010000075501017837481',
		'51260824978538000133550010000075771017893709',
		'51260824978538000133550010000075291017817380',
		'51260824978538000133550010000075351017831029',
		'51260824978538000133550010000075511017837497',
		'51260824978538000133550010000075531017837769',
		'51260824978538000133550010000075781017893722'
    ]) AS ch_nf
),
ns AS (
    SELECT ARRAY[ARRAY['new', 'http://www.portalfiscal.inf.br/nfe']] AS nfe
)
SELECT
    c.ch_nf,
    x.xml_id,
    CASE WHEN x.xml_id IS NULL THEN 'XML NAO ENCONTRADO' ELSE 'OK' END AS situacao_xml,
    COALESCE(array_length(xpath('//new:det/new:imposto/new:ICMS',   x.xml_file, ns.nfe), 1), 0) AS qtd_icms,
    COALESCE(array_length(xpath('//new:det/new:imposto/new:IBSCBS', x.xml_file, ns.nfe), 1), 0) AS qtd_ibscbs,
    COALESCE(array_length(xpath('//new:det', x.xml_file, ns.nfe), 1), 0) AS qtd_itens,
    CASE
        WHEN x.xml_id IS NULL THEN NULL
        WHEN COALESCE(array_length(xpath('//new:det/new:imposto/new:ICMS', x.xml_file, ns.nfe), 1), 0) = 0
             AND COALESCE(array_length(xpath('//new:det/new:imposto/new:IBSCBS', x.xml_file, ns.nfe), 1), 0) > 0
            THEN 'SEM ICMS (so IBSCBS) - NAO desestrutura icms_filhos'
        WHEN COALESCE(array_length(xpath('//new:det/new:imposto/new:ICMS', x.xml_file, ns.nfe), 1), 0) = 0
            THEN 'SEM ICMS e SEM IBSCBS - verificar'
        ELSE 'POSSUI ICMS - ok'
    END AS diagnostico
FROM chaves c
CROSS JOIN ns
LEFT JOIN xml.nfe_nfce x ON x.ch_nf = c.ch_nf
ORDER BY diagnostico, c.ch_nf;
