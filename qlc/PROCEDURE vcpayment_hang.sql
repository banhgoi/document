PROCEDURE vcpayment_hang (
    p_contract_id    IN NUMBER,
    p_payment_id     IN NUMBER,
    p_payment_date   IN DATE,
    p_error          OUT VARCHAR2
)
IS
    CURSOR c_get_payment_trans IS
        SELECT * FROM payment_contract
        WHERE payment_id = p_payment_id AND create_date = p_payment_date;

    CURSOR c_virtual_invoice (
        p_applied_cycle DATE,
        p_bill_cycle_from NUMBER
    ) IS
        SELECT virtual_invoice_id payment_invoice_id,
               contract_id,
               invoice_no,
               amount_tax,
               amount_not_tax,
               tax,
               amount,
               (amount - NVL(payment_amount, 0)) payment_debit,
               invoice_list_id,
               invoice_type_id,
               charge_invoice_id,
               DECODE(serial_no, 'AO', 'ATM', serial_no) serial_no,
               DECODE(block_no, 'AO', 'ATM', block_no) block_no,
               DECODE(invoice_number, 'AO', 'ATM', invoice_number) invoice_number,
               invoice_number,
               service_types invoice_service_types,
               (CASE WHEN invoice_no = 'AOAOAO' THEN pck_payment_general_invoice.c_invoice_type_virtual
                     ELSE pck_payment_general_invoice.c_invoice_type_printed
               END) invoice_type,
               bill_cycle,
               first_pay_date,
               applied_cycle,
               bill_cycle_from
        FROM virtual_invoice v1
        WHERE amount > NVL(payment_amount, 0)
          AND invoice_type_id IN (SELECT invoice_type_id FROM invoice_type WHERE TYPE = 2 AND status = '1')
          AND applied_cycle = p_applied_cycle
          AND bill_cycle_from = p_bill_cycle_from
          AND contract_id = p_contract_id;

    v_payment_trans c_get_payment_trans%ROWTYPE;
    v_bill_cycle    NUMBER := 0;
    v_applied_cycle DATE;
    v_count_hdis    NUMBER (10);
    v_payment_invoice c_virtual_invoice%ROWTYPE;
    v_amount NUMBER := 0;
    v_charge_invoice_id NUMBER;
    v_new_payment_invoice_id NUMBER;

BEGIN
    OPEN c_get_payment_trans;
    FETCH c_get_payment_trans INTO v_payment_trans;
    IF c_get_payment_trans%NOTFOUND THEN
        p_error := 'Khong tim thay giao dich treo co ma: ' || p_payment_id;
    END IF;
    CLOSE c_get_payment_trans;

    SELECT curr_bill_cycle INTO v_applied_cycle FROM payment_contract WHERE bill_cycle_from = v_payment_trans.bill_cycle_from;

    IF v_payment_trans.payment_invoice_type = 2 OR v_payment_trans.payment_invoice_type = 3 THEN
        v_invoice_type := '2';
    ELSE
        v_invoice_type := '1';
    END IF;

    IF v_invoice_type = '2' THEN
        v_analyze_type := '1';
    ELSE
        v_analyze_type := '2';
    END IF;

    FOR v_virtual_invoice IN c_virtual_invoice (v_applied_cycle, v_payment_trans.bill_cycle_from) LOOP
        EXIT WHEN v_amount <= 0;
        v_count_hdis := v_count_hdis + 1;
        IF v_virtual_invoice.payment_debit < 0 THEN
            p_error := 'Cong no cua hoa don < 0 , check VIRTUAL_INVOICE';
            RAISE PROGRAM_ERROR;
        END IF;

        IF v_amount >= v_virtual_invoice.payment_debit THEN
            v_payment_invoice_tmp := v_virtual_invoice.payment_debit;
        ELSE
            v_payment_invoice_tmp := v_amount;
        END IF;

        UPDATE payment_contract
        SET payment_invoice_id = v_virtual_invoice.payment_invoice_id,
            invoice_type = pck_payment_general_invoice.c_invoice_type_printed,
            payment_amount = v_payment_invoice_tmp
        WHERE payment_id = p_payment_id
          AND create_date = p_payment_date;

        IF SQL%ROWCOUNT <> 1 THEN
            p_error := 'Update payment_contract fail';
            RAISE PROGRAM_ERROR;
        END IF;
    END LOOP;

    IF p_error IS NOT NULL THEN
        RAISE PROGRAM_ERROR;
    END IF;
