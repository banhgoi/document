PROCEDURE request_open_block (
    p_sub_id      NUMBER,
    p_isdn        VARCHAR,
    p_bdd         NUMBER,
    p_act_status  VARCHAR,
    p_open_status VARCHAR,
    p_user_name   VARCHAR,
    p_ip          VARCHAR
)
IS
BEGIN
    -- Ghi log kiểm tra mở chặn
    /* INSERT INTO BCCS_PAYMENT.SUB_OPEN_BLOCK_CHECK VALUES (P_SUB_ID, P_BDD); */

    -- Kiểm tra nếu được mở chặn
    IF (p_bdd <= 0)
    THEN
        -- Nếu không phải là BADO
        UPDATE sub_open_block
        SET create_date = SYSDATE,
            act_status  = SUBSTR(p_act_status, 1, 1) || '00'
        WHERE sub_id = p_sub_id
          AND status = 1
          AND open_status IN ('1', '3');

        IF (SQL%ROWCOUNT = 0)
        THEN
            INSERT INTO sub_open_block (
                id, sub_id, isdn, barring_status, create_date, open_status,
                status, retry, act_status, active_type, actual_balance,
                reason_code, user_name, ip
            )
            VALUES (
                sub_open_block_seq.NEXTVAL, p_sub_id, p_isdn, '0', SYSDATE,
                p_open_status, '1', 0, SUBSTR(p_act_status, 1, 1) || '00', 'NC',
                0, 'PAID', p_user_name, p_ip
            );
        END IF;
    ELSE
        -- Nếu là BADO
        UPDATE sub_open_block
        SET active_type = 'BADO',
            create_date = SYSDATE,
            act_status  = SUBSTR(p_act_status, 1, 1) || '00',
            user_name   = p_user_name,
            ip          = p_ip
        WHERE sub_id = p_sub_id
          AND status = 1
          AND open_status IN ('1', '3');

        IF (SQL%ROWCOUNT = 0)
        THEN
            INSERT INTO sub_open_block (
                id, sub_id, isdn, barring_status, create_date, open_status,
                status, retry, act_status, active_type, actual_balance,
                reason_code, user_name, ip
            )
            VALUES (
                sub_open_block_seq.NEXTVAL, p_sub_id, p_isdn, '0', SYSDATE,
                p_open_status, '1', 0, SUBSTR(p_act_status, 1, 1) || '00',
                'BADO', 0, 'PAID', p_user_name, p_ip
            );
        END IF;

        -- Cập nhật trạng thái `red_baring_normal`
        UPDATE billing_import.red_baring_normal a
        SET a.status_barring = '9'
        WHERE a.sub_id = p_sub_id;
    END IF;

EXCEPTION
    WHEN OTHERS
    THEN
        RAISE;
END;
 
/** 
2. Phân tích tổng quan các bước thực hiện
Chức năng chính
PROCEDURE này thực hiện việc mở chặn dịch vụ dựa vào các thông số đầu vào. Cụ thể:

p_sub_id: ID thuê bao
p_isdn: Số thuê bao
p_bdd: Trạng thái chặn dịch vụ (0: không bị chặn, >0: bị chặn)
p_act_status: Trạng thái hành động
p_open_status: Trạng thái mở chặn
p_user_name: Người thực hiện hành động mở chặn
p_ip: IP của người thực hiện
Các bước chính
Ghi log kiểm tra mở chặn (mặc dù bị comment lại)

sql
Sao chép
Chỉnh sửa
/* INSERT INTO BCCS_PAYMENT.SUB_OPEN_BLOCK_CHECK VALUES (P_SUB_ID, P_BDD); */
→ Đây có thể là một bảng log kiểm tra trạng thái chặn của thuê bao trước khi thực hiện mở chặn.

Kiểm tra nếu thuê bao được mở chặn (p_bdd <= 0)

Nếu thuê bao không bị chặn (p_bdd <= 0):
Cập nhật sub_open_block nếu tồn tại.
Nếu không tìm thấy bản ghi (SQL%ROWCOUNT = 0), thêm mới vào bảng sub_open_block.
Gán trạng thái NC (có thể là "Normal Case").
Xử lý nếu thuê bao bị chặn (p_bdd > 0)

Nếu trạng thái là BADO:
Cập nhật trạng thái sub_open_block.
Nếu không có bản ghi, INSERT dữ liệu mới với trạng thái BADO.
Cập nhật trạng thái chặn red_baring_normal bằng cách đặt status_barring = '9'.
Bắt lỗi (EXCEPTION)

Nếu có bất kỳ lỗi nào xảy ra, hệ thống RAISE lỗi để xử lý.
3. Các bảng và PROCEDURE được sử dụng
Bảng liên quan
sub_open_block: Chứa thông tin về trạng thái mở/chặn của thuê bao.
billing_import.red_baring_normal: Chứa trạng thái chặn của thuê bao.
Câu lệnh SQL được sử dụng
UPDATE sub_open_block: Cập nhật trạng thái nếu bản ghi tồn tại.
INSERT INTO sub_open_block: Thêm mới bản ghi nếu không tìm thấy.
UPDATE billing_import.red_baring_normal: Đánh dấu thuê bao là đã được mở chặn.
4. Tổng kết
Mục đích: PROCEDURE request_open_block xử lý việc mở chặn dịch vụ dựa trên trạng thái của thuê bao (p_bdd).
Cách hoạt động:
Nếu thuê bao không bị chặn (p_bdd <= 0): Ghi nhận trạng thái mở chặn vào sub_open_block.
Nếu thuê bao bị chặn (p_bdd > 0): Xử lý cập nhật trạng thái BADO và cập nhật trạng thái red_baring_normal.
Lưu ý: EXCEPTION đảm bảo xử lý lỗi nếu xảy ra trong quá trình cập nhật dữ liệu.
**/