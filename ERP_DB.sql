-- Database Creation

create database erp;
use erp;

-- Tables Creation

CREATE TABLE ConsumerPort (
    Port_ID VARCHAR(50) PRIMARY KEY,    -- Unique ID for each consumer (Primary Key)
    Password VARCHAR(100) NOT NULL,     -- Password for the consumer
    Location VARCHAR(100) NOT NULL,     -- Consumer location
    Role ENUM('consumer', 'seller') NOT NULL  -- Role of the user (can be either 'consumer' or 'seller')
);

CREATE TABLE SellerPort (
    Port_ID VARCHAR(50) PRIMARY KEY,     -- Unique ID for each seller (Primary Key)
    Password VARCHAR(100) NOT NULL,      -- Password for the seller
    Role ENUM('seller') NOT NULL         -- Role (set to 'seller')
);

CREATE TABLE Products (
    Product_ID INT PRIMARY KEY,    				  -- Unique ID for each product
    Product_Name VARCHAR(100) NOT NULL,           -- Name of the product
    Quantity INT NOT NULL,                        -- Available quantity of the product
    Price DECIMAL(10, 2) NOT NULL                 -- Price of the product (with two decimal points)
);

CREATE TABLE Orders (
    Order_ID INT AUTO_INCREMENT PRIMARY KEY,
    Product_ID INT NOT NULL,
    Consumer_Port_ID VARCHAR(50) NOT NULL,
    Quantity INT NOT NULL,
    Order_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Order_Placed TINYINT(1) DEFAULT 0,          -- 0 = False, 1 = True
    Shipped TINYINT(1) DEFAULT 0,               -- 0 = False, 1 = True
    Out_For_Delivery TINYINT(1) DEFAULT 0,      -- 0 = False, 1 = True
    Delivered TINYINT(1) DEFAULT 0,             -- 0 = False, 1 = True
    CONSTRAINT fk_product FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID),
    CONSTRAINT fk_consumer FOREIGN KEY (Consumer_Port_ID) REFERENCES Consumerport(Port_ID) ON delete cascade
);

CREATE TABLE Reported_Products (
    Report_ID VARCHAR(20) PRIMARY KEY,                                -- Manually generated alphanumeric ID
    Consumer_Port_ID VARCHAR(50) NOT NULL,                            -- Foreign key to ConsumerPort table
    Product_ID INT NOT NULL,                                          -- Foreign key to Products table
    Issue_Type ENUM('damage', 'wrong product', 'delayed', 'missing') NOT NULL,  -- Type of issue
    Solution ENUM('solved', 'pending','solution - replacement','solution - compensation','solution - resend') DEFAULT 'pending',             -- Solution status
    Report_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,                  -- Date of report

    -- Foreign Key constraints with unique names
    CONSTRAINT fk_reported_consumer_port FOREIGN KEY (Consumer_Port_ID) 
        REFERENCES ConsumerPort(Port_ID) ON DELETE CASCADE,           -- Link to ConsumerPort table with cascading delete
    CONSTRAINT fk_reported_product FOREIGN KEY (Product_ID) 
        REFERENCES Products(Product_ID) ON DELETE CASCADE             -- Link to Products table with cascading delete
);

-- Procedures

-- Registration

DELIMITER $$

CREATE PROCEDURE RegisterUser(
    IN p_Port_ID VARCHAR(50),
    IN p_Password VARCHAR(100),
    IN p_Confirm_Password VARCHAR(100),
    IN p_Location VARCHAR(100),
    IN p_Role ENUM('consumer', 'seller')
)
BEGIN
    -- Check if the password and confirm password match
    IF p_Password <> p_Confirm_Password THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Password and Confirm Password do not match';
    ELSE
        -- Insert into the appropriate table based on the role
        IF p_Role = 'consumer' THEN
            INSERT INTO ConsumerPort (Port_ID, Password, Location, Role)
            VALUES (p_Port_ID, p_Password, p_Location, p_Role);
        ELSEIF p_Role = 'seller' THEN
            INSERT INTO SellerPort (Port_ID, Password, Role)
            VALUES (p_Port_ID, p_Password, p_Role);
        ELSE
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Invalid Role';
        END IF;
    END IF;
