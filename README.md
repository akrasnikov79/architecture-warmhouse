# Project_template

Это решение проектной работы для спринта «Тёплый дом».

# Задание 1. Анализ и планирование

### 1. Описание функциональности монолитного приложения

**Управление отоплением:**
- Пользователи могут удалённо включать и выключать отопление в своих домах.
- Каждая установка сопровождается выездом специалиста для подключения системы отопления.
- Самостоятельное подключение датчика к системе пользователем не поддерживается.
- Система поддерживает только синхронное взаимодействие (от сервера к датчику).

**Мониторинг температуры:**
- Система получает данные о температуре с датчиков, установленных в домах, через синхронный запрос от сервера к датчику.
- Пользователи могут просматривать текущую температуру в своих домах через веб-интерфейс.

### 2. Анализ архитектуры монолитного приложения

- Язык программирования: Go.
- База данных: PostgreSQL.
- Архитектура: Монолитная — все компоненты системы (обработка запросов, бизнес-логика, работа с данными) находятся в рамках одного приложения.
- Взаимодействие: Исключительно синхронное, запросы обрабатываются последовательно. Асинхронных вызовов или брокеров сообщений нет.
- Масштабируемость: Ограничена по причине монолитности. Приходится масштабировать всё приложение целиком, даже если нагрузка возрастает только на чтение телеметрии.
- Развертывание: Требует остановки всего приложения для выкатки обновлений.

### 3. Определение доменов и границы контекстов

Выделены следующие домены (и соответствующие границы контекстов):
1. **Управление устройствами (Device Management):** Регистрация новых устройств в системе, хранение их конфигурации, жизненный цикл и статус, отправка команд (включение/выключение).
2. **Телеметрия (Telemetry):** Сбор метрик и показаний (температура, влажность и т.д.) с датчиков в реальном времени, хранение исторической информации, агрегация.
3. **Управление домом/пользователями (Home & Access Management):** Хранение профилей пользователей, группировка устройств по домам/комнатам, выдача прав доступа и организация экосистемы (SaaS).
4. **Автоматизация и сценарии (Automation Scenarios):** Настройка пользовательских правил (например, «если температура ниже 20, включить реле»).

### **4. Проблемы монолитного решения**

- **Высокая связность и хрупкость:** Падение монолита (например, из-за долгой обработки телеметрии) приводит к невозможности управлять устройствами. Для IoT-систем критичен сбор данных отдельно от управляющих воздействий.
- **Ограничения масштабирования:** Телеметрия генерирует огромный поток данных (write-heavy), в то время как управление конфигурациями и домами — read-heavy. Масштабировать эти части монолита по-отдельности невозможно.
- **Синхронная модель:** Отсутствие брокеров сообщений делает интеграцию с новыми партнерскими устройствами (работающими через MQTT по событиям) архитектурно невозможной в рамках старой парадигмы без блокировок.
- **Узкое «горлышко» развертывания:** Добавление поддержки нового производителя датчиков требует пересборки всего монолита и его простоя. 

### 5. Визуализация контекста системы — диаграмма С4

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

Person(user, "Пользователь", "Владелец умного дома")
System(warmhouse, "Система «Тёплый дом» (Монолит)", "Обеспечивает управление отоплением и мониторинг температуры")
System_Ext(web_client, "Веб-клиент", "SPA в браузере пользователя для управления экосистемой")
System_Ext(sensors, "Датчики и реле", "Устройства, установленные в домах (температурные датчики, реле котла)")

Rel(user, web_client, "Взаимодействует через браузер", "HTTPS")
Rel(web_client, warmhouse, "Просматривает температуру, управляет отоплением", "HTTP/REST")
Rel(warmhouse, sensors, "Опрашивает термометры, отправляет команды на реле", "Синхронные запросы")
@enduml
```

# Задание 2. Проектирование микросервисной архитектуры

**Диаграмма контейнеров As-Is (текущее состояние)**

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

Person(user, "Пользователь", "Владелец дома с подключённым отоплением")

System_Boundary(current, "Текущая система «Тёплый дом» (As-Is)") {
    Container(monolith, "Монолитное приложение", "Go", "Обработка запросов, бизнес-логика, работа с данными — всё в одном приложении")
    ContainerDb(postgres, "PostgreSQL", "PostgreSQL", "Единая БД для всех данных (пользователи, датчики, показания)")
}

System_Ext(sensors, "Датчики и реле", "Температурные датчики и реле котлов, установленные в домах")

Rel(user, monolith, "Просматривает температуру, управляет отоплением", "HTTP")
Rel(monolith, postgres, "Чтение/запись всех данных", "SQL")
Rel(monolith, sensors, "Синхронный опрос датчиков и отправка команд", "HTTP")
@enduml
```

