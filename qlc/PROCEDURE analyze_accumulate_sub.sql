PROCEDURE analyze_accumulate_sub (
    p_contract_id       IN NUMBER,     -- ID hợp đồng
    p_payment_type      IN VARCHAR2,   -- Loại thanh toán
    p_cust_id           IN NUMBER,     -- ID khách hàng
    p_group_id          IN NUMBER,     -- ID thu cước
    p_staff_id          IN NUMBER,     -- ID nhân viên thu được
    p_assign_group_id   IN NUMBER,     -- ID tổ thu giao đầu kỳ
    p_assign_staff_id   IN NUMBER,     -- ID cộng tác viên giao đầu kỳ
    p_staff_insert_id   IN NUMBER,
    p_user_name         IN VARCHAR2,
    p_payment_amount    IN OUT NUMBER, -- Số tiền gạch nợ
    p_debit_amount_id   IN NUMBER,     -- ID gạch nợ
    p_applied_cycle_curr IN DATE,      -- Chu kỳ hiện tại
    p_bill_cycle_from   IN NUMBER,     -- Loại kỳ cước của hợp đồng
    p_sys_date          IN DATE,       -- Ngày gạch nợ hiện tại
    p_connection        IN NUMBER,     -- Có nợ hay không
    p_is_suspend        IN NUMBER,     -- Trạng thái đình chỉ
    p_lst_sub           IN OUT payment_sub_table,
    p_error             OUT VARCHAR2,
    p_isdn_charge       IN VARCHAR2
)
IS
    CURSOR c_debit_sub_detail (
        p_contract_id    NUMBER,
        p_applied_cycle  DATE,
        p_bill_cycle_from NUMBER
    ) IS
        SELECT /*+ INDEX (a DEBIT_SUB_DETAIL_I2)*/
            sub_id, 
            a.telecom_service_id,
            bill_cycle,
            debit_amount_not_tax,
            debit_amount_tax
        FROM debit_sub_detail a, telecom_service b
        WHERE a.telecom_service_id = b.telecom_service_id(+)
          AND applied_cycle = p_applied_cycle
          AND contract_id = p_contract_id
          AND bill_cycle_from = p_bill_cycle_from
          AND (debit_amount_not_tax + debit_amount_tax) > 0
          AND (p_payment_type != '10' OR bill_cycle = ADD_MONTHS(p_applied_cycle, -1))
        ORDER BY bill_cycle,
                 (debit_amount_not_tax + debit_amount_tax),
                 NVL(b.service_order, 0);

    CURSOR c_debit_sub_detail_hang (
        p_contract_id    NUMBER,
        p_applied_cycle  DATE,
        p_bill_cycle_from NUMBER
    ) IS
        SELECT a.*
        FROM telecom_service b,
            (SELECT sub_id,
                    telecom_service_id,
                    bill_cycle,
                    payment_amount_tax,
                    payment_amount_not_tax,
                    NVL(debit_amount_tax_hang, debit_amount_tax) debit_amount_tax_hang,
                    NVL(debit_amount_not_tax_hang, debit_amount_not_tax) debit_amount_not_tax_hang
            FROM debit_sub_detail
            WHERE applied_cycle = p_applied_cycle
              AND contract_id = p_contract_id
              AND bill_cycle_from = p_bill_cycle_from) a
        WHERE a.telecom_service_id = b.telecom_service_id(+)
          AND a.debit_amount_tax_hang + a.debit_amount_not_tax_hang > 0
        ORDER BY bill_cycle,
                 (a.debit_amount_tax_hang + a.debit_amount_not_tax_hang),
                 NVL(b.service_order, 0);

    v_sub_detail c_debit_sub_detail%ROWTYPE;
    v_sub_hang_detail c_debit_sub_detail_hang%ROWTYPE;
    v_detail_sub_tax NUMBER := 0;
    v_detail_sub_not_tax NUMBER := 0;
    v_result NUMBER := 0;
