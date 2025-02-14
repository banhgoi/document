
PROCEDURE insert_invoice (p_contract_id IN NUMBER,
P_amount_tax IN NUMBER,
p_amount_not_vat IN NUMBER, 
p_remain_amount IN NUMBER, 
p_applied_cycle IN DATE,
p_bill_cycle IN DATE,
p_bill_cycle_from IN NUMBER,
p_adjust_id IN NUMBER,
P_create_date IN DATE,
P_error OUT VARCHAR2
)
IS
v_error  VARCHAR2 (500); 
v_address VARCHAR2 (1200); 
v_unit  VARCHAR2 (3000);
v_cust_type  VARCHAR2 (3);  
v_contact_name VARCHAR2 (500);
v_name VARCHAR2 (500);


CURSOR cursor_temp
IS
SELECT con.contract_id contract_id,
con.bus_type bus_type,
con.num_of_subscribers num_of_subs,
con.payer name,
con.address address,
con.pay_area_code pay_area_code, con.pay_method_code pay_method_code, con.contract_no contract_no, (SELECT tin
FROM bccs_payment.customer cus WHERE con.cust_id = cus.cust_id) 
tin,
(SELECT tel_fax
FROM bccs_payment.customer cus WHERE con.cust_id=cus.cust_id) tel_fax,
NVL ((SELECT priv.privilege_level
>
'3'
FROM billing_import.privilege_contract priv WHERE priv.status = '1'
AND priv.privilege_level <> 5
AND con.contract_id = priv.contract_id),
privilege_level,
con.sub_type sub_type,
con.isdn,
con.service_types,
con.email,
con.tel_mobile,
con.notice_charge,
(SELECT tax
FROM bccs_payment.bus_type bus WHERE bus.bus_type = con.bus_type) tax_rate
FROM bccs_payment.contract con
WHERE con.contract_id = p_contract_id;
v_contract_record
cursor_temp%ROWTYPE;
v_max_bill_cycle DATE := NULL;


BEGIN
OPEN cursor_temp;
FETCH cursor_temp
INTO v_contract_record;
IF (cursor_temp%FOUND)
THEN
BEGIN
IF (p_remain_amount IS NOT NULL AND p_remain_amount > 0) THEN
SELECT NVL ((SELECT MAX (bill_cycle)
FROM bccs_payment.virtual_invoice WHERE contract_id = p_contract_id
AND applied_cycle = p_applied_cycle),
(SELECT MAX (bill_cycle)
FROM bccs_payment.virtual_invoice WHERE contract_id = p_contract_id
AND applied_cycle = ADD_MONTHS (p_applied_cycle, -1))
)
INTO v_max_bill_cycle
FROM DUAL;
END IF;


INSERT INTO adjustment_invoice_applied
(
adjustment_detail_id, contract_id,
applied_cycle,
bill_cycle,
bill_cycle_from,
invoice_list_id,
invoice_type_id,
serial_no,
block_no,
invoice_number,
invoice_no,
amount_tax,
amount_not_tax,
tax_rate,
tax_amount,
tot_charge,
collection_group_id,
collection_staff_id,
is_print )
VALUES (

p_adjust_id, 
p_contract_id, 
p_applied_cycle,
P_bill_cycle, 
p_bill_cycle_from,
NULL,
NULL,
'ATM',
'ATM',
'ATM',
'ATMATMATM',
p_amount_tax,
P_amount_not_vat,
V_contract_record.tax_rate, ROUND( NVL (p_amount_tax, 0) * v_contract_record.tax_rate / (v_contract_record.tax_rate + 100)),
p_amount_tax + p_amount_not_vat,
c_collection_group_id,
c_collection_staff_id,
Ө
);


get_cust_type (p_contract_id => p_contract_id,
p_cust_type => v_cust_type,
p_unit => v_unit,
p_address => v_address,
p_contact_name => v_contact_name
); 
IF (v_cust_type = '0')
THEN
v_unit := NULL;
v_address := v_contract_record.address;
v_name := v_contract_record.name;
END IF;

IF (v_cust_type = '1')
THEN
v_name := v_contact_name;
END IF;


INSERT INTO bccs_payment.adjustment_invoice_bill
(
adjustment_detail_id,
contract_id,
bill_cycle,
bill_cycle_from,
create_date,
cust_name,
unit,
address,
pay_area_code,
pay_method,
amount_tax,
amount_not_tax,
tax_rate,
tax_amount,
tot_charge,
invoice_type,
tin, tel_fax,
privilege_type,
contract_no,
isdn,
contract_form_mngt,
collection_group_id,
collection_group_name,
collection_staff_id,
collection_staff_name,
service_types,
invoice_list_id,
invoice_type_id,
serial_no,
block_no,
invoice_num,
invoice_no,
cust_type,
num_print,
adjustment_remain,
max_virtual_bill_cycle
)


VALUES
p_adjust_id, 
p_contract_id, 
p_bill_cycle, 
p_bill_cycle_from, 
P_create_date,
v_name,
v_unit,
v_address,
v_contract_record.pay_area_code, v_contract_record.pay_method_code,
P_amount_tax,
p_amount_not_vat,
v_contract_record.tax_rate, ROUND( NVL (p_amount_tax, 0) * v_contract_record.tax_rate / (v_contract_record.tax_rate + 100)),
P_amount_tax + p_amount_not_vat,
c_printed_invoice_type,
v_contract_record.tin,
v_contract_record.tel_fax,
v_contract_record.privilege_level,
v_contract_record.contract_no,
v_contract_record.isdn,
NULL,
c_collection_group_id,
c_collection_group_name,
c_collection_staff_id,
c_collection_staff_name,
v_contract_record.service_types,
NULL,
NULL,
'ATM',
'ATM',
'ATM',
'ATMATMATM',
v_cust_type,
0,
p_remain_amount,
v_max_bill_cycle
);
END;