END $$

DELIMITER ;

-- Login

DELIMITER //

CREATE PROCEDURE LoginUser(
    IN p_Port_ID VARCHAR(50),
    IN p_Password VARCHAR(100),
    IN p_Role ENUM('consumer', 'seller')
)
BEGIN
    DECLARE userExists INT DEFAULT 0;
    
    -- Check based on role
    IF p_Role = 'consumer' THEN
        -- Check if the user exists in ConsumerPort table with the given credentials
        SELECT COUNT(*) INTO userExists
        FROM ConsumerPort
        WHERE Port_ID = p_Port_ID AND Password = p_Password;

        -- If user exists, display the redirect message
        IF userExists = 1 THEN
            SELECT CONCAT('Login successful! Redirecting to ConsumerPort ') AS Message;
        ELSE
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Invalid consumer credentials';
        END IF;

    ELSEIF p_Role = 'seller' THEN
        -- Check if the user exists in SellerPort table with the given credentials
        SELECT COUNT(*) INTO userExists
        FROM SellerPort
        WHERE Port_ID = p_Port_ID AND Password = p_Password;

        -- If user exists, display the redirect message
        IF userExists = 1 THEN
            SELECT CONCAT('Login successful! Redirecting to SellerPort') AS Message;
        ELSE
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Invalid seller credentials';
        END IF;
        
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid role specified';
    END IF;
    
END //

DELIMITER ;

-- Seller Port

DELIMITER //

CREATE PROCEDURE Sellport()
BEGIN
    -- Select all columns from the sellerport table
    SELECT * 
    FROM sellerport;
END //

DELIMITER ;

-- Consumer Port

DELIMITER //

CREATE PROCEDURE Conport()
BEGIN
    -- Select all columns from the consumerport table
    SELECT * 
    FROM consumerport;
END //

DELIMITER ;

-- Add Product

DELIMITER //

CREATE PROCEDURE AddProduct(
    IN p_Product_ID INT,
    IN p_Product_Name VARCHAR(100),
    IN p_Quantity INT,
    IN p_Price DECIMAL(10, 2)
)
BEGIN
    -- Insert a new product into the Products table
    INSERT INTO Products (Product_ID, Product_Name, Quantity, Price)
    VALUES (p_Product_ID, p_Product_Name, p_Quantity, p_Price);
    
    -- Display a message confirming the addition
    SELECT CONCAT('Product ', p_Product_Name, ' has been successfully added with quantity ', p_Quantity, ' and price ', p_Price) AS Message;
	SELECT * FROM Products;
END //

DELIMITER ;

-- Update Product

DELIMITER //

CREATE PROCEDURE UpdateProduct(
    IN p_Product_ID INT,
    IN p_New_Product_Name VARCHAR(100),  -- Can be NULL if not updating the product name
    IN p_New_Quantity INT,               -- Can be NULL if not updating the quantity
    IN p_New_Price DECIMAL(10, 2)        -- Can be NULL if not updating the price
)
BEGIN
    -- Step 1: Update only the fields that are provided, leave others unchanged
    UPDATE Products
    SET 
        Product_Name = COALESCE(p_New_Product_Name, Product_Name),
        Quantity = COALESCE(p_New_Quantity, Quantity),
        Price = COALESCE(p_New_Price, Price)
    WHERE Product_ID = p_Product_ID;

    -- Step 2: Confirm the update with a message
    SELECT * FROM Products WHERE Product_ID = p_Product_ID;
    SELECT CONCAT('Product with ID ', p_Product_ID, ' has been successfully updated.') AS Message;
END //

DELIMITER ;

-- Delete Product

