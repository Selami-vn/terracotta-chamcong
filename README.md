# Terracotta · Chấm công nhân sự thời vụ

App chấm công bằng ảnh cho lao động thời vụ / sinh viên làm thêm của Công ty CP Bốn Mùa Tuyền Lâm (Terracotta Hotel & Resort).

## Tính năng

**Nhân viên (giao diện điện thoại, cài được như app)**
- **Đăng nhập bằng số điện thoại** (10 số, bắt đầu bằng 0) + mật khẩu. Quản lý bấm "Quản lý đăng nhập tại đây" để dùng tên đăng nhập.
- **Chấm công**: bấm Chụp ảnh CHECK IN / CHECK OUT bằng camera trước, ảnh đóng dấu tên + ngày giờ. Xem giờ làm hôm nay, các ca gần đây.
- **Lương của tôi**: chọn tháng, xem tổng tiền tạm tính, số ca, tổng giờ, chi tiết từng ca. Thấy sai thì bấm **Báo sai giờ**.
- **Hồ sơ**: xem thông tin của mình, **gửi yêu cầu chỉnh sửa** họ tên, SĐT, số tài khoản, ngân hàng, ảnh hồ sơ (admin duyệt mới đổi), đổi mật khẩu, cài app.
- Nhân viên chỉ thấy dữ liệu của chính mình.

**Quản trị (admin)**
- **Chấm công**: ai đang trong ca, cảnh báo quên check out, lịch sử theo ngày/người, bấm ảnh để so **ảnh gốc hồ sơ ↔ ảnh check in ↔ ảnh check out**. Sửa giờ phải ghi lý do, app lưu lại giờ gốc và người sửa.
- **Bảng lương**: chọn khoảng ngày → ra bảng đúng mẫu "Bảng tính lương sinh viên làm thêm giờ" (có thêm cột giờ vào – ra từng ca), in / lưu PDF, xuất Excel.
- **Yêu cầu**: duyệt / từ chối yêu cầu sửa thông tin và báo sai giờ của nhân viên (so sánh hiện tại ↔ đề nghị, xem lại ảnh ca).
- **Nhân sự**: thêm hàng loạt từ Excel, tạo / sửa / khoá tài khoản, mức tiền công theo giờ, TV/TT, STK, ngân hàng, ảnh gốc hồ sơ, cấp lại mật khẩu.
- **Cài đặt**: thông tin công ty, người ký, quy tắc làm tròn giờ, sao lưu / khôi phục dữ liệu.

## Luật tính công (đổi được trong Cài đặt)

- **Tính theo phút thực tế**, lấy phút đồng hồ lúc chụp: vào 14:45, ra 17:12 → **2h27** → 147 × 35.000 / 60 = **85.750đ**.
- **Giờ chốt ra ca**: Ca 1 chỉ tính công tới **14:00**, Ca 2 tới **22:00**. Ra trễ hơn giờ chốt thì chỉ tính tới giờ chốt; ra sớm hơn thì tính theo thực tế. App vẫn lưu giờ ra thật, bảng lương đánh dấu `*` ở các ca bị chốt.
- **Phân ca**: check in trước 12:00 là Ca 1, từ 12:00 trở đi là Ca 2.
- **Ngoại lệ**: admin mở ca → Sửa → tick "Duyệt tính công quá giờ chốt" (bắt buộc ghi lý do).
- Mức tiền công chốt theo lúc vào ca; đổi mức lương chỉ áp dụng cho ca sau đó.

## Chạy thử bản demo

Mở `index.html` bằng Chrome hoặc Safari (trên máy tính hoặc điện thoại). Đăng nhập lần đầu: bấm **Quản lý đăng nhập tại đây**, nhập `admin` / `admin123`.
Bấm **Tạo dữ liệu mẫu để xem thử** (hoặc Cài đặt → Tạo dữ liệu mẫu): 8 nhân sự giả, chấm công 14 ngày gần nhất. Xem xong bấm **Xoá dữ liệu mẫu** trước khi dùng thật.

> ⚠️ Bản demo lưu dữ liệu **trên trình duyệt của từng máy**. Phù hợp khi dùng 1 máy tính bảng đặt cố định ở bộ phận (kiosk). Muốn nhân sự chấm công bằng điện thoại riêng và admin xem từ máy khác thì cần làm bước "Đưa lên máy chủ" bên dưới.