END vcpayment_hang;

/** 
Tổng quan về Procedure vcpayment_hang
Procedure này có nhiệm vụ xử lý các giao dịch thanh toán treo (pending payments) dựa trên hợp đồng thanh toán (payment_contract). Nó truy vấn dữ liệu từ các bảng payment_contract và virtual_invoice, sau đó thực hiện cập nhật thông tin hóa đơn thanh toán.

1. Các bước thực hiện trong Procedure
Truy vấn thông tin giao dịch thanh toán treo:

Mở cursor c_get_payment_trans để lấy dữ liệu từ bảng payment_contract dựa vào p_payment_id và p_payment_date.
Nếu không tìm thấy giao dịch nào, trả về lỗi "Khong tim thay giao dich treo co ma: ".
Lấy thông tin chu kỳ thanh toán (bill_cycle):

Truy vấn curr_bill_cycle để lấy v_applied_cycle dựa trên bill_cycle_from.
Xác định loại hóa đơn (invoice_type):

Nếu loại hóa đơn thanh toán (payment_invoice_type) là 2 hoặc 3, gán v_invoice_type = '2'.
Ngược lại, gán v_invoice_type = '1'.
Xác định phương thức phân tích (analyze_type):

Nếu v_invoice_type = '2', gán v_analyze_type = '1'.
Nếu v_invoice_type = '1', gán v_analyze_type = '2'.
Duyệt danh sách hóa đơn ảo (virtual_invoice):

Sử dụng cursor c_virtual_invoice để lấy danh sách hóa đơn có liên quan.
Nếu payment_debit < 0, báo lỗi "Cong no cua hoa don < 0" và dừng procedure.
Kiểm tra số tiền cần thanh toán và quyết định số tiền thanh toán cho hóa đơn hiện tại.
Cập nhật dữ liệu trong payment_contract:

Gán payment_invoice_id từ virtual_invoice_id.
Cập nhật số tiền thanh toán (payment_amount) và loại hóa đơn (invoice_type).
Nếu cập nhật thất bại (SQL%ROWCOUNT <> 1), báo lỗi "Update payment_contract fail".
Kiểm tra và xử lý lỗi tổng thể:

Nếu có lỗi phát sinh, dừng procedure và trả về thông báo lỗi.
2. Các CURSOR và Procedure/Hàm được sử dụng
Thành phần	Chức năng
c_get_payment_trans	Lấy thông tin giao dịch từ payment_contract dựa trên p_payment_id.
c_virtual_invoice	Lấy danh sách hóa đơn ảo liên quan đến hợp đồng cần xử lý.
pck_payment_general_invoice.c_invoice_type_virtual	Xác định loại hóa đơn là hóa đơn ảo.
pck_payment_general_invoice.c_invoice_type_printed	Xác định loại hóa đơn là hóa đơn in.
pck_payment_general_invoice.update_invoice	Cập nhật dữ liệu hóa đơn thanh toán.
Tóm tắt
Procedure vcpayment_hang xử lý các giao dịch thanh toán treo.
Nó truy vấn dữ liệu từ payment_contract và virtual_invoice, xác định loại hóa đơn cần xử lý.
Cập nhật thông tin hóa đơn vào payment_contract, đảm bảo không có lỗi xảy ra trong quá trình xử lý.
Các hàm hỗ trợ trong package pck_payment_general_invoice được sử dụng để cập nhật dữ liệu hóa đơn.

**/