**Диаграмма контейнеров To-Be (целевая архитектура)**

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

Person(user, "Пользователь", "Покупает устройства SaaS и управляет домом")

System_Boundary(ecosystem, "Экосистема «Тёплый дом»") {
    Container(web_app, "Web Portal", "React / JS", "Интерфейс самообслуживания")
    Container(api_gateway, "API Gateway", "Go", "Единая точка входа, авторизация, маршрутизация")

    Container(user_service, "User & Auth Service", "Go", "Управление пользователями, аутентификация, авторизация, JWT")
    ContainerDb(user_db, "User DB", "PostgreSQL", "Профили пользователей, роли, токены")

    Container(home_service, "Home Management Service", "Go", "Управление домами, комнатами, группами устройств")
    ContainerDb(home_db, "Home DB", "PostgreSQL", "Дома, комнаты, привязки")

    Container(device_service, "Device Service", "Go", "Управление реестром устройств, отправка команд")
    ContainerDb(device_db, "Device DB", "PostgreSQL", "Хранение списка устройств и их состояний")

    Container(telemetry_service, "Telemetry Service", "Go", "Сбор и агрегация данных телеметрии")
    ContainerDb(telemetry_db, "Telemetry DB", "TimescaleDB", "Хранение истории показаний")

    Container(scenario_service, "Automation Service", "Go", "Обработка пользовательских правил и сценариев")
    ContainerDb(scenario_db, "Scenario DB", "PostgreSQL", "Хранение сконфигурированных сценариев")

    Container(message_broker, "Message Broker", "Kafka", "Асинхронная передача событий между сервисами")
}

System_Ext(devices, "Умные устройства", "Датчики, реле, модули сторонних партнеров")

Rel(user, web_app, "Управляет экосистемой", "HTTPS")
Rel(web_app, api_gateway, "REST API вызовы", "HTTPS")

Rel(api_gateway, user_service, "Аутентификация / авторизация", "REST/gRPC")
Rel(api_gateway, home_service, "Управление домами", "REST/gRPC")
Rel(api_gateway, device_service, "Управление устройствами", "REST/gRPC")
Rel(api_gateway, telemetry_service, "Получение истории", "REST/gRPC")
Rel(api_gateway, scenario_service, "Настройка правил", "REST/gRPC")

Rel(user_service, user_db, "Чтение/запись", "SQL")
Rel(home_service, home_db, "Чтение/запись", "SQL")
Rel(device_service, device_db, "Чтение/запись", "SQL")
Rel(telemetry_service, telemetry_db, "Вставка/чтение временных рядов", "SQL")
Rel(scenario_service, scenario_db, "Чтение/запись", "SQL")

Rel(devices, message_broker, "Отправка телеметрии и статусов", "MQTT")
Rel(device_service, message_broker, "Публикация событий (офлайн/онлайн)", "Kafka")
Rel(telemetry_service, message_broker, "Слушает события, генерирует триггеры", "Kafka")
Rel(scenario_service, message_broker, "Слушает триггеры, вызывает отправку команд", "Kafka")
Rel(device_service, devices, "Отправка команд", "MQTT")
@enduml
```

**Диаграмма компонентов (Components)**
Для микросервиса *Device Service* (Управление устройствами)

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

Container_Boundary(device_service, "Device Service") {
    Component(api, "API Layer", "Go HTTP/gRPC", "Предоставляет REST/gRPC интерфейс")
    Component(device_manager, "Device Manager", "Go", "Бизнес-логика: добавление, обновление, привязка устройств к дому")
    Component(command_sender, "Command Dispatcher", "Go", "Отправка управляющих команд в сеть или брокер устройств")
    Component(repo, "Database Repository", "Go", "Абстракция доступа к базе данных")
    Component(event_publisher, "Event Publisher", "Go", "Отправка событий об изменении стейта в Message Broker")
}

ContainerDb(device_db, "Device DB", "PostgreSQL", "Схема данных Device")
Container(message_broker, "Message Broker", "Kafka", "Шина событий")
System_Ext(devices, "Умные устройства", "Конечные устройства в домах")

Rel(api, device_manager, "Вызывает методы (Сreate, Update)")
Rel(api, command_sender, "Делегирует команду включения/выключения")
Rel(device_manager, repo, "Сохраняет состояние")
Rel(device_manager, event_publisher, "Формирует событие DeviceRegistered/DeviceUpdated")
Rel(repo, device_db, "Выполняет CRUD-запросы", "SQL")
Rel(event_publisher, message_broker, "Публикует сообщения", "TCP")
Rel(command_sender, devices, "Отправляет сигнал", "HTTP / MQTT")
@enduml
```

