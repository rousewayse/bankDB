--Выбрать всех клиентов по фамилии “Иванов”.
SELECT * FROM clients WHERE fname= 'Иванов';

--Выбрать всех клиентов, проживающих в Москве.
SELECT * FROM clients LEFT JOIN adresses ON clients.adress_id = adresses.id WHERE adresses.city = 'Москва';

--Найти количество открытых после 20 августа 2004 года рублевых счетов.

SELECT COUNT(*) FROM accounts LEFT JOIN currencies ON accounts.ISOnum = currencies.ISOnum WHERE currencies.name = 'RUB' AND accounts.open_date >= "2004-08-21 00:00:00";

--Вывести все счета и количество операций по этим счетам после 01.08.2004.

SELECT accounts.id, COUNT(*) AS AMOUNT FROM accounts LEFT JOIN operations_log ON accounts.id = operations_log.accountid GROUP BY accounts.id; 

--Вывести все операции по рублевым счетам (номер операции, тип операции, сумма операции, дата операции).

SELECT operations_log.id AS NUM, operations_log.optype AS NAME, operations_log.value, operations_log.opdate FROM accounts LEFT JOIN operations_log ON accounts.id = operations_log.accountid LEFT JOIN currencies ON accounts.ISOnum = currencies.ISOnum WHERE currencies.name = 'RUB';

--Вывести клиентов, у которых открыто несколько счетов.

SELECT clients.id,  fname, sname, thname, pass_num FROM clients LEFT JOIN accounts ON clients.id = accounts.client_id GROUP BY clients.id  HAVING COUNT(*) > 1;

--Вывести клиентов, у которых ни на одном счете не осталось средств.

SELECT clients.id,  fname, sname, thname, pass_num FROM clients LEFT JOIN accounts ON clients.id = accounts.client_id WHERE accounts.value = 0.0 GROUP BY clients.id  HAVING COUNT(*) > 1;

--Вывести список населенных пунктов, в которых проживают клиенты банка.

SELECT DISTINCT CONCAT(country, ' ', city) AS HUMAN_SETTLEMENT FROM clients LEFT JOIN adresses ON clients.adress_id = adresses.id;

--Вывести количество открытых счетов для каждой валюты.
SELECT currencies.name AS CURRENCY ,COUNT(*) AS AMOUNT FROM accounts LEFT JOIN currencies ON accounts.ISOnum = currencies.ISOnum GROUP BY currencies.ISOnum;

CREATE TABLE clients (
    id INT UNIQUE NOT NULL AUTO_INCREMENT,
    pass_num INT  NOT NULL CHECK(pass_num >= 0),
    fname VARCHAR(255) NOT NULL CHECK(fname LIKE '^[A-Z][a-z]*$' ), 
    sname VARCHAR(255) NOT NULL CHECK (sname LIKE '^[A-Z][a-z]*$'),
    thname VARCHAR(255) CHECK (thname LIKE '^[A-Z][a-z]*$'),
    adress_id INT,
    PRIMARY KEY (id),
    FOREIGN KEY (adress_id) REFERENCES adresses(id)      
);

CREATE TABLE adresses (
    id INT NOT NULL UNIQUE AUTO_INCREMENT,
    country VARCHAR(255) NOT NULL CHECK(country LIKE '[:alpha:]+'),
    city VARCHAR(255) NOT NULL CHECK(city LIKE '[:alpha:]+'),
    street VARCHAR(255) NOT NULL CHECK (street LIKE '[:alpha:]+'),
    home VARCHAR(255) NOT NULL CHECK (home LIKE '^[1-9]+[\]?[1-9]$'),
    PRIMARY KEY (id)
);

CREATE TABLE currencies (
    ISOnum INT NOT NULL PRIMARY KEY CHECK (ISOnum DIV 1000 = 0), 
    name VARCHAR(3) NOT NULL UNIQUE CHECK (name LIKE '[A-Z]+'),
    weight DOUBLE NOT NULL CHECK (weight>0)
);

