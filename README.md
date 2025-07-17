
# **Dự án "Vulcan" - Hệ thống Tự động Vá lỗi Thông minh**

Chào mừng bạn đến với dự án Vulcan\! Đây là một hệ thống CI/CD được thiết kế để tự động hóa hoàn toàn quy trình vá lỗi bảo mật cho các máy chủ Windows, được xây dựng để đáp ứng và vượt qua các yêu cầu của **VPBank Technology Hackathon 2025 - Challenge \#8**.

## **1. Tổng quan Dự án**

Vulcan là một giải pháp SecOps (Security Operations) hiện đại, giải quyết bài toán vá lỗi bảo mật thủ công, tốn thời gian và dễ xảy ra sai sót. Hệ thống có khả năng:

  * **Tự động phát hiện:** Lấy thông tin về các lỗ hổng và bản vá mới nhất trực tiếp từ API của Microsoft.
  * **Tự động thực thi:** Ra lệnh cài đặt các bản vá cần thiết trên các máy chủ đích một cách an toàn.
  * **Tự động báo cáo:** Tạo ra các báo cáo và nhật ký chi tiết sau mỗi lần chạy.

## **2. Kiến trúc Hệ thống**

Dự án sử dụng một kiến trúc kết hợp, tận dụng điểm mạnh của **GitLab CI/CD** để điều phối và **AWS Systems Manager (SSM)** để thực thi một cách an toàn, tuân thủ các tiêu chuẩn bảo mật trên đám mây.

**Luồng hoạt động chính:**

1.  **Trigger:** Pipeline được kích hoạt trên GitLab (thủ công hoặc theo lịch).
2.  **Dispatch:** GitLab Runner (chạy trên một EC2 instance riêng) nhận lệnh.
3.  **Execution:** Runner sử dụng AWS CLI để ra lệnh cho dịch vụ **AWS Systems Manager (SSM)**.
4.  **Remote & Secure Task:** SSM gửi một "kịch bản" (SSM Document) đến các máy chủ đích. Các máy chủ này tự thực thi kịch bản PowerShell được nhúng sẵn để vá lỗi.

## **3. Công nghệ & Dịch vụ**

  * **CI/CD:** GitLab CI/CD
  * **Cloud Provider:** Amazon Web Services (AWS)
  * **Core Services:** AWS EC2, AWS Systems Manager (SSM), AWS IAM
  * **Scripting:** PowerShell 5.1
  * **Modules:** MsrcSecurityUpdates, kbupdate

## **4. Phân tích các Thành phần Cốt lõi**

### **a. GitLab Pipeline (`.gitlab-ci.yml`)**

Pipeline được thiết kế tinh gọn với một stage và một job duy nhất, thể hiện sự "ủy quyền" thông minh cho AWS.

  * **Stage `deploy`:** Giai đoạn triển khai.
  * **Job `trigger_patching_on_targets`:**
      * **Nhiệm vụ:** Không thực thi logic vá lỗi, mà chỉ thực hiện một lệnh duy nhất: `aws ssm send-command`.
      * **Cấu hình:** Sử dụng các biến môi trường được định nghĩa trong GitLab (như `AWS_REGION`, `TARGET_INSTANCE_IDS`) để truyền tham số cho lệnh AWS CLI.

### **b. AWS Systems Manager (SSM) Document: `Vulcan-Execute-Self-Patching`**

Đây là **"trái tim"** của toàn bộ giải pháp. Thay vì lưu trữ script trong kho mã nguồn và có nguy cơ bị thay đổi, chúng ta nhúng toàn bộ logic PowerShell vào bên trong Document này để đảm bảo tính nhất quán và an toàn.

**Nội dung của script thực hiện các tác vụ sau:**

1.  **Chuẩn bị môi trường:** Tự động cài đặt các module PowerShell `MsrcSecurityUpdates` và `kbupdate`.
2.  **Xử lý môi trường Non-Interactive:** Bao gồm các lệnh sửa lỗi (`Set-PSRepository`) để đảm bảo script không bị dừng lại bởi các câu hỏi xác nhận.
3.  **Lấy dữ liệu:** Tự động xác định hệ điều hành và gọi `Get-MsrcCvrfDocument` để lấy dữ liệu lỗ hổng mới nhất từ API của Microsoft.
4.  **Báo cáo:** Tạo báo cáo HTML chi tiết và lưu vào `C:\temp\reports` trên máy chủ đích.
5.  **Vá lỗi:** Phân tích để tìm và cài đặt bản vá tích lũy mới nhất, sau đó cài đặt nốt các bản vá còn thiếu. Toàn bộ quá trình được ghi lại trong `C:\temp\logs`.

## **5. Hướng dẫn Cài đặt & Vận hành**

### **a. Môi trường AWS**

1.  **Tạo IAM Roles:**
      * `Target-EC2-SSM-Role`: Cấp quyền `AmazonSSMManagedInstanceCore` cho các máy chủ đích.
      * `GitLab-Runner-Role`: Cấp quyền `AmazonSSMFullAccess` cho máy chủ GitLab Runner.
2.  **Tạo EC2 Instances:**
      * Tạo các máy chủ đích (Windows Server) và gắn role `Target-EC2-SSM-Role`.
      * Tạo một máy chủ (Windows Server) để làm GitLab Runner và gắn role `GitLab-Runner-Role`.
3.  **Tạo SSM Document:** Tạo document `Vulcan-Execute-Self-Patching` với nội dung PowerShell đã được cung cấp.

### **b. Môi trường GitLab**

1.  **Cài đặt Git:** Cài đặt Git trên máy chủ GitLab Runner.
2.  **Đăng ký GitLab Runner:**
      * Vào **Settings \> CI/CD \> Runners**, tạo một runner mới (chọn platform `Windows`, thêm tag `windows, pwsh`).
      * Làm theo hướng dẫn để cài đặt và đăng ký runner trên máy chủ EC2 đã chuẩn bị.
      * Chỉnh sửa file `C:\GitLab-Runner\config.toml` và chỉ định `shell = "powershell"`.
3.  **Cấu hình Biến Môi trường:**
      * Vào **Settings \> CI/CD \> Variables**, thêm các biến sau: `AWS_REGION`, `TARGET_INSTANCE_IDS`, `SSM_DOCUMENT_NAME`.