**Диаграмма кода (Code)** 
Диаграмма последовательности для успешного выполнения команды включения реле-устройства.

```plantuml
@startuml
actor User
participant "API Gateway" as GW
participant "Device Service" as DS
database "Device DB" as DB
participant "Message Broker" as Kafka
participant "Heating Relay" as Relay

User -> GW: POST /devices/{id}/commands \n { "action": "turn_on" }
GW -> DS: Forward Request
DS -> DB: SELECT device FROM devices WHERE id={id}
DB --> DS: Device Info & Status
DS -> Relay: Send action "turn_on" (HTTP/MQTT)
Relay --> DS: OK
DS -> DB: UPDATE devices SET status='on' WHERE id={id}
DS -> Kafka: Publish "DeviceStatusChanged" {status: on}
DS --> GW: 200 OK
GW --> User: 200 OK
@enduml
```

**Диаграмма последовательности для автоматического срабатывания сценария**
Пример: датчик температуры фиксирует 29°C, что превышает порог 28°C в сценарии — система автоматически выключает котёл.

```plantuml
@startuml
participant "Датчик температуры" as Sensor
participant "Message Broker\n(Kafka)" as Kafka
participant "Telemetry Service" as TS
database "Telemetry DB\n(TimescaleDB)" as TDB
participant "Automation Service" as AS
database "Scenario DB" as SDB
participant "Device Service" as DS
database "Device DB" as DDB
participant "Реле котла" as Relay

== 1. Получение показания датчика ==
Sensor -> Kafka: MQTT: telemetry.reading\n{ device_id: "sensor-01", metric: "temperature", value: 29.0 }

== 2. Сохранение телеметрии ==
Kafka -> TS: Consume telemetry.reading
TS -> TDB: INSERT INTO telemetry_data\n(device_id, metric_name, metric_value, unit, recorded_at)\nVALUES ('sensor-01', 'temperature', 29.0, '°C', NOW())
TDB --> TS: OK

== 3. Проверка сценариев ==
Kafka -> AS: Consume telemetry.reading
AS -> SDB: SELECT sa.* FROM scenario_actions sa\nJOIN scenarios s ON s.scenario_id = sa.scenario_id\nWHERE s.is_active = true\nAND sa.trigger_type = 'telemetry_threshold'\nAND sa.trigger_condition->>'device_id' = 'sensor-01'\nAND sa.trigger_condition->>'metric' = 'temperature'
SDB --> AS: Правило найдено:\noperator: ">", value: 28,\naction: { device_id: "relay-01", command: "turn_off" }

AS -> AS: Проверка условия:\n29.0 > 28? — ДА

== 4. Выполнение действия ==
AS -> DS: POST /devices/relay-01/command\n{ "command": "turn_off" }
DS -> DDB: SELECT * FROM devices WHERE device_id = 'relay-01'
DDB --> DS: Device Info (status: 'on', is_online: true)
DS -> Relay: Send command "turn_off" (MQTT)
Relay --> DS: ACK
DS -> DDB: UPDATE devices SET status = 'off' WHERE device_id = 'relay-01'
DS -> Kafka: Publish device.status-changed\n{ device_id: "relay-01", previous_status: "on", status: "off" }
DS --> AS: 200 OK
@enduml
```

# Задание 3. Разработка ER-диаграммы

В целевой архитектуре применяется паттерн **Database per Service** — каждый микросервис владеет собственной базой данных. Между контекстами нет внешних ключей (FK); связь осуществляется через логические ссылки по ID и обеспечивается согласованность на уровне приложений (eventual consistency).

