--Выбрать всех клиентов по фамилии “Иванов”.
SELECT * FROM clients WHERE fname= 'Иванов';

--Выбрать всех клиентов, проживающих в Москве.
SELECT * FROM clients LEFT JOIN adresses ON clients.adress_id = adresses.id WHERE adresses.city = 'Москва';

--Найти количество открытых после 20 августа 2004 года рублевых счетов.

SELECT COUNT(*) FROM accounts LEFT JOIN currencies ON accounts.ISOnum = currencies.ISOnum WHERE currencies.name = 'RUB' AND accounts.open_date >= "2004-08-21 00:00:00";

--Вывести все счета и количество операций по этим счетам после 01.08.2004.

SELECT accounts.id, COUNT(*) AS AMOUNT FROM accounts LEFT JOIN operations_log ON accounts.id = operations_log.accountid GROUP BY accounts.id; 

--Вывести все операции по рублевым счетам (номер операции, тип операции, сумма операции, дата операции).

SELECT operations_log.id AS NUM, operations_log.optype AS NAME, operations_log.value FROM accounts LEFT JOIN operations_log ON accounts.id = operations_log.accountid LEFT JOIN currencies ON accounts.ISOnum = currencies.ISOnum WHERE currencies.name = 'RUB';

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

CREATE PROCEDURE Tranfer (IN source INT, IN dest INT, IN ante DOUBLE)
LANGUAGE SQL
SQL SECURITY INVOKER
BEGIN 
    INSERT operations_log (accountid, optype, value) VALUES (source, 'wite-off', ante), (dest, 'addition', ante);
    --same as: 
    --UPDATE accounts SET accounts.value = accounts.value - ante WHERE accounts.id = source;
    --UPDATE accounts SET accounts.value = accounts.value + ante WHERE accounts.id = dest;
END;

CREATE PROCEDURE get_debtors ()
LANGEAGE SQL
SQL SECURITY INVOKER
BEGIN
    DROP TABLE IF EXISTS debtors;
    CREATE TABLE IF NOT EXISTS debtors (
        id INT PRIMARY KEY,
        names VARCHAR(765), 
        account_values CHAR
    );
    DECLARE cstate, astate INT DEFAULT 1;
    DECLARE cid INT;
    DECLARE f, s, th VARCHAR(255);
    DECALE names_ CHAR;
    DECLARE CURSOR clients_ FOR 
        SELECT id, fname, sname, thname FROM clients;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET cstate = 0;
    WHILE (state = 1 )
    DO
        FETCH clients INTO cid, f, s, th;
        SET names_ = CONCAT(f, ' ',  s, ' ',  th);
        DECLARE CURSOR accounts_ FOR
            SELECT value FROM accounts LEFT JOIN WHERE client_id = cid;
        DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET astate = 0;
            DECLARE val DOUBLE 0.0;
            DECLARE str CHAR;
            WHILE(astate = 1)
            DO
                FETCH accounts_ INTO val;
                str = CONCAT 
            END WHILE;
    END WHILE;
END;
