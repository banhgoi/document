CREATE OR REPLACE PROCEDURE re_analyze_hang (
    p_contract_id   IN NUMBER,
    p_applied_cycle IN DATE,
    p_bill_cycle_from IN NUMBER,
    p_error OUT VARCHAR2
) IS
    -- Cursor lấy danh sách giao dịch gạch nợ cũ
    CURSOR c_get_old_payment IS
        SELECT ROWID, a.*
        FROM payment_suspend a
        WHERE contract_id = p_contract_id
          AND payment_date > p_applied_cycle + (p_bill_cycle_from - 1)
          AND status = '1'
        ORDER BY payment_id ASC;

    -- Cursor lấy thông tin giao dịch từ payment_contract
    CURSOR c_get_payment_contract (p_payment_id NUMBER, p_create_date DATE) IS
        SELECT * FROM payment_contract
        WHERE payment_id = p_payment_id
          AND create_date = p_create_date
          AND contract_id = p_contract_id
          AND status = '1';

    -- Cursor lấy thông tin giao dịch từ payment_sub
    CURSOR c_get_payment_sub (p_payment_id NUMBER, p_create_date DATE) IS
        SELECT ROWID, a.* FROM payment_sub a
        WHERE payment_id = p_payment_id
          AND create_date = p_create_date
          AND contract_id = p_contract_id
          AND status = '1';

    -- Cursor lấy thông tin chi tiết của payment_sub
    CURSOR c_get_payment_sub_detail (p_payment_id3 NUMBER, p_create_date3 DATE) IS
        SELECT ROWID, a.* FROM payment_sub_detail a
        WHERE payment_id = p_payment_id3
          AND contract_id = p_contract_id
          AND create_date = p_create_date3
          AND status = '1';

    -- Cursor lấy thông tin số tiền treo còn lại của giao dịch
    CURSOR c_get_contract_remain_audit (p_payment_id NUMBER, p_create_date DATE) IS
        SELECT ROWID, a.* FROM contract_remain_audit a
        WHERE payment_id = p_payment_id
          AND create_date = p_create_date
          AND status = 1;

    v_amount_con         NUMBER := 0;
    v_payment_sub_not_tax NUMBER;
    v_count_suspend      NUMBER;
    v_sub_id1            NUMBER;
    v_telecom_service_id1 NUMBER;
    v_count              NUMBER;
    v_amount_sub         NUMBER;
    v_amount_remain      NUMBER := 0;
    v_org_amount         NUMBER;
    v_sys_date           DATE;
    v_result             NUMBER := 0;
