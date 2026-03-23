-- ============================================
-- Automation Service — Scenario DB
-- ============================================

CREATE DATABASE scenario_db;
\c scenario_db;

-- Сценарии автоматизации
CREATE TABLE IF NOT EXISTS scenarios (
    scenario_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    house_id UUID NOT NULL,           -- логическая ссылка на Home Service
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scenarios_house_id ON scenarios(house_id);
CREATE INDEX IF NOT EXISTS idx_scenarios_active ON scenarios(is_active);

-- Действия сценария (триггер + реакция)
CREATE TABLE IF NOT EXISTS scenario_actions (
    action_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scenario_id UUID NOT NULL REFERENCES scenarios(scenario_id) ON DELETE CASCADE,
    trigger_type VARCHAR(50) NOT NULL,    -- telemetry_threshold, schedule, device_status
    trigger_condition JSONB NOT NULL,     -- {"metric": "temperature", "operator": "<", "value": 20, "device_id": "..."}
    action_type VARCHAR(50) NOT NULL,     -- send_command, notify
    action_payload JSONB NOT NULL,        -- {"device_id": "...", "command": "turn_on"}
    order_index INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_actions_scenario_id ON scenario_actions(scenario_id);