```plantuml
@startuml
skinparam packageStyle rectangle

package "User DB (User & Auth Service)" as user_ctx #E8F5E9 {
  entity "users" as users {
    * user_id : uuid <<PK>>
    --
    email : varchar <<unique>>
    password_hash : varchar
    role_id : int <<FK>>
    created_at : timestamptz
  }

  entity "roles" as roles {
    * role_id : serial <<PK>>
    --
    name : varchar <<unique>>
    description : varchar
  }

  entity "refresh_tokens" as tokens {
    * token_id : uuid <<PK>>
    --
    user_id : uuid <<FK>>
    token_hash : varchar
    expires_at : timestamptz
    created_at : timestamptz
  }

  users }o--|| roles : "Имеет роль"
  users ||--o{ tokens : "Имеет токены"
}

package "Home DB (Home Management Service)" as home_ctx #E3F2FD {
  entity "houses" as houses {
    * house_id : uuid <<PK>>
    --
    owner_user_id : uuid
    name : varchar
    address : varchar
    created_at : timestamptz
  }
  note right of houses::owner_user_id
    Логическая ссылка
    на User Service
  end note

  entity "rooms" as rooms {
    * room_id : uuid <<PK>>
    --
    house_id : uuid <<FK>>
    name : varchar
    floor : int
  }

  entity "modules" as modules {
    * module_id : uuid <<PK>>
    --
    house_id : uuid <<FK>>
    serial_number : varchar <<unique>>
    firmware_version : varchar
    status : varchar
    ip_address : varchar
  }

  houses ||--o{ rooms : "Содержит"
  houses ||--o{ modules : "Установлен"
}

package "Device DB (Device Service)" as device_ctx #FFF3E0 {
  entity "device_types" as dev_types {
    * type_id : serial <<PK>>
    --
    name : varchar
    description : varchar
    protocol : varchar
  }

  entity "devices" as devices {
    * device_id : uuid <<PK>>
    --
    room_id : uuid
    module_id : uuid
    type_id : int <<FK>>
    serial_number : varchar <<unique>>
    name : varchar
    status : varchar
    is_online : boolean
    last_seen_at : timestamptz
  }
  note right of devices::room_id
    Логическая ссылка
    на Home Service
  end note

  devices }o--|| dev_types : "Имеет тип"
}

package "Telemetry DB (Telemetry Service) — TimescaleDB" as telemetry_ctx #F3E5F5 {
  entity "telemetry_data" as telemetry {
    * recorded_at : timestamptz <<PK>>
    * device_id : uuid <<PK>>
    --
    metric_name : varchar
    metric_value : double precision
    unit : varchar
  }
  note bottom of telemetry
    Hypertable (TimescaleDB)
    Партиционирование по recorded_at
  end note
}

package "Scenario DB (Automation Service)" as scenario_ctx #FFEBEE {
  entity "scenarios" as scenarios {
    * scenario_id : uuid <<PK>>
    --
    house_id : uuid
    name : varchar
    description : text
    is_active : boolean
    created_at : timestamptz
  }

  entity "scenario_actions" as actions {
    * action_id : uuid <<PK>>
    --
    scenario_id : uuid <<FK>>
    trigger_type : varchar
    trigger_condition : jsonb
    action_type : varchar
    action_payload : jsonb
    order_index : int
  }

  scenarios ||--o{ actions : "Содержит действия"
}

' Межсервисные логические связи (пунктир)
users ..> houses : "owner_user_id"
rooms ..> devices : "room_id"
modules ..> devices : "module_id"
devices ..> telemetry : "device_id"
houses ..> scenarios : "house_id"
@enduml
```

# Задание 4. Создание и документирование API

### 1. Тип API

Основой взаимодействия между фронтендом (или API Gateway) и микросервисами для синхронных запросов (управление, получение состояния, настройка) будет **REST API**. Он оптимально подходит для CRUD-операций и сценариев, когда инициатор должен немедленно узнать результат (например, была ли применена команда включения). Для сбора потоковых данных с датчиков (телеметрия) внутри системы оптимально применять **событийную модель с использованием Message Broker (Kafka)** или протокол **MQTT**, однако публичный контракт для внешних клиентов для управления будет строиться на REST через JSON.

Для асинхронного взаимодействия (события телеметрии, уведомления о смене статуса устройств) используется **AsyncAPI** — контракт для событий, передаваемых через Message Broker (Kafka).

