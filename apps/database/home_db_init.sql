-- ============================================
-- Home Management Service — Home DB
-- ============================================

CREATE DATABASE home_db;
\c home_db;

-- Дома
CREATE TABLE IF NOT EXISTS houses (
    house_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL,  -- логическая ссылка на User Service
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_houses_owner ON houses(owner_user_id);

-- Комнаты
CREATE TABLE IF NOT EXISTS rooms (
    room_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES houses(house_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    floor INT DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_rooms_house_id ON rooms(house_id);

-- Модули (хабы / контроллеры, установленные в доме)
CREATE TABLE IF NOT EXISTS modules (
    module_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL REFERENCES houses(house_id) ON DELETE CASCADE,
    serial_number VARCHAR(100) NOT NULL UNIQUE,
    firmware_version VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'inactive',
    ip_address VARCHAR(45)
);

CREATE INDEX IF NOT EXISTS idx_modules_house_id ON modules(house_id);
CREATE INDEX IF NOT EXISTS idx_modules_serial ON modules(serial_number);