ELSE
p_error := 'Khong tim thay thong tin hop dong contract_id'
|| p_contract_id;
RAISE PROGRAM_ERROR;
END IF;
CLOSE cursor_temp;
EXCEPTION
WHEN OTHERS
THEN

IF (cursor_temp%ISOPEN)
THEN
CLOSE cursor_temp;
END IF;
IF (p_error IS NULL)
THEN
p_error := 
'Err:'
|| SQLERRM
|| CHR (10)
|| DBMS_UTILITY.format_error_backtrace;
ELSE
p_error :=
'Err:'
|| p_error
|| CHR (10)
|| DBMS_UTILITY.format_error_backtrace; END IF;
END;


/** 
Phân tích Procedure insert_invoice
1. Mục đích của Procedure
insert_invoice là một procedure để chèn hóa đơn điều chỉnh (adjustment_invoice) vào hệ thống thanh toán.
Procedure này lấy dữ liệu từ bảng bccs_payment.contract, xử lý thông tin khách hàng, xác định chu kỳ thanh toán và sau đó lưu thông tin vào bảng adjustment_invoice_applied và adjustment_invoice_bill.
2. Danh sách Procedure và Function được gọi
Procedure/Function	Được gọi bởi	Mô tả
get_cust_type	insert_invoice	Lấy thông tin loại khách hàng, đơn vị, địa chỉ và tên liên hệ.
3. Các bước chính trong Procedure
Bước 1: Khai báo biến
Biến xử lý lỗi: v_error
Biến chứa thông tin khách hàng: v_address, v_unit, v_cust_type, v_contact_name, v_name
Biến con trỏ: cursor_temp lấy thông tin hợp đồng từ bảng bccs_payment.contract
Biến chứa chu kỳ thanh toán lớn nhất: v_max_bill_cycle
Bước 2: Truy vấn thông tin hợp đồng (cursor_temp)
Mở cursor cursor_temp để lấy dữ liệu hợp đồng dựa trên p_contract_id.
Các thông tin lấy gồm:
Loại hình kinh doanh, số thuê bao, tên người thanh toán, địa chỉ, mã vùng thanh toán, phương thức thanh toán, mã số thuế (TIN), số fax (TEL_FAX), loại hợp đồng, số ISDN, loại dịch vụ, email, số điện thoại di động, thông tin thông báo thanh toán.
Nếu không tìm thấy dữ liệu hợp đồng, procedure sẽ báo lỗi:
vbnet
Sao chép
Chỉnh sửa
'Khong tim thay thong tin hop dong contract_id' || p_contract_id;
Bước 3: Xác định chu kỳ thanh toán lớn nhất
Nếu số tiền còn lại (p_remain_amount) lớn hơn 0, thì lấy chu kỳ thanh toán (v_max_bill_cycle) gần nhất trong bảng virtual_invoice.
Truy vấn:
sql
Sao chép
Chỉnh sửa
SELECT NVL (
    (SELECT MAX (bill_cycle) FROM bccs_payment.virtual_invoice
     WHERE contract_id = p_contract_id AND applied_cycle = p_applied_cycle),
    (SELECT MAX (bill_cycle) FROM bccs_payment.virtual_invoice
     WHERE contract_id = p_contract_id AND applied_cycle = ADD_MONTHS (p_applied_cycle, -1))
) INTO v_max_bill_cycle FROM DUAL;
Bước 4: Chèn dữ liệu vào adjustment_invoice_applied
Chèn hóa đơn điều chỉnh (adjustment_invoice_applied) với thông tin hợp đồng và số tiền.
Các cột quan trọng:
adjustment_detail_id: ID điều chỉnh.
contract_id: ID hợp đồng.
applied_cycle, bill_cycle, bill_cycle_from: Chu kỳ thanh toán.
invoice_number: ATM
amount_tax, amount_not_tax: Tiền thuế và tiền chưa có thuế.
tax_rate: Lấy từ contract_record.tax_rate.
tax_amount: Được tính bằng công thức:
sql
Sao chép
Chỉnh sửa
ROUND(NVL(p_amount_tax, 0) * v_contract_record.tax_rate / (v_contract_record.tax_rate + 100))
tot_charge: Tổng số tiền phải thanh toán (p_amount_tax + p_amount_not_vat).
Bước 5: Gọi Procedure get_cust_type
Gọi procedure get_cust_type để lấy thông tin khách hàng:
sql
Sao chép
Chỉnh sửa
get_cust_type (
    p_contract_id => p_contract_id,
    p_cust_type => v_cust_type,
    p_unit => v_unit,
    p_address => v_address,
    p_contact_name => v_contact_name
);
Nếu loại khách hàng (v_cust_type) là 0:
Địa chỉ (v_address) lấy từ hợp đồng.
Tên (v_name) lấy từ hợp đồng.
Nếu loại khách hàng (v_cust_type) là 1:
Tên (v_name) lấy từ v_contact_name.
Bước 6: Chèn dữ liệu vào adjustment_invoice_bill
Ghi hóa đơn vào bảng adjustment_invoice_bill.
Các trường quan trọng:
adjustment_detail_id: ID điều chỉnh.
contract_id, bill_cycle, bill_cycle_from: Chu kỳ thanh toán.
create_date: Ngày tạo hóa đơn.
cust_name, unit, address: Thông tin khách hàng.
amount_tax, amount_not_tax, tax_rate, tax_amount, tot_charge: Số tiền thuế và tổng tiền thanh toán.
invoice_type: Loại hóa đơn.
isdn: Số thuê bao.
collection_group_id, collection_group_name, collection_staff_id, collection_staff_name: Nhóm thu tiền.
Bước 7: Xử lý ngoại lệ
Nếu không tìm thấy hợp đồng, procedure sẽ báo lỗi:
sql
Sao chép
Chỉnh sửa
p_error := 'Khong tim thay thong tin hop dong contract_id' || p_contract_id;
RAISE PROGRAM_ERROR;
Nếu có lỗi khi chạy procedure, thì bắt lỗi SQL:
sql
Sao chép
Chỉnh sửa
p_error := 'Err:' || SQLERRM || CHR (10) || DBMS_UTILITY.format_error_backtrace;
4. Sơ đồ quan hệ giữa insert_invoice và các Procedure khác
css
Sao chép
Chỉnh sửa
insert_invoice
│
├── cursor_temp (truy vấn thông tin hợp đồng)
├── get_cust_type (Lấy thông tin khách hàng)
├── adjustment_invoice_applied (Chèn dữ liệu hóa đơn điều chỉnh)
└── adjustment_invoice_bill (Ghi nhận hóa đơn vào hệ thống)
5. Tổng kết
Tóm tắt các bước thực hiện
Lấy thông tin hợp đồng từ bảng bccs_payment.contract.
Xác định chu kỳ thanh toán lớn nhất từ bccs_payment.virtual_invoice.
Chèn hóa đơn điều chỉnh vào adjustment_invoice_applied.
Gọi get_cust_type để lấy thông tin khách hàng.
Chèn hóa đơn vào adjustment_invoice_bill.
Bắt lỗi nếu có sai sót.
Những điểm quan trọng
Procedure này chỉ hoạt động nếu tìm thấy hợp đồng (contract_id).
Có bước tính toán thuế và tổng tiền (tax_amount, tot_charge).
Dữ liệu được chèn vào 2 bảng chính:
adjustment_invoice_applied
adjustment_invoice_bill
Procedure get_cust_type được gọi để lấy thông tin khách hàng.


**/