BEGIN
    BEGIN
        -- Kiểm tra xem debit_contract có tồn tại không
        SELECT contract_id INTO v_result
        FROM debit_contract
        WHERE contract_id = p_contract_id
          AND bill_cycle = p_applied_cycle
          AND bill_cycle_from = p_bill_cycle_from
        FOR UPDATE NOWAIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_error := 'Không tìm thấy công nợ tháng ' || p_applied_cycle || ' của hợp đồng ' || p_contract_id;
            RAISE;
        WHEN OTHERS THEN
            p_error := 'Công nợ tháng ' || p_applied_cycle || ' của hợp đồng ' || p_contract_id || ' đang được xử lý trong giao dịch khác, vui lòng thử lại sau.';
            RAISE;
    END;

    SELECT SYSDATE INTO v_sys_date FROM DUAL;

    -- Lặp lại danh sách các giao dịch gạch nợ đã bị hủy để reset dữ liệu
    FOR v_old_payment IN c_get_old_payment LOOP
        FOR v_payment_sub IN c_get_payment_sub (v_old_payment.payment_id, v_old_payment.payment_date) LOOP
            UPDATE debit_sub
            SET payment = v_payment_sub.payment_amount
            WHERE contract_id = p_contract_id
              AND sub_id = v_payment_sub.sub_id
              AND bill_cycle = p_applied_cycle
              AND bill_cycle_from = p_bill_cycle_from;

            DELETE FROM payment_sub WHERE ROWID = v_payment_sub.ROWID;
        END LOOP;

        -- Cập nhật số tiền treo nếu có
        FOR v_contract_remain_audit IN c_get_contract_remain_audit (v_old_payment.payment_id, v_old_payment.payment_date) LOOP
            SELECT amount_hang INTO v_org_amount
            FROM contract_remain
            WHERE contract_id = v_contract_remain_audit.contract_id;

            v_amount_remain := v_contract_remain_audit.amount;

            UPDATE contract_remain
            SET amount_hang = amount_hang - v_amount_remain,
                last_modify = v_sys_date
            WHERE contract_id = v_contract_remain_audit.contract_id;

            DELETE FROM contract_remain_audit WHERE ROWID = v_contract_remain_audit.ROWID;
        END LOOP;

        -- Cập nhật công nợ debit_contract
        FOR v_payment_contract IN c_get_payment_contract (v_old_payment.payment_id, v_old_payment.payment_date) LOOP
            UPDATE debit_contract
            SET payment = payment - v_payment_contract.payment_amount + v_amount_remain,
                remain_payment = remain_payment - v_amount_remain
            WHERE contract_id = p_contract_id
              AND bill_cycle = p_applied_cycle
              AND bill_cycle_from = p_bill_cycle_from;
        END LOOP;

        -- Cập nhật chi tiết debit_sub
        FOR v_payment_sub_detail IN c_get_payment_sub_detail (v_old_payment.payment_id, v_old_payment.payment_date) LOOP
            UPDATE debit_sub_detail
            SET debit_amount_tax_hang = debit_amount_tax_hang - v_payment_sub_detail.amount_vat,
                debit_amount_not_tax_hang = debit_amount_not_tax_hang - v_payment_sub_detail.amount_not_vat
            WHERE sub_id = v_payment_sub_detail.sub_id
              AND contract_id = v_payment_sub_detail.contract_id
              AND applied_cycle = ADD_MONTHS(p_applied_cycle, -1)
              AND bill_cycle = v_payment_sub_detail.bill_cycle
              AND bill_cycle_from = v_payment_sub_detail.bill_cycle_from;

            DELETE FROM payment_sub_detail WHERE ROWID = v_payment_sub_detail.ROWID;
        END LOOP;
    END LOOP;

    -- Nếu có lỗi, báo lỗi
    IF (p_error IS NOT NULL) THEN
        RAISE PROGRAM_ERROR;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_error := 'Contract_id=' || p_contract_id || CHR(10);
        p_error := p_error || 'Error:' || SQLERRM || CHR(10);
        p_error := p_error || DBMS_UTILITY.format_error_backtrace;
END re_analyze_hang;

/** 
Phân tích re_analyze_hang
Procedure re_analyze_hang thực hiện việc phân tích lại các giao dịch gạch nợ bị hủy trước đó. Nó thực hiện các bước sau:

Kiểm tra tồn tại debit_contract:

Nếu không tìm thấy dữ liệu công nợ tháng (NO_DATA_FOUND), thông báo lỗi.
Nếu có lỗi khác xảy ra (OTHERS), báo lỗi xử lý giao dịch đồng thời.
Lặp qua các giao dịch payment_suspend đã bị hủy trước đó:

Cập nhật lại dữ liệu debit_sub, xóa dữ liệu cũ từ payment_sub.
Cập nhật số tiền treo còn lại từ contract_remain_audit.
Cập nhật lại công nợ debit_contract.
Cập nhật lại các khoản chi tiết debit_sub_detail.
Xử lý lỗi và ghi log:

Nếu có lỗi xảy ra trong quá trình thực thi, nó sẽ ghi log chi tiết vào p_error.
Các Procedure và Function Được Sử Dụng
c_get_old_payment: Lấy danh sách giao dịch gạch nợ bị hủy.
c_get_payment_contract: Truy vấn thông tin giao dịch từ payment_contract.
c_get_payment_sub: Truy vấn thông tin giao dịch từ payment_sub.
c_get_payment_sub_detail: Lấy chi tiết giao dịch từ payment_sub_detail.
c_get_contract_remain_audit: Kiểm tra số tiền treo còn lại từ contract_remain_audit.
debit_contract, contract_remain, payment_suspend: Cập nhật công nợ, số tiền treo, trạng thái giao dịch.
**/