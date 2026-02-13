-- Create Account Table
CREATE TABLE IF NOT EXISTS account (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    balance DECIMAL(19,2),
    UNIQUE (username)
);

-- Create Transaction Table
CREATE TABLE IF NOT EXISTS transaction (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    amount DECIMAL(19,2),
    type VARCHAR(255),
    timestamp DATETIME(6),
    account_id BIGINT,
    FOREIGN KEY (account_id) REFERENCES account(id)
);