CREATE TABLE accounts(
    id INT NOT NULL AUTO_INCREMENT,
    client_id INT NOT NULL REFERENCES clients(id),
    ISOnum INT NOT NULL REFERENCES currencies(ISOnum),
    value DOUBLE NOT NULL, 
    open_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    close_DATA TIMESTAMP DEFAULT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE operations (
    name VARCHAR(255) NOT NULL PRIMARY KEY CHECK(name IN ('addition', 'write-off')),
    symbol VARCHAR(1) NOT NULL CHECK (symbol IN ('+', '-'))
);

CREATE TABLE operations_log (
    id INT PRIMARY KEY NOT NULL AUTO_INCREMENT , 
    accountid INT NOT NULL REFERENCES accounts(id),
    optype VARCHAR(255) NOT NULL REFERENCES opreations(name),
    value DOUBLE NOT NULL, 
    opdate TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
--cascade deletion
CREATE TRIGGER auto_deletion AFTER DELETE ON clients 
FOR EACH ROW 
BEGIN 
DELETE FROM accounts WHERE OLD.id = client_id;
END;


CREATE TRIGGER operations_manager  AFTER INSERT  ON operations_log
FOR EACH ROW 
BEGIN 
    IF NEW.optype = 'addition' THEN 
        UPDATE accounts SET accounts.value = accounts.value + NEW.value WHERE NEW.accountid = accounts.id; 
    END IF;
    IF (NEW.optype = 'write-off') THEN
        UPDATE accounts SET accounts.value = accounts.value - NEW.value WHERE NEW.accountid = accounts.id;
    END IF;
END;

CREATE PROCEDURE Transfer (IN source INT, IN dest INT, IN ante DOUBLE)
LANGUAGE SQL
SQL SECURITY INVOKER
BEGIN 
    INSERT INTO operations_log (accountid, optype, value) VALUES (source, 'wite-off', ante), (dest, 'addition', ante);
    --same as: 
    --UPDATE accounts SET accounts.value = accounts.value - ante WHERE accounts.id = source;
    --UPDATE accounts SET accounts.value = accounts.value + ante WHERE accounts.id = dest;
END;

CREATE PROCEDURE get_debtors ()
BEGIN
    DECLARE cstate, astate INT DEFAULT 1;
    DECLARE cid INT;
    DECLARE f, s, th VARCHAR(255);
    DECLARE names_ CHAR(255);
    DECLARE  clients_ CURSOR  FOR 
        SELECT id, fname, sname, thname FROM clients;
        DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET cstate = 0;
	OPEN clients_;
    DROP TABLE IF EXISTS debtors;
    CREATE TABLE IF NOT EXISTS debtors (
        id INT PRIMARY KEY,
        names VARCHAR(765), 
        account_values TEXT
    );
    WHILE (astate = 1 )
    DO
        label1: BEGIN 
            DECLARE acc_amount, negative_acc, acc_id INT default 0;
            DECLARE val DOUBLE DEFAULT 0.0;
            DECLARE valname CHAR(3);
            DECLARE str CHAR;
            DECLARE  accounts_ CURSOR FOR
            SELECT accounts.id, accounts.value, currencies.name  FROM accounts LEFT JOIN currencies ON currencies.ISOnum = accounts.ISOnum WHERE client_id = cid;
            DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET astate = 0;
	OPEN accounts_;
            FETCH clients_ INTO cid, f, s, th;
            SET names_ = CONCAT(f, ' ',  s, ' ',  th);
            SET acc_amount = (SELECT COUNT(*) FROM accounts WHERE client_id = cid LIMIT 1);
            SET negative_acc = (SELECT COUNT(*) FROM accounts WHERE client_id = cid AND value < 0.0 LIMIT 1);
            IF (acc_amount > 1 AND negative_acc > 0) THEN
            SET str = '';
            WHILE(astate = 1)
            DO
                FETCH accounts_ INTO acc_id, val, valname;
                SET str = CONCAT(str, acc_id, ' (', valname, '): ', val, ' ');
            END WHILE;
            INSERT INTO  debtors (id, names, accounts_values) VALUES (cid, names_, str);
            END IF;
            CLOSE accounts_;
            END label1;
    END WHILE;
    CLOSE clients_;
END;

CREATE FUNCTION get_rate (cid INT) RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE rate DOUBLE DEFAULT 9.0;
    DECLARE min_rate DOUBLE DEFAULT 4.0;
    DECLARE years INT DEFAULT 0;
    SET years = (SELECT YEAR(open_date) AS y FROM accounts WHERE client_id = cid ORDER BY y ASC LIMIT 1 );
    SET years = ABS(years - YEAR(CURRENT_TIMESTAMP));
    SET rate = rate - 0.1*years;
    mid: BEGIN 
        DECLARE state INT DEFAULT 1;
        DECLARE income, outcome, val  DOUBLE DEFAULT 0.0;
        DECLARE operation VARCHAR(255);
        DECLARE ops_ CURSOR FOR
            SELECT ops.value, ops.optype FROM operations_log AS ops LEFT JOIN accounts ON ops.accountid = accounts.id WHERE accounts.client_id = cid AND ABS(YEAR(ops.opdate) - YEAR(CURRENT_TIMESTAMP)) < 3 ;
            DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET state = 0;
            OPEN ops_;
            WHILE (state = 1) 
            DO
                FETCH ops_ INTO val, operation;
                IF(operation = "addition") THEN 
                    SET income = income + val;
                END IF;
                IF (operation = 'write-off') THEN 
                    SET outcome = outcome + val;
                END IF;
            END WHILE;
            CLOSE ops_;
            IF (income DIV outcome > 1) THEN 
                 SET RATE = RATE - 0.1*(income DIV outcome) - 0.1*(income % outcome);
            END IF;
            IF (RATE < min_rate) THEN 
                SET RATE  = 4.0;
            END IF;
    END mid;
    RETURN RATE;
END;

CREATE TRIGGER account_close_checker BEFORE UPDATE on accounts 
FOR EACH ROW 
BEGIN 
    DECLARE rest DOUBLE DEFAULT 0.0;
        DECLARE cacc_id, acc_id, c_id INT;
    IF (NEW.close_DATA != NULL) THEN
        SET cacc_id = (SELECT id FROM accounts WHERE NEW.close_DATA != NULL LIMIT 1);
        SET rest = (SELECT value FROM accounts WHERE id = cacc_id LIMIT 1);
        IF (rest < 0.0) THEN 
            SIGNAL SQLSTATE '42927' SET MESSAGE_TEXT = 'ERROR: BALANCE IS NEGATIVE!';
        END IF;
        IF (rest >0.0) THEN 
            SET c_id = (SELECT client_id FROM accounts WHERE id = cacc_id LIMIT 1);
            SET acc_id = (SELECT id FROM accounts WHERE client_id = c_id AND close_DATA != NULL LIMIT 1);
            IF (acc_id = NULL ) THEN 
                SIGNAL SQLSTATE '42927' SET MESSAGE_TEXT = 'ERROR: NO OTHER ACCOUNTS!';
            END IF;
             INSERT INTO operations_log (accountid, optype, value) VALUES (cacc_id, 'wite-off', rest), (acc_id, 'addition', rest);
        END IF;
    END IF;
END;

