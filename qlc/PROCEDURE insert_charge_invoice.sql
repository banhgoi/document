PROCEDURE insert_charge_invoice (p_payment_invoice_id  IN  NUMBER,
                                 p_invoice_type        IN  VARCHAR2,
                                 p_amount_tax          IN  NUMBER,
                                 p_amount_not_tax      IN  NUMBER,
                                 p_tax_rate            IN  NUMBER,
                                 p_contract_id         IN  NUMBER,
                                 p_create_date         IN  DATE,
                                 p_bill_cycle_from     IN  NUMBER,
                                 p_applied_cycle       IN  DATE,
                                 p_charge_invoice_id   OUT NUMBER,
                                 p_error               OUT VARCHAR2)
IS
    CURSOR cursor_temp IS
        SELECT con.contract_id contract_id,
               con.bus_type bus_type,
               con.num_of_subscribers num_of_subs,
               con.payer name,
               con.address address,
               con.pay_area_code pay_area_code,
               con.pay_method_code pay_method_code,
               con.contract_no contract_no,
               (SELECT tin FROM bccs_payment.customer cus WHERE con.cust_id = cus.cust_id) tin,
               (SELECT tel_fax FROM bccs_payment.customer cus WHERE con.cust_id = cus.cust_id) tel_fax,
               NVL((SELECT priv.privilege_level
                    FROM billing_import.privilege_contract priv
                    WHERE priv.status = '1'
                      AND priv.privilege_level <> 5
                      AND con.contract_id = priv.contract_id), '3') privilege_level,
               con.sub_type sub_type,
               con.isdn,
               con.service_types,
               con.email,
               con.tel_mobile,
               con.notice_charge,
               con.bill_cycle_from,
               p_tax_rate tax_rate
        FROM bccs_payment.contract con
        WHERE con.contract_id = p_contract_id;

    v_contract_record cursor_temp%ROWTYPE;
    v_is_valid        BOOLEAN;
    v_charge_invoice_id NUMBER (15);
    v_address          VARCHAR2 (1200);
    v_unit             VARCHAR2 (3000);
    v_cust_type        VARCHAR2 (3);
    v_print_contract_info VARCHAR2 (10);
    v_bill_address     VARCHAR2 (500);
    v_contact_name     VARCHAR2 (500);
    v_name             VARCHAR2 (500);
    v_collection_staff_id NUMBER (15);
    v_collection_staff_name VARCHAR2 (300);
    v_collection_group_id NUMBER (15);
    v_collection_group_name VARCHAR2 (300);
    v_contract_form_mngt VARCHAR2 (10);
    v_contract_form_mngt_group VARCHAR2 (10);