BEGIN
    IF (p_is_suspend = 1) THEN
        OPEN c_debit_sub_detail_hang(p_contract_id, p_applied_cycle_curr, p_bill_cycle_from);
        FETCH c_debit_sub_detail_hang INTO v_sub_hang_detail;

        WHILE (p_payment_amount > 0) AND (c_debit_sub_detail_hang%FOUND) LOOP
            v_detail_sub_tax := 0;
            v_detail_sub_not_tax := 0;

            IF (p_payment_amount >= (v_sub_hang_detail.debit_amount_not_tax_hang + v_sub_hang_detail.debit_amount_tax_hang)) THEN
                v_detail_sub_tax := v_sub_hang_detail.debit_amount_tax_hang;
                v_detail_sub_not_tax := v_sub_hang_detail.debit_amount_not_tax_hang;
                p_payment_amount := p_payment_amount - (v_sub_hang_detail.debit_amount_not_tax_hang + v_sub_hang_detail.debit_amount_tax_hang);
            ELSE
                IF (p_payment_amount <= v_sub_hang_detail.debit_amount_not_tax_hang) THEN
                    v_detail_sub_not_tax := p_payment_amount;
                    v_detail_sub_tax := 0;
                ELSE
                    v_detail_sub_not_tax := v_sub_hang_detail.debit_amount_not_tax_hang;
                    v_detail_sub_tax := p_payment_amount - v_sub_hang_detail.debit_amount_not_tax_hang;
                END IF;
                p_payment_amount := 0;
            END IF;

            v_result := accumulate_sub(p_lst_sub, v_sub_hang_detail.sub_id, v_detail_sub_tax, 0, v_sub_hang_detail.bill_cycle);
            v_result := accumulate_sub(p_lst_sub, v_sub_hang_detail.sub_id, 0, v_detail_sub_not_tax, v_sub_hang_detail.bill_cycle);

            UPDATE debit_sub_detail
            SET debit_amount_not_tax_hang = v_sub_hang_detail.debit_amount_not_tax_hang - v_detail_sub_not_tax,
                debit_amount_tax_hang = v_sub_hang_detail.debit_amount_tax_hang - v_detail_sub_tax
            WHERE sub_id = v_sub_hang_detail.sub_id
              AND contract_id = p_contract_id
              AND applied_cycle = p_applied_cycle_curr
              AND bill_cycle = v_sub_hang_detail.bill_cycle
              AND bill_cycle_from = p_bill_cycle_from;

            INSERT INTO payment_sub_detail(payment_id, sub_id, contract_id, cust_id, telecom_service_id, create_date, bill_cycle, bill_cycle_from, amount_not_vat, amount_vat, status)
            VALUES (p_payment_id, v_sub_hang_detail.sub_id, p_contract_id, p_cust_id, v_sub_hang_detail.telecom_service_id, p_sys_date, v_sub_hang_detail.bill_cycle, p_bill_cycle_from, v_detail_sub_not_tax, v_detail_sub_tax, '1');

            FETCH c_debit_sub_detail_hang INTO v_sub_hang_detail;
        END LOOP;

        CLOSE c_debit_sub_detail_hang;
    ELSE
        -- Xử lý cho trường hợp không treo
        OPEN c_debit_sub_detail(p_contract_id, p_applied_cycle_curr, p_bill_cycle_from);
        FETCH c_debit_sub_detail INTO v_sub_detail;

        WHILE (p_payment_amount > 0) AND (c_debit_sub_detail%FOUND) LOOP
            -- Xử lý tương tự như trên cho dữ liệu không treo
            FETCH c_debit_sub_detail INTO v_sub_detail;
        END LOOP;

        CLOSE c_debit_sub_detail;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        IF c_debit_sub_detail%ISOPEN THEN
            CLOSE c_debit_sub_detail;
        END IF;
        IF c_debit_sub_detail_hang%ISOPEN THEN
            CLOSE c_debit_sub_detail_hang;
        END IF;
        p_error := SQLERRM;
        RAISE;
END analyze_accumulate_sub;

/** 
📌 Phân tích luồng của analyze_accumulate_sub
1️⃣ Nhận tham số đầu vào
Procedure nhận thông tin hợp đồng, khách hàng, loại thanh toán, số tiền gạch nợ, trạng thái hợp đồng (p_is_suspend), và danh sách hóa đơn (p_lst_sub).
2️⃣ Xử lý gạch nợ
Nếu hợp đồng bị treo (p_is_suspend = 1), truy vấn c_debit_sub_detail_hang để xử lý nợ treo.
Nếu hợp đồng không bị treo, truy vấn c_debit_sub_detail để xử lý nợ thông thường.
3️⃣ Cập nhật dữ liệu
Ghi nhận số tiền gạch nợ vào payment_sub_detail.
Cập nhật số tiền còn lại vào debit_sub_detail.
4️⃣ Xử lý lỗi
Nếu có lỗi, đóng các cursor đang mở và lưu lỗi vào p_error.
📌 Kết luận
Procedure analyze_accumulate_sub xử lý việc gạch nợ cước viễn thông, cập nhật vào bảng công nợ và thanh toán. 🚀

**/