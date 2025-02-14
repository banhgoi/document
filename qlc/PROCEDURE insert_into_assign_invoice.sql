PROCEDURE insert_into_assign_invoice (
    p_contract_id        IN NUMBER,
    p_assign_type        IN VARCHAR2,
    p_invoice_type       IN VARCHAR2,
    p_payment_id         IN NUMBER,
    p_payment_invoice_id IN NUMBER,
    p_amount_tax         IN NUMBER,
    p_amount_not_tax     IN NUMBER,
    p_adjustment_id      IN NUMBER,
    p_charge_invoice_id  IN NUMBER,
    p_create_date        IN DATE,
    p_bill_cycle_from    IN NUMBER,
    p_applied_cycle      IN DATE,
    p_number_retry       IN NUMBER,
    p_error_log          IN VARCHAR2,
    p_error              OUT VARCHAR2
)
IS
BEGIN
    INSERT INTO bccs_payment.assign_invoice (
        contract_id,
        assign_type,
        invoice_type,
        payment_id,
        payment_invoice_id,
        amount_tax,
        amount_not_tax,
        adjustment_id,
        charge_invoice_id,
        create_date,
        bill_cycle_from,
        applied_cycle,
        number_retry,
        error_log
    ) VALUES (
        p_contract_id,
        p_assign_type,
        p_invoice_type,
        p_payment_id,
        p_payment_invoice_id,
        p_amount_tax,
        p_amount_not_tax,
        p_adjustment_id,
        p_charge_invoice_id,
        p_create_date,
        p_bill_cycle_from,
        p_applied_cycle,
        p_number_retry,
        p_error_log
    );

EXCEPTION
    WHEN OTHERS THEN
        --ROLLBACK; -- vann18 comment
        p_error :=
            'Insert assign invoice fail:Err' || SQLERRM || CHR(10) || DBMS_UTILITY.format_error_backtrace;
END insert_into_assign_invoice;

/**
📌 Phân tích luồng hoạt động của insert_into_assign_invoice
1️⃣ Nhận dữ liệu đầu vào (IN parameters)
Procedure này nhận vào các tham số sau:

p_contract_id: ID hợp đồng cần gán hóa đơn.
p_assign_type: Loại gán hóa đơn.
p_invoice_type: Loại hóa đơn.
p_payment_id: ID của thanh toán.
p_payment_invoice_id: ID của hóa đơn thanh toán.
p_amount_tax, p_amount_not_tax: Giá trị thuế và giá trị không thuế.
p_adjustment_id: ID điều chỉnh.
p_charge_invoice_id: ID hóa đơn thu phí đã tạo.
p_create_date: Ngày tạo hóa đơn.
p_bill_cycle_from: Chu kỳ hóa đơn bắt đầu từ đâu.
p_applied_cycle: Chu kỳ được áp dụng.
p_number_retry: Số lần thử lại.
p_error_log: Log lỗi nếu có.
Ngoài ra, procedure có một tham số đầu ra:

p_error: Trả về thông tin lỗi nếu có.
2️⃣ Chèn dữ liệu vào bảng bccs_payment.assign_invoice
Procedure thực hiện câu lệnh INSERT INTO để lưu dữ liệu vào bảng bccs_payment.assign_invoice.
Cột dữ liệu và giá trị truyền vào tương ứng với các tham số đầu vào.
3️⃣ Xử lý lỗi với EXCEPTION
Nếu có lỗi xảy ra trong quá trình chèn dữ liệu:
Procedure gán giá trị lỗi vào p_error.
Lỗi sẽ chứa nội dung:
sql
Sao chép
Chỉnh sửa
'Insert assign invoice fail:Err' || SQLERRM || CHR(10) || DBMS_UTILITY.format_error_backtrace;
SQLERRM: Trả về thông báo lỗi SQL.
DBMS_UTILITY.format_error_backtrace: Trả về thông tin stack trace của lỗi.
Có một dòng bị comment -- ROLLBACK;, có thể do người viết muốn rollback nhưng chưa kích hoạt rollback thực sự.
📌 Luồng tổng quát của insert_into_assign_invoice
Bước	Mô tả
1️⃣	Nhận tham số đầu vào (thông tin hợp đồng, hóa đơn, số tiền, chu kỳ, v.v.)
2️⃣	Thực hiện INSERT INTO bảng bccs_payment.assign_invoice
3️⃣	Nếu lỗi xảy ra, gán p_error với chi tiết lỗi
4️⃣	Kết thúc procedure, trả về p_error nếu có lỗi
📌 Kết luận
Procedure insert_into_assign_invoice có nhiệm vụ gán hóa đơn thu phí (charge_invoice_id) vào bảng assign_invoice, giúp liên kết thông tin thanh toán với hợp đồng. Nếu quá trình chèn dữ liệu thất bại, procedure sẽ ghi lại lỗi nhưng không rollback giao dịch.
**/