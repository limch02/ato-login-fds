-- MySQL 8.x / utf8mb4
CREATE TABLE users (
                       user_id           BIGINT PRIMARY KEY AUTO_INCREMENT,
                       email             VARCHAR(255) NOT NULL UNIQUE,
                       password_hash     VARCHAR(255) NOT NULL,
                       role              VARCHAR(16)  NOT NULL,
                       status            VARCHAR(16)  NOT NULL,
                       security_version  INT NOT NULL DEFAULT 0,
                       locked_at         DATETIME NULL,
                       created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                       updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                       CONSTRAINT chk_users_role   CHECK (role IN ('USER','ADMIN')),
                       CONSTRAINT chk_users_status CHECK (status IN ('ACTIVE','LOCKED','DISABLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_sessions (
                               session_id            BIGINT PRIMARY KEY AUTO_INCREMENT,
                               user_id               BIGINT NOT NULL,
                               refresh_token_hash    BINARY(32) NOT NULL,
                               refresh_expires_at    DATETIME NOT NULL,
                               revoked_at            DATETIME NULL,
                               last_used_at          DATETIME NULL,
                               created_ip            VARBINARY(16) NOT NULL,
                               created_user_agent    VARCHAR(512) NULL,
                               device_id_hash        BINARY(32) NULL,
                               created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                               CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(user_id),
                               UNIQUE KEY uq_refresh_token_hash (refresh_token_hash),
                               KEY idx_sessions_user (user_id, revoked_at, refresh_expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_devices (
                              user_device_id        BIGINT PRIMARY KEY AUTO_INCREMENT,
                              user_id               BIGINT NOT NULL,
                              device_id_hash        BINARY(32) NOT NULL,
                              first_seen_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              last_seen_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users(user_id),
                              UNIQUE KEY uq_user_device (user_id, device_id_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ip_blocklist (
                              block_id              BIGINT PRIMARY KEY AUTO_INCREMENT,
                              ip_bin                VARBINARY(16) NOT NULL,
                              reason                VARCHAR(255) NULL,
                              is_active             TINYINT(1) NOT NULL DEFAULT 1,
                              expires_at            DATETIME NULL,
                              created_by_admin_id   BIGINT NOT NULL,
                              created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                              CONSTRAINT fk_blocklist_admin FOREIGN KEY (created_by_admin_id) REFERENCES users(user_id),
                              UNIQUE KEY uq_block_ip_active (ip_bin, is_active),
                              KEY idx_block_active_exp (is_active, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE auth_events (
                             event_id              BIGINT PRIMARY KEY AUTO_INCREMENT,
                             request_id            CHAR(36) NOT NULL,
                             event_type            VARCHAR(32) NOT NULL,
                             occurred_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

                             user_id               BIGINT NULL,
                             login_identifier_hash BINARY(32) NULL,
                             result                VARCHAR(32) NOT NULL,
                             fail_reason           VARCHAR(32) NULL,

                             ip_bin                VARBINARY(16) NOT NULL,
                             user_agent            VARCHAR(512) NULL,
                             device_id_hash        BINARY(32) NULL,

                             geo_country_iso       CHAR(2) NULL,
                             geo_city              VARCHAR(128) NULL,
                             geo_lat               DECIMAL(9,6) NULL,
                             geo_lon               DECIMAL(9,6) NULL,

                             asn                   INT NULL,
                             as_org                VARCHAR(255) NULL,
                             is_anonymous          TINYINT(1) NULL,

                             CONSTRAINT fk_events_user FOREIGN KEY (user_id) REFERENCES users(user_id),
                             CONSTRAINT chk_event_type CHECK (
                                 event_type IN ('LOGIN_SUCCESS','LOGIN_FAILURE','PASSWORD_CHANGE','LOGOUT','TOKEN_REFRESH','ADMIN_FORCE_LOGOUT','BLOCKED_IP_LOGIN')
                                 ),
                             CONSTRAINT chk_event_result CHECK (
                                 result IN ('SUCCESS','FAIL','BLOCKED_IP','LOCKED','DISABLED')
                                 ),
                             KEY idx_events_user_time (user_id, occurred_at),
                             KEY idx_events_ip_time (ip_bin, occurred_at),
                             KEY idx_events_type_time (event_type, occurred_at),
                             KEY idx_events_request (request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE risk_assessments (
                                  risk_id               BIGINT PRIMARY KEY AUTO_INCREMENT,
                                  event_id              BIGINT NOT NULL,
                                  user_id               BIGINT NULL,
                                  score                 INT NOT NULL,
                                  level                 VARCHAR(8) NOT NULL,
                                  hit_rules             JSON NOT NULL,
                                  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

                                  CONSTRAINT fk_risk_event FOREIGN KEY (event_id) REFERENCES auth_events(event_id),
                                  CONSTRAINT fk_risk_user  FOREIGN KEY (user_id) REFERENCES users(user_id),
                                  CONSTRAINT chk_risk_level CHECK (level IN ('LOW','MED','HIGH')),
                                  KEY idx_risk_level_time (level, created_at),
                                  KEY idx_risk_user_time  (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE admin_actions (
                               action_id             BIGINT PRIMARY KEY AUTO_INCREMENT,
                               admin_user_id         BIGINT NOT NULL,
                               target_user_id        BIGINT NULL,
                               action_type           VARCHAR(32) NOT NULL,
                               reason                VARCHAR(255) NULL,
                               metadata              JSON NULL,
                               admin_ip_bin          VARBINARY(16) NOT NULL,
                               admin_user_agent      VARCHAR(512) NULL,
                               created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

                               CONSTRAINT fk_action_admin  FOREIGN KEY (admin_user_id) REFERENCES users(user_id),
                               CONSTRAINT fk_action_target FOREIGN KEY (target_user_id) REFERENCES users(user_id),
                               CONSTRAINT chk_action_type CHECK (
                                   action_type IN ('LOCK_USER','UNLOCK_USER','FORCE_LOGOUT','BLOCK_IP','UNBLOCK_IP')
                                   ),
                               KEY idx_actions_time (created_at),
                               KEY idx_actions_admin_time (admin_user_id, created_at),
                               KEY idx_actions_target_time (target_user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- (선택) append-only 보호 트리거
DELIMITER $$
CREATE TRIGGER trg_auth_events_no_update
    BEFORE UPDATE ON auth_events
    FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'auth_events is append-only';
END$$

    CREATE TRIGGER trg_auth_events_no_delete
        BEFORE DELETE ON auth_events
        FOR EACH ROW
    BEGIN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'auth_events is append-only';
END$$

        CREATE TRIGGER trg_admin_actions_no_update
            BEFORE UPDATE ON admin_actions
            FOR EACH ROW
        BEGIN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin_actions is append-only';
END$$

            CREATE TRIGGER trg_admin_actions_no_delete
                BEFORE DELETE ON admin_actions
                FOR EACH ROW
            BEGIN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin_actions is append-only';
END$$
                DELIMITER ;