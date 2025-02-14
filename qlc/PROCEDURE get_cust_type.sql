PROCEDURE get_cust_type (p_contract_id IN NUMBER,
P_cust_type OUT VARCHAR2, P_unit OUT VARCHAR2, p_address OUT VARCHAR2, p_contact_name OUT VARCHAR2
>
IS
CURSOR cursor_temp
IS
SELECT contract_id, cust_id
FROM bccs_payment.contract a,
bccs_payment.sub_type s,
bccs_payment.bus_type b
WHERE s.sub_type(+) a.sub_type AND b.bus_type = a.bus_type AND ((a.sub_type IS NULL AND b.name LIKE 'DN%')
OR (s.cust_type = '1')
OR b.name LIKE 'DN%')
AND a.contract_id
v_contract_id
v_address
v_unit
v_cust_id
NUMBER (15);
p_contract_id;
VARCHAR2 (1200);
VARCHAR2 (3000);
v_contact_name
BEGIN
OPEN cursor_temp;
FETCH cursor_temp
NUMBER (15);
VARCHAR2 (120);
INTO v_contract_id, v_cust_id;
IF (cursor_temp%FOUND)
THEN
--
khach hang doanh nghiep
P_cust_type
BEGIN
:= '1';
SELECT address, name
INTO v_address, v_unit
FROM bccs_payment.customer WHERE cust_id = v_cust_id;
EXCEPTION
WHEN OTHERS
THEN
NULL;
END;
P_unit P_address
:= v_unit; := v_address;
BEGIN
SELECT contact_name
INTO v_contact_name
FROM bccs_payment.contract
WHERE contract_id = v_contract_id;
EXCEPTION
WHEN OTHERS
THEN
NULL;
END;
P_contact_name
ELSE
:= v_contact_name;
P_cust_type := '0'.
END IF;
CLOSE cursor_temp;
EXCEPTION
WHEN OTHERS
THEN
IF (cursor_temp%ISOPEN)
THEN
CLOSE cursor_temp;
END IF;
P_cust_type
:= '0';
END;