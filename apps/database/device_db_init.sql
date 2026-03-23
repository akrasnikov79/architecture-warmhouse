-- ============================================
-- Device Service — Device DB
-- ============================================

CREATE DATABASE device_db;
\c device_db;

-- Типы устройств
CREATE TABLE IF NOT EXISTS device_types (
    type_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    protocol VARCHAR(50)  -- MQTT, HTTP, Zigbee и т.д.
);

-- Предзаполнение типов
INSERT INTO device_types (name, description, protocol) VALUES
    ('temperature_sensor', 'Датчик температуры', 'MQTT'),
    ('heating_relay', 'Реле управления отоплением', 'MQTT'),
    ('light_switch', 'Выключатель освещения', 'Zigbee'),
    ('gate_controller', 'Контроллер ворот', 'HTTP'),
    ('camera', 'Камера наблюдения', 'RTSP')
ON CONFLICT DO NOTHING;

-- Устройства
CREATE TABLE IF NOT EXISTS devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID,             -- логическая ссылка на Home Service (rooms)
    module_id UUID,           -- логическая ссылка на Home Service (modules)
    type_id INT NOT NULL REFERENCES device_types(type_id),
    serial_number VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'inactive',
    is_online BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devices_room_id ON devices(room_id);
CREATE INDEX IF NOT EXISTS idx_devices_module_id ON devices(module_id);
CREATE INDEX IF NOT EXISTS idx_devices_type_id ON devices(type_id);
CREATE INDEX IF NOT EXISTS idx_devices_serial ON devices(serial_number);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
