CREATE OR REPLACE PACKAGE BODY "PCK_PAYMENT_UNTUNC"
IS
    -- Purpose: lib for payment sql.

    -- MODIFICATION HISTORY
    -- Person       Date       Comments
    -- Tienph2   20131106    check xem có phải thời điểm treo không

    PROCEDURE vcpayment_untunc (
        p_cust_id IN NUMBER,
        p_payment_amount IN NUMBER,
        p_fee IN NUMBER, -- phí giao dịch
        p_currtype IN VARCHAR2, -- đơn vị tiền tệ
        p_orgamount IN NUMBER, -- giống payment_amount
        p_staff_id IN NUMBER,
        p_receipt_date IN DATE,
        p_invoice_type_id IN VARCHAR2,
        p_serial_no IN VARCHAR2,
        p_block_no IN VARCHAR2,
        p_invoice_number IN VARCHAR2,
        p_connection IN NUMBER,
        p_client_id IN VARCHAR2,
        p_group_id IN NUMBER,
        p_user_name IN VARCHAR2,
        p_payment_type IN VARCHAR2, -- Hình thức thanh toán
        p_error OUT VARCHAR2,
        p_isdn_charge IN VARCHAR2 DEFAULT NULL,
        p_transaction_id IN OUT NUMBER -- QUANHH3 R11673 add
    )
    IS
        v_bill_cycles VARCHAR2(500);
        p_payment_id NUMBER := 0;

        -- NamDX bổ sung thêm tham số này
        v_payment_invoice_id NUMBER;
        v_payment_invoice_create_date DATE;
        v_transaction_id NUMBER(15) := NULL;
        v_payment_id_list pck_payment_lib.payment_id_list := pck_payment_lib.payment_id_list();
    BEGIN
        IF (p_cust_id = 5000604048)
        THEN
            raise_application_error (-20001, 'Fix lỗi với contract_id này');
        END IF;

        bccs_payment.pck_payment_lib.analyze_and_payment (
            p_contract_id => p_cust_id,
            p_payment_amount => p_payment_amount,
            p_currtype => p_currtype,
            p_receipt_date => p_receipt_date,
            p_connection => 0,
            p_client_id => p_client_id,
            p_client_ip => NULL,
            p_payment_type => p_payment_type,
            p_payment_staff_id => p_staff_id,
            p_payment_group_id => p_group_id,
            p_payment_user_name => p_user_name,
            p_insert_staff_id => p_staff_id,
            p_collection_group_id => NULL,
            p_collection_staff_id => NULL,
            p_using_assign_info => FALSE,
            -- Thongtv: 2014-11-03
            p_isdn_charge => p_isdn_charge,
            p_isdn_charge => NULL,
            p_transaction_id => p_transaction_id,
            p_payment_id_list => v_payment_id_list,
            p_error => p_error
        );
    END;
END;

/** 

Phân tích tổng quan về procedure vcpayment_untunc
1. Chức năng
Procedure này phục vụ cho việc xử lý thanh toán (payment sql).
Kiểm tra xem có phải giao dịch bị "treo" hay không và thực hiện một số thao tác liên quan đến thanh toán.
2. Các bước thực hiện
Khai báo các tham số đầu vào

Nhận thông tin về khách hàng (p_cust_id), số tiền thanh toán (p_payment_amount), loại hóa đơn (p_invoice_type_id), số hóa đơn (p_invoice_number), thông tin giao dịch (p_serial_no, p_block_no), người dùng thực hiện (p_user_name), và các tham số khác liên quan đến việc thanh toán.
Khai báo biến nội bộ

v_bill_cycles: Biến lưu trữ thông tin chu kỳ thanh toán.
p_payment_id: ID thanh toán, khởi tạo bằng 0.
v_payment_invoice_id, v_payment_invoice_create_date: Biến lưu thông tin hóa đơn thanh toán.
v_transaction_id: ID giao dịch, mặc định NULL.
v_payment_id_list: Danh sách ID thanh toán sử dụng package pck_payment_lib.payment_id_list().
Kiểm tra hợp lệ của p_cust_id

Nếu p_cust_id = 5000604048, procedure sẽ kích hoạt lỗi bằng raise_application_error (-20001, 'Fix lỗi với contract_id này');.
Đây có thể là một ID đặc biệt cần phải xử lý riêng hoặc một lỗi đã biết trong hệ thống.
Gọi hàm analyze_and_payment từ package pck_payment_lib

Chức năng chính của procedure là gọi bccs_payment.pck_payment_lib.analyze_and_payment, thực hiện quá trình phân tích và thanh toán dựa trên các tham số đã nhận.
Tham số được truyền vào bao gồm:
ID khách hàng, số tiền thanh toán, đơn vị tiền tệ, ngày nhận biên lai (p_receipt_date).
ID nhân viên xử lý, ID nhóm thanh toán (p_payment_group_id).
Các thông tin liên quan đến thanh toán (p_payment_type, p_payment_user_name).
Xử lý giao dịch (p_transaction_id, p_payment_id_list).
Nếu có lỗi, nó sẽ được lưu vào biến p_error.
3. Các procedure và hàm được sử dụng
Procedure/Hàm	Chức năng
raise_application_error (-20001, 'Fix lỗi với contract_id này');	Nếu p_cust_id trùng với giá trị 5000604048, procedure dừng lại và báo lỗi.
bccs_payment.pck_payment_lib.analyze_and_payment	Thực hiện phân tích và xử lý thanh toán.
pck_payment_lib.payment_id_list()	Trả về danh sách ID thanh toán, sử dụng trong v_payment_id_list.
4. Tổng kết
Procedure vcpayment_untunc chủ yếu kiểm tra ID hợp lệ của khách hàng, sau đó gọi procedure analyze_and_payment để xử lý thanh toán.
Nếu có lỗi (ví dụ như ID không hợp lệ), nó sẽ dừng ngay lập tức bằng raise_application_error.
Cấu trúc đơn giản, không có vòng lặp hoặc các thao tác phức tạp, chủ yếu gọi một procedure khác để thực hiện công việc chính.

**/