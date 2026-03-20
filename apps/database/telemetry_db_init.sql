-- ============================================
-- Telemetry Service — Telemetry DB (TimescaleDB)
-- ============================================

CREATE DATABASE telemetry_db;
\c telemetry_db;

-- Включение расширения TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Таблица телеметрии
CREATE TABLE IF NOT EXISTS telemetry_data (
    recorded_at TIMESTAMPTZ NOT NULL,
    device_id UUID NOT NULL,          -- логическая ссылка на Device Service
    metric_name VARCHAR(50) NOT NULL, -- temperature, humidity, power и т.д.
    metric_value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(20),                 -- °C, %, W и т.д.
    PRIMARY KEY (recorded_at, device_id)
);

-- Преобразование в hypertable для эффективного хранения временных рядов
SELECT create_hypertable('telemetry_data', 'recorded_at', if_not_exists => TRUE);

-- Индексы для частых запросов
CREATE INDEX IF NOT EXISTS idx_telemetry_device_id ON telemetry_data(device_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_metric ON telemetry_data(metric_name, recorded_at DESC);

-- Политика сжатия данных старше 30 дней
ALTER TABLE telemetry_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id,metric_name',
    timescaledb.compress_orderby = 'recorded_at DESC'
);

SELECT add_compression_policy('telemetry_data', INTERVAL '30 days', if_not_exists => TRUE);

-- Политика удаления данных старше 1 года
SELECT add_retention_policy('telemetry_data', INTERVAL '1 year', if_not_exists => TRUE);
