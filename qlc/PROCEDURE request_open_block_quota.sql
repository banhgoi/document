PROCEDURE request_open_block_quota (
    p_sub_id        NUMBER,
    p_isdn          VARCHAR,
    p_bdd           NUMBER,
    p_act_status    VARCHAR,
    p_open_status   VARCHAR,
    p_user_name     VARCHAR,
    p_ip            VARCHAR,
    p_open_all      NUMBER  -- 0: theo hướng, 1: mở tất cả, 2: mở nợ, không mở theo hướng
)
IS
    v_active_type   VARCHAR(10) := NULL;
BEGIN
    v_active_type := NULL;

    IF (p_open_all = 0) -- mở chặn theo hướng
    THEN
        v_active_type := 'BDOQUOTA';

        UPDATE sub_open_block
        SET active_type = v_active_type,
            create_date = SYSDATE,
            act_status = p_act_status,
            user_name = p_user_name,
            ip = p_ip
        WHERE sub_id = p_sub_id
          AND status = 1
          AND open_status IN ('1', '3')
          AND active_type = v_active_type;

        IF (SQL%ROWCOUNT = 0) THEN
            INSERT INTO sub_open_block (
                id, sub_id, isdn, barring_status, create_date, open_status, status,
                retry, act_status, active_type, actual_balance, reason_code,
                user_name, ip
            ) VALUES (
                sub_open_block_seq.NEXTVAL, p_sub_id, p_isdn, '0', SYSDATE, p_open_status,
                '1', 0, p_act_status, v_active_type, 0, 'PAID', p_user_name, p_ip
            );
        END IF;

    ELSE
        -- Xử lý mở nợ chặn
        IF (p_bdd < 0) THEN
            IF (p_open_all = 2) THEN -- Không phải BAD0
                v_active_type := 'NCNOBDD';

                UPDATE sub_open_block
                SET create_date = SYSDATE
                WHERE sub_id = p_sub_id
                  AND status = 1
                  AND open_status IN ('1', '3')
                  AND active_type = v_active_type;

            ELSE
                v_active_type := 'NCBDDOQUOTA';

                UPDATE sub_open_block
                SET create_date = SYSDATE,
                    active_type = v_active_type,
                    act_status = SUBSTR(p_act_status, 1, 1) || '00'
                WHERE sub_id = p_sub_id
                  AND status = 1
                  AND open_status IN ('1', '3');
            END IF;

            IF (SQL%ROWCOUNT = 0) THEN
                INSERT INTO sub_open_block (
                    id, sub_id, isdn, barring_status, create_date, open_status, status,
                    retry, act_status, active_type, actual_balance, reason_code,
                    user_name, ip
                ) VALUES (
                    sub_open_block_seq.NEXTVAL, p_sub_id, p_isdn, '0', SYSDATE, p_open_status,
                    '1', 0, SUBSTR(p_act_status, 1, 1) || '00', v_active_type, 0, 'PAID', p_user_name, p_ip
                );
            END IF;

        ELSE
            -- Nếu là BAD0
            UPDATE sub_open_block
            SET active_type = 'BADOALL',
                create_date = SYSDATE,
                act_status = SUBSTR(p_act_status, 1, 1) || '00',
                user_name = p_user_name,
                ip = p_ip
            WHERE sub_id = p_sub_id
              AND status = 1
              AND open_status IN ('1', '3');

            IF (SQL%ROWCOUNT = 0) THEN
                INSERT INTO sub_open_block (
                    id, sub_id, isdn, barring_status, create_date, open_status, status,
                    retry, act_status, active_type, actual_balance, reason_code,
                    user_name, ip
                ) VALUES (
                    sub_open_block_seq.NEXTVAL, p_sub_id, p_isdn, '0', SYSDATE, p_open_status,
                    '1', 0, SUBSTR(p_act_status, 1, 1) || '00', 'BADOALL', 0, 'PAID', p_user_name, p_ip
                );
            END IF;

            -- Cập nhật trạng thái chặn
            UPDATE billing_import.red_baring_normal a
            SET a.status_barring = '9'
            WHERE a.sub_id = p_sub_id;
        END IF;
    END IF;

    -- Cập nhật trạng thái red_baring_item nếu cần
    IF (p_open_all = 0 OR p_open_all = 1) THEN
        UPDATE billing_import.red_baring_item a
        SET a.status_barring = '9'
        WHERE a.sub_id = p_sub_id;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
 
/** 
Phân Tích Tổng Quan Các Bước
1. Xác định kiểu mở chặn (p_open_all)
p_open_all = 0: Mở chặn theo hướng.
p_open_all = 1: Mở tất cả.
p_open_all = 2: Mở nợ nhưng không theo hướng.
2. Nếu mở chặn theo hướng (p_open_all = 0)
Đặt giá trị v_active_type = 'BDOQUOTA'.
Cập nhật bản ghi trong sub_open_block nếu có.
Nếu không có bản ghi phù hợp (SQL%ROWCOUNT = 0), INSERT một bản ghi mới.
3. Nếu mở chặn theo kiểu nợ (p_open_all = 2)
Nếu p_bdd < 0, thực hiện kiểm tra loại nợ:
Nếu không phải BAD0, dùng NCNOBDD hoặc NCBDDOQUOTA:
Cập nhật bản ghi trong sub_open_block.
Nếu không tìm thấy bản ghi (SQL%ROWCOUNT = 0), thực hiện INSERT mới.
Nếu là BAD0:
Đặt trạng thái BADOALL, cập nhật sub_open_block.
Nếu không có bản ghi phù hợp (SQL%ROWCOUNT = 0), INSERT mới.
Cập nhật trạng thái billing_import.red_baring_normal.
4. Cập nhật trạng thái chặn (red_baring_item) nếu cần
Nếu p_open_all = 0 hoặc p_open_all = 1, cập nhật status_barring = '9' trong billing_import.red_baring_item.
5. Bắt ngoại lệ
Nếu có lỗi trong quá trình thực thi, procedure sẽ RAISE lỗi để xử lý bên ngoài.
Các Procedure và Hàm Được Sử Dụng
Tên	Mô tả
sub_open_block_seq.NEXTVAL	Lấy giá trị tiếp theo của sequence để tạo ID mới.
SYSDATE	Lấy thời gian hiện tại của hệ thống.
`SUBSTR(p_act_status, 1, 1)	
SQL%ROWCOUNT	Kiểm tra số bản ghi bị ảnh hưởng sau UPDATE.
Kết Luận
Procedure request_open_block_quota chịu trách nhiệm mở chặn theo hướng hoặc toàn bộ, đồng thời xử lý các trường hợp mở chặn nợ. Nó sử dụng:

Cập nhật (UPDATE) hoặc thêm (INSERT) dữ liệu vào sub_open_block.
Kiểm tra số lượng bản ghi bị ảnh hưởng (SQL%ROWCOUNT) để xác định có cần thêm bản ghi mới không.
Cập nhật trạng thái chặn (billing_import.red_baring_normal và billing_import.red_baring_item) để phản ánh trạng thái mới.
Bắt lỗi (EXCEPTION WHEN OTHERS THEN RAISE) đảm bảo procedure hoạt động ổn định.
**/