DELIMITER $$

CREATE PROCEDURE DeleteProduct(
    IN p_Product_ID INT
)
BEGIN
    DECLARE productExists INT DEFAULT 0;
    
    -- Check if the product exists with the given Product_ID and Product_Name
    SELECT COUNT(*) INTO productExists
    FROM Products
    WHERE Product_ID = p_Product_ID;
      
    -- If the product exists, proceed with deletion
    IF productExists = 1 THEN
        DELETE FROM Products
        WHERE Product_ID = p_Product_ID;
          
        -- Confirm deletion with a message
        SELECT CONCAT('Product  with ID ', p_Product_ID, ' has been successfully deleted') AS Message;
    ELSE
        -- If no such product exists, return an error message
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No matching product found for deletion';
    END IF;
END $$

DELIMITER ;

-- View Products

DELIMITER //

CREATE PROCEDURE ViewProducts()
BEGIN
    -- Select all columns from the Products table
    SELECT * 
    FROM Products;
END //

DELIMITER ;

-- Place Order

DELIMITER //

CREATE PROCEDURE PlaceOrder(
    IN p_Product_ID INT,
    IN p_Port_ID VARCHAR(50),
    IN p_Quantity INT
)
BEGIN
    DECLARE availableQuantity INT;
    DECLARE userExists INT DEFAULT 0;
    DECLARE productExists INT DEFAULT 0;

    -- Step 1: Verify if the user exists in the ConsumerPort table
    SELECT COUNT(*) INTO userExists
    FROM ConsumerPort
    WHERE Port_ID = p_Port_ID;

    IF userExists = 0 THEN
        -- If the user does not exist, raise an error
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Consumer not found';
    ELSE
        -- Step 2: Verify if the product exists
        SELECT COUNT(*) INTO productExists
        FROM Products
        WHERE Product_ID = p_Product_ID;

        IF productExists = 0 THEN
            -- If the product does not exist, raise an error
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product not found';
        ELSE
            -- Step 3: Fetch available product quantity
            SELECT Quantity INTO availableQuantity
            FROM Products
            WHERE Product_ID = p_Product_ID;

            IF availableQuantity < p_Quantity THEN
                -- If the product does not have enough quantity, raise an error
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient product quantity';
            ELSE
                -- Step 4: Insert the new order into Orders table with 'order_placed' status
                INSERT INTO Orders (Product_ID, Consumer_Port_ID, Quantity, Order_Date, Order_Placed)
                VALUES (p_Product_ID, p_Port_ID, p_Quantity, CURRENT_DATE, '1');

                -- Step 5: Update the product quantity after placing the order
                UPDATE Products
                SET Quantity = Quantity - p_Quantity
                WHERE Product_ID = p_Product_ID;

                -- Step 6: Confirm the order placement and product update with a message
                SELECT CONCAT('Order placed successfully for Product ID ', p_Product_ID, ' by Consumer ', p_Port_ID, '. Product quantity updated.') AS Message;
            END IF;
        END IF;
    END IF;
END //

DELIMITER ;

-- View Order

DELIMITER //

CREATE PROCEDURE ViewOrder(
    IN p_Order_ID INT
)
BEGIN
    DECLARE orderExists INT DEFAULT 0;
    DECLARE statusOrderPlaced INT;
    DECLARE statusShipped INT;
    DECLARE statusOutForDelivery INT;
    DECLARE statusDelivered INT;

    -- Step 1: Check if the order exists
    SELECT COUNT(*)
    INTO orderExists
    FROM Orders
    WHERE Order_ID = p_Order_ID;

    -- Step 2: If no matching order is found, raise an error
    IF orderExists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order not found';
    ELSE
        -- Step 3: Retrieve the current status of the order
        SELECT Order_Placed, Shipped, Out_For_Delivery, Delivered
        INTO statusOrderPlaced, statusShipped, statusOutForDelivery, statusDelivered
        FROM Orders
        WHERE Order_ID = p_Order_ID;

        -- Step 4: Return the current and past statuses of the order without resetting any of them
        SELECT Order_ID, Product_ID, Consumer_Port_ID, Quantity, Order_Date,
               CASE WHEN statusOrderPlaced = 1 THEN '1' ELSE '0' END AS Order_Placed_Status,
               CASE WHEN statusShipped = 1 THEN '1' ELSE '0' END AS Shipped_Status,
               CASE WHEN statusOutForDelivery = 1 THEN '1' ELSE '0' END AS Out_For_Delivery_Status,
               CASE WHEN statusDelivered = 1 THEN '1' ELSE '0' END AS Delivered_Status
        FROM Orders
        WHERE Order_ID = p_Order_ID;
    END IF;
