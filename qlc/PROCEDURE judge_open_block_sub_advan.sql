CREATE OR REPLACE PROCEDURE judge_open_block_sub_advan (
    p_check_vip IN NUMBER,
    p_contract_id IN NUMBER,
    p_lst_sub IN payment_sub_table,
    p_applied_cycle IN DATE,
    p_applied_cycle_curr IN DATE,
    p_is_suspend IN NUMBER,
    p_in_hang_time IN BOOLEAN,
    p_bill_cycle_from IN NUMBER,
    p_connection IN NUMBER,
    p_sysdate IN DATE,
    p_user_name IN VARCHAR2,
    p_date_baring_1 IN NUMBER,
    p_date_baring_2 IN NUMBER,
    p_ip IN VARCHAR2
)
IS
    -- Khai báo con trỏ lấy danh sách thuê bao trong hợp đồng được gạch nợ
    CURSOR c_get_sub IS
        SELECT a.sub_id, c.isdn, a.sta_of_cycle, a.payment, a.adjustment_negative,
               a.status, c.act_status, c.sta_datetime, c.adsl_sub_id, c.product_code,
               c.telecom_service_id,
               (SELECT service_types FROM contract WHERE contract_id = p_contract_id) AS service_types,
               d.pay_method_code
        FROM debit_sub a, subscriber c, contract d
        WHERE a.sub_id = c.sub_id
          AND c.contract_id = d.contract_id
          AND c.contract_id = p_contract_id
          AND a.bill_cycle_from = p_bill_cycle_from;
    
    -- Khai báo biến xử lý dữ liệu
    v_payment_sub payment_sub_rec;
    v_sub_iptv_rec sub_iptv_table%ROWTYPE;
    v_need_open NUMBER := 0;
    v_vip_contract NUMBER := 0;
    v_open_status VARCHAR2(2) := '1';
    v_total_bado NUMBER := 0;
    v_current_bado NUMBER := 0;
    v_count_bdd NUMBER := 0;
    v_result NUMBER;
    
BEGIN
    -- Kiểm tra nếu danh sách thuê bao rỗng
    IF p_lst_sub IS NULL THEN
        p_lst_sub := new payment_sub_table();
    END IF;
    
    -- Kiểm tra nếu hợp đồng mới thì thoát
    SELECT COUNT(vc.contract_id) INTO v_count_bdd
    FROM verification_contract vc, verification_management vm
    WHERE vc.verification_mngt_id = vm.verification_mngt_id
      AND vc.contract_id = p_contract_id
      AND vm.status = '1'
      AND vc.verify_status_code = 0
      AND vc.end_date IS NULL;
    
    IF v_count_bdd > 0 THEN
        RETURN;
    END IF;
    
    -- Xử lý danh sách thuê bao
    FOR v_sub IN c_get_sub LOOP
        IF v_sub.status = 3 THEN
            v_open_status := '3';
        END IF;
        
        v_payment_sub := get_accumulate_sub(p_lst_sub, v_sub.sub_id);
        
        -- Tính toán tổng tiền cần thanh toán
        v_current_bado := v_payment_sub.amount_tax + v_payment_sub.amount_not_tax;
        
        IF v_current_bado < v_total_bado THEN
            v_need_open := 1;
        ELSE
            v_need_open := 0;
        END IF;
    END LOOP;
    
    -- Nếu hợp đồng VIP thì đánh dấu thuê bao là VIP
    IF p_check_vip = 1 THEN
        v_vip_contract := pck_payment_util_invoice.check_vip_privilege(p_contract_id, p_applied_cycle_curr);
        
        IF v_vip_contract = 1 THEN
            v_payment_sub.is_vip := 1;
        END IF;
    END IF;
    
    -- Nếu có nhu cầu mở khóa, gọi hàm xử lý mở khóa
    IF v_need_open = 1 THEN
        request_open_block_quota(v_sub.sub_id, v_sub.isdn, v_count_bdd, v_sub.act_status, v_open_status, p_user_name, p_ip, 0);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        IF c_get_sub%ISOPEN THEN
            CLOSE c_get_sub;
        END IF;
        RAISE;
END judge_open_block_sub_advan;

/** 
Phân tích luồng xử lý của procedure judge_open_block_sub_advan
1. Nhận các tham số đầu vào
Procedure nhận vào một loạt tham số liên quan đến hợp đồng (p_contract_id), chu kỳ (p_applied_cycle, p_applied_cycle_curr), thông tin thuê bao (p_lst_sub), trạng thái (p_is_suspend, p_check_vip), và một số thông tin hệ thống (p_sysdate, p_ip).
2. Lấy danh sách thuê bao thuộc hợp đồng
Cursor c_get_sub truy vấn danh sách các thuê bao thuộc hợp đồng cần xử lý.
Thông tin thuê bao bao gồm:
sub_id, isdn, payment, status, act_status, telecom_service_id
Loại hợp đồng (service_types)
Phương thức thanh toán (pay_method_code)
3. Kiểm tra hợp đồng có mới không
Nếu hợp đồng đang trong quá trình xác minh (verification_contract) hoặc chưa kết thúc (end_date IS NULL), procedure dừng (RETURN).
4. Duyệt danh sách thuê bao và xử lý logic
Xác định trạng thái thuê bao:
Nếu status = 3 → Thuê bao bị khóa (v_open_status = '3')
Tính toán số tiền cần thanh toán:
Gọi function get_accumulate_sub để lấy tổng số tiền thuê bao cần thanh toán.
Nếu số tiền này nhỏ hơn tổng tiền v_total_bado, đánh dấu thuê bao cần mở khóa (v_need_open = 1).
5. Kiểm tra hợp đồng có phải VIP không
Nếu p_check_vip = 1, kiểm tra đặc quyền VIP bằng pck_payment_util_invoice.check_vip_privilege
Nếu hợp đồng là VIP (v_vip_contract = 1), đánh dấu thuê bao là VIP.
6. Mở khóa thuê bao nếu cần
Nếu v_need_open = 1, gọi request_open_block_quota để mở khóa thuê bao.
7. Xử lý lỗi
Nếu có lỗi xảy ra, procedure đóng cursor và đưa ra lỗi
**/
