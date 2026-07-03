-- =============================================================================
-- SEED: Status iniciais do roadmap/timeline SPED
-- Tabela: sped.sped_job_status_types
-- =============================================================================

INSERT INTO sped.sped_job_status_types (
    status_code,
    status_label_pt,
    is_system
)
VALUES
    ('DELETED',         'EXCLUÍDO',            TRUE),
    ('IMPORTED',        'IMPORTADO',           TRUE),
    ('EXPORTED',        'EXPORTADO',           TRUE),
    ('EXPORTED_DOMAIN', 'EXPORTADO - DOMÍNIO', TRUE),
    ('TRANSMITTED',     'TRANSMITIDO',         FALSE),
    ('RETIFY',          'RETIFICAR',           FALSE)
ON CONFLICT (status_code) DO UPDATE SET
    status_label_pt = EXCLUDED.status_label_pt,
    is_system = EXCLUDED.is_system;