END //

DELIMITER ;

-- Track Order

DELIMITER //

CREATE PROCEDURE TrackOrder(
    IN p_Order_ID INT
)
BEGIN
    DECLARE orderExists INT DEFAULT 0;
    DECLARE statusOrderPlaced INT;
    DECLARE statusShipped INT;
    DECLARE statusOutForDelivery INT;
    DECLARE statusDelivered INT;

    -- Step 1: Check if the order exists
    SELECT COUNT(*)
    INTO orderExists
    FROM Orders
    WHERE Order_ID = p_Order_ID;

    -- Step 2: If no matching order is found, raise an error
    IF orderExists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order not found';
    ELSE
        -- Step 3: Retrieve the current status of the order
        SELECT Order_Placed, Shipped, Out_For_Delivery, Delivered
        INTO statusOrderPlaced, statusShipped, statusOutForDelivery, statusDelivered
        FROM Orders
        WHERE Order_ID = p_Order_ID;

        -- Step 4: Return the current and past statuses of the order without resetting any of them
        SELECT Order_ID, Product_ID, Consumer_Port_ID, Quantity, Order_Date,
               CASE WHEN statusOrderPlaced = 1 THEN '1' ELSE '0' END AS Order_Placed_Status,
               CASE WHEN statusShipped = 1 THEN '1' ELSE '0' END AS Shipped_Status,
               CASE WHEN statusOutForDelivery = 1 THEN '1' ELSE '0' END AS Out_For_Delivery_Status,
               CASE WHEN statusDelivered = 1 THEN '1' ELSE '0' END AS Delivered_Status
        FROM Orders
        WHERE Order_ID = p_Order_ID;
    END IF;
END //

DELIMITER ;

-- Report Product

DELIMITER //

CREATE PROCEDURE ReportProduct(
    IN p_Product_ID INT,
    IN p_Port_ID VARCHAR(50),
    IN p_Issue_Type ENUM('damage', 'wrong product', 'delayed', 'missing')
)
BEGIN
    DECLARE productExists INT DEFAULT 0;
    DECLARE reportID VARCHAR(20);  -- Declare reportID as VARCHAR(20) for manually generated alphanumeric ID
    DECLARE pendingSolution VARCHAR(50);  -- Declare variable to store pending solution text

    -- Step 1: Check if the product exists in the Products table
    SELECT COUNT(*)
    INTO productExists
    FROM Products
    WHERE Product_ID = p_Product_ID;

    -- Step 2: If the product does not exist, raise an error
    IF productExists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Product not found';
    ELSE
        -- Step 3: Generate a random alphanumeric `report_id`
        SET reportID = CONCAT(
            LPAD(CONV(FLOOR(RAND() * 1000000), 10, 36), 6, '0'),
            LPAD(CONV(FLOOR(RAND() * 1000000), 10, 36), 6, '0')
        );

        -- Step 4: Assign the pending solution based on the issue type
        CASE p_Issue_Type
            WHEN 'damage' THEN SET pendingSolution = 'Pending - replacement';
            WHEN 'wrong product' THEN SET pendingSolution = 'Pending - compensation';
            WHEN 'delayed' THEN SET pendingSolution = 'Pending - resend';
            WHEN 'missing' THEN SET pendingSolution = 'Pending - compensation';
        END CASE;

        -- Step 5: Insert the report into the Reported_Products table with the generated reportID and pending solution
        INSERT INTO Reported_Products (Report_ID, Consumer_Port_ID, Product_ID, Issue_Type, Report_Date, Solution)
        VALUES (reportID, p_Port_ID, p_Product_ID, p_Issue_Type, NOW(), pendingSolution);

        -- Step 6: Display the report ID, issue type, and initial pending status
        SELECT CONCAT('Report ID: ', reportID, ', Issue Type: ', p_Issue_Type, ', Solution: ', pendingSolution) AS ReportDetails;
    END IF;