### 2. Документация REST API (OpenAPI 3.0)

Ниже представлен контракт REST API для взаимодействия с Device Service — 5 эндпоинтов.

```yaml
openapi: 3.0.0
info:
  title: Экосистема Тёплый Дом - Device API
  version: 1.0.0
  description: REST API для управления устройствами умного дома

paths:
  /devices:
    get:
      summary: Получение списка устройств
      description: Возвращает список устройств с возможностью фильтрации по дому и пагинацией
      parameters:
        - name: house_id
          in: query
          required: false
          description: Фильтр по идентификатору дома
          schema:
            type: string
            format: uuid
        - name: page
          in: query
          required: false
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          required: false
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: Список устройств
          content:
            application/json:
              schema:
                type: object
                properties:
                  items:
                    type: array
                    items:
                      $ref: '#/components/schemas/Device'
                  total:
                    type: integer
                  page:
                    type: integer
                  limit:
                    type: integer
              examples:
                success:
                  summary: Пример успешного ответа
                  value:
                    items:
                      - id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
                        house_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                        name: "Термодатчик гостиная"
                        serial_number: "SN-TEMP-001"
                        status: "on"
                        is_online: true
                        type_id: 1
                      - id: "b23dc10b-77aa-4372-b890-1e02b2c3d480"
                        house_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                        name: "Реле отопления"
                        serial_number: "SN-RELAY-002"
                        status: "off"
                        is_online: true
                        type_id: 2
                    total: 2
                    page: 1
                    limit: 20
        '401':
          description: Не авторизован

    post:
      summary: Регистрация нового устройства
      description: Добавляет новое устройство в систему и привязывает его к дому
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - house_id
                - name
                - type_id
                - serial_number
              properties:
                house_id:
                  type: string
                  format: uuid
                name:
                  type: string
                type_id:
                  type: integer
                serial_number:
                  type: string
            examples:
              temperature_sensor:
                summary: Регистрация температурного датчика
                value:
                  house_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                  name: "Термодатчик кухня"
                  type_id: 1
                  serial_number: "SN-TEMP-003"
      responses:
        '201':
          description: Устройство успешно зарегистрировано
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Device'
              examples:
                created:
                  summary: Пример созданного устройства
                  value:
                    id: "c34ed20c-88bb-4483-c901-2f13c3d4e591"
                    house_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                    name: "Термодатчик кухня"
                    serial_number: "SN-TEMP-003"
                    status: "inactive"
                    is_online: false
                    type_id: 1
        '400':
          description: Неверный формат запроса
        '409':
          description: Устройство с таким serial_number уже существует

  /devices/{deviceId}:
    get:
      summary: Получение подробной информации об устройстве
      parameters:
        - name: deviceId
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Успешный ответ
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Device'
              examples:
                success:
                  summary: Пример устройства
                  value:
                    id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
                    house_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                    name: "Термодатчик гостиная"
                    serial_number: "SN-TEMP-001"
                    status: "on"
                    is_online: true
                    type_id: 1
        '404':
          description: Устройство не найдено

  /devices/{deviceId}/status:
    put:
      summary: Обновление состояния устройства
      description: Используется устройством для heartbeat или оператором для ручного изменения статуса
      parameters:
        - name: deviceId
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                status:
                  type: string
                  enum: [on, off, error, maintenance]
                is_online:
                  type: boolean
            examples:
              heartbeat:
                summary: Heartbeat от устройства
                value:
                  status: "on"
                  is_online: true
              maintenance:
                summary: Перевод в режим обслуживания
                value:
                  status: "maintenance"
                  is_online: true
      responses:
        '200':
          description: Статус успешно обновлен
          content:
            application/json:
              examples:
                success:
                  value:
                    message: "Status updated successfully"
                    device_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
                    status: "on"
        '400':
          description: Неверный формат запроса
        '404':
          description: Устройство не найдено

  /devices/{deviceId}/command:
    post:
      summary: Отправка управляющей команды на устройство
      description: Отправляет команду (включить, выключить, задать параметры) на физическое устройство
      parameters:
        - name: deviceId
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - command
              properties:
                command:
                  type: string
                  enum: [turn_on, turn_off, set_temperature, lock, unlock]
                params:
                  type: object
                  additionalProperties: true
            examples:
              turn_on:
                summary: Включение устройства
                value:
                  command: "turn_on"
                  params: {}
              set_temperature:
                summary: Установка целевой температуры
                value:
                  command: "set_temperature"
                  params:
                    temperature_target: 24
      responses:
        '200':
          description: Команда успешно отправлена и обработана устройством
          content:
            application/json:
              examples:
                success:
                  value:
                    message: "Command executed successfully"
                    device_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
                    command: "turn_on"
                    result: "ok"
        '403':
          description: Нет доступа к устройству
        '404':
          description: Устройство не найдено
        '500':
          description: Ошибка связи с физическим устройством или таймаут
          content:
            application/json:
              examples:
                timeout:
                  value:
                    error: "Device communication timeout"
                    device_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"

components:
  schemas:
    Device:
      type: object
      properties:
        id:
          type: string
          format: uuid
        house_id:
          type: string
          format: uuid
        name:
          type: string
        serial_number:
          type: string
        status:
          type: string
          enum: [on, off, inactive, error, maintenance]
        is_online:
          type: boolean
        type_id:
          type: integer
```