BEGIN
    v_is_valid := TRUE;

    OPEN cursor_temp;
    FETCH cursor_temp INTO v_contract_record;

    IF (cursor_temp%NOTFOUND) THEN
        v_is_valid := FALSE;
    END IF;

    SELECT billing_import.charge_invoice_seq.NEXTVAL INTO v_charge_invoice_id FROM DUAL;

    BEGIN
        SELECT ext_value INTO v_print_contract_info
        FROM bccs_payment.contract_ext
        WHERE contract_id = p_contract_id
          AND ext_key = 'PRINT_CONTRACT_INFO'
          AND type_att = '1';
    EXCEPTION
        WHEN OTHERS THEN v_print_contract_info := '';
    END;

    BEGIN
        SELECT ext_value INTO v_bill_address
        FROM bccs_payment.contract_ext
        WHERE contract_id = p_contract_id
          AND ext_key = 'BILL_ADDRESS'
          AND type_att = '1';
    EXCEPTION
        WHEN OTHERS THEN v_bill_address := '';
    END;

    BEGIN
        SELECT collection_group_id,
               (SELECT name FROM bccs_payment.collection_group c2 WHERE c2.collection_group_id = c1.collection_group_id) collection_group_name,
               collection_staff_id,
               (SELECT name FROM bccs_payment.collection_staff c3 WHERE c3.collection_staff_id = c1.collection_staff_id) collection_staff_name,
               contract_form_mngt,
               contract_form_mngt_group
        INTO v_collection_group_id,
             v_collection_group_name,
             v_collection_staff_id,
             v_collection_staff_name,
             v_contract_form_mngt,
             v_contract_form_mngt_group
        FROM bccs_payment.collection_management c1
        WHERE applied_cycle = p_applied_cycle
          AND contract_id = p_contract_id
          AND ROWNUM = 1;
    EXCEPTION
        WHEN OTHERS THEN
            v_collection_group_id := NULL;
            v_collection_group_name := NULL;
            v_collection_staff_id := NULL;
            v_collection_staff_name := NULL;
            v_contract_form_mngt := NULL;
            v_contract_form_mngt_group := NULL;
    END;

    pck_adjust_general.get_cust_type(p_contract_id, p_contract_id, p_cust_type, v_unit, v_address, p_contact_name, v_name);

    IF (v_cust_type = '0') THEN
        v_unit := NULL;
        v_address := v_contract_record.address;
        v_name := v_contract_record.name;
    END IF;

    IF (v_cust_type = '1') THEN
        v_name := p_contact_name;
    END IF;

    IF (NOT v_is_valid) THEN
        p_error := 'Not found data for charge_invoice';
        RAISE PROGRAM_ERROR;
    END IF;

    IF (v_is_valid) THEN
        INSERT INTO billing_import.charge_invoice (charge_invoice_id,
                                                  contract_id,
                                                  bill_cycle,
                                                  bill_cycle_from,
                                                  sta_date,
                                                  end_date,
                                                  create_date,
                                                  cust_name,
                                                  unit,
                                                  address,
                                                  pay_area_code,
                                                  pay_method,
                                                  amount_not_tax,
                                                  amount_tax,
                                                  tax_rate,
                                                  tax_amount,
                                                  tot_charge,
                                                  invoice_type,
                                                  tin,
                                                  tel_fax,
                                                  privilege_type,
                                                  contract_no,
                                                  isdn,
                                                  contract_form_mngt,
                                                  collection_group_id,
                                                  collection_group_name,
                                                  collection_staff_id,
                                                  collection_staff_name,
                                                  contract_form_mngt_group,
                                                  service_types,
                                                  invoice_list_id,
                                                  invoice_type_id,
                                                  serial_no,
                                                  block_no,
                                                  invoice_num,
                                                  invoice_no,
                                                  cust_type,
                                                  is_payment,
                                                  print_contract_info,
                                                  bill_address,
                                                  status)
        VALUES (v_charge_invoice_id,
                p_contract_id,
                p_applied_cycle,
                v_contract_record.bill_cycle_from,
                p_applied_cycle,
                ADD_MONTHS (p_applied_cycle, 1) + v_contract_record.bill_cycle_from - 1 / 86400,
                p_create_date,
                v_name,
                v_unit,
                v_address,
                v_contract_record.pay_area_code,
                v_contract_record.pay_method_code,
                p_amount_tax,
                ROUND (NVL (p_amount_tax, 0) * v_contract_record.tax_rate / (v_contract_record.tax_rate + 100)),
                p_amount_not_tax,
                v_contract_record.tax_rate,
                ROUND (NVL (p_amount_tax, 0) * v_contract_record.tax_rate / (v_contract_record.tax_rate + 100)),
                p_amount_tax + p_amount_not_tax,
                p_invoice_type,
                v_contract_record.tin,
                v_contract_record.tel_fax,
                v_contract_record.privilege_level,
                v_contract_record.contract_no,
                v_contract_record.isdn,
                v_contract_record.contract_form_mngt,
                v_collection_group_id,
                v_collection_group_name,
                v_collection_staff_id,
                v_collection_staff_name,
                v_contract_form_mngt_group,
                v_contract_record.service_types,
                NULL, NULL, 'ATM', 'ATM', 'ATM', 'ATMATMATM', v_cust_type, 1, v_print_contract_info, v_bill_address, '1');

        p_charge_invoice_id := v_charge_invoice_id;
    END IF;

    UPDATE payment_invoice
    SET charge_invoice_id = v_charge_invoice_id
    WHERE payment_invoice_id = p_payment_invoice_id
      AND create_date = p_create_date;

    IF (sql%ROWCOUNT <> 1) THEN
        p_error := 'Not found record on payment_invoice to assign invoice, payment_invoice_id = ' || p_payment_invoice_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        IF (p_error IS NULL) THEN
            p_error := 'Err:' || SQLERRM || CHR (10) || DBMS_UTILITY.format_error_backtrace;
        ELSE
            p_error := 'Err:' || p_error || CHR (10) || DBMS_UTILITY.format_error_backtrace;
        END IF;
END insert_charge_invoice;