END //

DELIMITER ;

-- View All Orders

DELIMITER //

CREATE PROCEDURE ViewAllOrders()
BEGIN
    -- Select all columns from the Orders table
    SELECT * 
    FROM Orders;
END //

DELIMITER ;

-- View Reported Products

DELIMITER //

CREATE PROCEDURE ViewReportedProducts()
BEGIN
    -- Step 1: Retrieve data from Reported_Products and Products tables
    SELECT 
        rp.Report_ID, 
        rp.Consumer_Port_ID, 
        rp.Product_ID, 
        p.Product_Name, 
        rp.Issue_Type, 
        rp.Solution, 
        rp.Report_Date
    FROM 
        Reported_Products rp
    INNER JOIN 
        Products p
    ON 
        rp.Product_ID = p.Product_ID;

    -- Optional: If there are no reported products, raise a message
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No reported products found';
    END IF;
END //

DELIMITER ;

-- Update Order Status

DELIMITER //

CREATE PROCEDURE UpdateOrderStatus(
    IN p_Order_ID INT,         -- Order ID input to authenticate the order
    IN p_Status VARCHAR(50)    -- Status input ('Order_Placed', 'Shipped', 'Out_For_Delivery', 'Delivered')
)
BEGIN
    -- Declare a variable to check if the order exists
    DECLARE orderExists INT DEFAULT 0;

    -- Step 1: Check if the order exists in the Orders table
    SELECT COUNT(*)
    INTO orderExists
    FROM Orders
    WHERE Order_ID = p_Order_ID;
    
    -- Step 2: If the order does not exist, raise an error
    IF orderExists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order not found';
    ELSE
        -- Step 3: Update the order status based on the input status and reset other statuses to 0
        CASE p_Status
            WHEN 'Order_Placed' THEN
                UPDATE Orders 
                SET Order_Placed = 1, Shipped = 0, Out_For_Delivery = 0, Delivered = 0
                WHERE Order_ID = p_Order_ID;

            WHEN 'Shipped' THEN
                UPDATE Orders 
                SET Order_Placed = 1, Shipped = 1, Out_For_Delivery = 0, Delivered = 0
                WHERE Order_ID = p_Order_ID;

            WHEN 'Out_For_Delivery' THEN
                UPDATE Orders 
                SET Order_Placed = 1, Shipped = 1, Out_For_Delivery = 1, Delivered = 0
                WHERE Order_ID = p_Order_ID;

            WHEN 'Delivered' THEN
                UPDATE Orders 
                SET Order_Placed = 1, Shipped = 1, Out_For_Delivery = 1, Delivered = 1
                WHERE Order_ID = p_Order_ID;

            ELSE
                -- Raise an error if the status input is not valid
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Invalid status value. Valid values are Order_Placed, Shipped, Out_For_Delivery, Delivered';
        END CASE;
        
        -- Step 4: Display a success message after updating the status
        SELECT CONCAT('Order status for Order_ID ', p_Order_ID, ' has been updated to ', p_Status) AS StatusUpdate;
    END IF;
    
END //

DELIMITER ;

-- Handle Issue

DELIMITER //

