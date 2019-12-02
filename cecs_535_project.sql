CREATE DATABASE awnguy01CECS535;
USE awnguy01CECS535;
CREATE TABLE Publisher (
	publisherid INT AUTO_INCREMENT,
    name VARCHAR(255),
    address VARCHAR(255),
    discount FLOAT,
    PRIMARY KEY (publisherid)
);
CREATE TABLE Books (
	isbn VARCHAR(255),
    title VARCHAR(255),
    qty_in_stock INT,
    price FLOAT,
    year_published INT,
    publisherid INT,
    PRIMARY KEY (isbn),
    FOREIGN KEY (publisherid) REFERENCES Publisher(publisherid)
);
CREATE TABLE Author (
	author_id INT AUTO_INCREMENT,
    name VARCHAR(255),
    age INT,
    address VARCHAR(255),
    affiliation VARCHAR(255),
    PRIMARY KEY (author_id)
);
CREATE TABLE Writes (
	author_id INT,
    isbn VARCHAR(255),
    commission FLOAT,
    PRIMARY KEY (author_id, isbn),
    FOREIGN KEY (author_id) REFERENCES Author(author_id),
    FOREIGN KEY (isbn) REFERENCES Books(isbn)
);
CREATE TABLE Sales (
	isbn VARCHAR(255),
    year INT,
    month INT,
    number INT,
    PRIMARY KEY (isbn, year, month),
    FOREIGN KEY (isbn) REFERENCES Books(isbn)
);
DELIMITER $$
CREATE PROCEDURE discount_check_proc(discount FLOAT)
	BEGIN
		IF discount < 1 OR discount > 10
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERROR: discount not between 1-10';
		END IF;
	END;$$
DELIMITER ;
CREATE TRIGGER insert_discount_check
	BEFORE INSERT ON Publisher 
	FOR EACH ROW
    CALL discount_check_proc(NEW.discount);
CREATE TRIGGER update_discount_check
	BEFORE UPDATE ON Publisher
    FOR EACH ROW
    CALL discount_check_proc(NEW.discount);
DELIMITER $$
CREATE PROCEDURE commission_check_proc(author_id VARCHAR(255), isbn VARCHAR(255), commission FLOAT)
	BEGIN
		SET @sum = 0;
		IF commission < 0 OR commission > 100
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERROR: Commission not a valid percentage';
		END IF;
        SELECT SUM(Writes.commission) 
			INTO @sum
			FROM Writes 
			WHERE Writes.isbn = isbn 
				AND author_id <> Writes.author_id
			GROUP BY Writes.isbn;
		IF @sum IS NULL
			THEN SET @sum = 0;
		END IF;
		IF @sum + commission > 100
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERROR: Sum of commissions over 100%';
		END IF;
    END;$$
DELIMITER ;
CREATE TRIGGER insert_commission_check
	BEFORE INSERT ON Writes
    FOR EACH ROW
    CALL commission_check_proc(NEW.author_id, NEW.isbn, NEW.commission);
CREATE TRIGGER update_commission_check
	BEFORE UPDATE ON Writes
    FOR EACH ROW
    CALL commission_check_proc(NEW.author_id, NEW.isbn, NEW.commission);

DELIMITER $$
CREATE PROCEDURE sales_check_proc(number INT)
	BEGIN
		IF number <= 0
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERROR: Invalid number of books sold';
		END IF;
	END;$$
DELIMITER ;
CREATE TRIGGER insert_sales_check
	BEFORE INSERT ON Sales
    FOR EACH ROW
    CALL sales_check_proc(NEW.number);
CREATE TRIGGER update_sales_check
	BEFORE UPDATE ON Sales
    FOR EACH ROW
    CALL sales_check_proc(NEW.number);
INSERT INTO Publisher
	(name, address, discount)
VALUES
	('Leviathan Books', '4523 Locust St. Buffalo, NY 14201', '2.5'),
    ('Excelsior Ltd', '522 Hargrove Ave. Scottsdale, AZ 85054', '1.5'),
    ('First Sight Co', '1394 Piedmont Blvd. Philadelphia, PA 19019', '1.0'),
    ('Jack and Jane Publishing', '111 Hillview Ln. Norfolk, VA 23324', '6.0'),
    ('Monte Publications', '638 Gothe St. Cambridge, MA 02114', '3.5');
INSERT INTO Books
	(isbn, title, qty_in_stock, price, year_published, publisherid)
VALUES
	('0008493847265', 'Secret Heart', 44, 9.99, 2010, 5),
	('0004827364897', 'Chronicles of Swarnia', 45, 11.99, 2008, 1),
	('0001923482019', 'Jim Jam Goes the Zim Zam', 44, 4.99, 2018, 1),
	('0003928401923', 'Light Club', 48, 12.99, 2017, 4),
	('0004720192841', 'The Tale of Twine', 46, 10.99, 1999, 3),
    ('0008674923846', 'Dark Heart', 43, 11.99, 2012, 5);