### 3. Документация AsyncAPI (асинхронное взаимодействие)

Для событийного взаимодействия между микросервисами через Message Broker (Kafka) используется AsyncAPI.

```yaml
asyncapi: 2.6.0
info:
  title: Экосистема Тёплый Дом - Async Events
  version: 1.0.0
  description: Асинхронные события экосистемы умного дома, передаваемые через Kafka

servers:
  production:
    url: kafka:9092
    protocol: kafka

channels:
  device.status-changed:
    description: Событие при изменении статуса устройства (включение, выключение, ошибка)
    publish:
      summary: Публикация события смены статуса устройства
      operationId: onDeviceStatusChanged
      message:
        payload:
          type: object
          required:
            - device_id
            - status
            - timestamp
          properties:
            device_id:
              type: string
              format: uuid
            previous_status:
              type: string
              enum: [on, off, inactive, error]
            status:
              type: string
              enum: [on, off, inactive, error]
            timestamp:
              type: string
              format: date-time
        examples:
          - payload:
              device_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
              previous_status: "off"
              status: "on"
              timestamp: "2025-01-15T10:30:00Z"

  telemetry.reading:
    description: Новое показание телеметрии от датчика
    publish:
      summary: Публикация данных телеметрии
      operationId: onTelemetryReading
      message:
        payload:
          type: object
          required:
            - device_id
            - metric_name
            - value
            - recorded_at
          properties:
            device_id:
              type: string
              format: uuid
            metric_name:
              type: string
              example: "temperature"
            value:
              type: number
              format: double
              example: 22.5
            unit:
              type: string
              example: "°C"
            recorded_at:
              type: string
              format: date-time
        examples:
          - payload:
              device_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
              metric_name: "temperature"
              value: 22.5
              unit: "°C"
              recorded_at: "2025-01-15T10:30:00Z"
```

# Задание 5. Работа с docker и docker-compose

Перейдите в apps.

Там находится приложение-монолит для работы с датчиками температуры. В README.md описано как запустить решение.

Вам нужно:

1) сделать простое приложение temperature-api на любом удобном для вас языке программирования, которое при запросе /temperature?location= будет отдавать рандомное значение температуры.

Locations - название комнаты, sensorId - идентификатор названия комнаты

```
	// If no location is provided, use a default based on sensor ID
	if location == "" {
		switch sensorID {
		case "1":
			location = "Living Room"
		case "2":
			location = "Bedroom"
		case "3":
			location = "Kitchen"
		default:
			location = "Unknown"
		}
	}

	// If no sensor ID is provided, generate one based on location
	if sensorID == "" {
		switch location {
		case "Living Room":
			sensorID = "1"
		case "Bedroom":
			sensorID = "2"
		case "Kitchen":
			sensorID = "3"
		default:
			sensorID = "0"
		}
	}
```

2) Приложение следует упаковать в Docker и добавить в docker-compose. Порт по умолчанию должен быть 8081

3) Кроме того для smart_home приложения требуется база данных - добавьте в docker-compose файл настройки для запуска postgres с указанием скрипта инициализации ./smart_home/init.sql

Для проверки можно использовать Postman коллекцию smarthome-api.postman_collection.json и вызвать:

- Create Sensor
- Get All Sensors

Должно при каждом вызове отображаться разное значение температуры

Ревьюер будет проверять точно так же.