CREATE PROCEDURE HandleIssue(
    IN p_Report_ID VARCHAR(20),
    IN p_Status ENUM('resolved', 'pending')
)
BEGIN
    DECLARE reportExists INT DEFAULT 0;

    -- Step 1: Check if the report exists
    SELECT COUNT(*)
    INTO reportExists
    FROM Reported_Products
    WHERE Report_ID = p_Report_ID;

    -- Step 2: If the report does not exist, raise an error
    IF reportExists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Report not found';
    ELSE
        -- Step 3: Update the report status based on the input status
        IF p_Status = 'resolved' THEN
            UPDATE Reported_Products
            SET Solution = REPLACE(Solution, 'Pending', 'Resolved')
            WHERE Report_ID = p_Report_ID;
        ELSEIF p_Status = 'pending' THEN
            UPDATE Reported_Products
            SET Solution = REPLACE(Solution, 'Resolved', 'Pending')
            WHERE Report_ID = p_Report_ID;
        END IF;

        -- Step 4: Display a confirmation message
        SELECT CONCAT('Issue ', p_Report_ID, ' marked as ', p_Status) AS ConfirmationMessage;
    END IF;
END //

DELIMITER ;


-- Update Profile

DELIMITER //

CREATE PROCEDURE UpdateProfile(
    IN p_Port_ID VARCHAR(50),
    IN p_New_Password VARCHAR(100),
    IN p_New_Location VARCHAR(100)	
)
BEGIN
    DECLARE userRole ENUM('consumer', 'seller');

    -- Step 1: Check if the user exists and get their current role
    SELECT Role INTO userRole
    FROM ConsumerPort
    WHERE Port_ID = p_Port_ID;

    -- If user is not found in ConsumerPort, check in SellerPort
    IF userRole IS NULL THEN
        SELECT Role INTO userRole
        FROM SellerPort
        WHERE Port_ID = p_Port_ID;
    END IF;

    -- Step 2: If user does not exist, raise an error
    IF userRole IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User not found';
    ELSE
        -- Step 3: Update the user's password and location
        IF userRole = 'consumer' THEN
            UPDATE ConsumerPort
            SET Password = p_New_Password,
                Location = p_New_Location
            WHERE Port_ID = p_Port_ID;
        ELSEIF userRole = 'seller' THEN
            UPDATE SellerPort
            SET Password = p_New_Password
            WHERE Port_ID = p_Port_ID;  -- Sellers do not have a location field
        END IF;

        -- Step 4: Confirm the update with a message
        SELECT CONCAT('Profile for user with Port ID ', p_Port_ID, ' has been successfully updated.') AS Message;
    END IF;
END //

DELIMITER ;

-- Delete Profile

DELIMITER //

CREATE PROCEDURE DeleteProfile(
    IN p_Port_ID VARCHAR(50)
)
BEGIN
    DECLARE userRole ENUM('consumer', 'seller');
    
    -- Step 1: Check if the user exists in ConsumerPort
    SELECT Role INTO userRole
    FROM ConsumerPort
    WHERE Port_ID = p_Port_ID;

    -- If user is not found in ConsumerPort, check in SellerPort
    IF userRole IS NULL THEN
        SELECT Role INTO userRole
        FROM SellerPort
        WHERE Port_ID = p_Port_ID;
    END IF;

    -- Step 2: If user does not exist, raise an error
    IF userRole IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User not found';
    ELSE
        -- Step 3: Delete the user from the respective table
        IF userRole = 'consumer' THEN
            DELETE FROM ConsumerPort
            WHERE Port_ID = p_Port_ID;
        ELSEIF userRole = 'seller' THEN
            DELETE FROM SellerPort
            WHERE Port_ID = p_Port_ID;
        END IF;

        -- Step 4: Confirm the deletion with a message
        SELECT CONCAT('Profile for user with Port ID ', p_Port_ID, ' has been successfully deleted.') AS Message;
    END IF;
END //

DELIMITER ;