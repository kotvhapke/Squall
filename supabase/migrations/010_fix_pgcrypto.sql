-- Исправить gen_random_bytes: включить pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;