/**
Luồng hoạt động cơ bản của procedure insert_charge_invoice
Procedure này được viết bằng PL/SQL và dùng để tạo một hóa đơn thu phí (charge_invoice) từ thông tin hợp đồng (contract) và cập nhật vào bảng payment_invoice. Dưới đây là các bước chính của nó:

📌 1. Nhận dữ liệu đầu vào (IN parameters)
Procedure nhận vào các tham số đầu vào như:

p_payment_invoice_id: ID của hóa đơn thanh toán.
p_invoice_type: Loại hóa đơn.
p_amount_tax, p_amount_not_tax, p_tax_rate: Các thông tin về thuế.
p_contract_id: ID của hợp đồng liên quan.
p_create_date, p_bill_cycle_from, p_applied_cycle: Thời gian liên quan đến hóa đơn.
Ngoài ra, procedure cũng có hai tham số đầu ra:

p_charge_invoice_id: ID của hóa đơn thu phí vừa tạo.
p_error: Thông báo lỗi nếu có.
📌 2. Truy vấn thông tin hợp đồng (CURSOR cursor_temp)
Procedure mở một CURSOR để truy xuất thông tin hợp đồng từ bảng bccs_payment.contract, bao gồm:

Loại hợp đồng, số lượng người dùng, tên người thanh toán, địa chỉ, mã vùng thanh toán, phương thức thanh toán, số hợp đồng, thuế suất, v.v.
Truy vấn thêm từ bảng bccs_payment.customer để lấy số TIN (tin), số điện thoại (tel_fax).
Lấy thông tin mức đặc quyền (privilege_level) từ bảng billing_import.privilege_contract.
Sau khi truy vấn xong, dữ liệu được lưu vào biến v_contract_record.

📌 3. Kiểm tra hợp đồng có tồn tại không
Nếu không tìm thấy hợp đồng, đặt v_is_valid := FALSE và báo lỗi "Not found data for charge_invoice", thoát khỏi procedure.
📌 4. Sinh mã hóa đơn thu phí (charge_invoice_id)
Lấy ID hóa đơn mới (v_charge_invoice_id) từ sequence billing_import.charge_invoice_seq.NEXTVAL.
📌 5. Lấy thông tin bổ sung
Lấy thông tin in hợp đồng (PRINT_CONTRACT_INFO) từ bảng bccs_payment.contract_ext.
Lấy địa chỉ thanh toán (BILL_ADDRESS) từ bảng bccs_payment.contract_ext.
Lấy thông tin nhóm thu tiền (collection_group_id, collection_staff_id,...) từ bảng bccs_payment.collection_management.
Nếu có lỗi khi truy vấn, gán giá trị mặc định (NULL hoặc '').

📌 6. Xác định loại khách hàng (cust_type)
Gọi procedure pck_adjust_general.get_cust_type để lấy loại khách hàng (v_cust_type) và cập nhật thông tin:
Nếu cust_type = '0' → Dùng địa chỉ từ hợp đồng.
Nếu cust_type = '1' → Dùng tên từ tham số p_contact_name.
📌 7. Chèn dữ liệu vào bảng billing_import.charge_invoice
Nếu dữ liệu hợp lệ, thêm hóa đơn thu phí mới vào bảng billing_import.charge_invoice.
Các giá trị quan trọng được lưu trữ:
Thông tin hợp đồng (contract_id, bill_cycle, pay_area_code, pay_method,...).
Thông tin khách hàng (cust_name, unit, address, isdn, email,...).
Các khoản thuế (amount_tax, amount_not_tax, tax_rate, tot_charge).
Thông tin hóa đơn (invoice_type, invoice_no, status = '1').
📌 8. Cập nhật bảng payment_invoice
Sau khi tạo hóa đơn, procedure cập nhật ID của hóa đơn thu phí (charge_invoice_id) vào bảng payment_invoice dựa trên p_payment_invoice_id và p_create_date.

Nếu không tìm thấy bản ghi để cập nhật, báo lỗi "Not found record on payment_invoice to assign invoice".

📌 9. Xử lý lỗi
Nếu có bất kỳ lỗi nào xảy ra trong quá trình thực thi:
Ghi lỗi vào p_error với chi tiết SQLERRM và DBMS_UTILITY.format_error_backtrace.
Nếu trước đó đã có lỗi, nó sẽ được ghi tiếp vào p_error.
📌 10. Trả về kết quả
Nếu không có lỗi, procedure sẽ trả về p_charge_invoice_id của hóa đơn thu phí mới tạo.
Nếu có lỗi, nó sẽ trả về thông tin lỗi trong p_error.
💡 Tóm tắt luồng hoạt động
Bước	Mô tả
1️⃣	Nhận tham số đầu vào.
2️⃣	Lấy thông tin hợp đồng từ bảng contract.
3️⃣	Kiểm tra hợp đồng có tồn tại không.
4️⃣	Sinh charge_invoice_id mới.
5️⃣	Lấy thông tin bổ sung (print_contract_info, bill_address, collection_info).
6️⃣	Xác định loại khách hàng (cust_type).
7️⃣	Chèn dữ liệu vào bảng billing_import.charge_invoice.
8️⃣	Cập nhật bảng payment_invoice.
9️⃣	Xử lý lỗi nếu có.
🔟	Trả về p_charge_invoice_id hoặc báo lỗi p_error.
📌 Kết luận
Procedure insert_charge_invoice giúp tạo hóa đơn thu phí từ hợp đồng có sẵn, xử lý các thông tin bổ sung và cập nhật lại hệ thống thanh toán. Nếu gặp lỗi (hợp đồng không tồn tại, dữ liệu không hợp lệ, v.v.), nó sẽ ghi nhận lỗi và dừng lại.
**/