INSERT INTO Author
	(name, age, address, affiliation)
VALUES
	('George Harkwell', 33, '145 Golding St. Raleigh, NC 27513', null),
	('Jessica Chastain', 23, '6333 Sunmill Ave. Tucson, AZ 85641', 'University of Arizona'),
	('Marwa Spooner', 41, '79 Dunbar St, Carlisle. PA 17013', 'Writer\'s Guild of Pennsylvania'),
	('Kasey Goodwin', 33, '8047 Peg Shop Dr. Hanover Park, IL 60133', null),
	('Eiliyah Ramirez', 25, '506 Bald Hill St, Blackwood, NJ 08012', null),
    ('Joshua Eichenberg', 28, '444 Georges Ln, Helena, MT 59601', null),
    ('Eva Dixon', 31, '44 Stillwater Rd. Blacksburg, VA 24060', null);
INSERT INTO Writes
	(author_id, isbn, commission)
VALUES
	(6, '0004827364897', 100),
 	(3, '0008493847265', 30),
  	(4, '0008493847265', 70),
	(1, '0001923482019', 100),
 	(2, '0004720192841', 100),
    (3, '0008674923846', 100),
 	(5, '0003928401923', 100);
INSERT INTO Sales
	(isbn, year, month, number)
VALUES
	('0008493847265', 2019, 7, 12),
	('0008493847265', 2019, 8, 11),
	('0004827364897', 2019, 7, 10),
	('0004827364897', 2019, 8, 12),
	('0001923482019', 2019, 7, 8),
	('0001923482019', 2019, 8, 12),
	('0003928401923', 2019, 7, 15),
	('0003928401923', 2019, 8, 13),
	('0004720192841', 2019, 7, 18),
    ('0008674923846', 2019, 7, 11),
	('0004720192841', 2019, 8, 15);
DELIMITER $$
CREATE TRIGGER update_inventory
	BEFORE INSERT ON Sales
    FOR EACH ROW
    BEGIN
		IF (SELECT qty_in_stock FROM Books WHERE Books.isbn = NEW.isbn) <= 0
			THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERROR: Not enough quantity in stock to make sale';
		ELSE
		UPDATE Books
			SET qty_in_stock = GREATEST(qty_in_stock - NEW.number, 0)
			WHERE Books.isbn = NEW.isbn;
		END IF;
    END;
$$
DELIMITER ;
CREATE TABLE Royalties (
	author_id INT,
    amount FLOAT,
    PRIMARY KEY (author_id),
    FOREIGN KEY (author_id) REFERENCES Author(author_id)
);

INSERT INTO Royalties
SELECT author_id, ifnull(SUM(royalties), 0) as amount
	FROM (SELECT author_id, (price - discount) * commission / 100 * number as royalties
		FROM (SELECT author_id, v_join_sales.isbn, commission, number, price, publisherid 
			FROM (SELECT author_id, v_join_writes.isbn, commission, number
				FROM (SELECT v_trunc_author.author_id as author_id, isbn, commission
					FROM (SELECT author_id 
							FROM author) as v_trunc_author
					LEFT JOIN (SELECT author_id, isbn, commission
								FROM writes) as v_trunc_writes
					ON v_trunc_author.author_id = v_trunc_writes.author_id) AS v_join_writes
				LEFT JOIN (SELECT isbn, SUM(number) as number
							FROM Sales
                            GROUP BY isbn) as v_trunc_sales
				ON v_join_writes.isbn = v_trunc_sales.isbn) AS v_join_sales
			LEFT JOIN books
				ON v_join_sales.isbn = books.isbn) AS v_join_books
		LEFT JOIN (SELECT publisherid, discount
					FROM publisher) v_trunc_publisher 
			ON v_join_books.publisherid = v_trunc_publisher.publisherid
		GROUP BY author_id, isbn) AS v_royalties_by_isbn
	GROUP BY author_id;
    
DELIMITER $$
CREATE TRIGGER init_royalties_author
	AFTER INSERT ON Author
    FOR EACH ROW
		INSERT INTO Royalties (author_id, amount)
		VALUE (NEW.author_id, 0);
$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER update_royalties_sale
	AFTER INSERT ON Sales
    FOR EACH ROW
			UPDATE Royalties
            INNER JOIN (SELECT author_id, price, discount, commission
				FROM Writes, 
					(SELECT isbn, price, publisherid FROM Books) as v_trunc_books,
					(SELECT publisherid, discount FROM Publisher) as v_trunc_publisher
				WHERE Writes.isbn = NEW.isbn
				AND v_trunc_books.isbn = Writes.isbn
				AND v_trunc_publisher.publisherid = v_trunc_books.publisherid) AS v_join_sales
			SET Royalties.amount = ((price - discount) * commission / 100 * NEW.number) + Royalties.amount
            WHERE Royalties.author_id = v_join_sales.author_id;
$$
DELIMITER ;