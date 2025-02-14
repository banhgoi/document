PROCEDURE update_invoice (
    p_invoice_type                  IN NUMBER,
    p_payment_invoice_id            IN OUT NUMBER,
    p_payment_amount                IN NUMBER,
    p_invoice_debit                 IN NUMBER,
    p_tax                           IN NUMBER,
    p_amount_not_tax_sum            IN NUMBER,
    p_first_pay_date                OUT DATE,
    p_payment_id                    IN NUMBER,
    p_is_analyze_hang               IN BOOLEAN,
    p_is_analyze_remain             IN BOOLEAN,
    p_payment_type                  IN VARCHAR2,
    p_pay_method_code               IN VARCHAR2,
    p_contract_id                   IN NUMBER,
    p_payment_contract_create_date  IN DATE,
    p_serial_no                     IN VARCHAR2,
    p_block_no                      IN VARCHAR2,
    p_invoice_number                IN VARCHAR2,
    p_invoice_type_id               IN NUMBER,
    p_invoice_list_id               IN NUMBER,
    p_service_types                 IN VARCHAR2,
    p_virtual_invoice_id            IN NUMBER,
    p_charge_invoice_id             IN NUMBER,
    p_cycle_charge_invoice          IN DATE,
    p_applied_cycle                 IN DATE,
    p_applied_cycle_curr            IN DATE,
    p_bill_cycle_from               IN NUMBER,
    p_error                         OUT VARCHAR2
)
IS
    v_from_date         DATE := p_applied_cycle + p_bill_cycle_from - 1;
    v_to_date           DATE := ADD_MONTHS(p_applied_cycle + p_bill_cycle_from - 2, 1);
    v_remain_amount     NUMBER(15,2) := 0;
    v_payment_invoice_id NUMBER(15) := p_payment_invoice_id;
    v_count_update      NUMBER(5) := 0;
    v_virtual_amount_tax NUMBER(15) := 0;
    v_virtual_amount_not_tax NUMBER(15) := 0;
    v_num_print         NUMBER(5) := 0;
    v_payment_type      VARCHAR2(15) := '';
BEGIN
    IF (p_payment_invoice_id IS NULL) THEN
        p_error := 'payment_invoice_id is null';
        RETURN;
    END IF;
    
    IF (p_invoice_type = 2) THEN
        IF (p_payment_amount > 0) THEN
            v_payment_type := 'HDIS';
        END IF;
    END IF;
    
    IF (v_first_pay_date IS NOT NULL) THEN
        UPDATE payment_invoice
        SET payment_amount = NVL(payment_amount, 0) + p_payment_amount
        WHERE payment_invoice_id = p_virtual_invoice_id
        AND create_date = v_first_pay_date;
    ELSE
        INSERT INTO payment_invoice (
            payment_invoice_id, payment_id, contract_id, create_date, serial_no,
            block_no, invoice_number, invoice_no, amount, from_date, to_date,
            status, amount_tax, amount_not_tax, tax, service_types, invoice_type_id,
            invoice_list_id, payment_amount
        )
        VALUES (
            p_virtual_invoice_id, 1, p_contract_id, p_payment_contract_create_date, 
            p_serial_no, p_block_no, p_invoice_number, p_payment_amount,
            v_from_date, v_to_date, '1', v_virtual_amount_tax,
            v_virtual_amount_not_tax, p_tax, p_service_types,
            p_invoice_type_id, p_invoice_list_id, p_payment_amount
        );
    END IF;

    IF (p_is_analyze_remain) THEN
        pck_assign_invoice.insert_charge_invoice (
            p_payment_invoice_id, p_invoice_type, p_amount_tax,
            p_amount_not_tax, p_tax_rate, p_contract_id,
            p_payment_contract_create_date, p_bill_cycle_from,
            p_applied_cycle, p_charge_invoice_id, p_error
        );
    END IF;

    EXCEPTION
    WHEN OTHERS THEN
        p_error := 'Error when update invoice: ' || SQLERRM || CHR(10) || DBMS_UTILITY.format_error_backtrace;
END update_invoice;

/** 
Xác định ngày bắt đầu và kết thúc:

v_from_date và v_to_date được tính toán dựa trên p_applied_cycle và p_bill_cycle_from.
Kiểm tra payment_invoice_id:

Nếu p_payment_invoice_id là NULL, nó sẽ trả về lỗi 'payment_invoice_id is null' và thoát.
Xác định loại hóa đơn (v_payment_type):

Nếu p_invoice_type = 2 và p_payment_amount > 0, thì v_payment_type được gán 'HDIS'.
Cập nhật hóa đơn nếu v_first_pay_date không rỗng:

Nếu v_first_pay_date không NULL, cập nhật bảng payment_invoice với số tiền thanh toán mới.
Chèn hóa đơn mới nếu v_first_pay_date rỗng:

Nếu không có ngày thanh toán đầu tiên, chèn một dòng mới vào bảng payment_invoice với thông tin đầy đủ của hóa đơn.
Thêm khoản phí vào bảng assign_invoice nếu p_is_analyze_remain = TRUE:

Gọi pck_assign_invoice.insert_charge_invoice để gán chi tiết thanh toán vào hóa đơn.
Xử lý ngoại lệ (EXCEPTION HANDLING):

Nếu có lỗi trong quá trình thực thi, thông báo lỗi sẽ được lưu vào p_error và lấy chi tiết từ SQLERRM.
Các procedure và hàm được sử dụng
pck_assign_invoice.insert_charge_invoice:

Thêm dữ liệu vào bảng assign_invoice, có thể liên quan đến việc cập nhật thông tin thanh toán hóa đơn.
DBMS_UTILITY.format_error_backtrace:

Ghi lại chi tiết lỗi SQL khi xảy ra ngoại lệ.
Procedure này chủ yếu xử lý việc cập nhật hoặc chèn mới hóa đơn thanh toán, kết hợp với pck_assign_invoice để xử lý các khoản phí liên quan.

**/