## Cài app lên điện thoại

- **iPhone**: mở link bằng Safari → nút Chia sẻ → **Thêm vào MH chính**.
- **Android**: mở link bằng Chrome → ⋮ → **Cài đặt ứng dụng** / Thêm vào màn hình chính.
- Lần đầu chụp ảnh, cho phép app dùng Camera.

## Đưa lên GitHub Pages (chỉ là nơi đặt giao diện)

1. Tạo repo **Private** trên GitHub, tải `index.html` lên.
2. Settings → Pages → Deploy from branch → `main` / root. Trang có dạng `https://<tên>.github.io/<repo>/` (HTTPS, camera chạy được).
3. Gói GitHub miễn phí chỉ bật Pages cho repo public. Nếu để public: **tuyệt đối không commit dữ liệu thật** (tên, STK, ảnh). Dữ liệu chỉ nằm trong cơ sở dữ liệu, không nằm trong code.

## Hướng lưu dữ liệu bảo mật (đề xuất: Supabase)

| Tiêu chí | **Supabase** (đề xuất) | Firebase | Google Sheets + Apps Script |
|---|---|---|---|
| Đăng nhập, mật khẩu băm | Có sẵn | Có sẵn | Tự làm, yếu |
| Phân quyền theo từng dòng dữ liệu | Row Level Security trong Postgres | Security Rules | Gần như không có |
| Lưu ảnh riêng tư | Storage private + link có hạn | Storage | Google Drive, dễ lộ link |
| Giờ chấm công lấy từ máy chủ | Có (hàm `now()`) | Có (serverTimestamp) | Có |
| Báo cáo, xuất dữ liệu | SQL, xuất CSV | Khó truy vấn tổng hợp | Dễ xem |
| Chi phí ban đầu | Gói miễn phí đủ cho vài chục người | Gói miễn phí | Miễn phí |

**Vì sao chọn Supabase:** dữ liệu chấm công là dạng bảng (người – ca – giờ – tiền), cần cộng tổng theo ngày, nên cơ sở dữ liệu SQL hợp hơn. Phân quyền viết thẳng trong cơ sở dữ liệu nên kể cả ai đó lấy được code trên GitHub cũng không đọc được dữ liệu của người khác.

### Các lớp bảo mật đã thiết kế trong `supabase-schema.sql`
1. **Mật khẩu**: Supabase Auth băm bcrypt. Không ai xem lại được mật khẩu, kể cả admin. Quên thì admin cấp mật khẩu mới.
2. **Phân quyền (RLS)**: nhân sự chỉ đọc ca và ảnh của chính mình; admin đọc / sửa tất cả. Nhân sự không tự đổi được mức lương hay quyền.
3. **Chống gian lận giờ**: nhân sự không ghi trực tiếp vào bảng ca làm. Check in / out gọi hàm trên máy chủ, giờ lấy bằng đồng hồ máy chủ, không phụ thuộc giờ điện thoại. Mỗi người chỉ có 1 ca mở.
4. **Ảnh**: bucket riêng tư, đường dẫn theo mã người dùng, nhân sự không xoá / thay được ảnh đã chụp.
5. **Nhật ký**: mọi thay đổi ca làm và hồ sơ được ghi vào `audit_log` (ai sửa, lúc nào, trước – sau).
6. **Tắt tự đăng ký**: chỉ admin tạo tài khoản.
7. Trên GitHub chỉ để khoá `anon` công khai (được thiết kế để công khai). **Không bao giờ** đưa khoá `service_role` vào code.

### Việc cần làm tiếp
- [ ] Tạo project Supabase (vùng Singapore cho nhanh), chạy `supabase-schema.sql`.
- [ ] Thay lớp `DB` trong `index.html` bằng gọi Supabase (đăng nhập, `check_in`/`check_out`, tải ảnh lên Storage).
- [ ] Tạo Edge Function cho admin tạo tài khoản / đặt lại mật khẩu (cần khoá service_role nên phải chạy trên máy chủ).
- [ ] Nhập dữ liệu cũ từ file sao lưu JSON của bản demo.
- [ ] (Tuỳ chọn) Ghi toạ độ GPS lúc chấm công, chỉ cho chấm trong bán kính khu resort.
